extends SceneTree

## Frame times per level, at the places that cost most (looking down the longest views), in a window
## with vsync off (memory: time by wall clock with vsync off, never in a frame that saves a picture).
## Each place: the median and worst of 150 frames, wall clock between frames, and the GPU's own time.
##   run.sh windowed perf res://ramon/MazeRemake2/scripts/_perf_runner.gd

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const GB := preload("res://ramon/MazeRemake2/carried/ground_basis_4d.gd")

var _t0: int = 0
var _g: Node
var _p: CharacterBody4D

## [level, name, feet (x, z, w), yaw, turned]
const PLACES := [
	[0, "arrival, down the corridor", Vector4(0, 0, 5.5, 0.0), 0.0, false],
	[0, "corridor, door half open", Vector4(0, 0, -4.0, 0.9), 0.0, false],
	[0, "garden hall, the oak", Vector4(2.0, 0, -11.0, 2.2), 0.6, false],
	[1, "hub, kata", Vector4(0, 0, 2.5, -2.4), 0.0, false],
	[1, "pit landing, ana", Vector4(0, 0, -8.2, 2.4), -1.57, false],
	[1, "archive", Vector4(-5.0, 0, 0, 0.0), 1.57, false],
	[2, "atrium from the lift", Vector4(0, 0, 14.0, 0.0), 0.0, false],
	[2, "turned at the centre", Vector4(0, 0, 2.0, -0.8), 0.0, true],
	[2, "inside the Heart", Vector4(0, 0, 3.0, 3.2), 0.0, true],
]


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 200000:
		print("PERF FAIL: gave up after 200 s")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	_g.set("capture_mouse", false)
	root.add_child(_g)
	_p = _g.get("player")
	for i in 600:
		if String(_g.get("mode")) == "play":
			break
		await process_frame
	var vp: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var cur: int = -1
	for pl in PLACES:
		if int(pl[0]) != cur:
			cur = int(pl[0])
			_g.call("load_level", cur, true)
			for i in 400:
				if String(_g.get("mode")) == "play" and int(_g.get("level_index")) == cur:
					break
				await process_frame
			_p.set("input_enabled", false)
		var f: Vector4 = pl[2]
		_p.call("place", f, float(pl[3]))
		if bool(pl[4]):
			var t: Projection = GB.cleaned(Basis4D.from_zx(float(pl[3])) * Basis4D.from_zw(PI * 0.5))
			if (-t.z).w < 0.0:
				t = GB.cleaned(Basis4D.from_zx(float(pl[3])) * Basis4D.from_zw(-PI * 0.5))
			_p.set("ground", t)
			_p.basis = t
		for i in 40:
			await process_frame
		var times: Array = []
		var gpu: Array = []
		var last: int = Time.get_ticks_usec()
		for i in 150:
			await process_frame
			var now: int = Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			last = now
		times.sort()
		gpu.sort()
		print("PERF L%d %-28s median %.2f ms  worst %.2f ms  gpu median %.2f ms" % [cur + 1, String(pl[1]), times[75], times[149], gpu[75]])
	print("PERF DONE")
	quit(0)
