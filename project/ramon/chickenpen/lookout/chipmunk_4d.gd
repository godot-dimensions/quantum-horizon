@tool
extends Node4D

## An eastern chipmunk, in the kata wood (kata_wood_4d.gd): the subgame's fourth secret.
##
## DRESSED FROM THE FIELD GUIDES: reddish brown, greyer towards the front; five dark stripes
## down the back with two pale ones between them, the middle stripe running from the crown to
## the rump; pale and dark stripes across the face through the eye; a pale belly; a flattish
## tail, darker, held up when it runs. True size is about 25 cm with the tail; drawn at
## [member size] 1.6 so a photo of one is possible without the longest lens.
##
## WHAT IT DOES - what chipmunks are known for, and the one thing a 4D tree allows:
##   FORAGE   1  scurrying in short dashes across the litter, stopping dead to nose about
##   STUFF    2  sitting up with something in its paws, the cheek pouches filling
##   CLIMB    3  up the trunk in a spiral, out along a limb to sit, and down head first
##   ROUND_W  4  round the trunk THROUGH W: the trunk's cross-section is round in W as well as
##              across (a ball, not a disc - lofted trees are 4D solids of revolution), so going
##              round it can mean going ana of it. It leaves your slice halfway round, gone
##              behind the trunk in a direction the screen does not have, and comes back the
##              other side. Pull focus after it and you can photograph it there.
##   ALARM       a chip and a tail flick, then a dash for the burrow if you come close or whistle
##
## RIGID, LIKE THE HERON: a lofted body and head, boxes for the stripes, the legs and the ears,
## everything posed by moving nodes; nothing re-lofts after it is built.

enum State { FORAGE, SIT, STUFF, CLIMB, PERCH, DESCEND, ROUND_W, ALARM, HIDE }

const RIG := preload("res://ramon/chickenpen/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/chickenpen/scripts/loft_ball_4d.gd")

@export_range(0.5, 4.0, 0.05) var size: float = 1.6:
	set(v):
		size = v
		_changed()
@export_range(1.0, 4.0, 0.05) var w_stretch: float = 1.6:
	set(v):
		w_stretch = v
		_changed()
@export var fur: Color = Color(0.62, 0.38, 0.20)
@export var grey: Color = Color(0.52, 0.45, 0.38)
@export var stripe: Color = Color(0.14, 0.10, 0.08)
@export var pale: Color = Color(0.90, 0.84, 0.70)

@export_group("Life")
## Only sit and look about: for the creature showcase.
@export var idle_only: bool = false
## The wood it lives in: its tree and its burrow.
@export var wood_path: NodePath
@export var player_path: NodePath
@export var lookout_path: NodePath
@export var chipmunk_seed: int = 1
@export_range(1.0, 10.0, 0.5, "suffix:m") var flee_within: float = 3.5

var state: int = State.FORAGE

var _body: Node4D
var _head: Node4D
var _tail: Node4D
var _legs: Array[Node4D] = []
var _cheeks: Array[Node4D] = []
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _state_t: float = 0.0
var _state_len: float = 3.0
var _goal: Vector4
var _dash: bool = false
## On the trunk: height up it, the angle round it, and whether "round" goes through W.
var _climb_y: float = 0.0
var _round: float = 0.0
var _through_w: bool = false
var _seat: Vector4
var _seen: bool = true
var _seen_check: float = 0.0
var _home: Vector4


func _changed() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	_rng.seed = chipmunk_seed
	rebuild()
	if Engine.is_editor_hint():
		set_process(false)
		return
	_home = position
	_goal = position
	_enter(State.FORAGE, _rng.randf_range(1.0, 3.0))


