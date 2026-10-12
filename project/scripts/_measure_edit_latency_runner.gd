extends Node
## TEMPORARY - measures REAL set_density_region edit latency against the
## actual running hash+brick system (VoxelWorld4D + TerrainChunkPool4D),
## not estimated from the design doc. Fires real edit_sphere() calls with
## sync=false (the real "never blocks a frame" async path a live game
## would use - see VoxelWorld4D.set_density_region's own doc comment),
## drives process_regeneration_async()/chunk_pool.update() every frame
## exactly like a live game loop would, and times from the edit CALL to
## every affected brick's regenerated mesh actually swapping into the
## chunk pool - using the mesh_version-based "actually visible" signal
## established in _measure_live_popin_latency_runner.gd (pool-membership
## alone doesn't mean a new mesh is showing - see that script's comment
## on TerrainChunkPool4D.update() binding a brick before its mesh exists).
##
## Builds VoxelWorld4D/TerrainChunkPool4D directly (not via the full
## showcase scene) so the edit call site and its drive loop are fully
## visible here, matching the showcase's own construction pattern
## (terrain4d_voxel_showcase.gd's _ready()).

const HORIZONTAL_RADIUS := 3
const VERTICAL_RADIUS := 1
const W_RADIUS := 1
const STEP_SIZE := 0.75
const NOISE_SEED := 1
const NOISE_FREQUENCY := 0.06
const NOISE_AMPLITUDE := 6.0
const NOISE_PERSISTENCE := 0.55
const GROUND_LEVEL := 0.0
const MAX_SETTLE_FRAMES := 3000
const MAX_EDIT_WAIT_FRAMES := 3000

func _ready() -> void:
	await _run()

## Matches terrain4d_voxel_showcase.gd's own _density() exactly - the real
## native Math4D.noise_4d() binding already integrated into production, not
## the old hand-rolled GDScript Noise4D this script originally (wrongly)
## used, which was ~53x slower per call and made this measurement take
## many minutes for no reason relevant to what's being measured here
## (edit/regen latency, not noise cost).
func _density(p: Vector4) -> float:
	var total := 0.0
	var amplitude := 1.0
	var frequency := NOISE_FREQUENCY
	var max_value := 0.0
	for i in range(3):
		total += Math4D.noise_4d(NOISE_SEED, p.x * frequency, 0.0, p.z * frequency, p.w * frequency) * amplitude
		max_value += amplitude
		amplitude *= NOISE_PERSISTENCE
		frequency *= 2.0
	var height := GROUND_LEVEL + NOISE_AMPLITUDE * (total / max_value)
	return p.y - height

