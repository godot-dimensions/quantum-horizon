extends Node
## TEMPORARY - performance monitor for the shrubbery forest scene.
## Ramps tree_count up gradually (NOT straight to 30, which measured a
## crash - likely a GPU driver timeout/TDR from submitting ~20M
## tetrahedra in one frame, since this engine's cross-section renderer
## vertex-shades every tetrahedron every frame regardless of visibility -
## instance_set_ignore_culling(true), confirmed elsewhere this session)
## rather than assuming any particular count is safe. Logs real frame
## time/FPS to the console after each regenerate, so this is readable
## directly rather than needing someone to watch an on-screen HUD number.

const TREE_COUNTS := [30]
const MEASURE_FRAMES := 90


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var forest: Node4D = scene.get_node("FlatPlane/ShrubberyForestRoot")

	for tree_count in TREE_COUNTS:
		forest.tree_count = tree_count
		var gen_start := Time.get_ticks_usec()
		forest.regenerate()
		var gen_elapsed: float = (Time.get_ticks_usec() - gen_start) / 1_000_000.0

		# Let a few frames pass before measuring, so the very first
		# (often-slower, shader/pipeline-warmup) frames don't skew the
		# steady-state reading.
		for i in range(5):
			await get_tree().process_frame

		var frame_times: PackedFloat64Array = PackedFloat64Array()
		frame_times.resize(MEASURE_FRAMES)
		var last_usec := Time.get_ticks_usec()
		for i in range(MEASURE_FRAMES):
			await get_tree().process_frame
			var now_usec := Time.get_ticks_usec()
			frame_times[i] = (now_usec - last_usec) / 1000.0 # ms
			last_usec = now_usec

		var total_ms := 0.0
		var max_ms := 0.0
		var min_ms := INF
		for t in frame_times:
			total_ms += t
			max_ms = maxf(max_ms, t)
			min_ms = minf(min_ms, t)
		var avg_ms: float = total_ms / frame_times.size()
		var avg_fps: float = 1000.0 / avg_ms if avg_ms > 0.0 else 0.0

		print("=== tree_count=%d total_tets=%d gen_elapsed=%.2fs ===" % [tree_count, forest.last_tet_count, gen_elapsed])
		print("frame_time_ms: avg=%.2f min=%.2f max=%.2f -> avg_fps=%.1f" % [avg_ms, min_ms, max_ms, avg_fps])

	print("DONE")
	get_tree().quit()
