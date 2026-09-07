extends Node
## TEMPORARY - verifies VoxelWorld4D/VoxelBrick4D/TerrainMeshBackendMT end
## to end (hash+brick storage, corrected tile-collapse, apron/seam
## ownership filtering). Not part of the shipped scene. Pure logic - no
## scene dependencies, so this runs identically headless or windowed.
## Structural/invariant checks only - nothing here compares output against
## SingleVertexDualContour4D, since MT is a genuinely different algorithm by design,
## not a same-output swap like the earlier generate()->generate_native()
## native port.

const WORLD_ORIGIN := Vector4.ZERO
const STEP := Vector4(0.5, 0.5, 0.5, 0.5)
const SPHERE_RADIUS := 6.0

func _sphere_density(p: Vector4) -> float:
	return p.length() - SPHERE_RADIUS

## Uniform +1 (air) everywhere except a single point, matched by proximity
## rather than exact equality so this stays robust to how the caller
## arrived at the position - simulates a real feature (a solid speck)
## small enough to hide entirely inside one brick's interior, touching
## none of its 16 outer corners.
func _uniform_with_hidden_feature(p: Vector4, feature_point: Vector4) -> float:
	return -1.0 if p.distance_to(feature_point) < 0.01 else 1.0

func _ready() -> void:
	_run()

func _tet_count(mesh: ArrayTetraMesh4D) -> int:
	return mesh.get_simplex_cell_vertex_indices().size() / 4

func _centroid(vertices: PackedVector4Array, indices: PackedInt32Array, tet_index: int) -> Vector4:
	var base := tet_index * 4
	return (vertices[indices[base]] + vertices[indices[base + 1]] + vertices[indices[base + 2]] + vertices[indices[base + 3]]) * 0.25

static func _in_bounds(p: Vector4, lo: Vector4, hi: Vector4) -> bool:
	return p.x >= lo.x and p.x < hi.x and p.y >= lo.y and p.y < hi.y \
		and p.z >= lo.z and p.z < hi.z and p.w >= lo.w and p.w < hi.w

func _all_mesh_centroids_in_bounds(mesh: ArrayTetraMesh4D, lo: Vector4, hi: Vector4) -> bool:
	var vertices: PackedVector4Array = mesh.get_vertex_positions()
	var indices: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	for t in range(_tet_count(mesh)):
		if not _in_bounds(_centroid(vertices, indices, t), lo, hi):
			return false
	return true

func _no_mesh_centroids_in_bounds(mesh: ArrayTetraMesh4D, lo: Vector4, hi: Vector4) -> bool:
	var vertices: PackedVector4Array = mesh.get_vertex_positions()
	var indices: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	for t in range(_tet_count(mesh)):
		if _in_bounds(_centroid(vertices, indices, t), lo, hi):
			return false
	return true

## Operates on a raw (pre-filter) SingleVertexDualContour4D-style result Dictionary
## directly, rather than a built mesh - used to prove the apron really
## does produce geometry reaching into a neighbor's territory before
## filtering removes it (a positive control for the filter test below).
func _raw_result_has_centroid_in_bounds(result: Dictionary, lo: Vector4, hi: Vector4) -> bool:
	var positions: PackedVector4Array = result.unique_vertex_positions
	var indices: PackedInt32Array = result.tet_vertex_indices
	for t in range(result.tet_count):
		if _in_bounds(_centroid(positions, indices, t), lo, hi):
			return true
	return false

func _all_16_outer_corners_uniform(coord: Vector4i, world_origin: Vector4, step: Vector4, density_fn: Callable) -> bool:
	var nominal: Dictionary = VoxelBrick4D.nominal_bounds(coord, world_origin, step)
	var first_sign := true
	var uniform_negative := false
	for cx in [nominal.min.x, nominal.max.x]:
		for cy in [nominal.min.y, nominal.max.y]:
			for cz in [nominal.min.z, nominal.max.z]:
				for cw in [nominal.min.w, nominal.max.w]:
					var d: float = density_fn.call(Vector4(cx, cy, cz, cw))
					var negative := d < 0.0
					if first_sign:
						uniform_negative = negative
						first_sign = false
					elif negative != uniform_negative:
						return false
	return true

