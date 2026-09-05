class_name ShrubMeshBuilder4D
extends RefCounted
## Converts a shrub's sparse voxel set (shrub_generator.gd's own
## voxelize()) into a smooth implicit density field, then meshes it via
## the existing, already-proven TerrainMeshBackendMT - not new meshing
## code, and not dual contouring. See the approved port plan's "Mesh-
## building backend (revised)" section for why: this project's own crack
## investigation measured DC at 23-43% unpaired/hole faces at every
## tested resolution, MT at exactly 0.0% - MT is the correctness
## baseline to build on, not DC.
##
## Brick tiling is deliberately its OWN scheme here, not VoxelBrick4D's
## (terrain's) apron+nominal geometry verbatim: per that class's own
## documented reasoning (see terrain4d_mesh_backend_mt.gd's header), MT
## itself never needs an apron for correctness - "a cell's own tets are
## fully determined by that ONE cell's 16 corners, no neighboring cell is
## ever consulted." VoxelBrick4D's apron exists only for STREAMING/
## incremental-edit ownership bookkeeping, which doesn't apply here: a
## shrub's mesh is baked once from a plain density function, never
## incrementally edited brick-by-brick. So bricks here tile with zero
## apron and exactly one shared boundary POINT between neighbors (brick
## N's last grid point per axis is brick N+1's first, at the identical
## world position) - simpler, and still seamless because
## append_vertices(..., true) welds coincident positions across bricks.
##
## Narrow-band culling (skip bricks with no occupied voxel within
## smoothing_radius of their own bounds, before evaluating ANY density
## samples) is required for tractability, not just an optimization: a
## single dense grid over a whole shrub's bounding tesseract at a useful
## supersampled resolution would be many tens of millions of samples -
## the same size^4 blowup this port plan's own research flagged for
## VoxelField4D.
##
## Density sampling uses a spatial bucket (grid cell size ==
## smoothing_radius) built once per build, NOT a brute-force scan of
## every occupied voxel per sample point - with a shrub's ~1-3k occupied
## voxels and many tens of thousands of density samples, brute-force
## per-sample distance checks against the whole voxel set would dominate
## build time. This is a real, deliberate spatial-acceleration structure
## (unlike shrub_generator.gd's own attractor search, which matches
## shrubbery's own brute-force original at a much smaller n*m scale) - a
## different part of the pipeline, a different appropriate technique.
##
## An instance (not pure-static) class: the density function passed to
## TerrainMeshBackendMT has to be an instance-bound Callable
## (Callable(self, "_sample_density")) - every existing density-Callable
## site in this codebase (voxel_brick_4d.gd, terrain_generator.gd, the
## benchmark runners) binds to an instance for exactly this reason, not
## a bare static method reference.

const CELLS_PER_BRICK := 12 # points_per_axis = 13 -> 28,561 samples/meshed brick, close to this project's own ~20,736-point terrain reference point.
const POINTS_PER_BRICK := CELLS_PER_BRICK + 1

var _buckets: Dictionary
var _smoothing_radius: float
var _iso_threshold: float


static func build_mesh(voxels: Dictionary, species: ShrubSpecies4D) -> ArrayTetraMesh4D:
	var builder := ShrubMeshBuilder4D.new()
	return builder._build(voxels, species)


