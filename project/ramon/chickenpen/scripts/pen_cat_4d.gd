@tool
extends Node4D

## A black cat: lofted body, head and tail, four lofted legs, wandering.
##
## LOFTED FOR THE SHAPE, RIGID FOR THE MOTION. The body is a loft chain because a cat is
## the one animal here that has to read as a smooth tapering thing rather than a stack of
## boxes - a boxy cat looks like a crate with ears. But nothing is re-lofted or skinned
## while it moves: each leg is its OWN rig, and a leg swings by rotating that rig's node
## about its top. Moving a whole node costs nothing measurable, where re-lofting a leg
## measured 7.8 ms and skinning one is a couple of milliseconds. It is also what this
## project decided it wants everywhere after the per-frame horse.
##
## SEPARATE RIGS PER LEG, rather than one rig with branch balls. Branches are how the
## horse is built and they let a single surface flow from body into limb, which is better
## looking and much harder to animate rigidly - a branch cannot be rotated on its own
## because it is part of its parent's mesh. Four small rigs can each be turned freely, and
## at a cat's size the seam at the shoulder does not show.
##
## DIAGONAL PAIRS. A cat walks front-left with back-right; putting all four on one phase
## gives a pronking rabbit, and putting them on four different phases at this size reads as
## a shuffle. Two phases, half a cycle apart, is the whole gait.

