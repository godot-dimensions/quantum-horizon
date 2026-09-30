extends SceneTree

## Can you get out when it is over?
##
## THIS IS A REGRESSION TEST FOR A ROOM THAT WOULD NOT LET YOU LEAVE. The show ended, the
## shot camera stayed held, and the player stayed pinned in the chair with their physics
## and their input switched off. The only way out was a movement key nobody had been told
## about, and from the chair it looked exactly like a hang.
##
## Nothing in the other runners could have caught it. The part-two runner never sits down,
## so it never gets into the state; the chair runner sits down and then deliberately
## stands up again, which is the path that always worked. The failure only exists at the
## join between them, which is why this walks the whole thing end to end: sit, watch the
## lot, and then check you are on your feet.

var _root: Node
var _f := 0
var _fails: Array = []
var _player: CharacterBody4D
var _seat: Node
var _camera: Node
var _show: Node
var _two: Node
var _exit: Node
var _their: Camera4D
var _sat := false
var _started := false
var _ended_at := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f == 1:
		_player = _root.get_node("Player") as CharacterBody4D
		_seat = _root.get_node("UI/Seat")
		_camera = _root.get_node("ShotCamera")
		_show = _root.get_node("Show")
		_two = _root.get_node("PartTwo")
		_exit = _root.get_node("ExitArch")
		_their = _root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D
		_show.set("opening_seconds", 1.0)
		_show.set("act_seconds", 0.5)
		_show.set("closing_seconds", 0.3)
		_show.set("hold_on_seat_seconds", 0.1)
		_show.set("after_sit_seconds", 0.2)
		_seat.set("sit_seconds", 0.5)
		_two.set("moment_seconds", 0.4)
		_two.set("closing_seconds", 0.3)
		return false

	# Down the rake and into the chair, which is the state the bug lived in.
	if _f == 3:
		var stage: Node4D = _root.get_node("Stage") as Node4D
		var top: Vector4 = stage.get("aisle_to")
		var foot: Vector4 = stage.get("aisle_from")
		_player.set_physics_process(false)
		_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18,
			lerpf(top.z, foot.z, 0.5), 0.0)
		return false

	if not _sat and bool(_seat.call("is_offering")):
		_sat = true
		_seat.call("sit")
		print("\n--- sat down, and the show runs ---")
		return false

	# Slide I hands straight on to part two; nobody is asked.
	if not _started and bool(_two.call("is_running")):
		_started = true
		_check("it got all the way to slide II while you sat there", bool(_sat),
			"slide I played to an audience of one, seated, and handed on by itself")
		return false

	# The end of part two: not running any more, and no moment left to show.
	var count: int = (_two.get_script().get_script_constant_map()["MOMENTS"] as Array).size()
	var over: bool = _started and not bool(_two.call("is_running")) \
		and int(_two.call("current_moment")) >= count
	if over and _ended_at == 0:
		_ended_at = _f
		return false
	if _ended_at > 0 and _f < _ended_at + 8:
		return false

	if _ended_at > 0:
		print("\n--- and it lets you out ---")
		_check("you are out of the chair", not bool(_seat.call("is_seated")),
			"the show standing you up rather than waiting to be escaped")
		_check("the camera is yours again",
			_their.is_current() and not bool(_camera.call("is_holding")),
			"the shot camera has stood down")
		_check("and you can walk", _player.is_physics_processing()
			and bool(_player.get("input_enabled")),
			"physics and input back with the character")
		_check("with the way out lit", float(_exit.get("highlight")) > 0.9,
			"highlight %.2f - the exit is the thing to look at now"
				% float(_exit.get("highlight")))
		print("\n%d FAIL(s)" % _fails.size())
		quit(1 if _fails.size() > 0 else 0)
		return true

	if _f > 20000:
		print("   FAIL never reached the end (sat=%s started=%s moment=%d)"
			% [_sat, _started, int(_two.call("current_moment"))])
		quit(1)
		return true
	return false
