extends Node
## TEMPORARY - measures steady-state FPS: a fully-populated, IDLE world (no
## active generation/edits in flight), camera moving/looking around
## normally, sustained frame-time distribution. This is the actual headroom
## number for future physics/lighting/occlusion work - it didn't exist
## before this script.
##
## Runs WINDOWED, not headless: headless mode uses RendererDummy (a no-op
## renderer - see the "Parameter t is null" / RendererDummy::TextureStorage
## error every _verify_*_runner.gd screenshot step in this project already
## hits), so a headless FPS number would only measure engine-loop overhead,
## never real GPU/CPU render cost. A steady-state FPS number is meaningless
## without the real renderer doing real work.
##
## Drives the REAL left-click-drag camera-orbit input path via
## Input.parse_input_event() - the same proven pattern
## _verify_terrain4d_runner.gd's _drag() helper already uses successfully in
## this project - continuously throughout the measurement window, so "camera
## moves and looks around normally" is genuine input-driven motion through
## the actual camera script, not a bypass of it.
##
## Instances the REAL terrain4d_voxel_showcase.tscn (not a reimplemented
## copy), same override-exports-before-add_child() pattern as
## _measure_live_popin_latency_runner.gd.

const SHOWCASE_SCENE_PATH := "res://sandbox/terrain4d/terrain4d_voxel_showcase.tscn"
const HORIZONTAL_RADIUS := 5
const VERTICAL_RADIUS := 1
const W_RADIUS := 1
const SETTLE_TIMEOUT_FRAMES := 3000
const SETTLE_GRACE_FRAMES := 20
const MEASUREMENT_FRAMES := 600

func _ready() -> void:
	# The mean/p50 in the first run of this script landed suspiciously
	## exactly on 16.67ms (60.0 fps) - that's vsync capping the frame rate,
	## not a real measurement of engine-side cost. Disable it so this
	## reports true uncapped headroom, not "however fast the display
	## happens to refresh."
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _run()

func _run() -> void:
	var packed: PackedScene = load(SHOWCASE_SCENE_PATH)
	var root: Node = packed.instantiate()
	var showcase: Node4D = root.get_node("World/TerrainRig/VoxelShowcase")
	showcase.horizontal_brick_radius = HORIZONTAL_RADIUS
	showcase.vertical_brick_radius = VERTICAL_RADIUS
	showcase.w_brick_radius = W_RADIUS
	add_child(root)  # _ready() fires here, using the overridden radii above

	var world: VoxelWorld4D = showcase.world
	var frames := 0
	while frames < SETTLE_TIMEOUT_FRAMES:
		if showcase._population_done_msec >= 0 and not world.has_pending_regen_tasks():
			break
		await get_tree().process_frame
		frames += 1
	for i in range(SETTLE_GRACE_FRAMES):
		await get_tree().process_frame

	print("--- settled after %d frames: dense=%d visible=%d ---" % [
		frames, world.dense_brick_count(), showcase.chunk_pool.visible_brick_count()
	])

	# Hold the left button down for the whole measurement window - matches
	# _verify_terrain4d_runner.gd's _drag() helper's press/motion/release
	# shape, just held continuously instead of released after N steps.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame

	var frame_times_usec: Array = []
	var pending_regen_seen_during_window := false
	var last_time := Time.get_ticks_usec()
	for i in range(MEASUREMENT_FRAMES):
		# Smooth back-and-forth look-around, not a random walk - "looks
		# around normally" rather than a worst-case adversarial motion.
		var t := float(i)
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(sin(t * 0.05) * 6.0, cos(t * 0.033) * 3.0)
		Input.parse_input_event(motion)
		if world.has_pending_regen_tasks():
			pending_regen_seen_during_window = true
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_times_usec.append(now - last_time)
		last_time = now

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

	frame_times_usec.sort()
	var n := frame_times_usec.size()
	var total: int = 0
	for v in frame_times_usec:
		total += v
	var mean_usec: float = float(total) / float(n)
	var p50: int = frame_times_usec[int(n * 0.50)]
	var p90: int = frame_times_usec[mini(int(n * 0.90), n - 1)]
	var p99: int = frame_times_usec[mini(int(n * 0.99), n - 1)]
	var min_v: int = frame_times_usec[0]
	var max_v: int = frame_times_usec[n - 1]

	print("resident_bricks=%d visible_bricks=%d visible_tets=%d" % [
		world.get_all_bricks().size(), showcase.chunk_pool.visible_brick_count(), _sum_visible_tets(showcase.chunk_pool)
	])
	print("steady_state_frame_time_usec: min=%d p50=%d mean=%.1f p90=%d p99=%d max=%d" % [min_v, p50, mean_usec, p90, p99, max_v])
	print("steady_state_fps: mean=%.1f median=%.1f p90_frametime_fps=%.1f p99_frametime_fps=%.1f worst_frame_fps=%.1f" % [
		1000000.0 / mean_usec, 1000000.0 / float(p50), 1000000.0 / float(p90), 1000000.0 / float(p99), 1000000.0 / float(max_v)
	])
	print("regen_activity_during_window: %s (expect false - confirms this measured a genuinely idle steady state, not generation/meshing catch-up)" % [pending_regen_seen_during_window])
	print("DONE")
	get_tree().quit()

func _sum_visible_tets(chunk_pool: TerrainChunkPool4D) -> int:
	var total := 0
	for brick in chunk_pool.visible_bricks():
		if brick.cached_mesh != null:
			total += brick.cached_mesh.get_simplex_cell_vertex_indices().size() / 4
	return total
