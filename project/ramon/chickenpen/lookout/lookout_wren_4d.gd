@tool
extends Node4D

## Wren, who keeps the Lookout: a field vest of pockets, a wide-brimmed hat against the
## sun, binoculars on her chest and a camera strap across her - before she gives it away.
##
## THE SAME AVATAR AS EVERYBODY ELSE, dressed (the professor's rule, as the range master's
## header puts it: a new character is a few boxes on the shared body, not a new body).

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")

@export var vest: Color = Color(0.34, 0.38, 0.22):
	set(v):
		vest = v
		_set_colour(v)
@export var shirt: Color = Color(0.82, 0.76, 0.62):
	set(v):
		shirt = v
		_set_colour(v)
@export var skin: Color = Color(0.86, 0.66, 0.52):
	set(v):
		skin = v
		_set_colour(v)
@export var trousers: Color = Color(0.45, 0.38, 0.26):
	set(v):
		trousers = v
		_set_colour(v)
@export var hat: Color = Color(0.62, 0.50, 0.32):
	set(v):
		hat = v
		_set_colour(v)
@export var hair: Color = Color(0.48, 0.22, 0.10):
	set(v):
		hair = v
		_set_colour(v)
## Whether the camera still hangs off her (it goes to the player when you meet).
@export var has_camera: bool = true:
	set(v):
		has_camera = v
		_set_camera(v)


func _set_colour(_v: Color) -> void:
	if is_node_ready():
		rebuild()


func _set_camera(v: bool) -> void:
	var strap: Node = get_node_or_null("Figure/Tunic/Camera")
	if strap != null:
		(strap as Node4D).visible = v
	var band: Node = get_node_or_null("Figure/Tunic/Strap")
	if band != null:
		(band as Node4D).visible = v


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	var figure := Node4D.new()
	figure.name = "Figure"
	figure.set_script(AVATAR)
	figure.set("build", 2)
	figure.set("skin", shirt)
	figure.set("accent", skin)
	figure.set("hair", hair)
	figure.set("wear_cap", false)
	figure.set("eyes", true)
	figure.set("eye_colour", Color(0.20, 0.28, 0.18))
	figure.set("eye_spacing", 0.066)
	figure.set("eye_height", 0.024)
	add_child(figure)
	for tag in ["L", "R"]:
		_paint(figure, "Hip%s/Thigh%s" % [tag, tag], trousers)
		_paint(figure, "Hip%s/Knee%s/Shin%s" % [tag, tag, tag], trousers)
	_paint(figure, "Tunic/Belt", Color(0.25, 0.18, 0.12))
	var head: Node4D = figure.get_node_or_null("Tunic/Head") as Node4D
	if head != null:
		# A wide brim and a low crown: a field hat, not a cap.
		_box(head, "Brim", Vector4(0.0, 0.16, 0.0, 0.0), Vector3(0.52, 0.025, 0.50), hat)
		_box(head, "Crown", Vector4(0.0, 0.22, 0.0, 0.0), Vector3(0.32, 0.10, 0.30), hat)
		_box(head, "Band", Vector4(0.0, 0.185, 0.0, 0.0), Vector3(0.33, 0.025, 0.31), Color(0.30, 0.18, 0.10))
		# A plait down her back.
		_box(head, "Plait", Vector4(0.0, -0.12, -0.17, 0.0), Vector3(0.07, 0.24, 0.07), hair)
	var torso: Node4D = figure.get_node_or_null("Tunic") as Node4D
	if torso != null:
		_box(torso, "Vest", Vector4(0.0, 0.02, 0.0, 0.0), Vector3(0.36, 0.34, 0.27), vest)
		for side in [-1.0, 1.0]:
			_box(torso, "Pocket%d" % int(side), Vector4(side * 0.08, -0.06, 0.14, 0.0), Vector3(0.10, 0.08, 0.02), vest.darkened(0.25))
		# Binoculars on a short strap, at her chest.
		_box(torso, "Binoculars", Vector4(0.0, 0.08, 0.16, 0.0), Vector3(0.16, 0.07, 0.07), Color(0.12, 0.12, 0.12))
		# The camera, until she hands it over: on a strap across her, at her hip.
		_box(torso, "Strap", Vector4(0.0, 0.02, 0.14, 0.0), Vector3(0.04, 0.42, 0.02), Color(0.16, 0.10, 0.08)).basis = Basis4D.from_xy(0.6)
		_box(torso, "Camera", Vector4(0.15, -0.16, 0.12, 0.0), Vector3(0.14, 0.09, 0.08), Color(0.10, 0.10, 0.11))
	_set_camera(has_camera)


func _paint(figure: Node, path: String, colour: Color) -> void:
	var limb: MeshInstance4D = figure.get_node_or_null(path) as MeshInstance4D
	if limb == null:
		return
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	limb.material_override = material


func _box(parent: Node, part: String, at: Vector4, size: Vector3, colour: Color) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(size.x, size.y, size.z, maxf(maxf(size.x, size.z), 0.42))
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node