const RIG := preload("res://ramon/Model/scripts/loft_rig_4d.gd")
const BALL := preload("res://ramon/Model/scripts/loft_ball_4d.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

## Nose to tail-base, in world units. A cat beside a 1.7-unit person.
@export_range(0.2, 3.0, 0.05) var length: float = 0.78: set = _set_length
@export_range(0.05, 2.0, 0.05) var w_depth: float = 0.42: set = _set_w
@export var fur: Color = Color(0.07, 0.07, 0.09): set = _set_fur
@export var eye: Color = Color(0.85, 0.92, 0.35): set = _set_eye

@export_group("Walking")
@export var walks: bool = true
@export_range(0.05, 3.0, 0.05) var speed: float = 0.55
@export_range(0.2, 6.0, 0.1) var cadence: float = 2.1
@export_range(0.0, 1.2, 0.05) var leg_swing: float = 0.55
@export_range(0.0, 0.2, 0.005) var body_bob: float = 0.018
## How far it strays from where it was put.
@export_range(0.5, 20.0, 0.5) var roam_radius: float = 5.0
@export_range(5.0, 90.0, 1.0) var turn_rate_degrees: float = 38.0
@export_range(0.5, 12.0, 0.1) var pause_min: float = 1.5
@export_range(0.5, 20.0, 0.1) var pause_max: float = 5.0

var _legs: Array[Node4D] = []
var _tail: Node4D
var _spine: Node4D
var _home := Vector4.ZERO
var _heading: float = 0.0
var _clock: float = 0.0
var _pause: float = 0.0
var _rest_y: float = 0.0
var _rng := RandomNumberGenerator.new()


func _set_length(v: float) -> void: length = v; _later()
func _set_w(v: float) -> void: w_depth = v; _later()
func _set_fur(v: Color) -> void: fur = v; _later()
func _set_eye(v: Color) -> void: eye = v; _later()


func _ready() -> void:
	_rng.seed = 5150
	_home = position
	_rest_y = position.y
	_heading = _rng.randf_range(0.0, TAU)
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_legs.clear()
	var u: float = length

	# Spine, nose to hips, as one chain. The head is the front of it rather than a separate
	# piece, so the neck is a taper instead of a joint.
	_spine = _chain("Spine", Vector4.ZERO, [
		[Vector4(0.0, 0.40 * u, 0.52 * u, 0.0), 0.085 * u],
		[Vector4(0.0, 0.42 * u, 0.40 * u, 0.0), 0.105 * u],
		[Vector4(0.0, 0.38 * u, 0.24 * u, 0.0), 0.075 * u],
		[Vector4(0.0, 0.40 * u, 0.06 * u, 0.0), 0.125 * u],
		[Vector4(0.0, 0.40 * u, -0.16 * u, 0.0), 0.130 * u],
		[Vector4(0.0, 0.38 * u, -0.36 * u, 0.0), 0.105 * u],
	])

	# Ears and eyes, as blocks - a loft cannot make a point, and a cat without ears is an
	# otter.
	for side in [1.0, -1.0]:
		_block("Ear%s" % ("L" if side > 0.0 else "R"),
			Vector4(side * 0.055 * u, 0.50 * u, 0.50 * u, 0.0),
			Vector3(0.05 * u, 0.09 * u, 0.04 * u), fur)
		_block("Eye%s" % ("L" if side > 0.0 else "R"),
			Vector4(side * 0.048 * u, 0.42 * u, 0.575 * u, 0.0),
			Vector3(0.028 * u, 0.022 * u, 0.02 * u), eye)

	# The tail, its own rig so it can sway on its own.
	_tail = _chain("Tail", Vector4(0.0, 0.40 * u, -0.36 * u, 0.0), [
		[Vector4(0.0, 0.0, 0.0, 0.0), 0.040 * u],
		[Vector4(0.0, 0.04 * u, -0.14 * u, 0.0), 0.032 * u],
		[Vector4(0.0, 0.12 * u, -0.25 * u, 0.0), 0.026 * u],
		[Vector4(0.0, 0.22 * u, -0.31 * u, 0.0), 0.020 * u],
	])

	# Four legs, each hung from its own shoulder or hip so it can be turned alone.
	var hips := [
		["LegFL", 0.075, 0.20], ["LegFR", -0.075, 0.20],
		["LegBL", 0.080, -0.24], ["LegBR", -0.080, -0.24],
	]
	for row in hips:
		var leg := _chain(String(row[0]),
			Vector4(float(row[1]) * u, 0.36 * u, float(row[2]) * u, 0.0), [
				[Vector4(0.0, 0.0, 0.0, 0.0), 0.048 * u],
				[Vector4(0.0, -0.15 * u, 0.0, 0.0), 0.038 * u],
				[Vector4(0.0, -0.30 * u, 0.02 * u, 0.0), 0.042 * u],
			])
		_legs.append(leg)


## One loft rig with its balls, built once and then left alone.
func _chain(part: String, at: Vector4, balls: Array) -> Node4D:
	var rig := MeshInstance4D.new()
	rig.name = part
	rig.set_script(RIG)
	var material := TetraMaterial4D.new()
	material.albedo_color = fur
	rig.material_override = material
	add_child(rig)
	rig.position = at
	rig.set("profile_sides", 8)
	rig.set("profile_rings", 3)
	# Off BEFORE the balls go in: with it on, every ball added re-lofts the whole chain,
	# and the rig then re-checks its own signature every frame forever afterwards.
	rig.set("live_rebuild", false)
	_own(rig)

	for i in balls.size():
		var row: Array = balls[i]
		var ball := MeshInstance4D.new()
		ball.name = "Ball%d" % (i + 1)
		ball.set_script(BALL)
		rig.add_child(ball)
		ball.position = row[0]
		ball.set("radius", float(row[1]))
		_own(ball)

	if rig.has_method("build"):
		rig.call("build", false)
	return rig


func _block(part: String, at: Vector4, box: Vector3, colour: Color) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(box.x, box.y, box.z, w_depth * 0.6)
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


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not walks or _legs.size() < 4:
		return
	_clock += delta
	_wander(delta)
	_step()


func _wander(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	# Turn back when it has strayed, otherwise drift. Same shape as the chickens' leash.
	var offset: Vector4 = position - _home
	var strayed: float = Vector2(offset.x, offset.z).length()
	if strayed > roam_radius:
		var home_angle: float = atan2(-offset.x, -offset.z)
		_heading = rotate_toward(_heading, home_angle, deg_to_rad(turn_rate_degrees) * delta * 2.0)
	else:
		_heading += sin(_clock * 0.7) * deg_to_rad(turn_rate_degrees) * delta * 0.5
	position += Vector4(sin(_heading), 0.0, cos(_heading), 0.0) * speed * delta
	basis = Basis4D.from_zx(_heading)
	# Cats stop. Often.
	if _rng.randf() < delta * 0.12:
		_pause = _rng.randf_range(pause_min, pause_max)


## Legs on two phases, half a cycle apart; tail and body carried along.
func _step() -> void:
	var moving: float = 0.0 if _pause > 0.0 else 1.0
	var phase: float = _clock * cadence
	for i in _legs.size():
		# FL and BR share a phase; FR and BL share the other. Indices are FL, FR, BL, BR.
		var diagonal: bool = i == 0 or i == 3
		var swing: float = sin(phase + (0.0 if diagonal else PI)) * leg_swing * moving
		_legs[i].basis = Basis4D.from_yz(swing)
	if _spine != null:
		_spine.position.y = sin(phase * 2.0) * body_bob * moving
	if _tail != null:
		# A slow sway of its own, plus a lift while walking. It never stops entirely,
		# because a still tail on a moving cat is the thing that looks wrong.
		_tail.basis = Basis4D.from_zx(sin(_clock * 1.3) * 0.35) \
			* Basis4D.from_yz(-0.25 - sin(phase) * 0.12 * moving)
