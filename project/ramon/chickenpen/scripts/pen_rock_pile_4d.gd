@tool
extends Node4D

## A pile of rocks for the black cat to sit on, where its crate was (Ramon, 3 Oct: "instead of
## a box, make it a rock pile of some kind. midtone to dark grey").
##
## BOXES KNOCKED OUT OF TRUE, AND TURNED THROUGH W. Each stone starts as a BoxTetraMesh4D whose
## sixteen corners are each pushed a random way by up to [member rough] of its size (shared
## corners move together, so it stays closed), then flat-shaded: a lumpy block with no two faces
## parallel. Turned in two planes through W as well, the slice meets its faces at different
## slants. Squared-off boxes, only turned, still read as the crate stacked; this reads as split
## rock, in the pen's low-poly style. (A convex hull would be the real thing, but
## ConvexHullShape4D cannot make a mesh in this build.) The stones keep near w 0, so the pen's
## slice shows all of them.
##
## THE SEAT IS LEVEL. The flat stone on top is turned only through W and round the vertical, so
## its top stays flat, at [member top] above this node; this node stands on the ground. The
## cat's crate_top is that plus the few centimetres its feet stand off.
##
## Generated, so it shows in the editor; the stones are not saved into the scene.

@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild
## The top of the stone the cat sits on, above this node.
@export_range(0.2, 1.5, 0.01) var top: float = 0.6: set = _set_top
## How far the foot of the pile spreads from its middle.
@export_range(0.2, 1.5, 0.01) var spread: float = 0.42: set = _set_spread
@export var pile_seed: int = 7: set = _set_seed
## The stones' greys run between these two: mid grey to dark.
@export var light: Color = Color(0.43, 0.43, 0.42): set = _set_light
@export var dark: Color = Color(0.19, 0.19, 0.20): set = _set_dark
## How far each corner is knocked out of true, as a share of the stone's size.
@export_range(0.0, 0.35, 0.01) var rough: float = 0.2: set = _set_rough


func _set_top(v: float) -> void: top = v; _later()
func _set_spread(v: float) -> void: spread = v; _later()
func _set_seed(v: int) -> void: pile_seed = v; _later()
func _set_light(v: Color) -> void: light = v; _later()
func _set_dark(v: Color) -> void: dark = v; _later()
func _set_rough(v: float) -> void: rough = v; _later()


func _later() -> void:
	if is_node_ready():
		rebuild()


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = pile_seed
	# The foot: four stones round the middle, leaning in, a little sunk into the ground.
	for i in 4:
		var a: float = TAU * float(i) / 4.0 + rng.randf_range(-0.4, 0.4)
		var r: float = spread * rng.randf_range(0.8, 1.05)
		var size := Vector4(rng.randf_range(0.42, 0.58), rng.randf_range(0.28, 0.4), rng.randf_range(0.38, 0.52), 0.55)
		var at := Vector4(cos(a) * r, size.y * 0.5 - 0.04, sin(a) * r, rng.randf_range(-0.05, 0.05))
		_stone("Foot%d" % i, at, size, rng, -a, true)
	# Two between them and the seat, so the seat is held up by something.
	for i in 2:
		var a: float = PI * float(i) + rng.randf_range(-0.6, 0.6)
		var size := Vector4(rng.randf_range(0.4, 0.5), rng.randf_range(0.26, 0.32), rng.randf_range(0.36, 0.46), 0.5)
		var at := Vector4(cos(a) * spread * 0.35, top - 0.2 - size.y * 0.5 + 0.03, sin(a) * spread * 0.35, rng.randf_range(-0.04, 0.04))
		_stone("Middle%d" % i, at, size, rng, rng.randf_range(0.0, TAU), true)
	# The seat: wide and flat, its top level at `top`.
	var seat := Vector4(0.58, 0.2, 0.5, 0.55)
	_stone("Seat", Vector4(0.0, top - seat.y * 0.5, 0.0, 0.0), seat, rng, rng.randf_range(0.0, TAU), false)


## One stone: a box, turned round the vertical by [param yaw], through W in two planes, and,
## if [param tip], tipped a little off level. Its own grey between dark and light.
func _stone(part: String, at: Vector4, size: Vector4, rng: RandomNumberGenerator, yaw: float, tip: bool) -> void:
	var node := MeshInstance4D.new()
	node.name = part
	var box := BoxTetraMesh4D.new()
	box.size = size
	var mesh: ArrayTetraMesh4D = box.to_array_tetra_mesh()
	var corners: PackedVector4Array = mesh.get_vertex_positions()
	# The same push for the same corner, wherever it is listed.
	var pushed: Dictionary = {}
	for i in corners.size():
		var c: Vector4 = corners[i]
		var key := Vector4i(roundi(c.x * 1000.0), roundi(c.y * 1000.0), roundi(c.z * 1000.0), roundi(c.w * 1000.0))
		if not pushed.has(key):
			var push := Vector4(rng.randf_range(-1.0, 1.0) * size.x, rng.randf_range(-1.0, 1.0) * size.y,
				rng.randf_range(-1.0, 1.0) * size.z, rng.randf_range(-1.0, 1.0) * size.w) * rough * 0.5
			# The seat's top stays level, where the cat sits.
			if not tip and c.y > 0.0:
				push.y = 0.0
			pushed[key] = push
		corners[i] = c + pushed[key]
	mesh.set_vertex_positions(corners)
	mesh.calculate_boundary_normals(false)
	mesh.set_flat_shading_normals(true)
	node.mesh = mesh
	var material := TetraMaterial4D.new()
	var grey: Color = dark.lerp(light, rng.randf())
	# A touch warmer or cooler, as stones are.
	var warm: float = rng.randf_range(-0.012, 0.012)
	material.albedo_color = Color(grey.r + warm, grey.g, grey.b - warm)
	node.material_override = material
	var turn: Projection = Basis4D.from_zx(yaw) * Basis4D.from_zw(rng.randf_range(0.35, 0.6)) * Basis4D.from_xw(rng.randf_range(0.3, 0.55))
	if tip:
		turn = Basis4D.from_xy(rng.randf_range(-0.22, 0.22)) * Basis4D.from_yz(rng.randf_range(-0.22, 0.22)) * turn
	add_child(node)
	node.position = at
	node.basis = turn
