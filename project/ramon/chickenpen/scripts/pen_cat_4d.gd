@tool
extends Node4D

## A black cat, built and rigged the way the chicken and the brachiosaurus are.
##
## ONE HIDE, WITH BRANCHES. The whole animal is a single loft rig: a spine chain from nose
## to rump, with the legs and the tail hanging off it as branch balls. That is how
## animation_test's strider is authored and it is the structure strider_walker.gd expects -
## it collects a leg as a descending chain of three balls hanging off the body, solves it
## with closed-form two-bone IK, and skins the surface to follow. A first attempt here used
## four separate leg rigs swung rigidly from the hip, which animates for free but is not
## the pipeline: it cannot share a surface with the body, the shoulder is a seam rather
## than a taper, and none of the existing walkers can drive it.
##
## BOTH SIDES AUTHORED, NO MIRRORING. A branch ball can generate its own twin, but while
## mirroring is on the two sides ARE the same limb and cannot hold different phases - every
## gait collapses into a pronk, which is what strider_walker's header warns about. The
## answer there is detach_mirror(); the answer here is simply to build the left and the
## right as real balls in the first place, because this is generated rather than sculpted
## and there is no authoring convenience to preserve.
##
## THE HEAD FURNITURE IS NOT PART OF THE HIDE. Ears and eyes are boxes on this node rather
## than children of the head ball, because loft balls hide themselves at runtime and take
## their children with them - the trap that made the chicken's feet vanish. They do not
## follow the head, which is fine while the walker only drives legs.

