class_name PatchField4D
extends RefCounted
## PORTAL-LOCAL FORK of project/ramon/voxel_port/scripts/voxel_field_4d.gd.
##
## The only change is that the grid size is a Vector4i instead of one int, so
## the field can be fine across the patch face and coarse through its thickness
## and along w. That is not a micro-optimisation: cost is the product of the four
## axis counts, and a cubic grid fine enough for a circular rim (16 cells across)
## costs 65,536 points, while 16 x 16 x 4 x 4 costs 4,096 for the SAME rim
## quality. It is what makes a clean dual-contoured cut affordable per shot.
##
## Forked rather than edited because VoxelMining and voxel_port both depend on
## the originals and neither needs anisotropy. Kept deliberately close to the
## source so differences stay easy to diff.
## A fully volumetric 4D voxel field: a size^4 grid of (material, density)
## samples, plus the exact surface crossing recorded on every grid edge where
## the material changes.
##
## This is the "field" half of the pipeline - it knows nothing about meshes.
## [MultiVertexDualContour4D] consumes it.
##
## The important departure from the project's existing terrain generator
## (project/ramon/VoxelIsland/scripts/heightfield_dual_contour_terrain_4d.gd) is that this is
## volumetric rather than a height field. That generator defines terrain as
## y = height(x, z, w), which makes the vertical axis privileged and makes
## overhangs, caves, and closed solids (a hypersphere, a hypercube) literally
## unrepresentable. Here the field is an arbitrary signed density over all
## four axes, so those all become expressible - at the cost of the grid being
## genuinely 4-dimensional in memory rather than effectively 3-dimensional.
##
## Layers are composited in order, each one able to overwrite materials it is
## permitted to replace. That is what lets "water, then ground, then carve the
## boundary" build an ocean world in three declarative steps, with the
## shoreline falling out as exact geometry rather than being faked by
## intersecting a separate flat water plane with the terrain.

## Voxel material identity. Named VoxelMaterial rather than the more obvious
## Material because a bare "Material" shadows Godot's own native Material
## class, which is a hard parse error rather than a warning.
##
## Ordering matters: [method is_denser] treats a higher value as the denser
## material, which decides which way a surface between two materials faces.
## Air must stay 0 so a zero-initialized grid reads as empty.
enum VoxelMaterial {
	AIR = 0,
	WATER = 1,
	GROUND = 2,
}

## Grid points start as air with an arbitrary positive density. The value is
## only ever compared against other densities of the same material, never used
## as a distance, so its magnitude is not meaningful - it just has to be
## positive and comfortably larger than anything a layer is likely to report
## for a point deep inside air.
const INITIAL_AIR_DENSITY := 10.0

## Cap on the false-position refinement of an edge crossing. Each step is one
## density evaluation, and crossings are by far the hottest path in
## generation, so this trades a bounded amount of work for the sharp-feature
## accuracy that plain linear interpolation throws away.
const MAX_CROSSING_REFINEMENT_STEPS := 8

## A crossing is accepted once the density there is within this of zero.
## Expressed in density units, which for these models are roughly grid cells,
## so this is a thousandth of a cell - far below anything visible.
const CROSSING_EPSILON := 1e-3

## Passed as [param replace_mask] to accept any existing material.
const REPLACE_ANY := -1

var size: Vector4i = Vector4i.ZERO

# Per grid point, flat-indexed by _point_index().
var _material: PackedByteArray
var _density: PackedFloat32Array

# Per (grid point, axis), flat-indexed by _edge_slot(). An edge runs from its
# point in the positive direction along its axis, so points on the far
# boundary of an axis simply never own an edge along it.
var _edge_exists: PackedByteArray
var _edge_position: PackedFloat32Array
var _edge_normal: PackedVector4Array
var _edge_near_material: PackedByteArray
var _edge_far_material: PackedByteArray
## Which layer created each edge. [MultiVertexDualContour4D] hands this back on the
## generated vertices so the terrain node can ask a layer-specific question
## ("which way is up here?") without this class needing to know the answer.
var _edge_layer: PackedByteArray

var _layer_count: int = 0


func _init(p_size: Vector4i) -> void:
	size = Vector4i(maxi(2, p_size.x), maxi(2, p_size.y), maxi(2, p_size.z), maxi(2, p_size.w))
	var point_count: int = size.x * size.y * size.z * size.w
	_material.resize(point_count)
	_density.resize(point_count)
	_density.fill(INITIAL_AIR_DENSITY)

	var edge_count: int = point_count * 4
	_edge_exists.resize(edge_count)
	_edge_position.resize(edge_count)
	_edge_normal.resize(edge_count)
	_edge_near_material.resize(edge_count)
	_edge_far_material.resize(edge_count)
	_edge_layer.resize(edge_count)