func rebuild() -> void:
	for child in get_children():
		child.free()
	_legs.clear()
	_cheeks.clear()
	var u: float = size
	var ws: float = w_stretch
	var deep: float = 0.05 * u * ws
	_body = Node4D.new()
	_body.name = "Body"
	add_child(_body)
	_own(_body)
	var hide := _rig(_body, "Fur", fur)
	_ball(hide, "Rump", Vector4(0.0, 0.055 * u, -0.045 * u, 0.0), 0.045 * u, ws)
	_ball(hide, "Middle", Vector4(0.0, 0.06 * u, 0.0, 0.0), 0.046 * u, ws)
	_ball(hide, "Chest", Vector4(0.0, 0.062 * u, 0.045 * u, 0.0), 0.038 * u, ws)
	hide.call("build", false)
	_box(_body, "Belly", Vector4(0.0, 0.03 * u, 0.0, 0.0), Vector4(0.05 * u, 0.02 * u, 0.09 * u, deep * 0.8), pale)
	# The stripes down the back: five dark, two pale between the outer pairs.
	# Each in two short pieces following the curve of the back, so none stands off the body.
	for k in 5:
		var x: float = (float(k) - 2.0) * 0.012 * u
		var top: float = 0.101 * u - absf(float(k) - 2.0) * 0.009 * u
		var length: float = (0.045 if k == 2 else 0.035) * u
		for piece in [-1.0, 1.0]:
			var seg := _box(_body, "Stripe%d_%d" % [k, int(piece)], Vector4(x, top - 0.004 * u, piece * 0.022 * u, 0.0), Vector4(0.005 * u, 0.006 * u, length, deep * 0.7), stripe)
			seg.basis = Basis4D.from_yz(piece * 0.28)
	for side in [-1.0, 1.0]:
		for piece in [-1.0, 1.0]:
			var seg := _box(_body, "PaleStripe%d_%d" % [int(side), int(piece)], Vector4(side * 0.03 * u, 0.088 * u, piece * 0.02 * u, 0.0), Vector4(0.005 * u, 0.006 * u, 0.034 * u, deep * 0.7), pale)
			seg.basis = Basis4D.from_yz(piece * 0.28)
	# The head: a loft, the stripes through the eye, the cheeks that fill.
	_head = Node4D.new()
	_head.name = "Head"
	_body.add_child(_head)
	_own(_head)
	_head.position = Vector4(0.0, 0.075 * u, 0.07 * u, 0.0)
	var skull := _rig(_head, "Skull", fur.lerp(grey, 0.4))
	_ball(skull, "Back", Vector4(0.0, 0.012 * u, 0.012 * u, 0.0), 0.03 * u, ws * 0.9)
	_ball(skull, "Snout", Vector4(0.0, 0.004 * u, 0.042 * u, 0.0), 0.016 * u, ws * 0.9)
	skull.call("build", false)
	for side in [-1.0, 1.0]:
		var cheek := _box(_head, "Cheek%d" % int(side), Vector4(side * 0.019 * u, -0.002 * u, 0.03 * u, 0.0), Vector4(0.014 * u, 0.018 * u, 0.022 * u, deep * 0.8), pale)
		_cheeks.append(cheek)
		_box(_head, "EyeStripe%d" % int(side), Vector4(side * 0.025 * u, 0.016 * u, 0.025 * u, 0.0), Vector4(0.004 * u, 0.005 * u, 0.045 * u, deep * 0.5), stripe)
		_box(_head, "Brow%d" % int(side), Vector4(side * 0.023 * u, 0.026 * u, 0.02 * u, 0.0), Vector4(0.004 * u, 0.004 * u, 0.035 * u, deep * 0.5), pale)
		_box(_head, "Eye%d" % int(side), Vector4(side * 0.027 * u, 0.017 * u, 0.03 * u, 0.0), Vector4(0.005 * u, 0.008 * u, 0.008 * u, deep * 0.5), Color(0.02, 0.02, 0.02))
		_box(_head, "Ear%d" % int(side), Vector4(side * 0.017 * u, 0.04 * u, 0.0, 0.0), Vector4(0.008 * u, 0.014 * u, 0.005 * u, deep * 0.4), fur.darkened(0.2))
	_box(_head, "Nose", Vector4(0.0, 0.006 * u, 0.058 * u, 0.0), Vector4(0.006 * u, 0.005 * u, 0.004 * u, deep * 0.4), Color(0.1, 0.06, 0.05))
	# The tail, on a pivot at the rump: up when it runs, flicked in alarm.
	_tail = Node4D.new()
	_tail.name = "Tail"
	_body.add_child(_tail)
	_own(_tail)
	_tail.position = Vector4(0.0, 0.06 * u, -0.085 * u, 0.0)
	var tail := _rig(_tail, "Brush", grey.darkened(0.15))
	_ball(tail, "Root", Vector4(0.0, 0.0, 0.0, 0.0), 0.014 * u, ws * 0.8)
	_ball(tail, "Mid", Vector4(0.0, 0.025 * u, -0.045 * u, 0.0), 0.024 * u, ws * 0.8)
	_ball(tail, "Tip", Vector4(0.0, 0.06 * u, -0.095 * u, 0.0), 0.018 * u, ws * 0.8)
	tail.call("build", false)
	# The legs: a pivot and a box each, front and hind.
	for z in [0.035, -0.04]:
		for side in [-1.0, 1.0]:
			var hip := Node4D.new()
			hip.name = "Leg%s%d" % ["F" if z > 0.0 else "H", int(side)]
			_body.add_child(hip)
			_own(hip)
			hip.position = Vector4(side * 0.024 * u, 0.04 * u, z * u, 0.0)
			_box(hip, "Shank", Vector4(0.0, -0.02 * u, 0.0, 0.0), Vector4(0.01 * u, 0.04 * u, 0.012 * u, deep * 0.6), fur.darkened(0.25))
			_legs.append(hip)


