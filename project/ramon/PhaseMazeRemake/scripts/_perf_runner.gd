extends SceneTree

## What the maze costs (PLAN.md steps 10 and 76), windowed with vsync off: the median and 95th percentile
## frame, the script and physics time, and the GPU time, for the lobby and for every level level, turned
## into W, with 4D sight, and in first person. Also how long a level takes to build. Never measured in a
## frame that saves a screenshot (headless_frame_pacing: a screenshot stalls its own frame).
##   run.sh windowed perf res://ramon/PhaseMazeRemake/scripts/_perf_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"

var _t0: int = 0
var _m: Node4D
var _worst: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 180000:
		print("PERF: gave up after 180 s")
		return true
	return false


func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b: Array = a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _p95(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b: Array = a.duplicate()
	b.sort()
	return float(b[mini(b.size() - 1, int(b.size() * 0.95))])


func _measure(what: String, seconds: float = 1.5) -> void:
	for i in 20:
		await process_frame
	var frames: Array = []
	var scripts: Array = []
	var physics: Array = []
	var gpu: Array = []
	var vp: RID = root.get_viewport_rid()
	var end: int = Time.get_ticks_usec() + int(seconds * 1000000.0)
	var last: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() < end:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append(float(now - last) / 1000.0)
		last = now
		scripts.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	var f: float = _median(frames)
	_worst = maxf(_worst, f)
	print("PERF: %-28s frame %.2f ms (p95 %.2f)  process %.2f  physics %.2f  GPU %.2f ms" % [what, f, _p95(frames), _median(scripts), _median(physics), _median(gpu)])


func _run() -> void:
	var t: int = Time.get_ticks_usec()
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	await process_frame
	print("PERF: scene opened in %.0f ms" % [(Time.get_ticks_usec() - t) / 1000.0])
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for i in 20:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_m.set_process_unhandled_input(false)
	var player: Node4D = _m.get("player")
	player.set("input_enabled", false)
	var view: Node = _m.get("view")
	view.set("keys_on", false)
	await _measure("lobby")
	for i in 6:
		t = Time.get_ticks_usec()
		_m.call("_load_level", i)
		var build_ms: float = (Time.get_ticks_usec() - t) / 1000.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.set("input_enabled", false)
		print("PERF: level %d built in %.1f ms" % [i + 1, build_ms])
		await _measure("level %d level view" % (i + 1))
		view.call("quarter_turn")
		for k in 40:
			await process_frame
		await _measure("level %d turned into W" % (i + 1))
		view.call("quarter_turn")
		for k in 40:
			await process_frame
		(_m.get("sight") as Node).call("set_on", true)
		await _measure("level %d 4D sight" % (i + 1))
		(_m.get("sight") as Node).call("set_on", false)
		view.call("set_mode", "first")
		await _measure("level %d first person" % (i + 1))
		view.call("set_mode", "chase")
	print("PERF: worst median frame %.2f ms" % _worst)
	print("PERF: done")
	quit()
