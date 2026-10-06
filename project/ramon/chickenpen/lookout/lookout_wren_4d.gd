@tool
extends Node4D

## Wren, who keeps the Watchstone (6 Oct 2026, PenLayout/PLAN_WATCHSTONE.md step 8; Ramon: "no
## longer a forest ranger but a guy already looking through goggles. dark brown cloth and beard").
## A watcher in the medieval, ritual-tech look: a long coat of dark brown cloth over a darker shirt,
## a hood folded on his back, a satchel, a full beard, and brass goggles over his eyes, his right
## hand raised to them as he looks out. The camera hangs at his hip on its strap until he hands it
## over. (Until 6 Oct a forest ranger in dark green with a pack and binoculars; that build is in
## chickenpen/.backup/2026-10-06_before_watchstone/lookout/.)
##
## THE SAME AVATAR AS EVERYBODY ELSE, dressed (the professor's rule, as the range master's
## header puts it: a new character is a few boxes on the shared body, not a new body).

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")

@export var vest: Color = Color(0.27, 0.18, 0.11):
	set(v):
		vest = v
		_set_colour(v)
@export var shirt: Color = Color(0.19, 0.13, 0.08):
	set(v):
		shirt = v
		_set_colour(v)
@export var skin: Color = Color(0.86, 0.66, 0.52):
	set(v):
		skin = v
		_set_colour(v)
@export var trousers: Color = Color(0.16, 0.11, 0.07):
	set(v):
		trousers = v
		_set_colour(v)
## The goggles' brass.
@export var hat: Color = Color(0.70, 0.55, 0.26):
	set(v):
		hat = v
		_set_colour(v)
@export var hair: Color = Color(0.22, 0.14, 0.08):
	set(v):
		hair = v
		_set_colour(v)
## Whether the camera still hangs off him (it goes to the player when you meet).
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
	var leather := Color(0.20, 0.14, 0.09)
	for tag in ["L", "R"]:
		_paint(figure, "Hip%s/Thigh%s" % [tag, tag], trousers)
		_paint(figure, "Hip%s/Knee%s/Shin%s" % [tag, tag, tag], trousers)
		_paint(figure, "Hip%s/Knee%s/Ankle%s/Boot%s" % [tag, tag, tag, tag], Color(0.16, 0.11, 0.08))
	_paint(figure, "Tunic/Belt", leather)
	# Long sleeves: a ranger's shirt, not short ones with bare forearms (pale blocks at a distance).
	for tag in ["L", "R"]:
		_paint(figure, "Shoulder%s/Elbow%s/Forearm%s" % [tag, tag, tag], vest)
	var head: Node4D = figure.get_node_or_null("Tunic/Head") as Node4D
	var beard := hair.lightened(0.06)
	if head != null:
		# A little smaller than the cast's: less of a big-headed figure, more of a grown-up.
		head.basis = Basis4D.from_scale(Vector4(0.9, 0.9, 0.9, 1.0))
		# The beard: full, from the cheeks to below the chin, and a moustache over it.
		_box(head, "Beard", Vector4(0.0, -0.085, 0.135, 0.0), Vector3(0.25, 0.13, 0.05), beard)
		_box(head, "Chin", Vector4(0.0, -0.15, 0.11, 0.0), Vector3(0.2, 0.08, 0.1), beard)
		_box(head, "Moustache", Vector4(0.0, -0.035, 0.157, 0.0), Vector3(0.13, 0.03, 0.02), beard.darkened(0.15))
		# The goggles over his eyes: a brass rim round each lens, the lens dark and a little teal,
		# and a leather strap round the head.
		for side in [-1.0, 1.0]:
			_box(head, "Rim%d" % int(side), Vector4(side * 0.066, 0.026, 0.165, 0.0), Vector3(0.09, 0.09, 0.07), hat)
			_box(head, "Lens%d" % int(side), Vector4(side * 0.066, 0.026, 0.202, 0.0), Vector3(0.065, 0.065, 0.012), Color(0.10, 0.20, 0.22))
		_box(head, "Bridge", Vector4(0.0, 0.03, 0.17, 0.0), Vector3(0.05, 0.025, 0.03), hat.darkened(0.2))
		_box(head, "GoggleStrap", Vector4(0.0, 0.026, 0.0, 0.0), Vector3(0.31, 0.035, 0.3), Color(0.14, 0.09, 0.06))
	var torso: Node4D = figure.get_node_or_null("Tunic") as Node4D
	if torso != null:
		# The coat over the shirt, its skirt to the knee, a hood folded on the back.
		_box(torso, "Vest", Vector4(0.0, 0.02, 0.0, 0.0), Vector3(0.36, 0.34, 0.27), vest)
		_box(torso, "Skirt", Vector4(0.0, -0.27, 0.0, 0.0), Vector3(0.38, 0.24, 0.29), vest.darkened(0.08))
		_box(torso, "Hood", Vector4(0.0, 0.17, -0.155, 0.0), Vector3(0.28, 0.1, 0.09), vest.darkened(0.2))
		_box(torso, "Collar", Vector4(0.0, 0.17, 0.05, 0.0), Vector3(0.3, 0.05, 0.22), vest.darkened(0.15))
		_box(torso, "Buckle", Vector4(0.0, -0.17, 0.135, 0.0), Vector3(0.05, 0.04, 0.012), hat)
		# The satchel at his left hip on a strap over the right shoulder.
		_box(torso, "Satchel", Vector4(0.2, -0.2, 0.02, 0.0), Vector3(0.08, 0.16, 0.2), leather)
		_box(torso, "SatchelStrap", Vector4(0.03, 0.03, 0.14, 0.0), Vector3(0.035, 0.44, 0.012), leather).basis = Basis4D.from_xy(-0.6)
		# The camera, until it is handed over: on a strap across, at the hip.
		_box(torso, "Strap", Vector4(0.0, 0.02, 0.14, 0.0), Vector3(0.04, 0.42, 0.02), Color(0.16, 0.10, 0.08)).basis = Basis4D.from_xy(0.6)
		_box(torso, "Camera", Vector4(0.15, -0.16, 0.12, 0.0), Vector3(0.14, 0.09, 0.08), Color(0.10, 0.10, 0.11))
	# His right hand raised to the goggles, as if to steady them while he looks.
	var shoulder: Node4D = figure.get_node_or_null("ShoulderR") as Node4D
	var elbow: Node4D = figure.get_node_or_null("ShoulderR/ElbowR") as Node4D
	if shoulder != null and elbow != null:
		shoulder.basis = Basis4D.from_xy(0.35) * Basis4D.from_yz(-2.25)
		elbow.basis = Basis4D.from_yz(-1.75)
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