func _rig(parent: Node, part: String, colour: Color) -> MeshInstance4D:
	var hide := MeshInstance4D.new()
	hide.name = part
	hide.set_script(RIG)
	var m := TetraMaterial4D.new()
	m.albedo_color = colour
	hide.material_override = m
	parent.add_child(hide)
	hide.set("profile_sides", 10)
	hide.set("profile_rings", 3)
	hide.set("verbose", false)
	hide.set("live_rebuild", false)
	_own(hide)
	return hide


func _ball(parent: Node, part: String, at: Vector4, radius: float, w_scale: float) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	node.set_script(BALL)
	parent.add_child(node)
	node.position = at
	node.set("radius", radius)
	node.set("w_scale", w_scale)
	_own(node)


func _box(parent: Node, part: String, at: Vector4, box: Vector4, colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = box
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	_own(node)
	return node


func _own(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root


# --- For the camera --------------------------------------------------------------------------

func behaviour() -> Array:
	match state:
		State.STUFF:
			return [2, "Cheeks full"]
		State.CLIMB, State.PERCH, State.DESCEND:
			return [3, "Up the tree"]
		State.ROUND_W:
			return [4, "Round the back, through W"]
	return [1, "A chipmunk"]


func centre() -> Vector4:
	return global_position + global_basis * Vector4(0.0, 0.06 * size, 0.0, 0.0)


func perform(what: String) -> void:
	match what:
		"stuff":
			_enter(State.STUFF, 4.0)
		"sit":
			_enter(State.SIT, 3.0)
		"climb":
			_start_climb(false)
		"round_w":
			_start_climb(true)
		"alarm":
			_alarm()


## A whistle: it sits bolt upright, and chips.
func hear() -> void:
	if state in [State.FORAGE, State.SIT, State.STUFF]:
		_enter(State.SIT, 2.0)


# --- Its life ---------------------------------------------------------------------------------

func _enter(s: int, seconds: float) -> void:
	state = s
	_state_t = 0.0
	_state_len = seconds


func _wood() -> Node4D:
	return get_node_or_null(wood_path) as Node4D


func _tree() -> Node4D:
	var wood := _wood()
	return wood.get("tree") as Node4D if wood != null else null


func _process(delta: float) -> void:
	_t += delta
	_state_t += delta
	_seen_check -= delta
	if _seen_check <= 0.0:
		_seen_check = 0.5
		_seen = _visible_to_camera()
	if idle_only:
		state = State.SIT if fmod(_t, 9.0) < 5.0 else State.STUFF
		if _seen:
			_animate(delta)
		return
	_check_disturbed()
	match state:
		State.FORAGE:
			_forage(delta)
		State.SIT, State.STUFF:
			if _state_t > _state_len:
				_next()
		State.CLIMB, State.ROUND_W:
			_climb(delta, 1.0)
		State.PERCH:
			if _state_t > _state_len:
				_enter(State.DESCEND, 30.0)
		State.DESCEND:
			_climb(delta, -1.0)
		State.ALARM:
			_run_to(_burrow(), delta, 2.2)
			if _flat(global_position - _burrow()) < 0.08:
				_enter(State.HIDE, _rng.randf_range(5.0, 9.0))
				visible = false
		State.HIDE:
			if _state_t > _state_len:
				visible = true
				_enter(State.SIT, 2.0)
	if _seen:
		_animate(delta)


func _visible_to_camera() -> bool:
	var lookout: Node = get_node_or_null(lookout_path)
	if lookout == null:
		return true
	var cam: Camera4D = lookout.call("current_camera")
	if cam == null:
		return true
	var rel: Vector4 = global_position - cam.global_position
	return absf(rel.dot(cam.global_basis.w)) < 3.0 and rel.length() < 60.0


func _next() -> void:
	var roll: float = _rng.randf()
	if roll < 0.45:
		_pick_spot()
		_enter(State.FORAGE, 12.0)
	elif roll < 0.62:
		_enter(State.STUFF, _rng.randf_range(3.0, 5.0))
	elif roll < 0.82:
		_start_climb(false)
	else:
		_start_climb(true)


func _check_disturbed() -> void:
	if state in [State.ALARM, State.HIDE]:
		return
	var player := get_node_or_null(player_path) as Node4D
	if player == null or not player.is_visible_in_tree() or not bool(player.get("input_enabled") if "input_enabled" in player else true):
		return
	var gap: Vector4 = player.global_position - global_position
	if Vector2(gap.x, gap.z).length() < flee_within and absf(gap.w) < 1.5:
		_alarm()


func _alarm() -> void:
	if state in [State.CLIMB, State.PERCH, State.DESCEND, State.ROUND_W]:
		# Up a tree it stays up; it just freezes.
		_state_t = 0.0
		return
	_enter(State.ALARM, 8.0)


func _burrow() -> Vector4:
	var wood := _wood()
	if wood == null:
		return _home
	return wood.global_position + wood.global_basis * (wood.call("burrow") as Vector4)


func _flat(v: Vector4) -> float:
	return Vector2(v.x, v.z).length()


func _pick_spot() -> void:
	var tree := _tree()
	var centre: Vector4 = tree.global_position if tree != null else _home
	var a: float = _rng.randf() * TAU
	var r: float = _rng.randf_range(0.8, 3.5)
	_goal = Vector4(centre.x + cos(a) * r, centre.y, centre.z + sin(a) * r, centre.w + _rng.randf_range(-0.3, 0.3))


## Short dashes, stops to nose about, and on to the next spot - or up the tree.
func _forage(delta: float) -> void:
	var gap: Vector4 = _goal - global_position
	if _flat(gap) > 0.05:
		# Dash, stop, dash: about half a second of each.
		_dash = fmod(_state_t, 0.9) < 0.5
		if _dash:
			_run_to(_goal, delta, 1.4)
	else:
		_dash = false
		if _state_t > 1.0:
			_next()


func _run_to(goal: Vector4, delta: float, speed: float) -> void:
	var gap: Vector4 = goal - global_position
	gap.y = 0.0
	var d: float = gap.length()
	if d < 0.001:
		return
	var step: float = minf(speed * size * 0.6 * delta, d)
	global_position += gap / d * step
	global_basis = Basis4D.from_zx(atan2(gap.x, gap.z))


func _start_climb(through_w: bool) -> void:
	var tree := _tree()
	if tree == null:
		_enter(State.SIT, 2.0)
		return
	_through_w = through_w
	_climb_y = 0.15
	_round = 0.0
	var seats: Array = tree.get("seats")
	_seat = (seats[_rng.randi() % seats.size()] as Vector4) if not seats.is_empty() else Vector4(0.0, 2.5, 0.0, 0.0)
	_enter(State.ROUND_W if through_w else State.CLIMB, 30.0)


## Up the trunk in a spiral to the seat's height (or down, [param way] -1), the angle round it
## climbing as it goes. Through W, "round" is the plane of the tree's z and w; otherwise of its
## z and x.
func _climb(delta: float, way: float) -> void:
	var tree := _tree()
	if tree == null:
		_enter(State.FORAGE, 5.0)
		return
	var top: float = _seat.y - 0.05
	_climb_y = clampf(_climb_y + way * 0.55 * delta, 0.1, top)
	_round += way * 1.4 * delta
	var place: Dictionary = _on_trunk(tree, _climb_y, _round, _through_w)
	global_position = place["at"]
	# Down head first: turned about its own back, so the head points down the trunk.
	global_basis = place["basis"] if way > 0.0 else (place["basis"] as Projection) * Basis4D.from_zx(PI)
	if way > 0.0 and _climb_y >= top - 0.001:
		# Out along the limb to the seat, and sit facing out.
		global_position = tree.global_position + tree.global_basis * _seat
		var out: Vector4 = global_position - (tree.call("trunk_at", _seat.y) as Vector4)
		global_basis = Basis4D.from_zx(atan2(out.x, out.z))
		_enter(State.PERCH, _rng.randf_range(3.0, 6.0))
	elif way < 0.0 and _climb_y <= 0.11:
		var off: Vector4 = global_position - (tree.call("trunk_at", 0.1) as Vector4)
		global_position = tree.global_position + Vector4(off.x, 0.0, off.z, 0.0).normalized() * 0.6
		_goal = global_position
		_enter(State.SIT, 1.5)


## A place on the trunk at [param y], [param angle] round it, and the frame that holds the
## chipmunk there: head up the trunk, back away from it.
func _on_trunk(tree: Node4D, y: float, angle: float, through_w: bool) -> Dictionary:
	var centre: Vector4 = tree.call("trunk_at", y)
	var r: float = float(tree.call("trunk_radius_at", y))
	var ws: float = float(tree.get("w_scale"))
	var tb: Projection = tree.global_basis
	var a: Vector4 = tb * Vector4(0.0, 0.0, 1.0, 0.0)
	var b: Vector4 = tb * (Vector4(0.0, 0.0, 0.0, 1.0) if through_w else Vector4(1.0, 0.0, 0.0, 0.0))
	var other: Vector4 = tb * (Vector4(1.0, 0.0, 0.0, 0.0) if through_w else Vector4(0.0, 0.0, 0.0, 1.0))
	var up: Vector4 = tb * Vector4(0.0, 1.0, 0.0, 0.0)
	var out: Vector4 = a * cos(angle) + b * sin(angle)
	# The trunk is squashed along W by its w_scale: an ellipse in the z-w plane.
	var rb: float = r * (ws if through_w else 1.0)
	var reach: float = 1.0 / sqrt(pow(cos(angle) / r, 2.0) + pow(sin(angle) / rb, 2.0))
	var tangent: Vector4 = -a * sin(angle) + b * cos(angle)
	var frame := Projection(tangent, out, up, other)
	if frame.determinant() < 0.0:
		frame.w = -frame.w
	return {"at": centre + out * (reach + 0.035 * size), "basis": frame}


# --- Posing -----------------------------------------------------------------------------------

func _animate(_delta: float) -> void:
	var u: float = size
	var run: bool = (state == State.FORAGE and _dash) or state == State.ALARM or state in [State.CLIMB, State.ROUND_W, State.DESCEND]
	var sit: bool = state in [State.SIT, State.STUFF, State.PERCH]
	# The body: low and level running; sat up on its haunches, chest high.
	var pitch: float = -1.0 if sit else 0.0
	var hop: float = absf(sin(_t * 18.0)) * 0.012 * u if run else 0.0
	_body.basis = Basis4D.from_yz(pitch)
	_body.position = Vector4(0.0, hop + (0.02 * u if sit else 0.0), -0.02 * u if sit else 0.0, 0.0)
	# The legs: a gallop's bound when running, front paws to the mouth when stuffing.
	for i in _legs.size():
		var front: bool = i < 2
		var swing: float = 0.0
		if run:
			swing = sin(_t * 18.0 + (0.0 if front else PI)) * 0.8
		elif sit and front:
			swing = -1.6 if state == State.STUFF else -0.9
		elif sit:
			swing = 1.2
		_legs[i].basis = Basis4D.from_yz(swing)
	# The head: nosing about when foraging, still and up when sitting; nibbling when stuffing.
	var nod: float = 0.0
	if state == State.FORAGE and not _dash:
		nod = 0.35 + sin(_t * 9.0) * 0.12
	elif state == State.STUFF:
		nod = 0.6 + sin(_t * 14.0) * 0.08
	elif sit:
		nod = 0.9
	_head.basis = Basis4D.from_yz(nod) * Basis4D.from_zx(sin(_t * 0.7 + float(chipmunk_seed)) * 0.4 if sit and state != State.STUFF else 0.0)
	# The cheeks fill while it stuffs, and stay full a while.
	var full: float = clampf(_state_t / 2.5, 0.0, 1.0) if state == State.STUFF else 0.0
	for c in _cheeks:
		c.basis = Basis4D.from_scale(Vector4(1.0 + full * 0.9, 1.0 + full * 0.6, 1.0 + full * 0.4, 1.0))
	# The tail: up when it runs, flicking in alarm, curled down at rest.
	var tail: float = -0.2
	if run:
		tail = -1.1
	if state == State.ALARM or (state == State.SIT and _state_t < 1.0):
		tail = -1.2 + sin(_t * 22.0) * 0.4
	_tail.basis = Basis4D.from_yz(tail)
