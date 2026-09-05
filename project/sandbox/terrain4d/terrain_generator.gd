extends StaticBody4D
## Procedurally generates a small 4D voxel terrain chunk via DualContour4D +
## Noise4D, builds it into an ArrayTetraMesh4D (single flat material - no
## multi-material blending, per spike scope), and derives a walkable
## ConcaveMeshShape4D collision shape from the same mesh.

@export var noise_seed: int = 1
## x/z/w share the same extent - the domain is a cube in those 3 axes.
@export var bounds_half_extent_horizontal: float = 8.0
@export var bounds_min_y: float = -4.0
@export var bounds_max_y: float = 7.0
@export var resolution_horizontal: int = 21
@export var resolution_vertical: int = 16
@export var noise_frequency: float = 0.18
@export var noise_amplitude: float = 6.0
@export var noise_persistence: float = 0.55
@export var ground_level: float = 0.0
@export var albedo_color: Color = Color(0.32, 0.27, 0.16, 1.0)
@export var qef_regularization: float = 0.15
## How far inside the sampling domain the closing box walls sit - keeps the
## wall crossings comfortably away from the grid's own boundary so dual
## contouring has full cells on both sides to work with.
@export var boundary_margin_horizontal: float = 1.0
@export var boundary_margin_vertical: float = 1.0
## Blend radius for the seam where the noisy top surface meets the closing
## box walls - see _smooth_max().
@export var seam_smoothing: float = 0.6

@onready var mesh_instance: MeshInstance4D = $Mesh
@onready var collision_shape: CollisionShape4D = $Collision

var _noise: Noise4D
var _last_result: Dictionary = {}

func _ready() -> void:
	_noise = Noise4D.new(noise_seed)
	regenerate()

## Boundary closing term: negative (solid) inside a box inset from the
## sampling domain, positive (air) outside it. Combined with the height
## field via max(), the terrain becomes a proper closed chunk - a capped
## top surface plus flat side walls and a flat bottom - instead of just the
## bare top surface. That bare-top-only shape is what a first-person player
## standing on it never notices (they only ever see the top), but it reads
## as "a single flat plane" the instant the whole object is viewed from an
## arbitrary angle, e.g. rotated in front of a fixed camera.
func _box_density(p: Vector4) -> float:
	var half_horizontal := bounds_half_extent_horizontal - boundary_margin_horizontal
	var y_center := (bounds_min_y + bounds_max_y) * 0.5
	var half_y := (bounds_max_y - bounds_min_y) * 0.5 - boundary_margin_vertical
	return maxf(
		maxf(absf(p.x) - half_horizontal, absf(p.y - y_center) - half_y),
		maxf(absf(p.z) - half_horizontal, absf(p.w) - half_horizontal)
	)

## Smooth (polynomial) max, blending over a radius `k` around the tie point
## instead of the hard kink a plain maxf() has there. The height field and
## _box_density() are otherwise perfectly smooth on their own, but a hard
## max() of two smooth functions is only C0 at the seam where they cross -
## dual contouring's per-cell gradient estimate is a central difference of
## whatever density function it's given, so a real kink there gives a
## poor/inconsistent gradient right at the cap-meets-wall seam, which was a
## plausible contributor to leftover mesh holes beyond what adaptive
## diagonal selection (see DualContour4D) already fixed.
static func _smooth_max(a: float, b: float, k: float) -> float:
	if k <= 0.0:
		return maxf(a, b)
	var h := clampf(0.5 - 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) + k * h * (1.0 - h)

## Density convention: negative = solid, positive = air. This is a genuine
## volumetric field (not a heightfield) - the noise term is sampled at the
## full 4D point `p`, including `p.y`, so the surface can fold into
## overhangs/caves rather than being a pure function of x/z/w.
##
## 3 octaves - the base frequency is kept low enough that even the finest
## octave's noise-lattice spacing stays comfortably above the grid's own
## step size. Dual contouring only samples at grid points, so any density
## feature finer than one cell aliases: the generated mesh would silently
## skip it while a finer analytic probe (e.g. find_surface_y) still finds
## it, so the two disagree about where the surface is.
func get_density(p: Vector4) -> float:
	var height_field := p.y - ground_level - noise_amplitude * _noise.fractal_noise(p * noise_frequency, 3, noise_persistence, 2.0)
	return _smooth_max(height_field, _box_density(p), seam_smoothing)

func regenerate() -> void:
	var bounds_min := Vector4(-bounds_half_extent_horizontal, bounds_min_y, -bounds_half_extent_horizontal, -bounds_half_extent_horizontal)
	var bounds_max := Vector4(bounds_half_extent_horizontal, bounds_max_y, bounds_half_extent_horizontal, bounds_half_extent_horizontal)
	var result := DualContour4D.generate(
		bounds_min, bounds_max,
		resolution_horizontal, resolution_vertical, resolution_horizontal, resolution_horizontal,
		Callable(self, "get_density"), qef_regularization
	)
	_last_result = result

	var mesh := ArrayTetraMesh4D.new()
	# unique_vertex_positions is already deduplicated by construction (one
	# entry per active dual-contouring cell) - dedup=false skips
	# ArrayTetraMesh4D's own O(n) linear-scan dedup entirely, which would
	# otherwise make mesh-building O(n^2) in vertex count.
	var indices: PackedInt32Array = mesh.append_vertices(result.unique_vertex_positions, false)
	var tet_indices: PackedInt32Array = result.tet_vertex_indices
	var tet_count: int = result.tet_count
	for t in range(tet_count):
		var base := t * 4
		mesh.append_tetra_cell_indices(
			indices[tet_indices[base + 0]], indices[tet_indices[base + 1]],
			indices[tet_indices[base + 2]], indices[tet_indices[base + 3]]
		)
	mesh.normal_values = result.tet_vertex_normals
	mesh.simplex_cell_normal_indices = PackedInt32Array(range(result.tet_vertex_normals.size()))
	mesh.calculate_boundary_normals()

	var material := TetraMaterial4D.new()
	material.albedo_color = albedo_color

	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	collision_shape.shape = ConcaveMeshShape4D.create_from_mesh(mesh)

func get_last_result() -> Dictionary:
	return _last_result

## Scans downward from y_max for the first air-to-solid crossing at the
## given (x, z, w) - i.e. the topmost surface, matching what a raycast from
## above would hit first. Scanning downward matters now that the terrain is
## a closed chunk (see _box_density()): scanning upward from y_min would
## hit the box's own flat bottom before ever reaching the real ground.
func find_surface_y(x: float, z: float, w: float, y_min: float = -6.0, y_max: float = 10.0, steps: int = 96) -> float:
	var prev_y := y_max
	var prev_d := get_density(Vector4(x, y_max, z, w))
	for i in range(1, steps + 1):
		var y: float = lerpf(y_max, y_min, float(i) / float(steps))
		var d := get_density(Vector4(x, y, z, w))
		if (d < 0.0) != (prev_d < 0.0):
			var t: float = prev_d / (prev_d - d)
			return lerpf(prev_y, y, t)
		prev_y = y
		prev_d = d
	return 0.0
