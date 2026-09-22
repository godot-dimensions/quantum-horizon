@tool
extends Node4D

## A crow that perches, looks about, and flies off again.
##
## BUILT THE WAY THE CAT IS, which is the way the chicken and the sauropod are: one loft
## rig whose spine runs nose to tail as DIRECT children, with the legs hanging off it as
## branch balls. That is the pipeline this project already has, and reusing it means the
## bird gets the same tapered surface and the same tooling as everything else in the field.
##
## THE WINGS ARE NOT PART OF THE HIDE, and that is the one real departure. A loft rig
## builds a single skin over a chain of balls and nothing animates it but the walkers; a
## wing has to beat several times a second through ninety degrees or more. So each wing is
## a pivot with three tapering boxes on it - the same trick the cat's ears use, for the
## same reason: a loft cannot make the shape and cannot move it this fast.
##
## THE LEGS ARE NOT WALKED. strider_walker plants feet and carries a body forward off
## them, which is exactly wrong for an animal that spends its time either standing still
## or not touching the ground at all. The legs are posed - folded in flight, down on the
## perch - and the bird is moved by its own flight path.
##
## FLIGHT IS FOUR STATES AND ONE CURVE. Perched, taking off, flying, landing. Everything
## interesting is in how the wings and the body angle relate to what the bird is doing:
## hard deep beats climbing, shallow beats with glides between them cruising, and a flare
## - wings wide, nose up, legs down - on the way in. A bird that flaps at one rate the
## whole time reads as a toy.

