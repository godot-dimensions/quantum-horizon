extends SceneTree

## What happens when somebody clicks through it instead of watching it.
##
## THE BUG THIS EXISTS FOR. The talk ends on a closing beat that waits out a clock before
## it stands you out of the chair. Stepping forward re-entered whichever beat you were
## already on, because the index clamps, and re-entering reset that clock. So clicking to
## hurry the end along was the one action that held it open, for ever. The more impatient
## you were, the longer it took. (It used to happen at the question between the two parts
## as well; since 30 Sept there is no question, and clicking off slide V must go straight
## on to slide VI.)
##
## Nothing else could have caught it. Every other runner lets the clock run: they are
## testing what the room does, and this is testing what a person does to it.
##
## It clicks on EVERY frame from the moment the first act starts, which is far more
## brutal than anybody would really be, and that is the point - the failure was a race
## between a click and a clock, so the test should lose that race every time it can.

var _root: Node
var _f := 0
var _fails: Array = []
var _show: Node
var _two: Node
var _seat: Node
var _camera: Node
var _their: Camera4D
var _player: CharacterBody4D
var _clicking := false
var _handed := false
var _handed_at := 0
var _sat := false
var _down := false


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


## A left click, the way a mouse sends one: down, and then up on the next frame. The show
## reads the press, so the release is only good manners.
func _click() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)


func _process(_d) -> bool:
	_f += 1
	if _f == 1:
		_show = _root.get_node("Show")
		_two = _root.get_node("PartTwo")
		_seat = _root.get_node("UI/Seat")
		_camera = _root.get_node("ShotCamera")
		_player = _root.get_node("Player") as CharacterBody4D
		_their = _root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D
		# Long beats on purpose. A clock this slow means nothing can finish on time by
		# accident: if the ending arrives, it arrived because somebody clicked for it.
		_show.set("opening_seconds", 0.5)
		_show.set("act_seconds", 30.0)
		_show.set("closing_seconds", 30.0)
		_show.set("waits_for_seat", 0.0)
		_two.set("moment_seconds", 30.0)
		_two.set("closing_seconds", 30.0)
		return false

	# Into the chair first, so the ending has something to release.
	if _f == 3:
		var stage: Node4D = _root.get_node("Stage") as Node4D
		var top: Vector4 = stage.get("aisle_to")
		var foot: Vector4 = stage.get("aisle_from")
		_player.set_physics_process(false)
		_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18,
			lerpf(top.z, foot.z, 0.5), 0.0)
		_seat.set("sit_seconds", 0.3)
		return false
	if not _sat and bool(_seat.call("is_offering")):
		_sat = true
		_seat.call("sit")
		return false
	if not _down:
		_down = bool(_seat.call("is_settled"))
		return false

	if not _handed and bool(_two.call("is_running")):
		_handed = true
		_handed_at = _f
		print("\n--- clicked through slides I to V ---")
		_check("slide VI arrives for somebody who clicks", true,
			"reached on frame %d with every clock set to 30 seconds" % _f)
		_check("with nobody asked anything", _root.get_node_or_null("UI/Prompt") == null,
			"no question between slide V and slide VI")

	# Click on every frame, both parts.
	_clicking = true
	_click()

	if not _handed:
		if _f > 4000:
			print("   FAIL clicking through slides I to V never reached slide VI")
			print("        act %d, phase %.1f" % [int(_show.call("current_act")),
				float(_show.get("_phase"))])
			quit(1)
			return true
		return false

	# And through part two, to the end.
	if bool(_two.call("is_running")):
		if _f > _handed_at + 4000:
			print("   FAIL clicking through part two never reached the end, at moment %d"
				% int(_two.call("current_moment")))
			quit(1)
			return true
		return false

	print("\n--- and clicked through part two ---")
	var count: int = (_two.get_script().get_script_constant_map()["MOMENTS"] as Array).size()
	_check("it ends for somebody who clicks", int(_two.call("current_moment")) >= count,
		"ran out of moments on frame %d rather than holding on the last one" % _f)
	_check("and it lets go of them", not bool(_seat.call("is_seated"))
		and _their.is_current() and not bool(_camera.call("is_holding")),
		"out of the chair with the camera back, the same as sitting it out")
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