func _build(voxels: Dictionary, species: ShrubSpecies4D) -> ArrayTetraMesh4D:
	var mesh := ArrayTetraMesh4D.new()
	if voxels.is_empty():
		return mesh

	_smoothing_radius = species.smoothing_radius_in_voxels * species.voxel_size
	_iso_threshold = species.density_iso_threshold
	var mt_step_scalar: float = species.voxel_size / species.mt_supersample_factor
	var mt_step := Vector4(mt_step_scalar, mt_step_scalar, mt_step_scalar, mt_step_scalar)

	var occupied_cells: Array[Vector4i] = []
	for key in voxels:
		occupied_cells.append(ShrubGenerator4D.unpack_voxel_key(key))

	var voxel_min: Vector4i = occupied_cells[0]
	var voxel_max: Vector4i = occupied_cells[0]
	for cell in occupied_cells:
		voxel_min = Vector4i(mini(voxel_min.x, cell.x), mini(voxel_min.y, cell.y), mini(voxel_min.z, cell.z), mini(voxel_min.w, cell.w))
		voxel_max = Vector4i(maxi(voxel_max.x, cell.x), maxi(voxel_max.y, cell.y), maxi(voxel_max.z, cell.z), maxi(voxel_max.w, cell.w))

	var margin: float = species.voxel_size * 0.5 + _smoothing_radius
	var world_min: Vector4 = ShrubGenerator4D.cell_center(voxel_min, species.voxel_size) - Vector4(margin, margin, margin, margin)
	var world_max: Vector4 = ShrubGenerator4D.cell_center(voxel_max, species.voxel_size) + Vector4(margin, margin, margin, margin)

	_buckets = _build_buckets(occupied_cells, species.voxel_size, _smoothing_radius)

	var brick_span: float = CELLS_PER_BRICK * mt_step_scalar
	var brick_count := Vector4i(
		maxi(1, int(ceil((world_max.x - world_min.x) / brick_span))),
		maxi(1, int(ceil((world_max.y - world_min.y) / brick_span))),
		maxi(1, int(ceil((world_max.z - world_min.z) / brick_span))),
		maxi(1, int(ceil((world_max.w - world_min.w) / brick_span)))
	)

	var density_fn := Callable(self, "_sample_density")

	# Printed BEFORE the (potentially long) meshing loop - see this
	# class's own header on why candidate/meshed brick count and total
	# samples matter for tractability, not just correctness. A caller
	# watching this print can judge whether to let a run continue before
	# it has to wait for the whole thing to finish.
	var candidate_bricks: int = brick_count.x * brick_count.y * brick_count.z * brick_count.w
	print("ShrubMeshBuilder4D: candidate_bricks=%d (points_per_brick^4=%d each) mt_step=%.4f brick_span=%.4f" % [
		candidate_bricks, POINTS_PER_BRICK ** 4, mt_step_scalar, brick_span
	])

	var all_vertex_normals := PackedVector4Array()
	var all_boundary_normals := PackedVector4Array()
	var bricks_visited := 0
	var bricks_meshed := 0
	var total_tets := 0
	var start_usec := Time.get_ticks_usec()

	for bx in range(brick_count.x):
		for by in range(brick_count.y):
			for bz in range(brick_count.z):
				for bw in range(brick_count.w):
					bricks_visited += 1
					var bounds_min := Vector4(
						world_min.x + bx * brick_span, world_min.y + by * brick_span,
						world_min.z + bz * brick_span, world_min.w + bw * brick_span
					)
					var bounds_max: Vector4 = bounds_min + Vector4(brick_span, brick_span, brick_span, brick_span)
					if not _bucket_range_has_voxel(bounds_min, bounds_max):
						continue
					bricks_meshed += 1
					var result: Dictionary = TerrainMeshBackendMT.generate_brick_mesh(bounds_min, mt_step, POINTS_PER_BRICK, density_fn)
					total_tets += _merge_brick_result(mesh, result, all_vertex_normals, all_boundary_normals)
					if bricks_meshed % 5 == 0:
						var elapsed_so_far: float = (Time.get_ticks_usec() - start_usec) / 1_000_000.0
						print("  ...bricks_meshed=%d / bricks_visited=%d / candidate=%d, elapsed=%.1fs" % [bricks_meshed, bricks_visited, candidate_bricks, elapsed_so_far])

	mesh.normal_values = all_vertex_normals
	mesh.simplex_cell_normal_indices = PackedInt32Array(range(all_vertex_normals.size()))
	if all_boundary_normals.size() == total_tets:
		mesh.set_simplex_cell_boundary_normals(all_boundary_normals)
		mesh.calculate_boundary_normals(true)
	else:
		mesh.calculate_boundary_normals()

	var elapsed_sec: float = (Time.get_ticks_usec() - start_usec) / 1_000_000.0
	print("ShrubMeshBuilder4D.build_mesh: voxels=%d bricks_visited=%d bricks_meshed=%d total_tets=%d elapsed_sec=%.2f" % [voxels.size(), bricks_visited, bricks_meshed, total_tets, elapsed_sec])
	return mesh


