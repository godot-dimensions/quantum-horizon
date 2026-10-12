@tool
extends Node4D

## The professor: mystical, but rustic (Ramon, 7 Oct: "don't make the proffesor look like a typical wizard, more
## like brown and red tones and mystical in a rustic way, maybe a hoody"; before it, 6 Oct, a ritual tech wizard
## in a tall hat and a glowing lens, and before that a miner). He stands by the cave's road, its door four metres
## ana behind him.
##
## THE SAME AVATAR AS EVERYBODY ELSE, so he inherits every proportion fix the others get. What makes him himself
## is added in boxes: a brown tunic and trousers with a leather belt, a rust red hood raised over his head (his
## ears under it) and a short cape over his shoulders and down his back, a short grizzled beard, and an amber
## amulet glowing on his chest. No robe and no staff (Ramon, 7 Oct: "give the proffesor legs, not this weird dress.
## remove the stick. his ear clips in the robe"). The round marker at his feet is the pen's NPC marker now
## (pen_npc_markers_4d.gd). The glow is the lab's (LabKit/lab_materials.gd glow).

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export var robe: Color = Color(0.30, 0.19, 0.12): set = _set_colour
@export var mantle: Color = Color(0.50, 0.16, 0.10): set = _set_colour
@export var skin: Color = Color(0.86, 0.69, 0.55): set = _set_colour
@export var hair: Color = Color(0.40, 0.37, 0.34): set = _set_colour
@export var leather: Color = Color(0.22, 0.14, 0.09): set = _set_colour
@export var trousers: Color = Color(0.24, 0.16, 0.10): set = _set_colour
@export var rune: Color = Color(1.0, 0.58, 0.16): set = _set_colour
@export var wood: Color = Color(0.33, 0.22, 0.14): set = _set_colour

var _figure: Node4D
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


func rebuild() -> void:
	for child in get_children():
		child.free()

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


	# THE CAPE AND THE AMULET, on the tunic so they go where it goes: a short cape over the shoulders and down
	# the back in the hood's red, and an amber stone on a cord on the chest.
	#
	# THICKNESS THROUGH W, as the player's figure has it: what hangs on the body is as thick through W as
	# it is wide, in the body's own proportion (the tunic is 0.35 through W to 0.38 across: 0.92), and a
	# small thing is square (as thick through W as it is wide). The hood goes with the head: 0.285 through
	# W to 0.30 across, 0.95.
	var tunic: Node4D = figure.get_node_or_null("Tunic") as Node4D
	var body: Node = tunic if tunic != null else figure
	_box(body, "Cape", Vector4(0.0, 0.17, -0.01, 0.0), Vector3(0.47, 0.13, 0.30), mantle, false, 0.43)
	_box(body, "CapeBack", Vector4(0.0, -0.05, -0.135, 0.0), Vector3(0.43, 0.40, 0.03), mantle, false, 0.40)
	_box(body, "Cord", Vector4(0.0, 0.10, 0.126, 0.0), Vector3(0.10, 0.012, 0.012), leather, false, 0.10)
	_box(body, "Amulet", Vector4(0.0, 0.05, 0.13, 0.0), Vector3(0.06, 0.07, 0.02), rune, true, 0.06)

	# THE HEAD: the hood, raised over it, and a short beard, on the head ball so they come along when he turns
	# to face somebody. The hood is a top, a back, two sides deep enough to hide the ears, and a lip over the
	# brow that shades the face, with a small peak at the back. The top, back and lip reach through W as
	# the head does, and the sides come as two pairs: left and right along x, and the same slab turned a
	# quarter through W, ana and kata, so the hood closes round the head in W as it does in x.
	var head: Node4D = figure.get_node_or_null("Tunic/Head") as Node4D
	var on: Node = head if head != null else figure
	_box(on, "HoodTop", Vector4(0.0, 0.185, -0.01, 0.0), Vector3(0.37, 0.05, 0.35), mantle, false, 0.35)
	_box(on, "HoodBack", Vector4(0.0, 0.02, -0.17, 0.0), Vector3(0.37, 0.36, 0.05), mantle, false, 0.35)
	_box(on, "HoodL", Vector4(0.19, 0.03, -0.005, 0.0), Vector3(0.07, 0.34, 0.33), mantle, false, 0.35)
	_box(on, "HoodR", Vector4(-0.19, 0.03, -0.005, 0.0), Vector3(0.07, 0.34, 0.33), mantle, false, 0.35)
	_box(on, "HoodA", Vector4(0.0, 0.03, -0.005, 0.18), Vector3(0.37, 0.34, 0.33), mantle, false, 0.07)
	_box(on, "HoodK", Vector4(0.0, 0.03, -0.005, -0.18), Vector3(0.37, 0.34, 0.33), mantle, false, 0.07)
	_box(on, "HoodLip", Vector4(0.0, 0.155, 0.15, 0.0), Vector3(0.37, 0.06, 0.05), mantle.darkened(0.15), false, 0.35)
	_box(on, "HoodPeak", Vector4(0.0, 0.2, -0.2, 0.0), Vector3(0.12, 0.08, 0.08), mantle, false, 0.12)
	_box(on, "Beard", Vector4(0.0, -0.12, 0.13, 0.0), Vector3(0.22, 0.13, 0.07), hair, false, 0.21)
	# The ears are under the hood: the avatar's own, poking through its sides, are taken off.
	if head != null:
		for ear in ["EarL", "EarR"]:
			var e: Node = head.get_node_or_null(ear)
			if e != null:
				e.free()



## The legs in his trousers' colour (the chibi build paints them with `accent`, his skin), the belt leather. The
## boots are left their own.
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
		material.albedo_color = leather if path == "Tunic/Belt" else trousers
		limb.material_override = material


## [param w] is the thickness through W; left out, the old slab: the larger of width and depth, at least 0.42.
func _box(parent: Node, part: String, at: Vector4, size: Vector3, colour: Color, glow: bool = false, w: float = 0.0) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	# A real extent through W, or he vanishes the moment the slice moves.
	mesh.size = Vector4(size.x, size.y, size.z, w if w > 0.0 else maxf(maxf(size.x, size.z), 0.42))
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
