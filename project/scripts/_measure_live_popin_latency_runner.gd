extends Node
## TEMPORARY - measures REAL end-to-end pop-in latency in the actual live
## showcase scene (post native-noise swap), not the synchronous
## benchmark: decision-to-generate (first frame a brick is seen
## non-collapsed) to actually-visible (first frame it's bound in
## TerrainChunkPool4D), spanning the full live pipeline - synchronous
## collapse-check/apron-sampling, the threaded WorkerThreadPool regen job,
## and the once-a-frame chunk-pool bind step. Frame-resolution timing
## (~16ms buckets), which is the right granularity for a perceived pop-in
## number, not a micro-benchmark. Delete this file once the number is
## captured.
##
## Instances the REAL terrain4d_voxel_showcase.tscn (not a reimplemented
## copy) and overrides its brick-radius exports BEFORE add_child() (i.e.
## before its own _ready() runs), at the same h=3/5/7 sweep sizes already
## established elsewhere this session.

const SWEEP_HORIZONTAL_RADII := [3, 5, 7]
const VERTICAL_RADIUS := 1
const W_RADIUS := 1
const MAX_WAIT_FRAMES := 3000
const SETTLE_GRACE_FRAMES := 10  # extra frames after settling, so the last-meshed bricks' chunk-pool bind is captured too

const SHOWCASE_SCENE_PATH := "res://sandbox/terrain4d/terrain4d_voxel_showcase.tscn"

func _ready() -> void:
	await _run()

func _run() -> void:
	for h in SWEEP_HORIZONTAL_RADII:
		await _measure_one_size(h)
	print("DONE")
	get_tree().quit()

func _measure_one_size(h: int) -> void:
	var packed: PackedScene = load(SHOWCASE_SCENE_PATH)
	var root: Node = packed.instantiate()
	var showcase: Node4D = root.get_node("World/TerrainRig/VoxelShowcase")
	showcase.horizontal_brick_radius = h
	showcase.vertical_brick_radius = VERTICAL_RADIUS
	showcase.w_brick_radius = W_RADIUS
	add_child(root)  # _ready() fires here, using the overridden radii above

	var seen_dense := {}  # brick key -> first-seen-non-collapsed msec
	var seen_visible := {}  # brick key -> first-seen-in-chunk-pool msec
	var world: VoxelWorld4D = showcase.world
	var chunk_pool: TerrainChunkPool4D = showcase.chunk_pool

	var frames := 0
	var settled_at_frame := -1
	while frames < MAX_WAIT_FRAMES:
		var now := Time.get_ticks_usec()
		for brick in world.get_all_bricks():
			if brick.is_collapsed:
				continue
			var key := VoxelWorld4D.brick_key(brick.brick_coord)
			if not seen_dense.has(key):
				seen_dense[key] = now
		for brick in chunk_pool.visible_bricks():
			# chunk_pool.update() binds a dense brick into the pool the
			# INSTANT it's dense and in range - before its mesh exists
			# (_sync_node sets mesh_instance.mesh = brick.cached_mesh, which
			# is still null at bind time). So "in visible_bricks()" means
			# "pool-bound", not "actually has a rendered mesh" - that's why
			# the first pass of this measurement returned exactly 0 for
			# every single sample. brick.mesh_version only increments once
			# _build_brick_mesh() actually runs (regen complete), so gate on
			# that too - this is the real "something is now visible on
			# screen" signal.
			if brick.mesh_version <= 0:
				continue
			var key := VoxelWorld4D.brick_key(brick.brick_coord)
			if not seen_visible.has(key):
				seen_visible[key] = now

		if settled_at_frame < 0 and showcase._population_done_msec >= 0 and not world.has_pending_regen_tasks():
			settled_at_frame = frames
		if settled_at_frame >= 0 and frames >= settled_at_frame + SETTLE_GRACE_FRAMES:
			break

		await get_tree().process_frame
		frames += 1

	var latencies := []
	for key in seen_dense:
		if seen_visible.has(key):
			latencies.append(seen_visible[key] - seen_dense[key])
	latencies.sort()

	var dense_count := world.dense_brick_count()
	var visible_count := chunk_pool.visible_brick_count()

	print("--- h=%d v=%d w=%d (waited %d frames) ---" % [h, VERTICAL_RADIUS, W_RADIUS, frames])
	print("dense_brick_count=%d visible_brick_count=%d matched_latency_samples=%d" % [dense_count, visible_count, latencies.size()])
	if dense_count != visible_count:
		print("NOTE: dense_count != visible_count - some dense bricks never became visible in this run (check max_render_distance/timeout), latency stats below only cover the %d that matched" % [latencies.size()])
	if latencies.is_empty():
		print("no matched latency samples")
	else:
		var total := 0
		for v in latencies:
			total += v
		var mean := float(total) / float(latencies.size())
		var p50 = latencies[int(latencies.size() * 0.50)]
		var p90 = latencies[mini(int(latencies.size() * 0.90), latencies.size() - 1)]
		print("pop_in_latency_usec: min=%d p50=%d mean=%.1f p90=%d max=%d" % [latencies[0], p50, mean, p90, latencies[latencies.size() - 1]])

	root.queue_free()
	await get_tree().process_frame