## Higher material values are denser. Used to orient surfaces: a boundary
## normal always points from the denser material toward the thinner one, so
## ground-under-water and ground-under-air both face "outward" consistently.
static func is_denser(a: int, b: int) -> bool:
	return a > b


func point_count() -> int:
	return size.x * size.y * size.z * size.w


func _point_index(x: int, y: int, z: int, w: int) -> int:
	return ((x * size.y + y) * size.z + z) * size.w + w


func _point_index_v(p: Vector4i) -> int:
	return ((p.x * size.y + p.y) * size.z + p.z) * size.w + p.w


func _edge_slot(point_index: int, axis: int) -> int:
	return point_index * 4 + axis


func is_inside(p: Vector4i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.z >= 0 and p.w >= 0 \
		and p.x < size.x and p.y < size.y and p.z < size.z and p.w < size.w


func material_at(p: Vector4i) -> int:
	return _material[_point_index_v(p)]


func has_edge(point_index: int, axis: int) -> bool:
	return _edge_exists[_edge_slot(point_index, axis)] != 0


func edge_position(point_index: int, axis: int) -> float:
	return _edge_position[_edge_slot(point_index, axis)]


func edge_normal(point_index: int, axis: int) -> Vector4:
	return _edge_normal[_edge_slot(point_index, axis)]


func edge_near_material(point_index: int, axis: int) -> int:
	return _edge_near_material[_edge_slot(point_index, axis)]


func edge_far_material(point_index: int, axis: int) -> int:
	return _edge_far_material[_edge_slot(point_index, axis)]


func edge_layer(point_index: int, axis: int) -> int:
	return _edge_layer[_edge_slot(point_index, axis)]


func count_edges() -> int:
	var total := 0
	for value in _edge_exists:
		if value != 0:
			total += 1
	return total


## Composites one signed-density layer onto the field.
##
## [param density_fn] takes a [Vector4] in grid coordinates and returns a
## signed density: positive inside the layer's material, negative outside.
## [param gradient_fn] returns the (unnormalized) gradient of that density at
## a point; it only ever gets called at crossings, so it may be expensive
## relative to the density function.
##
## [param confidence] scales the recorded normals. Since [QEFSolver4D]
## weights each crossing by its normal's magnitude, a lower confidence means
## this layer's normals influence vertex placement less and hit the singular
## cutoff sooner - which is what you want for a layer whose surface direction
## is only approximately known (noisy terrain) versus one where it is exact
## (an analytic sphere).
##
## [param replace_mask] is a bitmask over [enum VoxelMaterial] of what this layer
## is allowed to overwrite, or [constant REPLACE_ANY].
##
## Returns the layer's index, for correlating generated geometry back to the
## layer that produced it.
func add_layer(material: int, density_fn: Callable, gradient_fn: Callable, confidence: float, replace_mask: int = REPLACE_ANY) -> int:
	var layer_index: int = _layer_count
	_layer_count += 1

	# Every grid point's density under this layer, evaluated exactly once.
	# Both passes below need it, and the edge pass needs it for both endpoints
	# of every edge - so without this cache each point would be evaluated
	# nine times over (once for itself, once as the neighbor of each of its
	# eight axis-adjacent points).
	var densities := PackedFloat32Array()
	densities.resize(point_count())
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				for w in range(size.w):
					densities[_point_index(x, y, z, w)] = density_fn.call(Vector4(x, y, z, w))

	_update_edges(material, densities, density_fn, gradient_fn, confidence, replace_mask, layer_index)
	_update_points(material, densities, replace_mask)
	return layer_index


func _can_replace(existing_material: int, new_material: int, replace_mask: int) -> bool:
	if existing_material == new_material:
		return false
	if replace_mask == REPLACE_ANY:
		return true
	return (replace_mask & (1 << existing_material)) != 0


## Records, clears, or re-labels the crossing on every grid edge this layer
## affects.
##
## Three distinct cases, and getting all three right is what lets layers
## composite rather than merely overwrite:
## 1. An edge previously had a crossing, but after this layer both sides are
##    the same material - the surface there no longer exists, so drop it.
## 2. The layer's own boundary passes through this edge and the two sides end
##    up as different materials - record a fresh crossing.
## 3. An existing crossing survives, but the materials on one or both sides
##    changed (e.g. ground poured into what used to be an air/water boundary).
##    Keep the geometry, re-label the sides, and flip the normal if the denser
##    side swapped over - otherwise the surface would face inward.
func _update_edges(material: int, densities: PackedFloat32Array, density_fn: Callable, gradient_fn: Callable, confidence: float, replace_mask: int, layer_index: int) -> void:
	for x in range(size.x):
		for y in range(size.y):
			for z in range(size.z):
				for w in range(size.w):
					var here := Vector4i(x, y, z, w)
					var here_index: int = _point_index(x, y, z, w)
					var here_material: int = _material[here_index]
					var here_density: float = densities[here_index]
					var here_replaceable: bool = _can_replace(here_material, material, replace_mask)

					for axis in range(4):
						if here[axis] + 1 >= size[axis]:
							continue # No neighbor along this axis - the edge would leave the grid.
						var there := here
						there[axis] += 1
						var there_index: int = _point_index_v(there)
						var there_material: int = _material[there_index]
						var there_density: float = densities[there_index]
						var there_replaceable: bool = _can_replace(there_material, material, replace_mask)

						var near_material: int = material if (here_density > 0.0 and here_replaceable) else here_material
						var far_material: int = material if (there_density > 0.0 and there_replaceable) else there_material

						var slot: int = _edge_slot(here_index, axis)
						var had_edge: bool = _edge_exists[slot] != 0

						if had_edge and near_material == far_material:
							_edge_exists[slot] = 0
							continue

						var is_layer_boundary: bool = (here_density > 0.0) != (there_density > 0.0)
						if is_layer_boundary and here_replaceable and there_replaceable and near_material != far_material:
							var crossing: float = _refine_crossing(density_fn, Vector4(x, y, z, w), axis, here_density, there_density)
							var crossing_point := Vector4(x, y, z, w)
							crossing_point[axis] += crossing
							var normal: Vector4 = gradient_fn.call(crossing_point)
							var gradient_length: float = normal.length()
							if gradient_length > 0.0:
								normal = normal * (confidence / gradient_length)
							# Point the normal from the denser material toward the
							# thinner one. `here_density > 0` means this layer is
							# claiming the near side, so the material it is facing
							# off against sits on the far side, and vice versa.
							var opposing_material: int = there_material if here_density > 0.0 else here_material
							if is_denser(material, opposing_material):
								normal = -normal
							_edge_exists[slot] = 1
							_edge_position[slot] = crossing
							_edge_normal[slot] = normal
							_edge_near_material[slot] = near_material
							_edge_far_material[slot] = far_material
							_edge_layer[slot] = layer_index
						elif had_edge:
							var was_denser_near: bool = is_denser(here_material, there_material)
							var is_denser_near: bool = is_denser(near_material, far_material)
							if was_denser_near != is_denser_near:
								_edge_normal[slot] = -_edge_normal[slot]
							_edge_near_material[slot] = near_material
							_edge_far_material[slot] = far_material


## Applies the layer's material and density to the grid points themselves.
## Runs after [method _update_edges] because that pass needs to compare the
## pre-layer materials against the post-layer ones to decide which of its
## three cases applies.
func _update_points(material: int, densities: PackedFloat32Array, replace_mask: int) -> void:
	for index in range(point_count()):
		var density: float = densities[index]
		var existing_material: int = _material[index]
		if existing_material != material and _can_replace(existing_material, material, replace_mask):
			if density <= 0.0:
				# Outside this layer, but the layer still tells us something:
				# how far outside. Keeping the tightest bound found so far
				# means a later layer sees an honest distance rather than the
				# stale placeholder density.
				_density[index] = minf(_density[index], -density)
			else:
				_material[index] = material
				_density[index] = density
		elif existing_material == material:
			_density[index] = maxf(_density[index], density)


## Finds where along an edge the density actually reaches zero, by false
## position (regula falsi) rather than a single linear interpolation.
##
## One linear step is exact only if the density varies linearly along the
## edge, which is precisely what stops being true near a sharp feature - an
## edge, a corner, the intersection of two layers. Those are the places dual
## contouring is supposed to reproduce faithfully, so interpolating them
## linearly rounds off the very features the algorithm exists to keep. Each
## refinement step re-brackets on whichever side still contains the sign
## change, so the result stays inside the edge no matter how nonlinear the
## density is.
func _refine_crossing(density_fn: Callable, base: Vector4, axis: int, density_low: float, density_high: float) -> float:
	var low := 0.0
	var high := 1.0
	var f_low: float = density_low
	var f_high: float = density_high
	var t: float = f_low / (f_low - f_high)

	for step in range(MAX_CROSSING_REFINEMENT_STEPS):
		var sample_point: Vector4 = base
		sample_point[axis] += t
		var f_t: float = density_fn.call(sample_point)
		if absf(f_t) < CROSSING_EPSILON:
			break
		if (f_t > 0.0) == (f_low > 0.0):
			low = t
			f_low = f_t
		else:
			high = t
			f_high = f_t
		var denominator: float = f_low - f_high
		if is_zero_approx(denominator):
			break
		t = low + (high - low) * (f_low / denominator)

	return clampf(t, 0.0, 1.0)
