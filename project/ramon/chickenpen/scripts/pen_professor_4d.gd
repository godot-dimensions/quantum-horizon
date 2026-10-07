@tool
extends Node4D

## The professor, a mystical ritual tech wizard (Ramon, 6 Oct 2026: "he should look like a mystical
## ritual tech wizard, no pickaxe anymore"; before it, a miner in a helmet with a pick). He stands by
## the cave's road, its door four metres ana behind him.
##
## THE SAME AVATAR AS EVERYBODY ELSE, so he inherits every proportion fix the others get. What makes
## him himself is what is added in boxes, as before: a long robe over the legs with a gold hem and a
## gold stripe, a tall crooked hat with a gold band and a glowing rune, a long white beard, one glowing
## lens over an eye (the tech in the mystic), and a staff in place of the pick, a fork of gold at its
## top holding a crystal that floats and turns. Round his feet a faint ritual ring on the ground, turning
## slowly with four runes on it. The glow is the lab's (LabKit/lab_materials.gd glow), the ring and the
## crystal move only in play.

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export var robe: Color = Color(0.16, 0.13, 0.34): set = _set_colour
@export var skin: Color = Color(0.88, 0.72, 0.58): set = _set_colour
@export var hair: Color = Color(0.86, 0.85, 0.82): set = _set_colour
@export var trim: Color = Color(0.86, 0.68, 0.26): set = _set_colour
@export var rune: Color = Color(0.32, 0.92, 1.0): set = _set_colour
@export var wood: Color = Color(0.30, 0.20, 0.14): set = _set_colour
## How fast the ritual ring turns (turns a second) and the crystal bobs.
@export_range(0.0, 1.0, 0.01) var ring_turns: float = 0.06
@export_range(0.0, 0.2, 0.005, "suffix:m") var crystal_bob: float = 0.04

var _figure: Node4D
var _ring: Node4D
var _crystal: Node4D
var _time: float = 0.0


func _set_colour(_v: Color) -> void: _later()


func _ready() -> void:
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	if _ring != null:
		_ring.basis = Basis4D.from_zx(_time * ring_turns * TAU)
	if _crystal != null:
		_crystal.position.y = 1.86 + sin(_time * 1.7) * crystal_bob
		_crystal.basis = Basis4D.from_zx(_time * 0.9) * Basis4D.from_xy(PI * 0.25)


