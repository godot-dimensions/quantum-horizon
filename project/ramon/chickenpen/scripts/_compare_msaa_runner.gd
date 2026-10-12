extends SceneTree
## Anti-aliasing in the cinema, for Ramon to judge: the same held moment of slide I (the ball
## in the chicken's sheet) with MSAA off, 4x and 8x on the window's viewport, each timed over
## 240 frames and saved. Nothing in the cinema is changed; the viewport is set here only.
##
## Windowed, vsync off. Writes res://smoke_test_output/theatre_perf/msaa_<n>.png.

var _root: Node
var _show: Node
var _seat: Node
var _player: CharacterBody4D
var _f := 0
var _stage := "wait"
var _n := 0
var _last := 0
var _times: Array = []
var _level := 0
const LEVELS := [Viewport.MSAA_DISABLED, Viewport.MSAA_4X, Viewport.MSAA_8X]
const NAMES := ["off", "4x", "8x"]


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var now: int = Time.get_ticks_usec()
	var dt: float = (now - _last) / 1000.0
	_last = now
	if _f == 1:
		_show = _root.get_node("Show")
		_seat = _root.get_node("UI/Seat")
		_player = _root.get_node("Player") as CharacterBody4D
		_show.set("opening_seconds", 2.0)
		_show.set("after_sit_seconds", 0.3)
		_show.set("hold_on_seat_seconds", 0.3)
		_seat.set("sit_seconds", 0.3)
		return false
	if _f == 3:
		var stage: Node4D = _root.get_node("Stage") as Node4D
		var top: Vector4 = stage.get("aisle_to")
		var foot: Vector4 = stage.get("aisle_from")
		_player.set_physics_process(false)
		_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18, lerpf(top.z, foot.z, 0.5), 0.0)
		return false
	if _f > 30000:
		print("MSAA FAIL: stuck at %s" % _stage)
		quit(1)
		return true
	if bool(_seat.call("is_offering")) and not bool(_seat.call("is_seated")):
		_seat.call("sit")
	match _stage:
		"wait":
			if int(_show.call("current_act")) == 0:
				_stage = "settle"
				_n = 0
		"settle":
			_n += 1
			var span: float = float(_show.call("_length", 0))
			if float(_show.get("_phase")) >= span * 0.27 and _show.is_processing():
				# Held at the ball's moment: the show stops, so the ball and its cut stay
				# where they are, while the camera finishes its move on its own clock.
				_show.set_process(false)
			if not _show.is_processing() and _n > 600:
				_stage = "time"
				_begin()
		"time":
			# Twenty frames to settle after the switch, 200 timed, then the picture (a
			# screenshot stalls its own frame, so it is taken after the timing).
			if _n >= 0 and _n < 200:
				_times.append(dt)
			_n += 1
			if _n == 205:
				var path := "res://smoke_test_output/theatre_perf/msaa_%s.png" % NAMES[_level]
				root.get_texture().get_image().save_png(path)
			if _n >= 210:
				_times.sort()
				print("MSAA %-3s  %5.2f ms median frame, %5.2f ms GPU" % [NAMES[_level], _times[_times.size() / 2],
					RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())])
				_level += 1
				if _level >= LEVELS.size():
					quit()
					return true
				_begin()
	return false


func _begin() -> void:
	root.msaa_3d = LEVELS[_level]
	_times.clear()
	_n = -20
