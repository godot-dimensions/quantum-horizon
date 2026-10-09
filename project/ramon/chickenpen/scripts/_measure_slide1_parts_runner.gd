extends SceneTree
## Slide I's frame time, taken apart: the slide held still (its clock stopped) and timed for
## 240 frames as it is, then with one thing at a time switched off - the see-through pane,
## the screen over the stage, the figures, the chicken's sheet, the motes, the house, the
## floor, the backdrop - so what each costs is the difference. Then the ball's moment the
## same way, with the ghost ball and its cut showing.
##
## Windowed, vsync off, no cap (follow_up/lofting_gotchas.md).

var _root: Node
var _show: Node
var _seat: Node
var _player: CharacterBody4D
var _f := 0
var _stage := "wait"
var _cfg := 0
var _n := 0
var _times: Array = []
var _last := 0
var _results: Array = []

## [name, path (relative to the cinema) to switch off, or a special].
const CONFIGS := [
	["as it is", ""],
	["no pane", "UI/Pane"],
	["no screen", "UI/Screen"],
	["no figures", "UI/Metrics"],
	["no caption", "UI/Caption"],
	["no chicken sheet", "Stage/Turntable/FlatWorld"],
	["no motes", "Stage/Motes"],
	["no house", "Stage/House"],
	["no floor", "Stage/Floor"],
	["no backdrop", "Stage/Backdrop"],
	["no presenter", "Presenter"],
	["as it is again", ""],
]


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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
	if _f > 20000:
		print("PARTS FAIL: stuck at %s" % _stage)
		quit(1)
		return true
	if bool(_seat.call("is_offering")) and not bool(_seat.call("is_seated")):
		_seat.call("sit")
	match _stage:
		"wait":
			# Into slide I, then hold its clock where it is: the ball (tau 0.25) or the start.
			if int(_show.call("current_act")) == 0:
				_stage = "settle"
				_n = 0
		"settle":
			_n += 1
			if _n == 2:
				_show.set("act_seconds", 1.0e6)
				var span: float = float(_show.call("_length", 0))
				_show.set("_phase", span * 0.02)
			# Let the camera's ease into the sheet shot finish and the build pumps go quiet.
			if _n > 900:
				_show.set_process(false)
				_stage = "time"
				_cfg = 0
				_begin()
		"time":
			_times.append(dt)
			_n += 1
			if _n >= 240:
				_end()
				_cfg += 1
				if _cfg >= CONFIGS.size():
					if _stage == "time":
						_ball()
					return false
				_begin()
		"ball":
			_times.append(dt)
			_n += 1
			if _n >= 240:
				_times.sort()
				print("%-24s %6.2f ms median  %6.2f p95  objects %d" % ["ball passing (all on)",
					_times[_times.size() / 2], _times[int(_times.size() * 0.95)],
					int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
				quit()
				return true
	return false


func _begin() -> void:
	var path: String = CONFIGS[_cfg][1]
	if path != "":
		var node: Node = _root.get_node_or_null(path)
		if node is CanvasItem:
			(node as CanvasItem).visible = false
			node.set_process(false)
		elif node is Node4D:
			(node as Node4D).visible = false
	_times.clear()
	_n = 0


func _end() -> void:
	_times.sort()
	print("%-24s %6.2f ms median  %6.2f p95  objects %d" % [CONFIGS[_cfg][0], _times[_times.size() / 2],
		_times[int(_times.size() * 0.95)], int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	var path: String = CONFIGS[_cfg][1]
	if path != "":
		var node: Node = _root.get_node_or_null(path)
		if node is CanvasItem:
			(node as CanvasItem).visible = true
			node.set_process(true)
		elif node is Node4D:
			(node as Node4D).visible = true


## The ball's moment: the slide's own demonstration run by hand at tau 0.27, where the ghost
## ball is in the sheet and its cut is drawn.
func _ball() -> void:
	_stage = "ball"
	_show.set_process(true)
	var span: float = float(_show.call("_length", 0))
	_show.set("_phase", span * 0.27)
	_show.set("act_seconds", 1.0e6)
	_times.clear()
	_n = -60
