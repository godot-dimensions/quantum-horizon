@tool
extends Node4D

## The camp's guide: one of the researchers from the camp, standing on the farm's slice where the camp's path
## gives out, just short of the camp (Ramon, 7 Oct: "can you make an npc explain this at the markerball, right
## before the campsite. keep his dialogue short and make him stand next to the marker ball. he must tell you to
## stare ahead aligned with the path and rotate the slice"). The camp is 2.5 m kata, so here you see nothing of it;
## he tells you how to bring it in (camp_guide_script.gd).
##
## THE SAME AVATAR AS EVERYBODY ELSE, dressed as the camp is: a canvas field jacket with the tents' maroon at the
## collar, a satchel on a strap, a flat cap. Every box hangs on the avatar's own parts, so the dev look leaves him
## as he is (block_avatar is a character to it).

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")

@export var jacket: Color = Color(0.62, 0.50, 0.36):
	set(v):
		jacket = v
		_changed()
@export var trim: Color = Color(0.45, 0.14, 0.13):
	set(v):
		trim = v
		_changed()
@export var skin: Color = Color(0.80, 0.62, 0.48):
	set(v):
		skin = v
		_changed()
@export var trousers: Color = Color(0.30, 0.24, 0.17):
	set(v):
		trousers = v
		_changed()
@export var leather: Color = Color(0.36, 0.23, 0.13):
	set(v):
		leather = v
		_changed()


func _changed() -> void:
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
	figure.set("hair", Color(0.30, 0.22, 0.15))
	figure.set("wear_cap", false)
	figure.set("eyes", true)
	figure.set("eye_colour", Color(0.12, 0.11, 0.10))
	figure.set("eye_spacing", 0.066)
	figure.set("eye_height", 0.022)
	add_child(figure)
	for tag in ["L", "R"]:
		_paint(figure, "Hip%s/Thigh%s" % [tag, tag], trousers)
		_paint(figure, "Hip%s/Knee%s/Shin%s" % [tag, tag, tag], trousers)
	_paint(figure, "Tunic/Belt", leather)
	var head: Node4D = figure.get_node_or_null("Tunic/Head") as Node4D
	if head != null:
		# A flat cap, its peak forward. Through W as the head is (0.285 to 0.30 across), the peak
		# across the whole of the cap's front, which is a face in x and W.
		_box(head, "Cap", Vector4(0.0, 0.185, -0.01, 0.0), Vector3(0.34, 0.08, 0.32), trousers, 0.32)
		_box(head, "Peak", Vector4(0.0, 0.15, 0.18, 0.0), Vector3(0.30, 0.03, 0.10), trousers, 0.28)
	var torso: Node4D = figure.get_node_or_null("Tunic") as Node4D
	if torso != null:
		# The tents' maroon at the collar, a satchel at his hip on a strap across him. Through W in
		# the tunic's proportion (0.35 to 0.38 across); the strap a band the whole of the tunic's W,
		# as a strap over a shoulder is in 4D; the satchel as thick through W as it is deep.
		_box(torso, "Collar", Vector4(0.0, 0.20, 0.0, 0.0), Vector3(0.40, 0.06, 0.26), trim, 0.37)
		var strap: MeshInstance4D = _box(torso, "Strap", Vector4(0.0, 0.0, 0.126, 0.0), Vector3(0.05, 0.50, 0.012), leather, 0.1)
		strap.basis = Basis4D.from_xy(-0.62)
		_box(torso, "Satchel", Vector4(-0.21, -0.18, 0.04, 0.0), Vector3(0.08, 0.16, 0.20), leather, 0.19)


func _paint(figure: Node, path: String, colour: Color) -> void:
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
	mesh.size = Vector4(size.x, size.y, size.z, w if w > 0.0 else maxf(maxf(size.x, size.z), 0.42))
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = colour
	node.material_override = material
	parent.add_child(node)
	node.position = at
	return node
