extends Node
## TEMPORARY diagnostic - ONE thing: direct measurement of frame time vs.
## visible tet count, to test the hypothesis that GPU vertex-shader cost
## scaling with total tet count (every tet emits 6 vertices to the
## Cross-section shader every frame, regardless of mesh-instance/draw-call
## count - see tetra_cross_section_shader.glsl) is the actual FPS
## bottleneck, now that draw-call count and background regen have both
## been directly measured and ruled out.
##
## Method: sweep chunk_pool.max_render_distance across several values in
## the SAME live, confirmed-idle scene (no edits, no regen, no camera
## move - only the render-distance cull threshold changes, which changes
## visible tet count without changing anything else), measuring avg FPS
## and the resulting visible tet count at each step. If frame TIME (not
## FPS) scales roughly linearly with visible tet count, that's direct
## evidence of a per-tet GPU cost dominating; if FPS stays roughly flat
## regardless of tet count, the bottleneck is elsewhere (fixed per-frame
## cost, unrelated to how much terrain is actually in view).
## Not part of the shipped scene.

@onready var showcase: Node4D = $"../Scene/World/TerrainRig/VoxelShowcase"

const RENDER_DISTANCES := [6.0, 12.0, 20.0, 30.0, 45.0]
const MEASURE_FRAMES := 60

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _count_visible_tets(chunk_pool: TerrainChunkPool4D) -> int:
	var total := 0
	for brick in chunk_pool.visible_bricks():
		var b4: VoxelBrick4D = brick
		if b4.cached_mesh != null:
			total += b4.cached_mesh.simplex_cell_indices.size() / 4
	return total

func _ready() -> void:
	await _wait_frames(3)
	await _run()

func _run() -> void:
	var world: VoxelWorld4D = showcase.world
	var chunk_pool: TerrainChunkPool4D = showcase.chunk_pool

	var waited_frames := 0
	while (showcase._settled_msec < 0 or not showcase._creatures_spawned) and waited_frames < 1800:
		await get_tree().process_frame
		waited_frames += 1
	print("0.settled_and_spawned_before_timeout: %s waited_frames=%d" % [showcase._settled_msec >= 0 and showcase._creatures_spawned, waited_frames])

	# Confirm idle (no pending regen) before starting, same signal as the
	# prior idle-FPS measurement - this sweep must not be confounded by
	# any background regen work.
	var max_pending := 0
	for i in range(30):
		await get_tree().process_frame
		max_pending = maxi(max_pending, world.pending_regen_task_count())
	print("0b.max_pending_regen_tasks_before_sweep: %d (expect 0)" % [max_pending])

	print("1.sweep_results (max_render_distance, visible_bricks, visible_tets, avg_fps, avg_frame_ms, us_per_1000_tets):")
	var results := []
	for dist in RENDER_DISTANCES:
		chunk_pool.max_render_distance = dist
		await _wait_frames(5)  # let the pool re-sync visibility at the new distance
		# Replicate update()'s own candidate_count formula exactly, purely
		# for instrumentation - to see directly which of the two internal
		# paths (bounded range-loop vs. occupied-cell iteration) is
		# actually selected at each distance, not just infer it from FPS.
		var cell_world_size := Vector4(
			TerrainChunkPool4D.COARSE_CELL_BRICKS * (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * world.step.x,
			TerrainChunkPool4D.COARSE_CELL_BRICKS * (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * world.step.y,
			TerrainChunkPool4D.COARSE_CELL_BRICKS * (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * world.step.z,
			TerrainChunkPool4D.COARSE_CELL_BRICKS * (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * world.step.w,
		)
		var vp: Vector4 = chunk_pool.viewer_position
		var lo_x := floori((vp.x - dist - world.world_origin.x) / cell_world_size.x)
		var lo_y := floori((vp.y - dist - world.world_origin.y) / cell_world_size.y)
		var lo_z := floori((vp.z - dist - world.world_origin.z) / cell_world_size.z)
		var lo_w := floori((vp.w - dist - world.world_origin.w) / cell_world_size.w)
		var hi_x := floori((vp.x + dist - world.world_origin.x) / cell_world_size.x)
		var hi_y := floori((vp.y + dist - world.world_origin.y) / cell_world_size.y)
		var hi_z := floori((vp.z + dist - world.world_origin.z) / cell_world_size.z)
		var hi_w := floori((vp.w + dist - world.world_origin.w) / cell_world_size.w)
		var candidate_count: float = float(hi_x - lo_x + 1) * float(hi_y - lo_y + 1) * float(hi_z - lo_z + 1) * float(hi_w - lo_w + 1)
		var occupied_cells: int = chunk_pool._coarse_index.size()
		print("  [instrumentation] dist=%.0f candidate_count=%.0f occupied_cells=%d path=%s" % [
			dist, candidate_count, occupied_cells, "range_loop" if candidate_count <= mini(50000, occupied_cells) else "occupied_iteration"
		])
		var tet_count := _count_visible_tets(chunk_pool)
		var visible_bricks := chunk_pool.visible_brick_count()
		var total_fps := 0.0
		var max_pending_during := 0
		for i in range(MEASURE_FRAMES):
			await get_tree().process_frame
			total_fps += Engine.get_frames_per_second()
			max_pending_during = maxi(max_pending_during, world.pending_regen_task_count())
		var avg_fps: float = total_fps / float(MEASURE_FRAMES)
		var avg_frame_ms: float = 1000.0 / avg_fps if avg_fps > 0.0 else -1.0
		var us_per_1000_tets: float = (avg_frame_ms * 1000.0 / float(tet_count)) * 1000.0 if tet_count > 0 else 0.0
		results.append({"dist": dist, "bricks": visible_bricks, "tets": tet_count, "fps": avg_fps, "frame_ms": avg_frame_ms, "us_per_1000_tets": us_per_1000_tets})
		print("  dist=%.0f  bricks=%d  tets=%d  fps=%.2f  frame_ms=%.2f  us_per_1000_tets=%.1f  max_pending_during=%d" % [
			dist, visible_bricks, tet_count, avg_fps, avg_frame_ms, us_per_1000_tets, max_pending_during
		])

	print("DONE")
	get_tree().quit()
