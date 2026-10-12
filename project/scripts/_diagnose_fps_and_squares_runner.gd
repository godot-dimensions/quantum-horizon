extends Node
## TEMPORARY diagnostic - two specific checks, not open-ended investigation.
##
## 1. FPS regression: confirms the per-band coloring pass increased
##    MeshInstance4D/draw-call count per resident brick (3x, one per
##    TerrainColorBands.BAND_COUNT, replacing the pre-banding single "Mesh"
##    child), and measures FPS with the CURRENT (3-mesh-per-brick) state vs
##    a live-swapped 1-mesh-per-brick state (every visible pooled node's
##    Mesh_0 set to brick.cached_mesh, Mesh_1/Mesh_2 hidden) - a genuine
##    controlled A/B in the SAME scene/viewpoint, to confirm draw-call count
##    (not band-bucketing CPU cost or something else) is actually the
##    bottleneck before proposing any fix.
## 2. Floating gray squares: forces every resident dense brick to fully
##    regenerate its mesh/collision from scratch right now (mark dirty +
##    regenerate_dirty_bricks(), not just re-render whatever's already
##    resident) and takes a wide overview screenshot to scan for them.
## Not part of the shipped scene.

@onready var showcase: Node4D = $"../Scene/World/TerrainRig/VoxelShowcase"

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)
	print("SCREENSHOT_SAVED: %s" % [image_name])

## Averages Engine.get_frames_per_second() over `frame_count` real frames -
## a single-frame reading is noisy, this is a stable measurement.
func _measure_avg_fps(frame_count: int) -> float:
	var total := 0.0
	for i in range(frame_count):
		await get_tree().process_frame
		total += Engine.get_frames_per_second()
	return total / float(frame_count)

func _ready() -> void:
	await _wait_frames(3)
	await _run()

func _run() -> void:
	var waited_frames := 0
	while (showcase._settled_msec < 0 or not showcase._creatures_spawned) and waited_frames < 1800:
		await get_tree().process_frame
		waited_frames += 1
	print("0.settled_and_spawned_before_timeout: %s waited_frames=%d" % [showcase._settled_msec >= 0 and showcase._creatures_spawned, waited_frames])

	var world: VoxelWorld4D = showcase.world
	var chunk_pool: TerrainChunkPool4D = showcase.chunk_pool

	# --- Part 1a: confirm the node/draw-call count per brick directly, by
	# inspecting one bound pooled node's actual children right now.
	var bound: Dictionary = chunk_pool._bound
	if not bound.is_empty():
		var sample_key = bound.keys()[0]
		var sample_body: StaticBody4D = bound[sample_key]
		var mesh_instance_count := 0
		for child in sample_body.get_children():
			if child is MeshInstance4D:
				mesh_instance_count += 1
		print("1a.mesh_instance_children_per_bound_brick_node: %d (TerrainColorBands.BAND_COUNT=%d - pre-banding this was 1)" % [mesh_instance_count, TerrainColorBands.BAND_COUNT])
	print("1b.visible_bricks_now: %d" % [chunk_pool.visible_brick_count()])

	# --- Part 1b: measure FPS with the CURRENT (3-mesh-per-brick) state.
	await _wait_frames(10)  # let any transient loading/settling noise clear
	var fps_current: float = await _measure_avg_fps(60)
	print("1c.avg_fps_CURRENT_3_mesh_per_brick: %.2f" % [fps_current])

	# --- Part 1c: live-swap every visible pooled node to 1 mesh per brick
	# (cached_mesh, no color material needed for this specific A/B - only
	# testing whether draw-call/node count itself is the bottleneck) and
	# re-measure FPS at the exact same viewpoint.
	var bound_brick: Dictionary = chunk_pool._bound_brick
	for key in bound:
		var body: StaticBody4D = bound[key]
		var brick: VoxelBrick4D = bound_brick[key]
		(body.get_node("Mesh_0") as MeshInstance4D).mesh = brick.cached_mesh
		(body.get_node("Mesh_1") as MeshInstance4D).mesh = null
		(body.get_node("Mesh_2") as MeshInstance4D).mesh = null
	await _wait_frames(10)
	var fps_single_mesh: float = await _measure_avg_fps(60)
	print("1d.avg_fps_EXPERIMENTAL_1_mesh_per_brick: %.2f" % [fps_single_mesh])
	print("1e.fps_delta: %.2f (%.1f%% change)" % [fps_single_mesh - fps_current, 100.0 * (fps_single_mesh - fps_current) / fps_current])

	# Restore the 3-mesh-per-brick state (re-sync from the pool's own
	# tracked version so subsequent screenshots reflect the REAL shipped
	# state, not this experiment's leftover swap).
	for key in bound:
		var body: StaticBody4D = bound[key]
		var brick: VoxelBrick4D = bound_brick[key]
		for band in range(TerrainColorBands.BAND_COUNT):
			var mi := body.get_node("Mesh_%d" % [band]) as MeshInstance4D
			mi.mesh = brick.cached_band_meshes[band] if band < brick.cached_band_meshes.size() else null

	# --- Part 2: force every resident dense brick to fully regenerate its
	# mesh/collision from scratch right now, not just re-render whatever
	# was already resident from initial population.
	var dense_bricks: Array = world.get_dense_bricks()
	for brick in dense_bricks:
		var b4: VoxelBrick4D = brick
		world.mark_brick_dirty(b4.brick_coord)
	print("2a.dense_bricks_marked_dirty_for_forced_regen: %d" % [dense_bricks.size()])
	world.regenerate_dirty_bricks()
	print("2b.regenerate_dirty_bricks_completed")
	# Bump the render distance and re-sync so the wide overview below
	# actually reflects the freshly-regenerated meshes, not stale pooled
	# node bindings.
	chunk_pool.update()

	# Wide overview screenshot - zoom the existing orbit camera way out
	# from its current framing (already centered on the populated volume
	# at scene start) to scan as much of the terrain as possible for
	# floating gray squares in one shot.
	var camera: Camera4D = showcase.camera
	camera.radius = 40.0
	camera._apply_orbit()
	await _wait_frames(3)
	await _screenshot("fps_and_squares_wide_overview.png")

	print("DONE")
	get_tree().quit()