## Buckets occupied voxels into cells of side length == smoothing_radius,
## keyed by the same packed-int64 scheme as the voxel set itself (a
## coarser grid, same packing function - the two never collide in
## meaning since callers never mix bucket keys and voxel keys). Each
## bucket holds an Array of the occupied voxels' WORLD-SPACE centers, not
## their cell coordinates, since that's what density sampling actually
## needs.
static func _build_buckets(occupied_cells: Array[Vector4i], voxel_size: float, smoothing_radius: float) -> Dictionary:
	var buckets: Dictionary = {}
	for cell in occupied_cells:
		var world_pos: Vector4 = ShrubGenerator4D.cell_center(cell, voxel_size)
		var bucket_coord: Vector4i = ShrubGenerator4D.world_to_cell(world_pos, smoothing_radius)
		var bucket_key: int = ShrubGenerator4D.pack_voxel_key(bucket_coord)
		if not buckets.has(bucket_key):
			buckets[bucket_key] = []
		(buckets[bucket_key] as Array).append(world_pos)
	return buckets


func _sample_density(point: Vector4) -> float:
	var blob_sum: float = 0.0
	var center_bucket: Vector4i = ShrubGenerator4D.world_to_cell(point, _smoothing_radius)
	# A voxel within smoothing_radius of `point` can only live in the
	# center bucket or its immediate 1-ring neighbors, since bucket side
	# length == smoothing_radius - checking exactly those 3^4=81 buckets
	# is sufficient and exhaustive.
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for dz in range(-1, 2):
				for dw in range(-1, 2):
					var bucket_key: int = ShrubGenerator4D.pack_voxel_key(center_bucket + Vector4i(dx, dy, dz, dw))
					if not _buckets.has(bucket_key):
						continue
					for voxel_pos in _buckets[bucket_key]:
						var dist: float = point.distance_to(voxel_pos)
						if dist < _smoothing_radius:
							blob_sum += 1.0 - dist / _smoothing_radius
	return _iso_threshold - blob_sum


## Cheap pre-check: does ANY occupied voxel lie within smoothing_radius
## of the brick's own [bounds_min, bounds_max] box? Checked via the same
## bucket structure _sample_density uses - a brick with no nearby voxel
## at all is skipped before a single density sample is evaluated (the
## narrow-band culling this class's own header describes).
func _bucket_range_has_voxel(bounds_min: Vector4, bounds_max: Vector4) -> bool:
	var expanded_min: Vector4 = bounds_min - Vector4(_smoothing_radius, _smoothing_radius, _smoothing_radius, _smoothing_radius)
	var expanded_max: Vector4 = bounds_max + Vector4(_smoothing_radius, _smoothing_radius, _smoothing_radius, _smoothing_radius)
	var bucket_min: Vector4i = ShrubGenerator4D.world_to_cell(expanded_min, _smoothing_radius)
	var bucket_max: Vector4i = ShrubGenerator4D.world_to_cell(expanded_max, _smoothing_radius)
	for x in range(bucket_min.x, bucket_max.x + 1):
		for y in range(bucket_min.y, bucket_max.y + 1):
			for z in range(bucket_min.z, bucket_max.z + 1):
				for w in range(bucket_min.w, bucket_max.w + 1):
					if _buckets.has(ShrubGenerator4D.pack_voxel_key(Vector4i(x, y, z, w))):
						return true
	return false


## Appends one brick's MT result into the shared mesh (dedup=true, so
## shared-boundary vertices between adjacent bricks weld into a single
## vertex - see this class's own header on why zero-apron tiling is
## still seamless). Returns the tet count merged, for the caller's
## boundary-normals-size sanity check.
static func _merge_brick_result(mesh: ArrayTetraMesh4D, result: Dictionary, all_vertex_normals: PackedVector4Array, all_boundary_normals: PackedVector4Array) -> int:
	var index_map: PackedInt32Array = mesh.append_vertices(result.unique_vertex_positions, true)
	var tet_indices: PackedInt32Array = result.tet_vertex_indices
	var tet_count: int = result.tet_count
	var tet_vertex_normals: PackedVector4Array = result.tet_vertex_normals
	var boundary_normals: PackedVector4Array = result.get("tet_boundary_normals", PackedVector4Array())
	var has_boundary: bool = boundary_normals.size() == tet_count
	for t in range(tet_count):
		var base: int = t * 4
		mesh.append_tetra_cell_indices(
			index_map[tet_indices[base + 0]], index_map[tet_indices[base + 1]],
			index_map[tet_indices[base + 2]], index_map[tet_indices[base + 3]]
		)
		for v in range(4):
			all_vertex_normals.append(tet_vertex_normals[base + v])
		if has_boundary:
			all_boundary_normals.append(boundary_normals[t])
	return tet_count