const RIG := preload("res://ramon/chickenpen/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/chickenpen/scripts/loft_ball_4d.gd")
const WALKER := preload("res://ramon/chickenpen/scripts/strider_walker.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

## Nose to rump, in world units. A cat beside a 1.7-unit person.
@export_range(0.2, 4.0, 0.05) var length: float = 0.95: set = _set_length
@export var fur: Color = Color(0.07, 0.07, 0.09): set = _set_fur
@export var eye: Color = Color(0.85, 0.92, 0.35): set = _set_eye

@export_group("Walking")
@export var walks: bool = true
## Cadence, handed to strider_walker as its belt_speed. NOT a distance: the creature's
## actual pace comes out of stride times cadence, and travel is then measured off the
## planted feet. At the walker's default of 1.6 this animal crawled - measured at under a
## tenth of a unit per second, which is a body length every ten seconds.
@export_range(0.5, 20.0, 0.1) var pace: float = 6.0
@export_range(0.05, 4.0, 0.05) var stride_length: float = 0.42
@export_range(0.02, 2.0, 0.02) var step_height: float = 0.11
@export_range(0.0, 0.3, 0.005) var body_bob: float = 0.02
## How far it strays from where it was put, and how sharply it can turn.
@export_range(0.5, 20.0, 0.5) var roam_radius: float = 5.0
@export_range(5.0, 90.0, 1.0) var turn_rate_degrees: float = 30.0
@export_range(0.5, 12.0, 0.1) var pause_min: float = 1.5
@export_range(0.5, 20.0, 0.1) var pause_max: float = 5.0

@export_group("Sitting and fleeing")
## Something to sit on. It goes there of its own accord, jumps up, and stays until it is
## disturbed - which is most of what makes a cat read as a cat rather than as livestock.
@export var crate_path: NodePath
@export var player_path: NodePath
## How high the crate's top is ABOVE THE CRATE'S OWN ORIGIN, not above the floor. The
## crate sits at 0.3 and is 0.6 tall, so its surface is 0.3 above itself - measuring from
## the floor instead put the cat a quarter of a unit into the air above it.
@export_range(0.1, 3.0, 0.05) var crate_top: float = 0.34
@export_range(0.2, 2.0, 0.05) var jump_seconds: float = 0.55
@export_range(0.5, 20.0, 0.5) var sit_min: float = 6.0
@export_range(0.5, 40.0, 0.5) var sit_max: float = 16.0
## How hard and how long it runs once it HAS been provoked, which now only happens when
## it scratches its way out of your arms.
@export_range(1.0, 20.0, 0.5) var flee_pace: float = 20.0
@export_range(0.5, 12.0, 0.5) var flee_seconds: float = 5.0
## An extra shove on top of what the legs carry it. A startled cat does not accelerate
## like a horse, and the walker's travel alone reads as a brisk trot rather than a bolt.
@export_range(0.0, 6.0, 0.1) var flee_dash: float = 1.5
## Where a thrown cat decides to settle - the coop. It walks there and gets on top.
@export var perch_path: NodePath
## MEASURED OFF THE COOP'S ROOF, and above its own origin - the same trap the crate had.
## At 2.45 the cat sat 0.16 in the air: the roof is at 2.29 and the coop's origin is on
## the floor, so reading the number as a world height floated it by the difference.
@export_range(0.1, 6.0, 0.05) var perch_top: float = 2.28
## It starts the game already up on its crate, rather than wandering into it.
@export var starts_on_crate: bool = true
## How long one wash of the paw takes.
@export_range(0.3, 4.0, 0.1) var wash_seconds: float = 1.5

@export_group("Living somewhere")
## A building this one belongs to. Given one it keeps house instead of keeping a crate:
## it comes out, mooches about nearby, and goes back in for a while.
##
## INSIDE IS HIDDEN, NOT MOVED SOMEWHERE ELSE. The shed has walls and no floor plan worth
## pathing round, and a cat that walks through a wall to get in is worse than one that
## simply is not out. Hidden, it is also unpickable for free - the grab asks the cat.
@export var den_path: NodePath
@export var lives_in_den: bool = false
## How far from the door it is willing to get.
@export_range(0.5, 14.0, 0.5) var den_radius: float = 4.0
## How far clear of the den's walls it is held.
##
## WHY THIS IS NEEDED AT ALL: nothing in this scene has walls a wanderer can feel. The
## buildings are meshes, the animals are driven by their own code rather than by physics,
## and so a cat that decides to stroll north strolls through the shed. Pushing it back out
## of the footprint each frame is the cheapest honest fix - no colliders, no pathing, and
## it cannot end up stuck inside because being inside is the one state it corrects.
@export_range(0.0, 2.0, 0.05) var den_clearance: float = 0.35
@export_range(1.0, 60.0, 0.5) var indoors_min: float = 5.0
@export_range(1.0, 90.0, 0.5) var indoors_max: float = 14.0
@export_range(2.0, 90.0, 0.5) var outdoors_min: float = 8.0
@export_range(2.0, 90.0, 0.5) var outdoors_max: float = 22.0

enum Mood { WANDER, TO_CRATE, JUMP, SIT, FLEE, CARRIED, THROWN, TO_PERCH, TO_DEN, INSIDE }

var _walker: Node4D
var _crate: Node4D
var _perch: Node4D
var _den: Node4D
var _player: Node4D
var _mood: Mood = Mood.WANDER
var _mood_left: float = 0.0
var _jump_from := Vector4.ZERO
var _jump_to := Vector4.ZERO
var _jump_t: float = 0.0
var _lick: float = 0.0
var _feet: Array[Node4D] = []
var _foot_rest: Array[Vector4] = []
var _head_ball: Node4D
var _head_rest := Vector4.ZERO
var _home := Vector4.ZERO
var _heading: float = 0.0
var _clock: float = 0.0
var _pause: float = 0.0
var _rng := RandomNumberGenerator.new()


func _set_length(v: float) -> void: length = v; _later()
func _set_fur(v: Color) -> void: fur = v; _later()
func _set_eye(v: Color) -> void: eye = v; _later()


func _ready() -> void:
	_rng.seed = 5150
	_home = position
	_heading = _rng.randf_range(0.0, TAU)
	_crate = get_node_or_null(crate_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	_perch = get_node_or_null(perch_path) as Node4D
	_den = get_node_or_null(den_path) as Node4D
	rebuild()
	_mood_left = _rng.randf_range(4.0, 9.0)
	if lives_in_den and _den != null:
		# Found at home, and due out shortly.
		_mood = Mood.INSIDE
		_mood_left = _rng.randf_range(1.0, 4.0)
		_indoors(true)
	elif starts_on_crate and _crate != null:
		position = _crate.position + Vector4(0.0, crate_top, 0.0, 0.0)
		_mood = Mood.SIT
		_mood_left = _rng.randf_range(sit_min, sit_max)
		_lick = _rng.randf_range(2.0, 5.0)


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	var u: float = length

	var hide := MeshInstance4D.new()
	hide.name = "Hide"
	hide.set_script(RIG)
	var coat := TetraMaterial4D.new()
	coat.albedo_color = fur
	hide.material_override = coat
	add_child(hide)
	hide.set("profile_sides", 8)
	hide.set("profile_rings", 3)
	# Off before any ball goes in, or each one re-lofts the whole animal as it is added.
	hide.set("live_rebuild", false)
	_own(hide)

	# Spine, nose to rump, as DIRECT children of the rig in order. Not nested one inside
	# the next: strider_walker looks exactly one level down for a limb - body balls under
	# the rig, hips under those - so a nested spine hides every leg from it and it reports
	# finding none. The horse is authored the same flat way.
	var head := _ball(hide, "Head", Vector4(0.0, 0.40 * u, 0.50 * u, 0.0), 0.075 * u)
	var neck := _ball(hide, "Neck", Vector4(0.0, 0.40 * u, 0.37 * u, 0.0), 0.095 * u)
	var chest := _ball(hide, "Chest", Vector4(0.0, 0.40 * u, 0.22 * u, 0.0), 0.125 * u)
	var mid := _ball(hide, "Mid", Vector4(0.0, 0.40 * u, 0.02 * u, 0.0), 0.130 * u)
	var rump := _ball(hide, "Rump", Vector4(0.0, 0.39 * u, -0.18 * u, 0.0), 0.110 * u)

	# Legs, as branches. Named so strider_walker can be told exactly which chains are legs
	# rather than having to guess from which ones descend - the guess is what made the
	# brachiosaurus try to walk on its tail.
	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		var shoulder := _ball(chest, "FrontHip" + tag,
			Vector4(side * 0.070 * u, -0.02 * u, 0.02 * u, 0.0), 0.050 * u, true)
		# Long enough to reach the ground AND have slack for a stride - at 0.14 + 0.14
		# against a shoulder 0.38 up, the leg fell short of the floor and the IK clamped
		# flat out, which is why the paw barely swung however fast the cat went.
		var fknee := _ball(shoulder, "FrontKnee" + tag,
			Vector4(side * 0.004 * u, -0.22 * u, -0.01 * u, 0.0), 0.038 * u)
		_ball(fknee, "FrontFoot" + tag, Vector4(0.0, -0.22 * u, 0.03 * u, 0.0), 0.042 * u)

		var hip := _ball(rump, "HindHip" + tag,
			Vector4(side * 0.075 * u, -0.01 * u, 0.0, 0.0), 0.055 * u, true)
		var hknee := _ball(hip, "HindKnee" + tag,
			Vector4(side * 0.004 * u, -0.22 * u, -0.02 * u, 0.0), 0.040 * u)
		_ball(hknee, "HindFoot" + tag, Vector4(0.0, -0.22 * u, 0.04 * u, 0.0), 0.042 * u)

	# A snout: two small balls branching forward off the head. Forward rather than down,
	# so the slope test never mistakes it for a limb - and the walker is name-restricted
	# to hips anyway.
	var snout := _ball(head, "SnoutBase", Vector4(0.0, -0.012 * u, 0.055 * u, 0.0), 0.045 * u, true)
	_ball(snout, "SnoutTip", Vector4(0.0, -0.008 * u, 0.045 * u, 0.0), 0.030 * u)

	# The tail, also a branch, rising away from the rump so it never reads as a fifth leg.
	var tail := _ball(rump, "TailBase", Vector4(0.0, 0.05 * u, -0.13 * u, 0.0), 0.036 * u, true)
	var t2 := _ball(tail, "TailB", Vector4(0.0, 0.08 * u, -0.14 * u, 0.0), 0.030 * u)
	var t3 := _ball(t2, "TailC", Vector4(0.0, 0.09 * u, -0.13 * u, 0.0), 0.025 * u)
	var t4 := _ball(t3, "TailD", Vector4(0.0, 0.08 * u, -0.12 * u, 0.0), 0.021 * u)
	_ball(t4, "TailE", Vector4(0.0, 0.05 * u, -0.10 * u, 0.0), 0.017 * u)

	# Kept so the sitting pose can write them directly. Safe ONLY while the walker is
	# switched off: it owns these positions the rest of the time and would overwrite any
	# pose put underneath it on the very next frame.
	_feet.clear()
	_foot_rest.clear()
	for path in ["Chest/FrontHipL/FrontKneeL/FrontFootL", "Chest/FrontHipR/FrontKneeR/FrontFootR",
			"Rump/HindHipL/HindKneeL/HindFootL", "Rump/HindHipR/HindKneeR/HindFootR"]:
		var foot: Node4D = hide.get_node_or_null(path) as Node4D
		if foot != null:
			_feet.append(foot)
			_foot_rest.append(foot.position)
	_head_ball = head
	_head_rest = head.position

	if hide.has_method("build"):
		hide.call("build", false)

	# Ears and eyes: a loft cannot make a point, and a cat without ears is an otter.
	for side in [1.0, -1.0]:
		var tag: String = "L" if side > 0.0 else "R"
		_block("Ear" + tag, Vector4(side * 0.050 * u, 0.48 * u, 0.48 * u, 0.0),
			Vector3(0.045 * u, 0.085 * u, 0.035 * u), fur)
		_block("Eye" + tag, Vector4(side * 0.042 * u, 0.42 * u, 0.555 * u, 0.0),
			Vector3(0.026 * u, 0.020 * u, 0.02 * u), eye)

	# And the rig that walks it: the same script that walks the horse and the sauropod.
	var walker := Node4D.new()
	walker.name = "Walker"
	walker.set_script(WALKER)
	# EVERY PROPERTY BEFORE add_child. A node's _ready fires the moment it enters the tree,
	# and this one resolves rig_path there - setting it afterwards left the walker having
	# already given up, reporting that rig_path did not point at a loft rig.
	walker.set("rig_path", NodePath("../Hide"))
	walker.set("leg_name_prefixes", PackedStringArray(["FrontHip", "HindHip"]))
	walker.set("stride_length", stride_length)
	walker.set("step_height", step_height)
	walker.set("body_bob", body_bob)
	# It carries the animal forward off its own planted feet, so this node only has to
	# decide which way is forward.
	walker.set("belt_speed", pace)
	walker.set("travel", true)
	add_child(walker)
	_own(walker)
	_walker = walker


## One ball in the chain, hung off whatever came before it.
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
		# None, not Mirror: see the header. Both sides are built for real so they can hold
		# opposite phases.
		node.set("symmetry_type", 0)
	_own(node)
	return node


func _block(part: String, at: Vector4, box: Vector3, colour: Color) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(box.x, box.y, box.z, box.x)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	add_child(node)
	node.position = at
	_own(node)


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root


## Which way is forward. The walker does the walking; this only steers and stops.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not walks or _walker == null:
		return
	_clock += delta
	# IT DOES NOT RUN FROM YOU. An earlier version bolted whenever you came within a
	# couple of units, which made it unapproachable: the only way to reach it was to
	# corner it, and the pick-up - the thing the cat is actually for - could not be
	# reached at all. The one time it runs is after it has scratched its way out of your
	# arms, which is the beat that needs it.
	match _mood:
		Mood.WANDER:
			_do_wander(delta)
		Mood.TO_CRATE:
			_do_to_crate(delta)
		Mood.JUMP:
			_do_jump(delta)
		Mood.SIT:
			_do_sit(delta)
		Mood.FLEE:
			_do_flee(delta)
		Mood.CARRIED:
			# Held. Whoever is holding it owns its position; it just stays tucked.
			_walking(false)
			_tuck(1.0)
		Mood.THROWN:
			_do_thrown(delta)
		Mood.TO_PERCH:
			_do_to_perch(delta)
		Mood.TO_DEN:
			_do_to_den(delta)
		Mood.INSIDE:
			_do_inside(delta)
	_keep_out_of_den()


## The walker owns the feet while it runs, so anything that poses them by hand has to
## switch it off first and hand the rest pose back afterwards.
func _walking(on: bool) -> void:
	_walker.set("travel", on)
	_walker.set_process(on)
	_walker.set_physics_process(on)
	if on:
		_restore_pose()


func _do_wander(delta: float) -> void:
	_walking(true)
	_walker.set("belt_speed", pace)
	_mood_left -= delta
	var offset: Vector4 = position - _home
	if Vector2(offset.x, offset.z).length() > roam_radius:
		_heading = rotate_toward(_heading, atan2(-offset.x, -offset.z),
			deg_to_rad(turn_rate_degrees) * delta * 2.0)
	else:
		_heading += sin(_clock * 0.6) * deg_to_rad(turn_rate_degrees) * delta * 0.5
	basis = Basis4D.from_zx(_heading)
	# Sooner or later it decides it would rather be up somewhere - or indoors.
	if _mood_left <= 0.0 and lives_in_den and _den != null:
		_mood = Mood.TO_DEN
	elif _mood_left <= 0.0 and _crate != null:
		_mood = Mood.TO_CRATE


## The doorway if the den knows where its door is, the middle of it if not.
func _den_door() -> Vector4:
	if _den != null and _den.has_method("door_point"):
		return _den.call("door_point")
	return _den.global_position if _den != null else global_position


## Shoves it back out of its den's footprint, and turns it away so it does not spend the
## rest of the minute walking into the same wall. Called after whatever moved it.
##
## IT ONLY EVER PUSHES OUT. There is no "am I allowed through here" test and no doorway
## gap, because the cat never actually goes in: reaching the door it is hidden instead,
## for the reason in the den_path note. So the footprint can be solid, which means there
## is no gap to get wedged in.
func _keep_out_of_den() -> void:
	if _den == null or not visible or not _den.has_method("footprint_half"):
		return
	var half: Vector2 = _den.call("footprint_half") + Vector2(den_clearance, den_clearance)
	var local: Vector4 = _den.global_basis.inverse() * (global_position - _den.global_position)
	var into_x: float = half.x - absf(local.x)
	var into_z: float = half.y - absf(local.z)
	if into_x <= 0.0 or into_z <= 0.0:
		return
	# Out by the nearer wall, which is the shortest way back into the daylight.
	if into_x < into_z:
		local.x = (half.x if local.x >= 0.0 else -half.x)
	else:
		local.z = (half.y if local.z >= 0.0 else -half.y)
	var fixed: Vector4 = _den.global_position + _den.global_basis * local
	global_position = Vector4(fixed.x, global_position.y, fixed.z, global_position.w)
	var away := Vector2(fixed.x - _den.global_position.x, fixed.z - _den.global_position.z)
	if away.length() > 0.01:
		_heading = atan2(away.x, away.y)
		basis = Basis4D.from_zx(_heading)


func _do_to_crate(delta: float) -> void:
	_walking(true)
	_walker.set("belt_speed", pace)
	var to: Vector4 = _crate.global_position - global_position
	var flat: float = Vector2(to.x, to.z).length()
	_heading = rotate_toward(_heading, atan2(to.x, to.z),
		deg_to_rad(turn_rate_degrees) * delta * 3.0)
	basis = Basis4D.from_zx(_heading)
	if flat < 0.85:
		_leap_to(_crate.position + Vector4(0.0, crate_top, 0.0, 0.0))


## An arc, with the legs held still - the walker plants feet on the floor and a cat in the
## air has none, so it is switched off for the whole jump rather than fought.
func _do_jump(delta: float) -> void:
	_walking(false)
	_jump_t = minf(_jump_t + delta / jump_seconds, 1.0)
	var along: Vector4 = _jump_from.lerp(_jump_to, _jump_t)
	var lift: float = maxf(0.3, (_jump_to.y - _jump_from.y) * 0.7)
	position = Vector4(along.x, along.y + sin(_jump_t * PI) * lift, along.z, along.w)
	_tuck(clampf(_jump_t * 2.0, 0.0, 1.0))
	if _jump_t < 1.0:
		return
	if _jump_to.y > _home.y + 0.1:
		_mood = Mood.SIT
		_mood_left = _rng.randf_range(sit_min, sit_max)
		_lick = _rng.randf_range(2.0, 5.0)
	else:
		_mood = Mood.WANDER
		_mood_left = _rng.randf_range(5.0, 12.0)


## Sitting, and every so often washing a paw.
func _do_sit(delta: float) -> void:
	_walking(false)
	_tuck(1.0)
	_mood_left -= delta
	_lick -= delta
	if _lick <= 0.0:
		var into: float = -_lick
		if into <= wash_seconds:
			_wash(into / wash_seconds)
		else:
			_lick = _rng.randf_range(3.0, 9.0)
	if _mood_left <= 0.0:
		_hop_down()


func _do_flee(delta: float) -> void:
	_walking(true)
	_walker.set("belt_speed", flee_pace)
	_mood_left -= delta
	# Aimed away ONCE, at the start, then run straight. Re-aiming every frame while
	# moving curves the path into an arc around the player, which covers a third of the
	# ground and does not read as bolting.
	if _player != null and _mood_left > flee_seconds - 0.2:
		var away: Vector4 = global_position - _player.global_position
		_heading = atan2(away.x, away.z)
	basis = Basis4D.from_zx(_heading)
	position += Vector4(sin(_heading), 0.0, cos(_heading), 0.0) * flee_dash * delta
	# Ends on its own clock. It used to also wait until the player was far away, which was
	# right while proximity was what started the run and is wrong now: a scratch leaves
	# them lying right next to it, so that test would never clear and it would run for
	# ever.
	if _mood_left <= 0.0:
		_mood = Mood.WANDER
		_mood_left = _rng.randf_range(4.0, 9.0)


func _hop_down() -> void:
	_leap_to(Vector4(position.x + sin(_heading) * 1.0, _home.y,
		position.z + cos(_heading) * 1.0, position.w))


func _leap_to(target: Vector4) -> void:
	_jump_from = position
	_jump_to = target
	_jump_to.w = position.w
	_jump_t = 0.0
	_mood = Mood.JUMP


## Picked up. Whoever grabbed it drives its position from here until they let go.
func grab() -> void:
	_mood = Mood.CARRIED
	_walking(false)


## Let go without being thrown: it lands where it is and leaves at speed.
func drop_and_flee() -> void:
	position.y = _home.y
	_mood = Mood.FLEE
	_mood_left = flee_seconds
	_walking(true)


## Thrown. It arcs to where it was aimed, then walks to the coop and gets on top of it -
## which is what makes a successful throw read as the cat AGREEING rather than as the cat
## simply landing somewhere.
func thrown_to(landing: Vector4) -> void:
	_leap_to(Vector4(landing.x, _home.y, landing.z, position.w))
	_mood = Mood.THROWN


func _do_thrown(delta: float) -> void:
	_walking(false)
	_jump_t = minf(_jump_t + delta / maxf(jump_seconds * 1.6, 0.05), 1.0)
	var along: Vector4 = _jump_from.lerp(_jump_to, _jump_t)
	position = Vector4(along.x, along.y + sin(_jump_t * PI) * 1.1, along.z, along.w)
	_tuck(0.6)
	if _jump_t >= 1.0:
		_mood = Mood.TO_PERCH if _perch != null else Mood.WANDER
		_mood_left = _rng.randf_range(5.0, 10.0)


## Walks to the coop and jumps up. It ignores the player on the way - having just been
## thrown there, bolting from whoever threw it would undo the whole point.
func _do_to_perch(delta: float) -> void:
	_walking(true)
	# A trot, not a stroll: the coop can be fifteen units away and a cat ambling there at
	# its own pace is two minutes of nothing.
	_walker.set("belt_speed", pace * 4.0)
	var to: Vector4 = _perch.global_position - global_position
	var flat: float = Vector2(to.x, to.z).length()
	_heading = rotate_toward(_heading, atan2(to.x, to.z),
		deg_to_rad(turn_rate_degrees) * delta * 4.0)
	basis = Basis4D.from_zx(_heading)
	if flat < 1.6:
		var top: Vector4 = _perch.global_position - (get_parent() as Node4D).global_position
		_leap_to(Vector4(top.x, top.y + perch_top, top.z, position.w))
		# Landing above its home height sends it into SIT, which is where it stays.


## Home, at a trot. It ignores the player on the way for the same reason a thrown cat
## does: being turned around by whoever is standing there would never let it arrive.
func _do_to_den(delta: float) -> void:
	_walking(true)
	_walker.set("belt_speed", pace * 1.4)
	var to: Vector4 = _den_door() - global_position
	_heading = rotate_toward(_heading, atan2(to.x, to.z),
		deg_to_rad(turn_rate_degrees) * delta * 3.0)
	basis = Basis4D.from_zx(_heading)
	if Vector2(to.x, to.z).length() < 0.8:
		_mood = Mood.INSIDE
		_mood_left = _rng.randf_range(indoors_min, indoors_max)
		_indoors(true)


func _do_inside(delta: float) -> void:
	_walking(false)
	_mood_left -= delta
	if _mood_left > 0.0:
		return
	_indoors(false)
	# Out of the door and off in whatever direction it fancies.
	_heading = _rng.randf_range(0.0, TAU)
	basis = Basis4D.from_zx(_heading)
	_mood = Mood.WANDER
	_mood_left = _rng.randf_range(outdoors_min, outdoors_max)


## In or out. Parked at the door either way, so coming out starts from the doorway rather
## than from wherever it last happened to be standing.
func _indoors(shut_in: bool) -> void:
	if _den != null:
		var host: Node4D = get_parent() as Node4D
		var door: Vector4 = _den_door() - (host.global_position if host != null else Vector4.ZERO)
		position = Vector4(door.x, _home.y, door.z, position.w)
		_home = position
	visible = not shut_in


## Whether somebody could pick this up right now. ASKED, NOT GUESSED: the grab handler
## used to test the mood against a handful of literal numbers, which quietly went wrong
## the moment two more moods were added to the middle of the enum.
func can_be_picked_up() -> bool:
	if not visible:
		return false
	return _mood == Mood.WANDER or _mood == Mood.TO_CRATE or _mood == Mood.SIT \
		or _mood == Mood.TO_DEN


## Folds the legs under the body: 0 standing, 1 fully sat. The back pair come further
## forward than the front, because that is the difference between sitting and crouching.
func _tuck(amount: float) -> void:
	for i in _feet.size():
		var rest: Vector4 = _foot_rest[i]
		var lift: float = (0.6 if i >= 2 else 0.25) * amount
		_feet[i].position = rest + Vector4(0.0, -rest.y * lift, length * 0.05 * amount, 0.0)


## One front paw up to the muzzle and back down, with the head dipping to meet it - a cat
## brings its face to the paw as much as the paw to its face.
func _wash(t: float) -> void:
	if _feet.is_empty() or _head_ball == null:
		return
	var reach: float = sin(clampf(t, 0.0, 1.0) * PI)
	var rest: Vector4 = _foot_rest[0]
	_feet[0].position = rest + Vector4(0.0,
		-rest.y * 0.6 - length * 0.10 * reach, length * 0.13 * reach, 0.0)
	_head_ball.position = _head_rest + Vector4(0.0,
		-length * 0.05 * reach, -length * 0.02 * reach, 0.0)


func _restore_pose() -> void:
	for i in _feet.size():
		_feet[i].position = _foot_rest[i]
	if _head_ball != null:
		_head_ball.position = _head_rest