const RIG := preload("res://ramon/chickenpen/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/chickenpen/scripts/loft_ball_4d.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

## Beak to tail, in world units. A crow beside a 1.5-unit person.
## Its own seed. THREE CROWS SHARING ONE would be three birds doing the same thing at the
## same moment, which reads as a single bird rendered three times - and the first version
## of this had the seed written into _ready as a constant.
@export var flock_seed: int = 0
@export_range(0.15, 2.0, 0.05) var length: float = 0.52: set = _set_length
@export var feather: Color = Color(0.10, 0.10, 0.13): set = _set_feather
@export var sheen: Color = Color(0.22, 0.24, 0.34): set = _set_sheen
@export var beak_color: Color = Color(0.16, 0.15, 0.14): set = _set_beak
@export var eye_color: Color = Color(0.86, 0.80, 0.30): set = _set_eye

@export_group("Where it goes")
## The fence it likes to sit on. Perches are picked along its rails.
@export var fence_path: NodePath
## And the patch of ground it works, as a radius about this node's own position.
@export_range(1.0, 30.0, 0.5) var ground_radius: float = 7.0
## Anything else it might stand on - the coop, the shed, a crate, a rock. The TOP of each
## is worked out from its own meshes rather than typed in, so a thing that is rebuilt or
## resized is still landed on correctly and nothing here has to know how tall a shed is.
@export var perch_paths: Array[NodePath] = []
## How often it goes for something rather than the bare ground. The rest of the time it
## drops into the field, which is where a crow spends most of its day anyway.
@export_range(0.0, 1.0, 0.05) var perch_preference: float = 0.75

@export_group("Timing")
@export_range(1.0, 60.0, 0.5) var perch_min: float = 4.0
@export_range(1.0, 90.0, 0.5) var perch_max: float = 11.0
@export_range(0.2, 3.0, 0.05) var takeoff_seconds: float = 0.7
@export_range(1.0, 30.0, 0.5) var fly_min: float = 4.0
@export_range(1.0, 40.0, 0.5) var fly_max: float = 9.0
@export_range(0.4, 4.0, 0.05) var land_seconds: float = 1.1

@export_group("Flight")
@export_range(0.5, 20.0, 0.5) var fly_speed: float = 4.5
@export_range(1.0, 14.0, 0.5) var cruise_height: float = 3.6
## Beats a second, climbing and cruising. A climb is worked for; a cruise is not.
@export_range(1.0, 14.0, 0.5) var climb_beats: float = 6.5
@export_range(0.5, 10.0, 0.5) var cruise_beats: float = 3.2
## How much of a cruise is spent gliding with the wings held out and still.
@export_range(0.0, 0.9, 0.05) var glide_share: float = 0.45
## How far back a folded wing lies, in radians. About 75 degrees tucks it along the body
## while leaving the shoulder visible; a full right angle reads as a bird with no wings.
@export_range(0.0, 1.6, 0.05) var fold_sweep: float = 1.30

enum Mood { PERCHED, TAKEOFF, FLYING, LANDING }

var _hide: MeshInstance4D
var _wings: Array[Node4D] = []
var _head: Node4D
var _head_rest := Vector4.ZERO
var _legs: Array[Node4D] = []
var _leg_rest: Array[Vector4] = []
var _fence: Node
var _perches: Array[Node4D] = []

var _mood: Mood = Mood.PERCHED
var _mood_left: float = 0.0
var _clock: float = 0.0
var _beat: float = 0.0
var _heading: float = 0.0
var _home := Vector4.ZERO
var _from := Vector4.ZERO
var _to := Vector4.ZERO
var _leg: float = 0.0
var _look: float = 0.0
var _look_at: float = 0.0
var _shrug: float = 0.0
var _rng := RandomNumberGenerator.new()


func _set_length(v: float) -> void: length = v; _later()
func _set_feather(v: Color) -> void: feather = v; _later()
func _set_sheen(v: Color) -> void: sheen = v; _later()
func _set_beak(v: Color) -> void: beak_color = v; _later()
func _set_eye(v: Color) -> void: eye_color = v; _later()


func _ready() -> void:
	_rng.seed = flock_seed if flock_seed != 0 else int(hash(name))
	_home = position
	_heading = _rng.randf_range(0.0, TAU)
	_fence = get_node_or_null(fence_path)
	for path in perch_paths:
		var thing: Node4D = get_node_or_null(path) as Node4D
		if thing != null:
			_perches.append(thing)
	rebuild()
	_mood_left = _rng.randf_range(perch_min, perch_max)


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_wings.clear()
	_legs.clear()
	_leg_rest.clear()
	var u: float = length

	var hide := MeshInstance4D.new()
	hide.name = "Hide"
	hide.set_script(RIG)
	var coat := TetraMaterial4D.new()
	coat.albedo_color = feather
	hide.material_override = coat
	add_child(hide)
	hide.set("profile_sides", 8)
	hide.set("profile_rings", 3)
	# Off before any ball goes in, or each one re-lofts the whole bird as it is added.
	hide.set("live_rebuild", false)
	_own(hide)
	_hide = hide

	# Spine, head to tail, FLAT under the rig. Nested one inside the next, the rig cannot
	# see past the first - the note on the cat has the detail.
	var head := _ball(hide, "Head", Vector4(0.0, 0.62 * u, 0.30 * u, 0.0), 0.085 * u)
	_ball(hide, "Neck", Vector4(0.0, 0.55 * u, 0.20 * u, 0.0), 0.075 * u)
	_ball(hide, "Chest", Vector4(0.0, 0.46 * u, 0.08 * u, 0.0), 0.125 * u)
	_ball(hide, "Body", Vector4(0.0, 0.42 * u, -0.10 * u, 0.0), 0.130 * u)
	_ball(hide, "Rump", Vector4(0.0, 0.42 * u, -0.28 * u, 0.0), 0.085 * u)
	# The tail is a chain of its own so it tapers to a fan rather than a point.
	_ball(hide, "Tail", Vector4(0.0, 0.43 * u, -0.46 * u, 0.0), 0.045 * u)

	# Legs, as branch chains off the body - posed, never walked. See the header.
	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		var hip := _ball(hide, "Hip" + tag,
			Vector4(side * 0.055 * u, 0.30 * u, -0.04 * u, 0.0), 0.030 * u, true)
		var knee := _ball(hip, "Knee" + tag,
			Vector4(side * 0.010 * u, -0.10 * u, -0.01 * u, 0.0), 0.022 * u)
		_ball(knee, "Foot" + tag,
			Vector4(0.0, -0.11 * u, 0.03 * u, 0.0), 0.020 * u)

	if hide.has_method("build"):
		hide.call("build", false)

	for tag in ["L", "R"]:
		var hip: Node4D = hide.get_node_or_null("Hip%s" % tag) as Node4D
		if hip != null:
			_legs.append(hip)
			_leg_rest.append(hip.position)
	_head = head
	_head_rest = head.position

	# The beak: a loft cannot make a point, and a crow is mostly beak.
	_block("Beak", Vector4(0.0, 0.615 * u, 0.44 * u, 0.0),
		Vector3(0.035 * u, 0.040 * u, 0.20 * u), beak_color)
	for side in [1.0, -1.0]:
		_block("Eye" + ("L" if side > 0.0 else "R"),
			Vector4(side * 0.055 * u, 0.655 * u, 0.335 * u, 0.0),
			Vector3(0.028 * u, 0.024 * u, 0.024 * u), eye_color)

	# THE WINGS. A pivot at the shoulder with three boxes that shorten and thin as they go
	# out, so a flap sweeps the whole span rather than waving a plank.
	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		var pivot := Node4D.new()
		pivot.name = "Wing" + tag
		add_child(pivot)
		pivot.position = Vector4(side * 0.09 * u, 0.50 * u, 0.02 * u, 0.0)
		_own(pivot)
		# EACH SEGMENT HAS ITS OWN LENGTH. Deriving it from how far OUT the segment sits
		# made every box run from the shoulder past its own position, so three of them
		# overlapped into one long plank - a wing with no taper and no shape at all.
		# offset along the wing, chord, thickness, length of this piece
		var spans := [[0.13, 0.30, 0.055, 0.26], [0.36, 0.23, 0.042, 0.22],
			[0.55, 0.14, 0.030, 0.18]]
		for i in spans.size():
			var span: Array = spans[i]
			var quill := _block("Quill%d" % i,
				Vector4(side * float(span[0]) * u, 0.0, -0.02 * u, 0.0),
				Vector3(float(span[3]) * u, float(span[2]) * u,
					float(span[1]) * u), sheen if i == 2 else feather)
			quill.reparent(pivot, false)
			quill.position = Vector4(side * float(span[0]) * u, 0.0, -0.02 * u, 0.0)
		_wings.append(pivot)

	_fold(1.0)


func _ball(parent: Node, part: String, at: Vector4, radius: float,
		branch: bool = false) -> Node4D:
	var node := MeshInstance4D.new()
	node.name = part
	node.set_script(BALL)
	parent.add_child(node)
	node.position = at
	node.set("radius", radius)
	if branch:
		node.set("starts_branch", true)
		node.set("symmetry_type", 0)
	_own(node)
	return node


func _block(part: String, at: Vector4, size: Vector3, colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	# A real extent through W, or the bird vanishes the moment the slice moves.
	mesh.size = Vector4(size.x, size.y, size.z, maxf(size.x, 0.26))
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	add_child(node)
	node.position = at
	_own(node)
	return node


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _hide == null:
		return
	_clock += delta
	_mood_left -= delta
	match _mood:
		Mood.PERCHED:
			_do_perched(delta)
		Mood.TAKEOFF:
			_do_takeoff(delta)
		Mood.FLYING:
			_do_flying(delta)
		Mood.LANDING:
			_do_landing(delta)


## Sat still, with the head doing most of the work. A perched crow is never quite still -
## it is the little turns of the head that keep it from reading as an ornament.
func _do_perched(delta: float) -> void:
	_fold(1.0)
	_stand(1.0)
	# A new thing to look at every second or two, turned to rather than snapped to.
	if _rng.randf() < delta * 0.9:
		_look_at = _rng.randf_range(-0.9, 0.9)
	_look = move_toward(_look, _look_at, delta * 4.0)
	basis = Basis4D.from_zx(_heading + _look)
	# And a bob, which is the other half of it.
	var bob: float = maxf(sin(_clock * 2.1), 0.0)
	_head.position = _head_rest + Vector4(0.0, -0.045 * length * bob,
		0.02 * length * bob, 0.0)
	# And every so often it shrugs its wings, which is the thing a real one does that
	# nothing else in the pose does - a bird that only ever turns its head is a puppet.
	_shrug = maxf(_shrug - delta, 0.0)
	if _shrug <= 0.0 and _rng.randf() < delta * 0.35:
		_shrug = 0.45
	if _shrug > 0.0:
		var flick: float = sin((1.0 - _shrug / 0.45) * PI)
		for i in _wings.size():
			var side: float = 1.0 if i == 0 else -1.0
			_wings[i].basis = Basis4D.from_zx(side * fold_sweep) 				* Basis4D.from_xy(-side * (-0.16 - flick * 0.55))
	if _mood_left <= 0.0:
		_from = position
		_to = position + Vector4(0.0, cruise_height, 0.0, 0.0)
		_mood = Mood.TAKEOFF
		_mood_left = takeoff_seconds


## Straight up, off the perch, working for it. Deep fast beats and the legs trailing.
func _do_takeoff(delta: float) -> void:
	var t: float = 1.0 - clampf(_mood_left / maxf(takeoff_seconds, 0.01), 0.0, 1.0)
	# A CROUCH FIRST. A bird does not rise off a rail, it pushes off one - and the first
	# version simply started travelling upwards on the frame the timer ran out, which
	# reads as being lifted rather than jumping.
	if t < 0.22:
		var dip: float = sin(t / 0.22 * PI) * 0.055 * length
		position = _from - Vector4(0.0, dip, 0.0, 0.0)
		_fold(1.0)
		_stand(1.0)
		return
	var climb: float = (t - 0.22) / 0.78
	position = _from.lerp(_to, ease(climb, 0.5))
	_beat += delta * climb_beats
	_flap(0.95)
	_stand(1.0 - climb)
	_head.position = _head_rest
	if _mood_left > 0.0:
		return
	_mood = Mood.FLYING
	_mood_left = _rng.randf_range(fly_min, fly_max)
	_pick_air()


## Cruising. Shallower beats with glides between them, and the body banking into a turn -
## a bird that flaps at one rate the whole time reads as a toy.
func _do_flying(delta: float) -> void:
	var to: Vector4 = _to - position
	var flat: float = Vector2(to.x, to.z).length()
	if flat < 0.9:
		_pick_air()
		to = _to - position
		flat = Vector2(to.x, to.z).length()
	var want: float = atan2(to.x, to.z)
	var turn: float = wrapf(want - _heading, -PI, PI)
	_heading = rotate_toward(_heading, want, delta * 1.8)
	position += Vector4(sin(_heading), 0.0, cos(_heading), 0.0) * fly_speed * delta
	position.y = lerpf(position.y, _to.y, clampf(delta * 1.2, 0.0, 1.0))
	# Banking, so a turn is something the whole bird does.
	# Banking into the turn, and the nose following the climb - a bird holds level while
	# its height changes only in a cartoon.
	var rise: float = clampf((_to.y - position.y) * 0.25, -0.45, 0.45)
	basis = Basis4D.from_zx(_heading) * Basis4D.from_xy(clampf(-turn, -0.7, 0.7)) 		* Basis4D.from_yz(-rise)
	_beat += delta * cruise_beats
	# A glide is the wings held out and still for part of every cycle.
	var phase: float = fposmod(_beat, 1.0)
	_flap(0.55 if phase > glide_share else 0.0)
	_stand(0.0)
	if _mood_left > 0.0:
		return
	_from = position
	_to = _pick_perch()
	_mood = Mood.LANDING
	_mood_left = land_seconds


## The flare: wings wide, nose up, legs reaching. This is the part that sells a landing,
## and it is why the legs are posed rather than walked - they have to come DOWN on cue.
func _do_landing(delta: float) -> void:
	var t: float = 1.0 - clampf(_mood_left / maxf(land_seconds, 0.01), 0.0, 1.0)
	var along: Vector4 = _from.lerp(_to, ease(t, 0.6))
	# A shallow approach rather than a drop, with the last of it almost level.
	position = Vector4(along.x, along.y + sin(t * PI) * 0.25 * (1.0 - t), along.z, along.w)
	var to: Vector4 = _to - _from
	if Vector2(to.x, to.z).length() > 0.05:
		_heading = rotate_toward(_heading, atan2(to.x, to.z), delta * 3.0)
	# Nose up into the flare, and level again as it settles.
	basis = Basis4D.from_zx(_heading) * Basis4D.from_yz(-0.5 * sin(t * PI))
	_beat += delta * lerpf(climb_beats, 1.2, t)
	_flap(lerpf(0.9, 0.2, t))
	_stand(t)
	if _mood_left > 0.0:
		return
	position = _to
	basis = Basis4D.from_zx(_heading)
	_mood = Mood.PERCHED
	_mood_left = _rng.randf_range(perch_min, perch_max)
	_look = 0.0


## Somewhere to fly to next: a point on a wide circuit at cruising height.
func _pick_air() -> void:
	var angle: float = _rng.randf_range(0.0, TAU)
	var reach: float = ground_radius * _rng.randf_range(0.6, 1.2)
	_to = Vector4(_home.x + sin(angle) * reach,
		_home.y + cruise_height * _rng.randf_range(0.75, 1.25),
		_home.z + cos(angle) * reach, position.w)


## Somewhere to come down.
##
## GATHERED, THEN CHOSEN AT RANDOM. Everything it could stand on goes into one list - the
## fence's top rail, the top of every object it has been pointed at, and the open ground -
## and one is drawn out. Adding somewhere new to land is then a NodePath in the scene and
## nothing here, which is the difference between a bird that uses its world and a bird
## with a list of two places written into its script.
func _pick_perch() -> Vector4:
	var spots: Array[Vector4] = []
	if _fence != null:
		spots.append(_rail_spot())
	for thing in _perches:
		if is_instance_valid(thing):
			var top: Vector4 = _top_of(thing)
			if not is_nan(top.y):
				spots.append(top)
	if not spots.is_empty() and _rng.randf() < perch_preference:
		return spots[_rng.randi() % spots.size()]
	var angle: float = _rng.randf_range(0.0, TAU)
	var reach: float = ground_radius * _rng.randf_range(0.2, 1.0)
	return Vector4(_home.x + sin(angle) * reach, _home.y,
		_home.z + cos(angle) * reach, position.w)


## The highest point of a built thing, and somewhere on top of it to stand.
##
## Measured off its own meshes, so it follows a shed that is resized or a rock that is
## mined away, and nothing here has to know how tall a shed is. The spot is jittered
## across the top rather than always dead centre, because three crows queueing for the
## same square inch of roof is worse than none.
func _top_of(thing: Node4D) -> Vector4:
	var box: Array = _extent(thing)
	if box.is_empty():
		return Vector4(0.0, NAN, 0.0, 0.0)
	var top: float = box[0]
	var lo: Vector2 = box[1]
	var hi: Vector2 = box[2]
	var host: Node4D = get_parent() as Node4D
	var origin: Vector4 = host.global_position if host != null else Vector4.ZERO
	var inset: float = 0.25
	return Vector4(
		_rng.randf_range(minf(lo.x + inset, hi.x), maxf(hi.x - inset, lo.x)) - origin.x,
		top - origin.y,
		_rng.randf_range(minf(lo.y + inset, hi.y), maxf(hi.y - inset, lo.y)) - origin.z,
		position.w)


## A thing's highest surface and its footprint, as [top, low corner, high corner].
##
## RETURNED rather than accumulated into arguments: GDScript passes floats and Vector2s by
## value, so the obvious recursive version quietly measured nothing but the last branch it
## walked. Boxes only - they are what everything in this scene is built from, and a
## faceted ball has no flat top to stand on anyway.
func _extent(thing: Node) -> Array:
	var top: float = -1.0e9
	var lo := Vector2(1.0e9, 1.0e9)
	var hi := Vector2(-1.0e9, -1.0e9)
	var any: bool = false
	for child in thing.get_children():
		if child is MeshInstance4D and (child as MeshInstance4D).mesh is BoxTetraMesh4D:
			var m: MeshInstance4D = child
			var size: Vector4 = (m.mesh as BoxTetraMesh4D).size
			var at: Vector4 = m.global_position
			top = maxf(top, at.y + size.y * 0.5)
			lo = Vector2(minf(lo.x, at.x - size.x * 0.5), minf(lo.y, at.z - size.z * 0.5))
			hi = Vector2(maxf(hi.x, at.x + size.x * 0.5), maxf(hi.y, at.z + size.z * 0.5))
			any = true
		var deeper: Array = _extent(child)
		if not deeper.is_empty():
			any = true
			top = maxf(top, float(deeper[0]))
			lo = Vector2(minf(lo.x, (deeper[1] as Vector2).x),
				minf(lo.y, (deeper[1] as Vector2).y))
			hi = Vector2(maxf(hi.x, (deeper[2] as Vector2).x),
				maxf(hi.y, (deeper[2] as Vector2).y))
	return [top, lo, hi] if any else []


## A spot on the fence's top rail. Along a SIDE rather than anywhere within the pen,
## because a bird that lands in the middle of a fence is sitting on nothing.
func _rail_spot() -> Vector4:
	var height: float = float(_fence.get("height"))
	var east: float = float(_fence.get("extend_x_positive"))
	var west: float = float(_fence.get("extend_x_negative"))
	var north: float = float(_fence.get("extend_z_positive"))
	var south: float = float(_fence.get("extend_z_negative"))
	var origin: Vector4 = (_fence as Node4D).global_position
	var host: Node4D = get_parent() as Node4D
	var local: Vector4 = origin - (host.global_position if host != null else Vector4.ZERO)
	var side: int = _rng.randi_range(0, 3)
	var along: float = _rng.randf_range(-0.85, 0.85)
	var spot := Vector4.ZERO
	match side:
		0: spot = Vector4(along * east, 0.0, north, 0.0)
		1: spot = Vector4(along * east, 0.0, -south, 0.0)
		2: spot = Vector4(east, 0.0, along * north, 0.0)
		_: spot = Vector4(-west, 0.0, along * north, 0.0)
	return Vector4(local.x + spot.x, height, local.z + spot.z, position.w)


## Wings. 0 is held out flat and still - a glide - and 1 is a full beat.
func _flap(depth: float) -> void:
	for i in _wings.size():
		var side: float = 1.0 if i == 0 else -1.0
		# Folded against the body when there is nothing to do, swept when there is.
		var swing: float = sin(_beat * TAU) * depth
		_wings[i].basis = Basis4D.from_xy(-side * (swing * 1.15 - 0.12))


## Legs. 1 is down on a perch, 0 is tucked up under the tail.
func _stand(down: float) -> void:
	_leg = down
	for i in _legs.size():
		# Folded forward and up, which is where a bird actually puts them.
		_legs[i].position = _leg_rest[i] + Vector4(0.0, 0.10 * length * (1.0 - down),
			0.06 * length * (1.0 - down), 0.0)


## Folded wings, for sitting. Kept separate from _flap so a perched bird is not holding a
## beat at amplitude zero - it is holding a pose.
##
## SWEPT BACK, NOT JUST LOWERED. A wing is modelled along the bird's X, so drooping it
## leaves a perched crow sitting with both wings held straight out like a weather vane -
## which is what the first version did. Folding is mostly a turn in the z-x plane that
## lays the wing along the body, with a little droop on top of it.
func _fold(_amount: float) -> void:
	for i in _wings.size():
		var side: float = 1.0 if i == 0 else -1.0
		_wings[i].basis = Basis4D.from_zx(side * fold_sweep) 			* Basis4D.from_xy(-side * -0.16)
