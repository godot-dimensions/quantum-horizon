@tool
extends Node4D

## Somebody in a suit: the miner in the spacesuit, and the three researchers in white.
##
## THE SAME AVATAR AS EVERYBODY ELSE (block_avatar_4d, the chibi build), so the cave's
## people stand, turn and scale like the pen's. A suit is paint on it plus a helmet, a
## visor and a pack - the professor's rule that a new character should not need a new body.
##
## THEY ARE BUSY, NOT WAITING. Each has one thing they are doing, as a slow motion of whole
## limbs (moving a node costs nothing measurable; deforming a mesh costs 2.5 us a
## tetrahedron): the surveyor sights down the instrument, the kneeling one takes samples at
## the plinth's foot, the one with the tablet reads and taps, the miner leans on his pick
## and looks at the thing. They do not stop for you, apart from the miner, who talks.

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")

enum Task { MINER, SURVEY, SAMPLE, TABLET }

@export var task: Task = Task.SURVEY: set = _set_task
@export var suit: Color = Color(0.93, 0.94, 0.95): set = _set_colour
@export var trim: Color = Color(0.62, 0.66, 0.72): set = _set_colour
@export var visor: Color = Color(0.06, 0.08, 0.12): set = _set_colour
@export var boots: Color = Color(0.30, 0.31, 0.33): set = _set_colour
## So three researchers doing the same job are not in step.
@export var phase: float = 0.0
## Which way they face, as the player's yaw convention (0 faces +z; atan2(x, z) of the
## direction). An angle rather than a hand-written basis, which is how facings in this
## project have gone wrong before.
@export_range(-180.0, 180.0, 0.5) var yaw_degrees: float = 0.0

var _figure: Node4D
var _parts := {}
var _t := 0.0
## Seconds of panic left, and the way they turn to face while it lasts.
var _panic := 0.0
var _panic_yaw := 0.0
var _yaw := 0.0


func _set_task(v: Task) -> void: task = v; _later()
func _set_colour(_v: Color) -> void: _later()


func _ready() -> void:
	_yaw = deg_to_rad(yaw_degrees)
	if not Engine.is_editor_hint():
		basis = Basis4D.from_zx(_yaw)
	rebuild()


## Somebody has taken a pick to the cube. Turn to [param towards] (world space), hands up,
## for [param seconds], then go back to work - more slowly than they stopped.
func panic(seconds: float, towards: Vector4) -> void:
	_panic = seconds
	var d: Vector4 = towards - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		# The player's facing convention: atan2(x, z), +z is the way a figure faces.
		_panic_yaw = atan2(d.x, d.z)


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	_parts.clear()
	var figure := Node4D.new()
	figure.name = "Figure"
	figure.set_script(AVATAR)
	figure.set("build", 2)
	figure.set("skin", suit)
	figure.set("accent", suit)
	figure.set("hair", suit)
	figure.set("wear_cap", false)
	add_child(figure)
	_figure = figure
	# The avatar's waistband and boots are its own brown; a suit is one piece.
	_repaint(figure, "Tunic/Belt", trim)
	for tag in ["L", "R"]:
		_repaint(figure, "Hip%s/Knee%s/Ankle%s/Boot%s" % [tag, tag, tag, tag], boots)
		_repaint(figure, "Shoulder%s/Elbow%s/Hand%s" % [tag, tag, tag], trim)
	var head: Node4D = figure.get_node_or_null("Tunic/Head") as Node4D
	var torso: Node4D = figure.get_node_or_null("Tunic") as Node4D
	if head != null:
		# A helmet round the head rather than a hat on it: bigger than the head in every
		# direction, so none of the head shows - through W too, in the head's proportion (0.285
		# to 0.30 across), the visor across the whole front, which is a face in x and W.
		_box(head, "Helmet", Vector4(0.0, 0.03, -0.01, 0.0), Vector3(0.40, 0.40, 0.39), suit, 0.38)
		_box(head, "Visor", Vector4(0.0, 0.02, 0.19, 0.0), Vector3(0.30, 0.19, 0.03), visor, 0.285)
		_box(head, "Collar", Vector4(0.0, -0.19, 0.0, 0.0), Vector3(0.34, 0.06, 0.32), trim, 0.32)
	if torso != null:
		# On the body, in the tunic's proportion (0.35 to 0.38 across).
		_box(torso, "Pack", Vector4(0.0, 0.05, -0.20, 0.0), Vector3(0.32, 0.38, 0.14), trim, 0.29)
		_box(torso, "Chest", Vector4(0.0, 0.08, 0.125, 0.0), Vector3(0.16, 0.10, 0.02), trim, 0.15)
	# What they hold: a small thing square, a slab as thick through W as it is deep, a rod as thick
	# through W as it is across.
	match task:
		Task.MINER:
			if head != null:
				_box(head, "Lamp", Vector4(0.0, 0.20, 0.17, 0.0), Vector3(0.10, 0.07, 0.06), Color(1.0, 0.96, 0.72), 0.10)
			if torso != null:
				_box(torso, "Stripe", Vector4(0.0, -0.06, 0.125, 0.0), Vector3(0.39, 0.05, 0.02), Color(0.95, 0.52, 0.12), 0.36)
			_pick()
		Task.TABLET:
			var hand: Node4D = figure.get_node_or_null("ShoulderR/ElbowR") as Node4D
			if hand != null:
				_box(hand, "Tablet", Vector4(0.08, -0.22, 0.10, 0.0), Vector3(0.26, 0.02, 0.18), Color(0.12, 0.13, 0.15), 0.18)
				_box(hand, "Screen", Vector4(0.08, -0.205, 0.10, 0.0), Vector3(0.22, 0.01, 0.14), Color(0.45, 0.80, 1.0), 0.14)
		Task.SAMPLE:
			var hand: Node4D = figure.get_node_or_null("ShoulderR/ElbowR") as Node4D
			if hand != null:
				_box(hand, "Probe", Vector4(0.0, -0.30, 0.0, 0.0), Vector3(0.03, 0.22, 0.03), Color(0.75, 0.77, 0.80), 0.03)
	for part in ["ShoulderL", "ShoulderR", "ShoulderL/ElbowL", "ShoulderR/ElbowR", "Tunic/Head",
			"HipL", "HipR", "HipL/KneeL", "HipR/KneeR", "HipL/KneeL/AnkleL", "HipR/KneeR/AnkleR"]:
		_parts[part] = figure.get_node_or_null(part)
	_pose(0.0)


