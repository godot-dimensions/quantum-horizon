@tool
extends Node4D

## The mining professor: a figure in a helmet with a pick, standing beside the rock.
##
## THE SAME AVATAR AS EVERYBODY ELSE, so he inherits every proportion fix the others get.
## What makes him himself is three boxes on his head and a pick resting against his
## shoulder - and that is deliberately all of it, because a character who needs a new body
## to be a new character means the next one will too.
##
## THE PICK IS NOT THE PLAYER'S. pen_pickaxe_4d builds one, but that one is a tool: it
## hangs off an elbow, it swings, it raycasts, it asks a belt whether it is in hand. His
## is scenery. Sharing the code would mean either carrying all of that dead weight or
## pulling the geometry out into a third file for the sake of two users, and the geometry
## is nine boxes.

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild

@export var coat: Color = Color(0.30, 0.34, 0.42): set = _set_coat
@export var skin: Color = Color(0.88, 0.72, 0.58): set = _set_skin
@export var hair: Color = Color(0.82, 0.80, 0.76): set = _set_hair
## Denim, for the legs. The chibi build paints thigh and shin with `accent`, which is
## his skin, so out of the box he is a man in a coat and no trousers - fine on a figure
## nobody stands close to, and not fine now that a conversation puts a camera on him.
##
## REPAINTED AFTER THE BUILD rather than added to the avatar as a fourth colour: every
## other figure in the field shares that script, and a new export on it is a decision
## about all of them. This is one character wanting trousers.
@export var trousers: Color = Color(0.22, 0.31, 0.52): set = _set_trousers
@export var helmet: Color = Color(0.92, 0.66, 0.16): set = _set_helmet
@export var lamp: Color = Color(1.0, 0.96, 0.70): set = _set_lamp
@export var haft: Color = Color(0.55, 0.36, 0.20): set = _set_haft
@export var head_iron: Color = Color(0.68, 0.71, 0.76): set = _set_iron

var _figure: Node4D


func _set_coat(v: Color) -> void: coat = v; _later()
func _set_trousers(v: Color) -> void: trousers = v; _later()
func _set_skin(v: Color) -> void: skin = v; _later()
func _set_hair(v: Color) -> void: hair = v; _later()
func _set_helmet(v: Color) -> void: helmet = v; _later()
func _set_lamp(v: Color) -> void: lamp = v; _later()
func _set_haft(v: Color) -> void: haft = v; _later()
func _set_iron(v: Color) -> void: head_iron = v; _later()


func _ready() -> void:
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()

	# Properties BEFORE add_child: the avatar builds itself in _ready, which fires the
	# moment it is parented, and anything set afterwards arrives too late to affect it.
	var figure := Node4D.new()
	figure.name = "Figure"
	figure.set_script(AVATAR)
	figure.set("build", 2)
	figure.set("skin", coat)
	figure.set("accent", skin)
	figure.set("hair", hair)
	figure.set("wear_cap", false)
	# Close-set and small under the helmet brim: peering at something.
	figure.set("eyes", true)
	figure.set("eye_colour", Color(0.16, 0.13, 0.11))
	figure.set("eye_spacing", 0.062)
	figure.set("eye_height", 0.025)
	figure.set("eye_width", 0.036)
	figure.set("eye_tall", 0.044)
	add_child(figure)
	_own(figure)
	_figure = figure

	_wear_trousers(figure)

	# THE HELMET SITS ON THE HEAD BALL, not on this node, so it comes along when he turns
	# to face somebody. The lamp is a separate block rather than a bright face on the
	# helmet, because a flat colour on a box reads as paint and a block that sticks out
	# reads as a lamp.
	var head: Node4D = figure.get_node_or_null("Tunic/Head") as Node4D
	var on: Node = head if head != null else figure
	_box(on, "Helmet", Vector4(0.0, 0.17, 0.0, 0.0), Vector3(0.34, 0.15, 0.32), helmet)
	_box(on, "Brim", Vector4(0.0, 0.11, 0.17, 0.0), Vector3(0.34, 0.05, 0.10), helmet)
	# ON THE BROW OF THE HELMET, not on his face. At 0.18 up it sat level with his eyes
	# and read as a bandage.
	_box(on, "Lamp", Vector4(0.0, 0.155, 0.185, 0.0), Vector3(0.10, 0.07, 0.05), lamp)

	# The pick, leaning on his shoulder. Built here rather than borrowed from the tool -
	# see the header.
	var prop := Node4D.new()
	prop.name = "Pick"
	add_child(prop)
	# OUT AT ARM'S LENGTH AND UPRIGHT. Tucked in at his shoulder the head of it was
	# behind his own, and the one thing he is meant to be holding was the one thing you
	# could not see.
	prop.position = Vector4(-0.40, 0.42, 0.10, 0.0)
	prop.basis = Basis4D.from_xy(0.20)
	_own(prop)
	_box(prop, "Haft", Vector4(0.0, 0.10, 0.0, 0.0), Vector3(0.035, 0.70, 0.035), haft)
	_box(prop, "Collar", Vector4(0.0, 0.42, 0.0, 0.0), Vector3(0.062, 0.070, 0.062), head_iron)
	for side in [-1.0, 1.0]:
		var tag: String = "L" if side < 0.0 else "R"
		var steps := [[0.070, 0.436, 0.094, 0.040, 0.10],
			[0.152, 0.424, 0.078, 0.033, 0.26],
			[0.218, 0.394, 0.058, 0.025, 0.45]]
		for i in steps.size():
			var step: Array = steps[i]
			var part: MeshInstance4D = _box(prop, "Pick%s%d" % [tag, i],
				Vector4(side * float(step[0]), float(step[1]), 0.0, 0.0),
				Vector3(float(step[2]), float(step[3]), 0.030), head_iron)
			part.basis = Basis4D.from_xy(-side * float(step[4]))


## Paints the four leg blocks. The boots are left alone - they are already their own
## brown and a boot the colour of the trouser stops reading as a boot.
func _wear_trousers(figure: Node4D) -> void:
	# The waistband goes too. It is the top of the same garment, and left brown it reads
	# as a belt he is wearing over them rather than as the trousers themselves.
	var parts: Array[String] = ["Tunic/Belt"]
	for tag in ["L", "R"]:
		parts.append("Hip%s/Thigh%s" % [tag, tag])
		parts.append("Hip%s/Knee%s/Shin%s" % [tag, tag, tag])
	for path in parts:
		var limb: MeshInstance4D = figure.get_node_or_null(path) as MeshInstance4D
		if limb == null:
			push_warning("%s: no %s to put a trouser leg on." % [name, path])
			continue
		var material := TetraMaterial4D.new()
		material.albedo_color = trousers
		limb.material_override = material


func _box(parent: Node, part: String, at: Vector4, size: Vector3,
		colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	# A real extent through W, or he vanishes the moment the slice moves.
	mesh.size = Vector4(size.x, size.y, size.z, maxf(maxf(size.x, size.z), 0.42))
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