func rebuild() -> void:
	for child in get_children():
		child.free()
	_ring = null
	_crystal = null

	# Properties BEFORE add_child: the avatar builds itself in _ready, which fires the
	# moment it is parented, and anything set afterwards arrives too late to affect it.
	var figure := Node4D.new()
	figure.name = "Figure"
	figure.set_script(AVATAR)
	figure.set("build", 2)
	figure.set("skin", robe)
	figure.set("accent", skin)
	figure.set("hair", hair)
	figure.set("wear_cap", false)
	figure.set("eyes", true)
	figure.set("eye_colour", Color(0.16, 0.13, 0.11))
	figure.set("eye_spacing", 0.062)
	figure.set("eye_height", 0.025)
	figure.set("eye_width", 0.036)
	figure.set("eye_tall", 0.044)
	add_child(figure)
	_own(figure)
	_figure = figure
	_robe_legs(figure)

	# THE ROBE: the legs painted robe, and over them a skirt that flares to just above the boots,
	# its hem and a stripe down the front in gold. On the figure, not on the legs (he stands).
	_box(figure, "RobeUpper", Vector4(0.0, 0.36, 0.0, 0.0), Vector3(0.42, 0.26, 0.30), robe)
	_box(figure, "RobeLower", Vector4(0.0, 0.15, 0.0, 0.0), Vector3(0.50, 0.22, 0.36), robe)
	_box(figure, "Hem", Vector4(0.0, 0.05, 0.0, 0.0), Vector3(0.52, 0.035, 0.38), trim)
	_box(figure, "Stripe", Vector4(0.0, 0.26, 0.185, 0.0), Vector3(0.05, 0.44, 0.012), trim)

	# THE HEAD: the hat, the beard and the lens sit on the head ball, so they come along when he
	# turns to face somebody.
	var head: Node4D = figure.get_node_or_null("Tunic/Head") as Node4D
	var on: Node = head if head != null else figure
	# A tall hat in four shrinking courses, each a little further forward: the crooked tip of a
	# wizard's hat in blocks. A gold band at its foot, a rune glowing on the band's front.
	_box(on, "HatBrim", Vector4(0.0, 0.16, 0.0, 0.0), Vector3(0.46, 0.04, 0.44), robe)
	var courses := [[0.31, 0.13, 0.00], [0.24, 0.13, 0.025], [0.16, 0.12, 0.06], [0.09, 0.11, 0.10]]
	var y: float = 0.18
	for i in courses.size():
		var c: Array = courses[i]
		y += float(c[1]) * 0.5
		_box(on, "Hat%d" % i, Vector4(0.0, y, float(c[2]), 0.0), Vector3(float(c[0]), float(c[1]), float(c[0])), robe)
		y += float(c[1]) * 0.5
	_box(on, "HatBand", Vector4(0.0, 0.215, 0.0, 0.0), Vector3(0.325, 0.045, 0.325), trim)
	_box(on, "HatRune", Vector4(0.0, 0.215, 0.166, 0.0), Vector3(0.06, 0.03, 0.012), rune, true)
	# A long beard under the chin, the colour of his hair.
	_box(on, "Beard", Vector4(0.0, -0.17, 0.13, 0.0), Vector3(0.20, 0.26, 0.07), hair)
	# One lens over his right eye, glowing: the tech in the mystic.
	_box(on, "Lens", Vector4(-0.062, 0.025, 0.155, 0.0), Vector3(0.07, 0.07, 0.02), rune, true)
	_box(on, "LensRim", Vector4(-0.062, 0.025, 0.150, 0.0), Vector3(0.09, 0.09, 0.012), trim)

	# THE STAFF, where the pick was: out at arm's length and upright, taller than he is, a fork of
	# gold at its top holding a crystal that floats in it.
	var staff := Node4D.new()
	staff.name = "Staff"
	add_child(staff)
	staff.position = Vector4(-0.40, 0.0, 0.10, 0.0)
	_own(staff)
	_box(staff, "Shaft", Vector4(0.0, 0.85, 0.0, 0.0), Vector3(0.04, 1.70, 0.04), wood)
	_box(staff, "Collar", Vector4(0.0, 1.70, 0.0, 0.0), Vector3(0.07, 0.06, 0.07), trim)
	for side in [-1.0, 1.0]:
		var prong: MeshInstance4D = _box(staff, "Prong%s" % ("L" if side < 0.0 else "R"), Vector4(side * 0.06, 1.80, 0.0, 0.0),
			Vector3(0.03, 0.16, 0.03), trim)
		prong.basis = Basis4D.from_xy(-side * 0.35)
	_crystal = Node4D.new()
	_crystal.name = "Crystal"
	staff.add_child(_crystal)
	_crystal.position = Vector4(0.0, 1.86, 0.0, 0.0)
	_crystal.basis = Basis4D.from_xy(PI * 0.25)
	_own(_crystal)
	_box(_crystal, "Gem", Vector4.ZERO, Vector3(0.09, 0.09, 0.09), rune, true)

	# THE RITUAL RING on the ground round his feet: sixteen thin glowing pieces, four runes.
	_ring = Node4D.new()
	_ring.name = "Ring"
	add_child(_ring)
	_own(_ring)
	var r: float = 0.85
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		var piece: MeshInstance4D = _box(_ring, "Arc%d" % k, Vector4(cos(a) * r, 0.012, sin(a) * r, 0.0),
			Vector3(2.0 * r * tan(PI / 16.0) * 0.8, 0.012, 0.025), rune, true)
		piece.basis = Basis4D.from_zx(-a + PI * 0.5)
	for k in 4:
		var a: float = TAU * float(k) / 4.0 + PI * 0.25
		var glyph: MeshInstance4D = _box(_ring, "Rune%d" % k, Vector4(cos(a) * (r + 0.16), 0.012, sin(a) * (r + 0.16), 0.0),
			Vector3(0.10, 0.012, 0.10), rune, true)
		glyph.basis = Basis4D.from_zx(a)


## The legs in the robe's colour (the chibi build paints them with `accent`, his skin): under the robe
## they show only as he turns, and they should read as robe. The boots are left their own.
func _robe_legs(figure: Node4D) -> void:
	var parts: Array[String] = ["Tunic/Belt"]
	for tag in ["L", "R"]:
		parts.append("Hip%s/Thigh%s" % [tag, tag])
		parts.append("Hip%s/Knee%s/Shin%s" % [tag, tag, tag])
	for path in parts:
		var limb: MeshInstance4D = figure.get_node_or_null(path) as MeshInstance4D
		if limb == null:
			continue
		var material := TetraMaterial4D.new()
		material.albedo_color = trim if path == "Tunic/Belt" else robe
		limb.material_override = material


func _box(parent: Node, part: String, at: Vector4, size: Vector3, colour: Color, glow: bool = false) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	# A real extent through W, or he vanishes the moment the slice moves.
	mesh.size = Vector4(size.x, size.y, size.z, maxf(maxf(size.x, size.z), 0.42))
	node.mesh = mesh
	if glow:
		node.material_override = Mats.glow(colour, 1.0)
	else:
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