func _run() -> void:
	var step := Vector4(STEP_SIZE, STEP_SIZE, STEP_SIZE, STEP_SIZE)
	var world := VoxelWorld4D.new(Vector4.ZERO, step, Callable(self, "_density"))
	var pool := TerrainChunkPool4D.new()
	add_child(pool)
	pool.world = world
	pool.max_render_distance = 100000.0

	var cell_size := (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * STEP_SIZE
	var half_cell := 0.5 * cell_size
	pool.viewer_position = Vector4(half_cell, GROUND_LEVEL + half_cell, half_cell, half_cell)

	for bx in range(-HORIZONTAL_RADIUS, HORIZONTAL_RADIUS + 1):
		for by in range(-VERTICAL_RADIUS, VERTICAL_RADIUS + 1):
			for bz in range(-HORIZONTAL_RADIUS, HORIZONTAL_RADIUS + 1):
				for bw in range(-W_RADIUS, W_RADIUS + 1):
					world.get_or_create_brick(Vector4i(bx, by, bz, bw))

	var frames := 0
	while frames < MAX_SETTLE_FRAMES:
		world.process_regeneration_async()
		pool.update()
		if not world.has_pending_regen_tasks():
			break
		await get_tree().process_frame
		frames += 1
	for i in range(10):
		world.process_regeneration_async()
		pool.update()
		await get_tree().process_frame

	print("--- world settled after %d frames: dense=%d visible=%d ---" % [frames, world.dense_brick_count(), pool.visible_brick_count()])

	# Three cases: a small and a medium edit well inside a single brick's
	# nominal core, and one deliberately centered ON a shared brick
	# boundary (x = N * cell_size is exactly the seam between brick N-1
	# and brick N) - the more expensive case, since it dirties multiple
	# bricks (and, via apron-overlap, potentially their further neighbors
	# too - see set_density_region's own doc comment on this).
	var interior_center := Vector4(half_cell, GROUND_LEVEL + half_cell, half_cell, half_cell)
	var boundary_center := Vector4(cell_size, GROUND_LEVEL + half_cell, half_cell, half_cell)
	var cases := [
		{"name": "small_sphere_brick_interior", "center": interior_center, "radius": 0.3},
		{"name": "medium_sphere_brick_interior", "center": interior_center, "radius": 1.2},
		{"name": "boundary_straddling_sphere", "center": boundary_center, "radius": 0.5},
	]

	for c in cases:
		await _measure_one_edit(world, pool, c.name, c.center, c.radius)

	print("DONE")
	get_tree().quit()

## Always carves air (a large positive density) unconditionally within the
## sphere - guarantees a real solid->air flip (and therefore a real
## re-mesh) wherever the dug region was previously solid, rather than
## risking a no-op edit that happens to match the existing sign.
func _carve_air(_old_density: float, _dist: float) -> float:
	return 5.0

func _measure_one_edit(world: VoxelWorld4D, pool: TerrainChunkPool4D, name: String, center: Vector4, radius: float) -> void:
	var pre_versions := {}
	for brick in pool.visible_bricks():
		pre_versions[VoxelWorld4D.brick_key(brick.brick_coord)] = brick.mesh_version

	var t0 := Time.get_ticks_usec()
	world.edit_sphere(center, radius, Callable(self, "_carve_air"), false)
	# The exact set of bricks this edit just dirtied - read directly from
	# VoxelWorld4D's own bookkeeping right after the call (before any
	# regen has run) rather than re-deriving the apron-overlap AABB math
	# independently, so this measurement can't silently drift from what
	# the edit actually touched.
	var affected_keys: Array = world._dirty_brick_keys.keys()
	print("%s: center=%s radius=%.2f affected_bricks=%d" % [name, center, radius, affected_keys.size()])

	var per_brick_done_usec := {}
	var per_brick_timing := {}  # key -> brick.last_regen_timing_usec snapshot at the moment it completed
	var frames := 0
	while frames < MAX_EDIT_WAIT_FRAMES:
		world.process_regeneration_async()
		pool.update()
		var now := Time.get_ticks_usec()
		for key in affected_keys:
			if per_brick_done_usec.has(key):
				continue
			if pool._bound_version.get(key, -1) != pre_versions.get(key, -1):
				per_brick_done_usec[key] = now
				per_brick_timing[key] = world._bricks[key].last_regen_timing_usec
		if per_brick_done_usec.size() == affected_keys.size():
			break
		await get_tree().process_frame
		frames += 1

	if per_brick_done_usec.size() < affected_keys.size():
		print("  NOTE: only %d/%d affected bricks swapped in a new mesh within %d frames" % [
			per_brick_done_usec.size(), affected_keys.size(), MAX_EDIT_WAIT_FRAMES
		])

	var latencies := []
	for key in per_brick_done_usec:
		latencies.append(per_brick_done_usec[key] - t0)
	latencies.sort()
	if latencies.is_empty():
		print("  no completions observed")
		return
	var total := 0
	for v in latencies:
		total += v
	var mean_usec := float(total) / float(latencies.size())
	print("  edit_latency_usec (call -> new mesh visible in pool): fastest_brick=%d slowest_brick=%d mean=%.1f (n=%d, waited %d frames)" % [
		latencies[0], latencies[latencies.size() - 1], mean_usec, latencies.size(), frames
	])

	# Aggregate (summed across every affected brick) per-stage breakdown -
	# race-free (see last_regen_timing_usec's own comment): phase1/2/3 come
	# back thread-locally from each WorkerThreadPool job's own return
	# value, and mesh_build is timed on the single finalize-calling thread,
	# so this is correct even though up to affected_keys.size() jobs ran
	# concurrently. No separate "apron resample" bucket - these bricks were
	# already dense before the edit, so _uncollapse_brick (the only place
	# apron resampling happens) never runs; only brick CREATION resamples
	# an apron, never a regen of an already-dense brick.
	var sum_phase1 := 0
	var sum_phase2 := 0
	var sum_phase3 := 0
	var sum_mesh_build := 0
	for key in per_brick_timing:
		var t: Dictionary = per_brick_timing[key]
		sum_phase1 += int(t.get("phase1_usec", 0))
		sum_phase2 += int(t.get("phase2_usec", 0))
		sum_phase3 += int(t.get("phase3_usec", 0))
		sum_mesh_build += int(t.get("mesh_build_usec", 0))
	var sum_all := sum_phase1 + sum_phase2 + sum_phase3 + sum_mesh_build
	print("  per_stage_aggregate_usec (summed across %d affected bricks, worker-side phase1/2/3 race-free via thread-local return, mesh_build timed on the single finalize thread):" % [per_brick_timing.size()])
	print("    density(stored-lookup)=%d  qef=%d  tet_assembly=%d  mesh+collision_build(serial main-thread)=%d  sum=%d" % [
		sum_phase1, sum_phase2, sum_phase3, sum_mesh_build, sum_all
	])
	if sum_all > 0:
		print("    pct_of_sum: density=%.1f%% qef=%.1f%% tet=%.1f%% mesh_build=%.1f%%" % [
			100.0 * sum_phase1 / sum_all, 100.0 * sum_phase2 / sum_all, 100.0 * sum_phase3 / sum_all, 100.0 * sum_mesh_build / sum_all
		])
	print("    mesh_build_sum_vs_total_wall_latency_pct=%.1f%% (how much of the observed slowest-brick wall-clock latency the serial main-thread finalize step alone accounts for, summed across all affected bricks)" % [
		(100.0 * sum_mesh_build / float(latencies[latencies.size() - 1])) if latencies[latencies.size() - 1] > 0 else 0.0
	])
