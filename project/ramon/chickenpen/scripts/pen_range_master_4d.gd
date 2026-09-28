@tool
extends Node4D

## The range master: a figure in a dark field jacket with ear defenders round his neck -
## pushed down, because nothing is firing here - who has somewhere better to send you.
##
## THE SAME AVATAR AS EVERYBODY ELSE, dressed. The professor's rule: a new character is a
## few boxes on the shared body, not a new body.

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")

@export var jacket: Color = Color(0.20, 0.24, 0.17): set = _set_colour
@export var skin: Color = Color(0.78, 0.60, 0.46): set = _set_colour
@export var cap: Color = Color(0.13, 0.12, 0.11): set = _set_colour
@export var trousers: Color = Color(0.17, 0.16, 0.15): set = _set_colour
@export var defenders: Color = Color(0.85, 0.52, 0.10): set = _set_colour


func _set_colour(_v: Color) -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	var figure := Node4D.new()
	figure.name = "Figure"
	figure.set_script(AVATAR)
	figure.set("build", 2)
	figure.set("skin", jacket)
	figure.set("accent", skin)
	figure.set("hair", Color(0.25, 0.20, 0.16))
	figure.set("wear_cap", false)
	figure.set("eyes", true)
	figure.set("eye_colour", Color(0.12, 0.11, 0.10))
	figure.set("eye_spacing", 0.068)
	figure.set("eye_height", 0.02)
	add_child(figure)
	for tag in ["L", "R"]:
		_paint(figure, "Hip%s/Thigh%s" % [tag, tag], trousers)
		_paint(figure, "Hip%s/Knee%s/Shin%s" % [tag, tag, tag], trousers)
	_paint(figure, "Tunic/Belt", trousers)
	var head: Node4D = figure.get_node_or_null("Tunic/Head") as Node4D
	if head != null:
		_box(head, "Cap", Vector4(0.0, 0.19, 0.0, 0.0), Vector3(0.33, 0.10, 0.31), cap)
		_box(head, "Peak", Vector4(0.0, 0.15, 0.19, 0.0), Vector3(0.30, 0.03, 0.12), cap)
		# Round the neck, cups either side.
		_box(head, "Band", Vector4(0.0, -0.20, -0.03, 0.0), Vector3(0.36, 0.04, 0.05), Color(0.12, 0.12, 0.12))
		for side in [-1.0, 1.0]:
			_box(head, "Cup%d" % int(side), Vector4(side * 0.18, -0.20, 0.02, 0.0), Vector3(0.08, 0.12, 0.12), defenders)
	var torso: Node4D = figure.get_node_or_null("Tunic") as Node4D
	if torso != null:
		# A vest of pockets, the one thing that says "range" before he speaks.
		_box(torso, "Vest", Vector4(0.0, 0.02, 0.125, 0.0), Vector3(0.30, 0.30, 0.03), Color(0.30, 0.26, 0.16))


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
