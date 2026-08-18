extends Node
## TEMPORARY diagnostic - NOT open-ended investigation. Tests one specific
## hypothesis: that a parity/off-by-one/boundary bug in TerrainColorBands
## classification or the _build_brick_mesh bucketing loop is systematically
## dropping/misrouting a large regular fraction of tets, which would explain
## "roughly half the surface reads gray" better than residual structural
## degeneracy (already measured at 0/240 for the live alternate-split
## formula, ruling that out at this magnitude).
##
## Two things reported:
## 1. GLOBAL band tet-count distribution across every dense brick in the
##    live showcase, read directly off brick.cached_band_meshes (the actual
##    production output, not a reimplementation) - this alone tells us
##    whether "gray" really is ~half by TET COUNT, or whether the bucketing
##    loop is dropping tets (band counts summing to less than the brick's
##    own total tet count would be the direct signature of a bucketing bug).
## 2. A per-tet trace for ONE real brick: re-runs the exact same production
##    calls (TerrainMeshBackendMT.generate_brick_mesh +
##    _filter_to_brick_ownership) that regenerate_dirty_bricks() already
##    ran for that brick, and prints (centroid, normal, dot(UP), band) for a
##    sample of tets - a direct trace of "which tet, which band, why."
## Not part of the shipped scene.

@onready var showcase: Node4D = $"../Scene/World/TerrainRig/VoxelShowcase"

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _ready() -> void:
	await _wait_frames(3)
	await _run()

