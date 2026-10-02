@tool
extends Node4D

## Wren, who keeps the Lookout: a forest ranger in dark green (Ramon, 2 Oct: "a little less
## bubbly ... a dark green forest ranger suit, and backpack, and goggles in his hand") - a
## field jacket of pockets over a green shirt, a badge, a flat-brimmed ranger's hat, a pack on
## the back, binoculars in the right hand, and a camera strap across - until it is given away.
##
## THE SAME AVATAR AS EVERYBODY ELSE, dressed (the professor's rule, as the range master's
## header puts it: a new character is a few boxes on the shared body, not a new body).

const AVATAR := preload("res://ramon/chickenpen/scripts/block_avatar_4d.gd")

@export var vest: Color = Color(0.12, 0.18, 0.11):
	set(v):
		vest = v
		_set_colour(v)
@export var shirt: Color = Color(0.17, 0.25, 0.16):
	set(v):
		shirt = v
		_set_colour(v)
@export var skin: Color = Color(0.86, 0.66, 0.52):
	set(v):
		skin = v
		_set_colour(v)
@export var trousers: Color = Color(0.14, 0.17, 0.12):
	set(v):
		trousers = v
		_set_colour(v)
@export var hat: Color = Color(0.30, 0.29, 0.20):
	set(v):
		hat = v
		_set_colour(v)
@export var hair: Color = Color(0.24, 0.16, 0.10):
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
	if head != null:
		# A little smaller than the cast's: less of a big-headed figure, more of a grown-up.
		head.basis = Basis4D.from_scale(Vector4(0.9, 0.9, 0.9, 1.0))
		# A ranger's hat: a flat, stiff brim and a tall crown pinched at the top.
		_box(head, "Brim", Vector4(0.0, 0.16, 0.0, 0.0), Vector3(0.50, 0.02, 0.48), hat)
		_box(head, "Crown", Vector4(0.0, 0.24, 0.0, 0.0), Vector3(0.28, 0.14, 0.27), hat)
		_box(head, "Pinch", Vector4(0.0, 0.33, 0.0, 0.0), Vector3(0.20, 0.05, 0.19), hat.darkened(0.08))
		_box(head, "Band", Vector4(0.0, 0.18, 0.0, 0.0), Vector3(0.29, 0.03, 0.28), Color(0.10, 0.09, 0.07))
	var torso: Node4D = figure.get_node_or_null("Tunic") as Node4D
	if torso != null:
		# The field jacket over the shirt, with its pockets, a badge and a shoulder patch.
		_box(torso, "Vest", Vector4(0.0, 0.02, 0.0, 0.0), Vector3(0.36, 0.34, 0.27), vest)
		for side in [-1.0, 1.0]:
			_box(torso, "Pocket%d" % int(side), Vector4(side * 0.08, -0.06, 0.14, 0.0), Vector3(0.10, 0.08, 0.02), vest.darkened(0.3))
			_box(torso, "Flap%d" % int(side), Vector4(side * 0.08, 0.1, 0.14, 0.0), Vector3(0.10, 0.03, 0.02), vest.darkened(0.3))
		_box(torso, "Badge", Vector4(-0.085, 0.13, 0.145, 0.0), Vector3(0.05, 0.06, 0.012), Color(0.78, 0.62, 0.26))
		_box(torso, "Buckle", Vector4(0.0, -0.17, 0.135, 0.0), Vector3(0.05, 0.04, 0.012), Color(0.62, 0.52, 0.30))
		# The pack: a body, a flap over its top, a rolled mat under it, straps over the shoulders.
		_box(torso, "Pack", Vector4(0.0, 0.03, -0.21, 0.0), Vector3(0.30, 0.34, 0.15), Color(0.22, 0.24, 0.15))
		_box(torso, "PackFlap", Vector4(0.0, 0.17, -0.205, 0.0), Vector3(0.31, 0.08, 0.16), Color(0.18, 0.20, 0.12))
		_box(torso, "PackPocket", Vector4(0.0, -0.04, -0.295, 0.0), Vector3(0.18, 0.14, 0.04), Color(0.18, 0.20, 0.12))
		_box(torso, "Bedroll", Vector4(0.0, -0.17, -0.21, 0.0), Vector3(0.36, 0.08, 0.09), Color(0.30, 0.22, 0.14))
		for side in [-1.0, 1.0]:
			_box(torso, "PackStrap%d" % int(side), Vector4(side * 0.1, 0.12, 0.138, 0.0), Vector3(0.035, 0.2, 0.012), leather)
		# The camera, until it is handed over: on a strap across, at the hip.
		_box(torso, "Strap", Vector4(0.0, 0.02, 0.14, 0.0), Vector3(0.04, 0.42, 0.02), Color(0.16, 0.10, 0.08)).basis = Basis4D.from_xy(0.6)
		_box(torso, "Camera", Vector4(0.15, -0.16, 0.12, 0.0), Vector3(0.14, 0.09, 0.08), Color(0.10, 0.10, 0.11))
	# Binoculars in the right hand, the forearm brought up to hold them in front.
	var elbow: Node4D = figure.get_node_or_null("ShoulderR/ElbowR") as Node4D
	var hand: Node4D = figure.get_node_or_null("ShoulderR/ElbowR/HandR") as Node4D
	if elbow != null and hand != null:
		elbow.basis = Basis4D.from_yz(-1.25)
		for side in [-1.0, 1.0]:
			_box(hand, "Barrel%d" % int(side), Vector4(side * 0.03, -0.02, 0.04, 0.0), Vector3(0.05, 0.05, 0.12), Color(0.10, 0.10, 0.10))
		_box(hand, "Bridge", Vector4(0.0, -0.02, 0.03, 0.0), Vector3(0.04, 0.025, 0.04), Color(0.16, 0.16, 0.15))
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
