extends SceneTree

## Plan steps 45, 55, 63, 90 and 97: what the Arboretum costs, measured the way
## follow_up/lofting_gotchas.md says to (vsync off, frames timed between process_frame signals, the
## GPU's own render time from RenderingServer; the engine's TIME_PROCESS monitor is the worst frame of
## the last second, so it is not used). Windowed, unfocusable.
##
## For each view: the median and 95th-percentile frame (ms) and GPU time (ms) over 150 frames, with
## everything shown; then each tree alone (the others hidden), the oak without its leaves, the wind
## off, the grove from near its door (drawn) and from its crossing (the hall's trees hidden, then
## shown). Each line says whether the grove was drawn. Prints a table; the numbers go into
## follow_up/arboretum.md.

const SCENE := "res://ramon/Arboretum/arboretum.tscn"
const FRAMES := 150

var _room: Node4D
var _jobs: Array = []
var _job: Dictionary = {}
var _samples: Array = []
var _gpu: Array = []
var _last: int = 0
var _settle: int = 0
var _deadline: int = 0
var _rid: RID


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_deadline = Time.get_ticks_msec() + 300000
	(func() -> void: _open()).call_deferred()


func _open() -> void:
	var t0: int = Time.get_ticks_usec()
	_room = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_room)
	print("PERF open %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	# (Video memory before the room's first frame: the engine and the empty window.)
	print("PERF video memory at open %.0f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)
	var views := {
		"door": [0.0, 14.0, 0.0],
		"at_01": [-2.0, 10.6, 50.0],
		"at_02": [2.4, 3.6, -50.0],
		"at_03": [-2.0, -3.6, 50.0],
		"at_oak": [0.0, -5.2, 0.0],
	}
	for v in views:
		_jobs.append({"name": v, "at": views[v]})
	for i in 4:
		_jobs.append({"name": "only_%02d" % (i + 1), "at": views["door"], "only": i})
	_jobs.append({"name": "none (empty hall)", "at": views["door"], "only": -2})
	_jobs.append({"name": "oak no leaves", "at": views["at_oak"], "leaves": false})
	# Wind and leaves as A/B/A at one view, so a drifting GPU clock shows as a difference between the
	# two A runs rather than hiding inside the B.
	_jobs.append({"name": "door wind off", "at": views["door"], "wind": false})
	_jobs.append({"name": "door wind on again", "at": views["door"]})
	_jobs.append({"name": "door, oak leaves off", "at": views["door"], "leaves": false})
	_jobs.append({"name": "door, all on again", "at": views["door"]})
	_jobs.append({"name": "near the grove door", "at": [0.0, -16.0, 0.0], "grove": true})
	_jobs.append({"name": "grove crossing", "at": [-3.0, -38.0, 140.0], "grove": true})
	_jobs.append({"name": "crossing, hall drawn", "at": [-3.0, -38.0, 140.0], "grove": true, "hall": true})
	_next()


func _next() -> void:
	if _jobs.is_empty():
		print("PERF done")
		quit()
		return
	_job = _jobs.pop_front()
	var at: Array = _job["at"]
	_room.call("go_to", Vector4(float(at[0]), 0.05, float(at[1]), 0.0), deg_to_rad(float(at[2])))
	var p: Node = _room.get("player")
	if p != null:
		p.set("input_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var only: int = int(_job.get("only", -1))
	for i in 4:
		var s: Node4D = _room.get_node_or_null("Station%02d" % (i + 1))
		if s != null:
			s.visible = only == -1 or only == i
	var oak: Node = _room.get_node_or_null("Station04")
	var ex: Node = oak.get("exhibit") if oak != null else null
	if ex != null and ex.get("leaves") != null:
		(ex.get("leaves") as Node).set("enabled", bool(_job.get("leaves", true)) and (only == -1 or only == 3))
	var w: Node = _room.call("wind")
	if w != null:
		w.set("enabled", bool(_job.get("wind", true)))
	if bool(_job.get("grove", false)):
		var g: Node = _room.get_node_or_null("Grove")
		if g != null:
			g.call("preload_all")
	_room.set("hall_hide_depth", 99.0 if bool(_job.get("hall", false)) else 6.0)
	_samples = []
	_gpu = []
	_settle = 240 if bool(_job.get("grove", false)) else 40
	_last = Time.get_ticks_usec()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("PERF TIMEOUT")
		quit(2)
		return true
	if _job.is_empty():
		return false
	var now: int = Time.get_ticks_usec()
	var dt: float = (now - _last) / 1000.0
	_last = now
	if _settle > 0:
		_settle -= 1
		return false
	_samples.append(dt)
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_rid))
	if _samples.size() >= FRAMES:
		_samples.sort()
		_gpu.sort()
		var g: Node4D = _room.get_node_or_null("Grove")
		var drawn: String = "grove drawn" if g != null and g.visible and String(g.get("state")) != "idle" else "grove not drawn"
		var vram: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		print("PERF %-22s frame median %.2f ms, 95%% %.2f ms   GPU median %.2f ms, 95%% %.2f ms   %s, video memory %.0f MB" % [
			String(_job["name"]), _samples[FRAMES / 2], _samples[int(FRAMES * 0.95)], _gpu[FRAMES / 2], _gpu[int(FRAMES * 0.95)], drawn, vram])
		_job = {}
		(func() -> void: _next()).call_deferred()
	return false