func _run() -> void:
	var waited_frames := 0
	while (showcase._settled_msec < 0 or not showcase._creatures_spawned) and waited_frames < 1800:
		await get_tree().process_frame
		waited_frames += 1
	print("0.settled_and_spawned_before_timeout: %s waited_frames=%d" % [showcase._settled_msec >= 0 and showcase._creatures_spawned, waited_frames])

	await _wait_frames(2)
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/gray_bands_diagnostic.png")
	print("SCREENSHOT_SAVED: gray_bands_diagnostic.png")

	# --- Isolation test: does the SAME checkerboard-of-missing-facets show
	# up on the UNSPLIT brick.cached_mesh (single ArrayTetraMesh4D, all tets,
	# one calculate_boundary_normals() call), or only on the per-band SPLIT
	# submeshes? If it's on cached_mesh too, splitting-by-band isn't the
	# cause - it's inherent to calculate_boundary_normals() on this
	# terrain's geometry (a large, open, non-convex sheet, not a closed
	# volume around the origin - exactly what that method's own doc warns
	# it isn't designed for). Swaps every currently-bound pooled node's
	# Mesh_0 to show the full cached_mesh and hides Mesh_1/Mesh_2, at the
	# exact same camera framing already established above.
	var chunk_pool: TerrainChunkPool4D = showcase.chunk_pool
	var bound: Dictionary = chunk_pool._bound
	var bound_brick: Dictionary = chunk_pool._bound_brick
	for key in bound:
		var body: StaticBody4D = bound[key]
		var brick: VoxelBrick4D = bound_brick[key]
		# Keep material_override as the GRASS material (already set on
		# Mesh_0 by _make_node) - a single solid color makes any missing
		# facet just as visible against the background as in the banded
		# screenshot, without confounding the comparison with a default-
		# material color that might itself read as gray.
		(body.get_node("Mesh_0") as MeshInstance4D).mesh = brick.cached_mesh
		(body.get_node("Mesh_1") as MeshInstance4D).mesh = null
		(body.get_node("Mesh_2") as MeshInstance4D).mesh = null
	await _wait_frames(2)
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("res://smoke_test_output/gray_bands_diagnostic_unsplit_mesh.png")
	print("SCREENSHOT_SAVED: gray_bands_diagnostic_unsplit_mesh.png (cached_mesh, unsplit, single GRASS-colored material)")

	var world: VoxelWorld4D = showcase.world
	var dense_bricks: Array = world.get_dense_bricks()
	print("1.dense_brick_count: %d" % [dense_bricks.size()])

	# --- Part 1: global band distribution, read directly off the real
	# production output (brick.cached_band_meshes), across every resident
	# brick - not a re-derivation. Also sums each brick's cached_mesh tet
	# count (the pre-banding, unfiltered total) so a mismatch between
	# "sum of band tet counts" and "cached_mesh tet count" would itself be
	# direct proof of a bucketing bug (tets silently dropped).
	var band_totals := []
	band_totals.resize(TerrainColorBands.BAND_COUNT)
	for b in range(TerrainColorBands.BAND_COUNT):
		band_totals[b] = 0
	var total_cached_mesh_tets := 0
	var total_band_tets := 0
	for brick in dense_bricks:
		var b4: VoxelBrick4D = brick
		if b4.cached_mesh != null:
			total_cached_mesh_tets += b4.cached_mesh.simplex_cell_indices.size() / 4
		for b in range(TerrainColorBands.BAND_COUNT):
			if b < b4.cached_band_meshes.size():
				var band_mesh: ArrayTetraMesh4D = b4.cached_band_meshes[b]
				var count: int = band_mesh.simplex_cell_indices.size() / 4
				band_totals[b] += count
				total_band_tets += count

	print("2a.total_cached_mesh_tets (pre-banding, unfiltered): %d" % [total_cached_mesh_tets])
	print("2b.total_band_tets (sum across ROCK+GRASS+DIRT): %d (expect == 2a if bucketing drops nothing)" % [total_band_tets])
	for b in range(TerrainColorBands.BAND_COUNT):
		var name: String = ["ROCK", "GRASS", "DIRT"][b]
		var pct := 0.0
		if total_band_tets > 0:
			pct = 100.0 * float(band_totals[b]) / float(total_band_tets)
		print("2c.band[%s]_tet_count: %d (%.1f%%) color=%s" % [name, band_totals[b], pct, TerrainColorBands.BAND_COLORS[b]])

	# --- Part 2: per-tet trace for one real brick - exact same production
	# calls regenerate_dirty_bricks() already made for this brick, so this
	# is tracing the REAL computation, not a reimplementation that could
	# subtly differ.
	if dense_bricks.is_empty():
		print("NO DENSE BRICKS - cannot trace individual tets. DONE")
		get_tree().quit()
		return

	var brick: VoxelBrick4D = dense_bricks[dense_bricks.size() / 2]
	var nominal: Dictionary = VoxelBrick4D.nominal_bounds(brick.brick_coord, world.world_origin, world.step)
	var actual: Dictionary = VoxelBrick4D.actual_bounds(brick.brick_coord, world.world_origin, world.step)
	var raw_result: Dictionary = TerrainMeshBackendMT.generate_brick_mesh(
		actual.min, world.step, VoxelBrick4D.ACTUAL_POINTS_PER_AXIS,
		brick.stored_density_fn(world.world_origin, world.step)
	)
	var owned: Dictionary = world._filter_to_brick_ownership(raw_result, nominal.min, nominal.max)

	print("3a.traced_brick_coord: %s tet_count=%d" % [brick.brick_coord, owned.tet_count])

	var positions: PackedVector4Array = owned.unique_vertex_positions
	var tet_indices: PackedInt32Array = owned.tet_vertex_indices
	var tet_normals: PackedVector4Array = owned.tet_vertex_normals
	var tet_count: int = owned.tet_count

	var local_band_counts := [0, 0, 0]
	var dot_min := 1.0
	var dot_max := -1.0
	var dot_sum := 0.0
	# Coarse histogram of normal.dot(UP) in 10 buckets across [-1, 1] - lets
	# us see whether values cluster tightly around the 0.7 threshold
	# (miscalibration) or are spread/bimodal in some other way.
	var histogram := []
	histogram.resize(10)
	for i in range(10):
		histogram[i] = 0

	var sample_lines := []
	for t in range(tet_count):
		var base := t * 4
		var i0: int = tet_indices[base + 0]
		var i1: int = tet_indices[base + 1]
		var i2: int = tet_indices[base + 2]
		var i3: int = tet_indices[base + 3]
		var centroid := (positions[i0] + positions[i1] + positions[i2] + positions[i3]) * 0.25
		var normal: Vector4 = tet_normals[base]
		var dot: float = normal.dot(TerrainColorBands.UP)
		var band: int = TerrainColorBands.classify(centroid, normal)
		local_band_counts[band] += 1
		dot_min = minf(dot_min, dot)
		dot_max = maxf(dot_max, dot)
		dot_sum += dot
		var bucket: int = clampi(int((dot + 1.0) * 5.0), 0, 9)
		histogram[bucket] += 1
		if t < 15:
			var band_name: String = ["ROCK", "GRASS", "DIRT"][band]
			sample_lines.append("  tet %d: centroid=%s normal=%s dot=%.3f -> %s" % [t, centroid, normal, dot, band_name])

	print("3b.traced_brick_band_counts: ROCK=%d GRASS=%d DIRT=%d" % [local_band_counts[0], local_band_counts[1], local_band_counts[2]])
	print("3c.dot(UP)_stats_over_traced_brick: min=%.3f max=%.3f mean=%.3f threshold=%.3f" % [dot_min, dot_max, dot_sum / float(tet_count), TerrainColorBands.STEEP_DOT_THRESHOLD])
	print("3d.dot(UP)_histogram_[-1..1_in_10_buckets]: %s" % [histogram])
	print("3e.sample_tets:")
	for line in sample_lines:
		print(line)

	print("DONE")
	get_tree().quit()