## The miner's pick, resting on the ground against him, head up.
func _pick() -> void:
	var prop := Node4D.new()
	prop.name = "Pick"
	add_child(prop)
	prop.position = Vector4(0.36, 0.0, 0.18, 0.0)
	prop.basis = Basis4D.from_xy(-0.12)
	_box(prop, "Haft", Vector4(0.0, 0.42, 0.0, 0.0), Vector3(0.04, 0.84, 0.04), Color(0.45, 0.30, 0.18), 0.04)
	_box(prop, "Head", Vector4(0.0, 0.86, 0.0, 0.0), Vector3(0.46, 0.06, 0.05), Color(0.62, 0.65, 0.70), 0.05)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_panic = maxf(_panic - delta, 0.0)
	var want: float = _panic_yaw if _panic > 0.0 else deg_to_rad(yaw_degrees)
	_yaw = lerp_angle(_yaw, want, minf(1.0, delta * (9.0 if _panic > 0.0 else 1.5)))
	basis = Basis4D.from_zx(_yaw)
	_pose(_t + phase)


## One slow motion per task, in whole limbs.
func _pose(t: float) -> void:
	if _figure == null:
		return
	if _panic > 0.0 and task != Task.MINER:
		# On their feet, both hands up, shaking - whatever they were doing a moment ago.
		_figure.position = Vector4.ZERO
		for part in ["HipL", "HipR", "HipL/KneeL", "HipR/KneeR", "HipL/KneeL/AnkleL", "HipR/KneeR/AnkleR", "ShoulderL/ElbowL", "ShoulderR/ElbowR"]:
			_turn(part, 0.0)
		var shake: float = 0.12 * sin(t * 15.0)
		_turn("ShoulderL", -2.7 + shake)
		_turn("ShoulderR", -2.7 - shake)
		_turn("Tunic/Head", -0.2)
		return
	match task:
		Task.SURVEY:
			# Leaning in to the eyepiece and back, one hand on the instrument.
			_turn("ShoulderR", -1.25 + 0.06 * sin(t * 0.9))
			_turn("ShoulderR/ElbowR", -0.35)
			_turn("ShoulderL", -0.2 + 0.1 * sin(t * 0.5))
			_turn("Tunic/Head", 0.25 + 0.15 * sin(t * 0.45))
		Task.SAMPLE:
			# Down on one knee, reaching to the foot of the plinth and back.
			_figure.position = Vector4(0.0, -0.26, 0.0, 0.0)
			_turn("HipL", -1.45)
			_turn("HipL/KneeL", 1.55)
			_turn("HipL/KneeL/AnkleL", -0.1)
			_turn("HipR", -0.2)
			_turn("HipR/KneeR", 1.5)
			_turn("HipR/KneeR/AnkleR", -1.3)
			var reach: float = 0.5 + 0.5 * sin(t * 0.7)
			_turn("ShoulderR", -0.7 - 0.5 * reach)
			_turn("ShoulderR/ElbowR", -0.3 * (1.0 - reach))
			_turn("Tunic/Head", 0.35 + 0.1 * reach)
		Task.TABLET:
			# Reading, and now and then a tap.
			_turn("ShoulderR", -0.55)
			_turn("ShoulderR/ElbowR", -0.95)
			var tap: float = maxf(0.0, sin(t * 1.7)) * 0.25
			_turn("ShoulderL", -0.5 - tap)
			_turn("ShoulderL/ElbowL", -0.9)
			_turn("Tunic/Head", 0.45 + 0.05 * sin(t * 0.8))
		Task.MINER:
			# One hand on the pick, looking up at the thing now and then.
			_turn("ShoulderL", -0.25)
			_turn("ShoulderL/ElbowL", -0.4)
			_turn("Tunic/Head", -0.18 * maxf(0.0, sin(t * 0.25)))


## A forward-back swing of one joint - the plane the gait swings legs in.
func _turn(part: String, angle: float) -> void:
	var node: Node4D = _parts.get(part) as Node4D
	if node != null:
		node.basis = Basis4D.from_yz(angle)


func _repaint(figure: Node, path: String, colour: Color) -> void:
	var limb: MeshInstance4D = figure.get_node_or_null(path) as MeshInstance4D
	if limb == null:
		return
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	limb.material_override = material


## [param w] is the thickness through W; left out, the old slab: the larger of width and depth, at least 0.42.
func _box(parent: Node, part: String, at: Vector4, size: Vector3, colour: Color, w: float = 0.0) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	# A real extent through W, or they vanish the moment the slice moves.
	mesh.size = Vector4(size.x, size.y, size.z, w if w > 0.0 else maxf(maxf(size.x, size.z), 0.42))
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node
