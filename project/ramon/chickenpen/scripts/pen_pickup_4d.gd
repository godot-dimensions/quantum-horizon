@tool
extends Node4D

## Something to find: an ADA coin, or a golden egg.
##
## THE LOGO IS GEOMETRY, NOT A TEXTURE. A coin would normally be a cylinder with the mark
## painted on it, and that is the wrong tool twice over here. TetraMaterial4D takes a
## Texture3D rather than a flat image, so a 2D logo would have to be lifted into a volume
## before it could be applied at all; and every other object in this scene is untextured
## flat colour, so a texture-mapped coin would be the one thing in the world that did not
## match. Built as dots it belongs, and it stays sharp at any distance.
##
## AND THE COIN IS A ROSETTE, NOT A CYLINDER. The module has boxes and orthoplexes and no
## round primitive, so the disc is six rectangles turned thirty degrees apart - a rough
## twelve-sided plate. At the size a coin is actually seen, that reads as round, and it
## costs six meshes rather than a lathe.
##
## FOUND, NOT GIVEN. These sit off the starting slice on purpose. The gauntlet is handed
## over in conversation; these are what the gauntlet is FOR, so they are only reachable by
## doing the thing it teaches.

enum Kind { ADA_COIN, GOLDEN_EGG }

@export var kind: Kind = Kind.ADA_COIN: set = _set_kind
@export_range(0.05, 2.0, 0.01) var size: float = 0.34: set = _set_size
@export_range(0.05, 3.0, 0.05) var w_depth: float = 0.5: set = _set_w
## Turns on the spot, because a collectible that is not moving reads as scenery.
@export_range(0.0, 6.0, 0.1) var spin_speed: float = 1.3
@export_range(0.0, 0.5, 0.01) var bob_height: float = 0.08

@export_group("Colours")
@export var coin_face: Color = Color(0.04, 0.20, 0.70): set = _set_a
@export var coin_mark: Color = Color(0.97, 0.98, 1.0): set = _set_b
@export var egg_shell: Color = Color(0.98, 0.80, 0.24): set = _set_c
@export var egg_shine: Color = Color(1.0, 0.94, 0.62): set = _set_d

var _rest_y: float = 0.0
var _clock: float = 0.0


func _set_kind(v: Kind) -> void: kind = v; _later()
func _set_size(v: float) -> void: size = v; _later()
func _set_w(v: float) -> void: w_depth = v; _later()
func _set_a(v: Color) -> void: coin_face = v; _later()
func _set_b(v: Color) -> void: coin_mark = v; _later()
func _set_c(v: Color) -> void: egg_shell = v; _later()
func _set_d(v: Color) -> void: egg_shine = v; _later()


func _ready() -> void:
	_rest_y = position.y
	rebuild()


func _later() -> void:
	if is_node_ready():
		rebuild()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_clock += delta
	basis = Basis4D.from_zx(_clock * spin_speed)
	position.y = _rest_y + sin(_clock * 2.0) * bob_height


func rebuild() -> void:
	for child in get_children():
		child.free()
	if kind == Kind.ADA_COIN:
		_build_coin()
	else:
		_build_egg()


## A disc standing on edge, with the mark on both faces so it reads while it turns.
func _build_coin() -> void:
	var face := TetraMaterial4D.new()
	face.albedo_color = coin_face
	var mark := TetraMaterial4D.new()
	mark.albedo_color = coin_mark

	var thickness: float = size * 0.16
	# Six plates, thirty degrees apart. Each is as wide as the coin and narrow enough that
	# six of them tile the circle rather than stacking into a square.
	for i in 6:
		var plate := _box("Plate%d" % i, Vector4.ZERO,
			Vector3(size * 2.0, size * 0.54, thickness), face)
		plate.basis = Basis4D.from_xy(PI * float(i) / 6.0)

	# The Cardano mark: rings of dots, thinning outward. Not the logo to the millimetre -
	# the number of dots per ring and how fast they shrink is what makes it recognisable.
	# Bolder than the first pass, which read as a fine speckle rather than a mark. The
	# gradation matters more than the count: dots that shrink noticeably outward are what
	# makes it look designed instead of scattered.
	var rings := [
		[6, 0.28, 0.21], [6, 0.50, 0.16], [12, 0.70, 0.115], [12, 0.88, 0.075],
	]
	for r in rings.size():
		var ring: Array = rings[r]
		var count: int = int(ring[0])
		var radius: float = size * float(ring[1])
		var dot: float = size * float(ring[2])
		# Alternate rings are offset half a step, which is what stops the dots forming
		# spokes instead of a field.
		var twist: float = (PI / float(count)) if r % 2 == 1 else 0.0
		for i in count:
			var angle: float = TAU * float(i) / float(count) + twist
			for side in [1.0, -1.0]:
				_box("Dot%d_%d_%s" % [r, i, "F" if side > 0.0 else "B"],
					Vector4(cos(angle) * radius, sin(angle) * radius,
						side * thickness * 0.56, 0.0),
					Vector3(dot, dot, thickness * 0.3), mark)


## A blocky egg: stacked slabs, widest below the middle, the way an egg actually is.
func _build_egg() -> void:
	var shell := TetraMaterial4D.new()
	shell.albedo_color = egg_shell
	var shine := TetraMaterial4D.new()
	shine.albedo_color = egg_shine

	# height fraction, half-width fraction. Fatter low down and tapering to a narrower
	# top - an egg is not a symmetric ellipse, and the asymmetry is most of what says egg.
	# Taller than it is wide, which is most of the difference between an egg and a pebble:
	# the widths peak at 0.66 of the half-height, not 0.82.
	var slabs := [
		[-1.00, 0.26], [-0.74, 0.46], [-0.44, 0.60], [-0.08, 0.66],
		[0.28, 0.60], [0.58, 0.46], [0.82, 0.28], [1.00, 0.12],
	]
	for i in slabs.size() - 1:
		var low: Array = slabs[i]
		var high: Array = slabs[i + 1]
		var mid: float = (float(low[0]) + float(high[0])) * 0.5
		var span: float = (float(high[0]) - float(low[0])) * size
		var half: float = maxf(float(low[1]), float(high[1])) * size
		_box("Slab%d" % i, Vector4(0.0, mid * size, 0.0, 0.0),
			Vector3(half * 2.0, span, half * 2.0), shell)

	# One lighter band, so a turning egg has something to catch the eye rather than reading
	# as a single flat colour whatever angle it is at.
	_box("Shine", Vector4(0.0, -size * 0.10, size * 0.72, 0.0),
		Vector3(size * 0.5, size * 0.44, size * 0.18), shine)


func _box(part: String, at: Vector4, box: Vector3, material: TetraMaterial4D) -> MeshInstance4D:
	var node := MeshInstance4D.new()
	node.name = part
	var mesh := BoxTetraMesh4D.new()
	mesh.size = Vector4(box.x, box.y, box.z, w_depth)
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	node.position = at
	if Engine.is_editor_hint() and get_tree() != null and get_tree().edited_scene_root != null:
		node.owner = get_tree().edited_scene_root
	return node