func _run() -> void:
	# 1. A brick entirely inside the sphere (well within the radius at
	# every one of its 256 nominal sample points, not just its corners)
	# collapses to a solid tile - no dense array, no mesh, no collision.
	var world_a := VoxelWorld4D.new(WORLD_ORIGIN, STEP, Callable(self, "_sphere_density"))
	var deep_inside := world_a.get_or_create_brick(Vector4i(0, 0, 0, 0))
	print("1a.deep_inside_collapses_solid: is_collapsed=%s is_collapsed_solid=%s (expect true, true)" % [deep_inside.is_collapsed, deep_inside.is_collapsed_solid])

	# 2. A brick entirely outside the sphere collapses to an air tile.
	var far_outside := world_a.get_or_create_brick(Vector4i(10, 10, 10, 10))
	print("2a.far_outside_collapses_air: is_collapsed=%s is_collapsed_solid=%s (expect true, false)" % [far_outside.is_collapsed, far_outside.is_collapsed_solid])

	# 3. Two adjacent bricks whose shared face straddles the sphere's
	# surface do NOT collapse, and produce real geometry once meshed.
	var brick_a := world_a.get_or_create_brick(Vector4i(2, 1, 1, 1))
	var brick_b := world_a.get_or_create_brick(Vector4i(3, 1, 1, 1))
	print("3a.straddling_brick_a_not_collapsed: %s (expect false)" % [brick_a.is_collapsed])
	print("3b.straddling_brick_b_not_collapsed: %s (expect false)" % [brick_b.is_collapsed])

	world_a.regenerate_dirty_bricks()
	var mesh_a: ArrayTetraMesh4D = brick_a.cached_mesh
	var mesh_b: ArrayTetraMesh4D = brick_b.cached_mesh
	print("3c.brick_a_tet_count: %d (expect > 0)" % [_tet_count(mesh_a)])
	print("3d.brick_b_tet_count: %d (expect > 0)" % [_tet_count(mesh_b)])

	# 4. Seam correctness: the raw (pre-filter) apron-extended result for
	# brick_a genuinely reaches into brick_b's nominal territory (proves
	# the filter isn't a no-op); after filtering, every kept tet's
	# centroid lies in brick_a's OWN nominal bounds and none reach into
	# brick_b's - i.e. no duplicate geometry across the shared seam.
	var nominal_a: Dictionary = VoxelBrick4D.nominal_bounds(brick_a.brick_coord, WORLD_ORIGIN, STEP)
	var nominal_b: Dictionary = VoxelBrick4D.nominal_bounds(brick_b.brick_coord, WORLD_ORIGIN, STEP)
	var actual_a: Dictionary = VoxelBrick4D.actual_bounds(brick_a.brick_coord, WORLD_ORIGIN, STEP)
	var raw_a: Dictionary = TerrainMeshBackendMT.generate_brick_mesh(actual_a.min, STEP, VoxelBrick4D.ACTUAL_POINTS_PER_AXIS, brick_a.stored_density_fn(WORLD_ORIGIN, STEP))
	print("4a.unfiltered_apron_genuinely_overlaps_neighbor: %s (expect true - proves the filter does real work)" % [_raw_result_has_centroid_in_bounds(raw_a, nominal_b.min, nominal_b.max)])
	print("4b.brick_a_filtered_centroids_all_in_own_bounds: %s (expect true)" % [_all_mesh_centroids_in_bounds(mesh_a, nominal_a.min, nominal_a.max)])
	print("4c.brick_b_filtered_centroids_all_in_own_bounds: %s (expect true)" % [_all_mesh_centroids_in_bounds(mesh_b, nominal_b.min, nominal_b.max)])
	print("4d.brick_a_no_centroids_leak_into_brick_b: %s (expect true)" % [_no_mesh_centroids_in_bounds(mesh_a, nominal_b.min, nominal_b.max)])
	print("4e.brick_b_no_centroids_leak_into_brick_a: %s (expect true)" % [_no_mesh_centroids_in_bounds(mesh_b, nominal_a.min, nominal_a.max)])

	# 5. Corrected tile-collapse: a thin, corner-avoiding interior feature
	# must NOT collapse - this is the exact bug the plan's design review
	# caught in the original 16-corner-probe proposal.
	var feature_coord := Vector4i(5, 5, 5, 5)
	var feature_nominal: Dictionary = VoxelBrick4D.nominal_bounds(feature_coord, WORLD_ORIGIN, STEP)
	var feature_point := Vector4(
		feature_nominal.min.x + 1 * STEP.x, feature_nominal.min.y + 1 * STEP.y,
		feature_nominal.min.z + 1 * STEP.z, feature_nominal.min.w + 1 * STEP.w
	)
	var feature_density_fn := Callable(self, "_uniform_with_hidden_feature").bind(feature_point)
	var world_b := VoxelWorld4D.new(WORLD_ORIGIN, STEP, feature_density_fn)
	var feature_brick := world_b.get_or_create_brick(feature_coord)
	print("5a.corner_avoiding_feature_not_collapsed: %s (expect false)" % [feature_brick.is_collapsed])
	print("5b.naive_corner_probe_would_have_missed_it: %s (expect true - confirms this case genuinely defeats a 16-corner-only check)" % [_all_16_outer_corners_uniform(feature_coord, WORLD_ORIGIN, STEP, feature_density_fn)])

	# 6. Determinism: recreating the same world/brick from scratch produces
	# a bit-identical density array (world_step reproducibility - the fix
	# that makes independently-generated neighbors agree at their seam).
	var world_c := VoxelWorld4D.new(WORLD_ORIGIN, STEP, Callable(self, "_sphere_density"))
	var brick_a_repeat := world_c.get_or_create_brick(Vector4i(2, 1, 1, 1))
	print("6a.repeated_generation_is_deterministic: %s (expect true)" % [brick_a_repeat.density == brick_a.density])

	# 7. TerrainChunkPool4D: distance culling acquires/releases pooled
	# nodes correctly, recycles rather than leaking, and only re-syncs a
	# bound node's mesh when its brick actually came back dirty.
	var pool := TerrainChunkPool4D.new()
	add_child(pool)
	pool.world = world_a
	var midpoint := Vector4(4.5, 2.25, 2.25, 2.25)  # brick_a/brick_b's shared face center
	pool.viewer_position = midpoint
	pool.max_render_distance = 2.0
	pool.update()
	print("7a.both_straddling_bricks_visible_in_range: %d (expect 2)" % [pool.visible_brick_count()])
	var pooled_after_first_update := pool.pooled_node_count()

	pool.max_render_distance = 0.5
	pool.update()
	print("7b.both_bricks_released_out_of_range: %d (expect 0)" % [pool.visible_brick_count()])
	print("7c.released_nodes_recycled_not_freed: %d (expect == %d, not grown/shrunk)" % [pool.pooled_node_count(), pooled_after_first_update])

	pool.max_render_distance = 2.0
	pool.update()
	print("7d.both_bricks_visible_again: %d (expect 2)" % [pool.visible_brick_count()])
	print("7e.no_new_nodes_created_on_re_entry: %d (expect == %d - proves reuse, not recreation)" % [pool.pooled_node_count(), pooled_after_first_update])

	var mesh_before: ArrayTetraMesh4D = brick_a.cached_mesh
	world_a.mark_brick_dirty(brick_a.brick_coord)
	world_a.regenerate_dirty_bricks()
	var mesh_after: ArrayTetraMesh4D = brick_a.cached_mesh
	pool.update()
	# Pool nodes now have one MeshInstance4D per color band (Mesh_0..Mesh_N-1,
	# see TerrainColorBands/TerrainChunkPool4D) rather than a single "Mesh"
	# child - check band 0 against the brick's own corresponding band mesh
	# (cached_band_meshes is rebuilt fresh every regen exactly like
	# cached_mesh is, so this is an equally valid "did the pool resync"
	# check, just against the array the pool actually displays now).
	var bound_mesh: ArrayTetraMesh4D = pool._bound[VoxelWorld4D.brick_key(brick_a.brick_coord)].get_node("Mesh_0").mesh
	var band0_mesh_after: ArrayTetraMesh4D = brick_a.cached_band_meshes[0]
	print("7f.dirty_regen_produced_new_mesh_object: %s (expect true)" % [mesh_before != mesh_after])
	print("7g.pool_resynced_bound_node_to_new_mesh: %s (expect true)" % [bound_mesh == band0_mesh_after])

	# 8. edit_sphere ("dig") on a previously-collapsed solid brick: must
	# un-collapse it (a collapsed brick has no density array to mutate)
	# and produce real cavity geometry once regenerated.
	var dig_world := VoxelWorld4D.new(WORLD_ORIGIN, STEP, Callable(self, "_sphere_density"))
	var dig_brick := dig_world.get_or_create_brick(Vector4i(0, 0, 0, 0))
	print("8a.dig_target_starts_collapsed_solid: %s (expect true)" % [dig_brick.is_collapsed])
	# radius=0.6, not 0.3: at STEP=0.5 the center (0.75,...) sits exactly
	# equidistant (0.5) from its nearest grid neighbors in every
	# direction - a radius under 0.5 catches zero grid points and edits
	# nothing (a real trap for a first draft of this test, not a code
	# bug: it silently produced a "successful" no-op edit).
	dig_world.edit_sphere(Vector4(0.75, 0.75, 0.75, 0.75), 0.6, func(_old_d: float, _dist: float) -> float: return 5.0)
	var dig_brick_after := dig_world.get_brick(Vector4i(0, 0, 0, 0))
	print("8b.dig_uncollapsed_the_brick: %s (expect false)" % [dig_brick_after.is_collapsed])
	print("8c.dig_produced_cavity_mesh: %d (expect > 0)" % [_tet_count(dig_brick_after.cached_mesh)])

	# 9. Dirty propagation crosses the brick boundary: editing exactly at
	# brick_a/brick_b's shared face must regenerate BOTH bricks (this is
	# the bug the design review caught in a naive face-adjacency-only
	# neighbor enumeration - AABB overlap against ACTUAL bounds is what
	# catches it correctly), and ownership filtering must still hold with
	# no duplicate/leaking geometry after the edit.
	var version_a_before := brick_a.mesh_version
	var version_b_before := brick_b.mesh_version
	world_a.edit_sphere(Vector4(4.5, 2.25, 2.25, 2.25), 0.2, func(_old_d: float, _dist: float) -> float: return 5.0)
	print("9a.edit_at_shared_boundary_regenerated_brick_a: %s (expect true)" % [brick_a.mesh_version != version_a_before])
	print("9b.edit_at_shared_boundary_regenerated_brick_b: %s (expect true)" % [brick_b.mesh_version != version_b_before])
	print("9c.post_edit_brick_a_centroids_still_owned: %s (expect true)" % [_all_mesh_centroids_in_bounds(brick_a.cached_mesh, nominal_a.min, nominal_a.max)])
	print("9d.post_edit_brick_b_centroids_still_owned: %s (expect true)" % [_all_mesh_centroids_in_bounds(brick_b.cached_mesh, nominal_b.min, nominal_b.max)])
	print("9e.post_edit_no_leak_a_into_b: %s (expect true)" % [_no_mesh_centroids_in_bounds(brick_a.cached_mesh, nominal_b.min, nominal_b.max)])
	print("9f.post_edit_no_leak_b_into_a: %s (expect true)" % [_no_mesh_centroids_in_bounds(brick_b.cached_mesh, nominal_a.min, nominal_a.max)])

	# 10. edit_box is genuinely box-shaped, not a relabeled sphere: a grid
	# point that lies inside the box but OUTSIDE a same-half-extent sphere
	# must still get edited, while a point outside the box entirely must
	# not.
	var box_world := VoxelWorld4D.new(WORLD_ORIGIN, STEP, Callable(self, "_sphere_density"))
	var box_center := Vector4(1.0, 1.0, 1.0, 1.0)
	var box_half_extent := Vector4(0.9, 0.9, 0.9, 0.9)
	box_world.edit_box(box_center, box_half_extent, func(_old_d: float, _pos: Vector4) -> float: return 5.0)
	var box_brick := box_world.get_brick(Vector4i(0, 0, 0, 0))
	var box_density_fn := box_brick.stored_density_fn(WORLD_ORIGIN, STEP)
	var inside_box_outside_sphere := Vector4(0.5, 0.5, 0.5, 0.5)  # distance 1.0 from center > half_extent 0.9, but within box bounds on every axis
	var outside_box_point := Vector4(0.0, 0.0, 0.0, 0.0)  # x=0.0 < box min 0.1
	print("10a.box_edited_a_point_a_same_radius_sphere_would_have_missed: %s (expect true)" % [is_equal_approx(box_density_fn.call(inside_box_outside_sphere), 5.0)])
	print("10b.box_left_a_point_outside_it_untouched: %s (expect true)" % [not is_equal_approx(box_density_fn.call(outside_box_point), 5.0)])

	# 11. process_regeneration_async() must converge to the SAME result as
	# the synchronous path for identical input - the load-bearing
	# correctness claim for threading. A single deterministic test run
	# can't prove the absence of races; this checks the async CONTRACT
	# (dispatch -> poll -> finalize -> matches sync) end to end instead.
	var sync_reference_world := VoxelWorld4D.new(WORLD_ORIGIN, STEP, Callable(self, "_sphere_density"))
	var sync_ref_brick_a := sync_reference_world.get_or_create_brick(Vector4i(2, 1, 1, 1))
	var sync_ref_brick_b := sync_reference_world.get_or_create_brick(Vector4i(3, 1, 1, 1))
	sync_reference_world.regenerate_dirty_bricks()

	var async_world := VoxelWorld4D.new(WORLD_ORIGIN, STEP, Callable(self, "_sphere_density"))
	var async_brick_a := async_world.get_or_create_brick(Vector4i(2, 1, 1, 1))
	var async_brick_b := async_world.get_or_create_brick(Vector4i(3, 1, 1, 1))
	print("11a.no_pending_tasks_before_first_dispatch: %s (expect true)" % [not async_world.has_pending_regen_tasks()])
	var async_iterations := 0
	async_world.process_regeneration_async()
	while async_world.has_pending_regen_tasks() and async_iterations < 2000:
		OS.delay_msec(1)
		async_world.process_regeneration_async()
		async_iterations += 1
	print("11b.async_regen_converged_within_timeout: %s (expect true)" % [not async_world.has_pending_regen_tasks()])
	print("11c.async_brick_a_tet_count_matches_sync_reference: %d (expect == %d)" % [_tet_count(async_brick_a.cached_mesh), _tet_count(sync_ref_brick_a.cached_mesh)])
	print("11d.async_brick_b_tet_count_matches_sync_reference: %d (expect == %d)" % [_tet_count(async_brick_b.cached_mesh), _tet_count(sync_ref_brick_b.cached_mesh)])
	var nominal_async_a: Dictionary = VoxelBrick4D.nominal_bounds(async_brick_a.brick_coord, WORLD_ORIGIN, STEP)
	var nominal_async_b: Dictionary = VoxelBrick4D.nominal_bounds(async_brick_b.brick_coord, WORLD_ORIGIN, STEP)
	print("11e.async_brick_a_ownership_still_holds: %s (expect true)" % [_all_mesh_centroids_in_bounds(async_brick_a.cached_mesh, nominal_async_a.min, nominal_async_a.max)])
	print("11f.async_brick_b_ownership_still_holds: %s (expect true)" % [_all_mesh_centroids_in_bounds(async_brick_b.cached_mesh, nominal_async_b.min, nominal_async_b.max)])

	# 12. edit_sphere(..., sync=false) must return immediately without
	# regenerating anything - the caller has to drive
	# process_regeneration_async() itself to see the change land.
	var async_edit_world := VoxelWorld4D.new(WORLD_ORIGIN, STEP, Callable(self, "_sphere_density"))
	var async_edit_brick := async_edit_world.get_or_create_brick(Vector4i(0, 0, 0, 0))
	print("12a.async_edit_target_starts_collapsed: %s (expect true)" % [async_edit_brick.is_collapsed])
	async_edit_world.edit_sphere(Vector4(0.75, 0.75, 0.75, 0.75), 0.6, func(_old_d: float, _dist: float) -> float: return 5.0, false)
	print("12b.async_edit_call_deferred_regen_entirely: %s (expect true - sync=false marks dirty and returns; nothing is dispatched until the caller drives process_regeneration_async() itself)" % [not async_edit_world.has_pending_regen_tasks()])
	var async_edit_brick_ref := async_edit_world.get_brick(Vector4i(0, 0, 0, 0))
	var async_edit_iterations := 0
	async_edit_world.process_regeneration_async()
	while async_edit_world.has_pending_regen_tasks() and async_edit_iterations < 2000:
		OS.delay_msec(1)
		async_edit_world.process_regeneration_async()
		async_edit_iterations += 1
	print("12c.async_edit_eventually_converged: %s (expect true)" % [not async_edit_world.has_pending_regen_tasks()])
	print("12d.async_edit_uncollapsed_and_produced_cavity: %d (expect > 0)" % [_tet_count(async_edit_brick_ref.cached_mesh)])

	print("DONE")
	get_tree().quit()
