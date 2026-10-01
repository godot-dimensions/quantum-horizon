extends SceneTree

## Sitting down again after the talk is over. Ramon, 30 Sept: "after the presentation when
## I press F to sit in the chair again, I can't watch it over. Instead I'm locked in a
## freeze, nothing works anymore" - and a double Escape did not get him out.
##
## Walks the whole thing: sit, watch it to the end, get stood up, walk back to the chair,
## press F, and then try to get up again with a movement key. Prints what every party to
## it thinks is going on at each step, so a freeze says whose it is.

var _root: Node
var _f := 0
var _fails: Array = []
var _stage := 0
var _mark := 0
var _show: Node
var _two: Node
var _seat: Node
var _talk: Node
var _camera: Node
var _player: CharacterBody4D
var _rig: Node
var _their: Camera4D


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-50s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _state(what: String) -> void:
	print("   [%s] seated=%s settled=%s offering=%s  camera holding=%s  theirs current=%s  talk running=%s  input=%s physics=%s rig_input=%s  show over=%s act=%d  two running=%s"
		% [what, _seat.call("is_seated"), _seat.call("is_settled"), _seat.call("is_offering"),
			_camera.call("is_holding"), _their.is_current(), _talk.call("is_running"),
			_player.get("input_enabled"), _player.is_physics_processing(),
			_rig.is_processing_unhandled_input(), _show.call("is_over"), int(_show.call("current_act")),
			_two.call("is_running")])


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)


func _release(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = false
	Input.parse_input_event(ev)


func _process(_d) -> bool:
	_f += 1
	if _f == 1:
		_show = _root.get_node("Show")
		_two = _root.get_node("PartTwo")
		_seat = _root.get_node("UI/Seat")
		_talk = _root.get_node("TrymTalk")
		_camera = _root.get_node("ShotCamera")
		_player = _root.get_node("Player") as CharacterBody4D
		_rig = _root.get_node("Player/CameraRig")
		_their = _root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D
		_show.set("opening_seconds", 0.6)
		_show.set("act_seconds", 0.5)
		_show.set("closing_seconds", 0.3)
		_show.set("hold_on_seat_seconds", 0.1)
		_show.set("after_sit_seconds", 0.2)
		_seat.set("sit_seconds", 0.3)
		_two.set("moment_seconds", 0.4)
		_two.set("closing_seconds", 0.3)
		return false
	match _stage:
		0:
			if _f == 3:
				var stage: Node4D = _root.get_node("Stage") as Node4D
				var top: Vector4 = stage.get("aisle_to")
				var foot: Vector4 = stage.get("aisle_from")
				_player.set_physics_process(false)
				_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18,
					lerpf(top.z, foot.z, 0.5), 0.0)
			if bool(_seat.call("is_offering")):
				_seat.call("sit")
				_stage = 1
		1:
			# The first showing, to the end, and stood up by it.
			if bool(_show.call("is_over")) and not bool(_seat.call("is_seated")):
				print("\n--- the talk is over and you are on your feet ---")
				_state("after")
				_stage = 2
				_mark = _f + 30
			elif _f > 30000:
				print("   FAIL the first showing never ended")
				return _end()
		2:
			if _f < _mark:
				return false
			# Back to the chair: stood where the sit starts from, a step in front of it.
			var chair: Node4D = _root.get_node("Stage/House/YourSeat") as Node4D
			var ahead: Vector4 = -chair.global_basis.z
			_player.global_position = chair.global_position + ahead * 0.9 - Vector4(0.0, 0.2, 0.0, 0.0)
			_player.set("linear_velocity", Vector4.ZERO)
			_stage = 3
			_mark = _f + 400
		3:
			if bool(_seat.call("is_offering")):
				print("\n--- F at the chair, a second time ---")
				_state("offered")
				_press(&"catch_target")
				_stage = 4
				_mark = _f + 120
			elif _f > _mark:
				_state("never offered")
				_check("the chair offers itself again", false, "")
				return _end()
		4:
			if _f == _mark - 119:
				_release(&"catch_target")
			# Watch it over: slide I comes back, with you still in the chair.
			if int(_show.call("current_act")) == 0 and not bool(_show.call("is_over")):
				_state("slide I again")
				_check("F sits you down again", bool(_seat.call("is_seated")), "")
				_check("and does not also start Trym's talk", not bool(_talk.call("is_running")), "")
				_check("and the talk starts over from slide I", true, "act 0, not over")
				var card: Node = _root.get_node_or_null("UI/EndCard")
				_check("with the end card gone", card != null and not bool(card.call("is_showing")), "")
				print("
--- Escape to stand up ---")
				_press(&"ui_cancel")
				_stage = 5
				_mark = _f + 30
			elif _f > _mark + 3000:
				_state("stuck")
				_check("and the talk starts over from slide I", false,
					"act %d, over=%s" % [int(_show.call("current_act")), _show.call("is_over")])
				return _end()
		5:
			if _f == _mark - 29:
				_release(&"ui_cancel")
			if _f < _mark:
				return false
			_state("after Esc")
			_check("Escape stands you up", not bool(_seat.call("is_seated")), "")
			_check("with the camera back", _their.is_current() and not bool(_camera.call("is_holding")), "")
			_check("and your legs back", bool(_player.get("input_enabled")) and _player.is_physics_processing()
				and _rig.is_processing_unhandled_input(), "")
			return _end()
	return false


func _end() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
