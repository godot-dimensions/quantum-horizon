@tool
extends Node4D

## The gauntlet: a wrist unit with a screen, built from boxes.
##
## TWO BUILDS OF ONE OBJECT. `DETAILED` is for the moment it is handed over, turning above
## the player's head at several times life size, where it is the only thing on screen and
## can afford a bezel, a dial, a gauge, a button row and vents. `BLOCK` is what it is for
## the rest of the game - strapped to a forearm 0.2 units long, seen from behind, over the
## shoulder of a character who is usually running. At that size every one of those details
## is under a pixel, so they are not drawn: it is the cuff and the screen and nothing else.
##
## The alternative - one model at one detail level - loses either way round. Built for the
## arm it is a grey lump in the reveal; built for the reveal it spends a few hundred
## tetrahedra a frame on a smear of green.
##
## GREEN BECAUSE THE SCREEN IS GREEN. The casing is nearly black with a green cast and the
## only bright thing on it is the display, which is what makes a phosphor screen read as
## lit rather than as painted.

enum Build { DETAILED, BLOCK }

@export var build: Build = Build.DETAILED: set = _set_build
## Overall size. The wearable is about 0.22 across; the one that turns overhead is scaled
## up by whoever is showing it rather than rebuilt larger.
@export_range(0.05, 2.0, 0.01) var width: float = 0.22: set = _set_width
## How far it reaches through W. Generous on the showcase copy so it survives a player
## fiddling with their slice while it turns.
@export_range(0.05, 4.0, 0.05) var w_depth: float = 0.55: set = _set_w

@export var casing: Color = Color(0.11, 0.15, 0.12): set = _set_casing
@export var screen: Color = Color(0.36, 0.98, 0.46): set = _set_screen
@export var trim: Color = Color(0.20, 0.26, 0.21): set = _set_trim


func _set_build(v: Build) -> void: build = v; _later()
func _set_width(v: float) -> void: width = v; _later()
func _set_w(v: float) -> void: w_depth = v; _later()
func _set_casing(v: Color) -> void: casing = v; _later()
func _set_screen(v: Color) -> void: screen = v; _later()
func _set_trim(v: Color) -> void: trim = v; _later()


func _ready() -> void:
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	var case_mat := TetraMaterial4D.new()
	case_mat.albedo_color = casing
	var screen_mat := TetraMaterial4D.new()
	screen_mat.albedo_color = screen
	var trim_mat := TetraMaterial4D.new()
	trim_mat.albedo_color = trim

	# Everything is expressed as a fraction of `width`, so one number resizes the whole
	# unit and the proportions cannot drift apart.
	var u: float = width

	# The cuff, and the screen sitting proud of it. Both builds have these two - they are
	# what makes it a gauntlet rather than a brick.
	_box("Cuff", Vector4(0.0, 0.0, 0.0, 0.0), Vector3(u, u * 1.15, u * 0.88), case_mat)
	_box("Bezel", Vector4(0.0, u * 0.06, u * 0.50, 0.0), Vector3(u * 0.92, u * 0.78, u * 0.22), trim_mat)
	_box("Screen", Vector4(0.0, u * 0.06, u * 0.60, 0.0), Vector3(u * 0.74, u * 0.60, u * 0.08), screen_mat)

	if build == Build.BLOCK:
		return

	# Straps above and below, which is what reads as "worn" rather than "held".
	for side in [1.0, -1.0]:
		_box("Strap%s" % ("T" if side > 0.0 else "B"),
			Vector4(0.0, side * u * 0.62, 0.0, 0.0),
			Vector3(u * 1.08, u * 0.16, u * 0.96), trim_mat)

	# The dial housing and its knob, on the inboard side.
	_box("DialHouse", Vector4(-u * 0.56, -u * 0.10, u * 0.16, 0.0),
		Vector3(u * 0.22, u * 0.52, u * 0.50), case_mat)
	_box("Knob", Vector4(-u * 0.66, -u * 0.10, u * 0.34, 0.0),
		Vector3(u * 0.10, u * 0.26, u * 0.26), trim_mat)
	# A small round-ish gauge above it, the one detail that is not a rectangle in spirit.
	_box("Gauge", Vector4(-u * 0.46, u * 0.42, u * 0.42, 0.0),
		Vector3(u * 0.20, u * 0.20, u * 0.14), screen_mat)

	# Three buttons under the screen. Lit, because on the real thing they are.
	for i in 3:
		_box("Button%d" % i,
			Vector4((float(i) - 1.0) * u * 0.20, -u * 0.46, u * 0.52, 0.0),
			Vector3(u * 0.11, u * 0.11, u * 0.10), screen_mat)

	# Cooling ribs down the outboard edge.
	for i in 3:
		_box("Rib%d" % i,
			Vector4(u * 0.54, (float(i) - 1.0) * u * 0.22, u * 0.10, 0.0),
			Vector3(u * 0.14, u * 0.12, u * 0.62), trim_mat)


func _box(part: String, at: Vector4, size: Vector3, material: TetraMaterial4D) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(size.x, size.y, size.z, w_depth)
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	node.position = at
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
	return node
