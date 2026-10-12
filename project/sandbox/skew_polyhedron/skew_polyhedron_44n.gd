extends MeshInstance4D
## Procedural {4,4|n} regular skew polyhedron - a discretized Clifford torus:
## the product of two circles living in ORTHOGONAL 2-planes (x/y and z/w),
## each of radius 1/sqrt(2), so every vertex lands exactly on the unit
## hypersphere by construction (x^2+y^2=0.5, z^2+w^2=0.5, sum=1) - finiteness
## for free, no separate bounding step needed.
##
## Built via ArrayWireMesh4D directly (append_vertex/append_edge_indices),
## NOT the ArrayTetraMesh4D-then-to_wire_mesh() route the 600-cell gun
## ornament uses - that route is for genuine 4D SOLIDS with real tetrahedral
## cells (a real volume); this object has no such cells, it's a 2D grid
## (surface) embedded in 4D, so specifying its edges directly is the
## correct tool for this shape, not a workaround for it.
##
## Each unit grid cell (i,j),(i+1,j),(i+1,j+1),(i,j+1) is a genuine planar
## RECTANGLE, not just a planar quad - confirmed by hand, not just assumed:
## the i-step edge vector always lives purely in the x/y pair (a function
## of i alone) and the j-step edge vector always lives purely in the z/w
## pair (a function of j alone), so the two are orthogonal for every i, j,
## n, and the opposite corner is exactly base+edge_i+edge_j (the
## parallelogram identity) - both properties hold structurally for the
## whole family, not just for one sampled face.
##
## n is live-adjustable: number keys 1-9 jump directly to that value; [ and
## ] step by 1 beyond that range, up to MAX_N (chosen so a full rebuild -
## O(n^2) vertices and edges - stays instant on every keypress).
##
## Topologically a genuine torus threading through 4D: i controls x/y, j
## controls z/w, so for any FIXED j (one "ring" of the torus) every i sits
## at the SAME (z,w) point - meaning only whichever j-rings currently have
## a w-coordinate near the player's own current slice are visible at all.
## As the player slice-rotates, different rings phase in and out - a
## direct, hands-on demonstration of why the bearing/minimap tooling
## exists, not a shape that just sits statically within one slice.

const MIN_N := 3
const MAX_N := 24
const DEFAULT_N := 6
const RADIUS := 6.0 # World-space size after normalization - comfortably walk-through-able (player capsule radius 0.25, height 1.75).
const LINE_THICKNESS := 2.0
const WIRE_COLOR := Color(0.3, 0.9, 0.85, 1.0)

var n: int = DEFAULT_N

@onready var label: Label = $"../../PolyhedronLabel"


func _ready() -> void:
	var material := WireMaterial4D.new()
	material.line_thickness = LINE_THICKNESS
	material.albedo_color = WIRE_COLOR
	material_override = material
	_rebuild()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key_event: InputEventKey = event
	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		_set_n(key_event.keycode - KEY_1 + 1)
	elif key_event.keycode == KEY_BRACKETRIGHT:
		_set_n(n + 1)
	elif key_event.keycode == KEY_BRACKETLEFT:
		_set_n(n - 1)


func _set_n(new_n: int) -> void:
	new_n = clampi(new_n, MIN_N, MAX_N)
	if new_n == n:
		return
	n = new_n
	_rebuild()


## Exposed (not just called from _ready/_input) so a test can rebuild at a
## specific n directly without going through simulated key presses.
func rebuild_with_n(new_n: int) -> void:
	n = clampi(new_n, MIN_N, MAX_N)
	_rebuild()


func _rebuild() -> void:
	var wire_mesh := ArrayWireMesh4D.new()
	var vertex_index := PackedInt32Array()
	vertex_index.resize(n * n)
	var scale: float = RADIUS / sqrt(2.0)
	for i in n:
		var angle_i: float = TAU * i / n
		for j in n:
			var angle_j: float = TAU * j / n
			var vertex := Vector4(cos(angle_i), sin(angle_i), cos(angle_j), sin(angle_j)) * scale
			vertex_index[i * n + j] = wire_mesh.append_vertex(vertex, false)
	for i in n:
		var i_next: int = (i + 1) % n
		for j in n:
			var j_next: int = (j + 1) % n
			wire_mesh.append_edge_indices(vertex_index[i * n + j], vertex_index[i_next * n + j], false)
			wire_mesh.append_edge_indices(vertex_index[i * n + j], vertex_index[i * n + j_next], false)
	mesh = wire_mesh
	if label != null:
		label.text = "{4,4|%d} skew polyhedron - press 1-9 or [ ] to change n" % n
