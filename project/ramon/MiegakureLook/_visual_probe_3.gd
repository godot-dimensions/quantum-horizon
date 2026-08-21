extends SceneTree

## Verifies the three v3 fixes in miegakure_look_3.tscn, in play, with a real
## rendering device. Runs the whole puzzle using ONE key at a time - which is the
## point of the yaw fix, since v2 needed forward+right held together to move
## along a single world axis.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/MiegakureLook/_visual_probe_3.gd
##
## Checks, in order:
##   1. The w-gauge HUD script actually loaded (v2's silently did not).
##   2. Single-key forward at theta 0 is pure -z and stops at the wall.
##   3. Single-key forward at theta 90 is pure -w and reaches the gap.
##   4. Rotating back and walking forward reaches the goal and shows the banner.
##   5. Walking off the edge respawns instead of falling forever.
##
## Input injection note: the rotation is an EVENT action (`_input` +
## is_action_pressed) so it needs Input.parse_input_event() with a real
## InputEventMouseButton; movement is POLLED (Input.get_axis) so that needs
## Input.action_press(). parse_input_event also arrives a frame late, so gate on
## the angle having actually arrived rather than on is_transitioning() alone.
##
## Screenshots come out 1920x1080 regardless of the requested size - root.set_size
## does not take in a SceneTree script, as hub_demo_lessons.md already records
## for _screenshot.gd.

const OUT_DIR := "res://ramon/MiegakureLook/"

var _root_node: Node = null
var _ball: Node = null
var _camera: Node = null
var _banner: Node = null
var _elapsed: float = 0.0
var _step: int = 0
var _step_started: float = 0.0
var _tapped: bool = false
var _pass: PackedStringArray = PackedStringArray()
var _fail: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	root.set_size(Vector2i(1280, 720))
	var packed: PackedScene = load("res://ramon/MiegakureLook/miegakure_look_3.tscn")
	if packed == null:
		printerr("V3: could not load miegakure_look_3.tscn")
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	set_current_scene(_root_node)
	_ball = _root_node.get_node("Ball")
	_camera = _root_node.get_node("CameraRig")
	_banner = _root_node.get_node("GoalBanner")

	# FIX 3: v2's equivalent node ended up with no script at all because the
	# script failed to parse. A null script here is that same failure.
	var readout: Node = _root_node.get_node("WReadout")
	_check("w-gauge HUD script loaded", readout.get_script() != null)


func _check(what: String, ok: bool, detail: String = "") -> void:
	var line := "%s%s" % [what, "" if detail.is_empty() else " (" + detail + ")"]
	if ok:
		_pass.append(line)
		print("V3 PASS: ", line)
	else:
		_fail.append(line)
		print("V3 FAIL: ", line)


func _tap_rotate() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		Input.parse_input_event(event)


func _shot(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("V3: no viewport image - running headless by mistake?")
		return
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + name))
	var p: Vector4 = _ball.global_position
	print("V3: %s | ball=(%+.2f %+.2f %+.2f %+.2f) floor=%s cam=%.1fdeg" % [
		name, p.x, p.y, p.z, p.w, "Y" if _ball.is_on_floor() else "N",
		_camera.get_current_angle_degrees(),
	])


func _advance() -> void:
	_step += 1
	_step_started = _elapsed
	_tapped = false


func _arrived(degrees: float) -> bool:
	return not _camera.is_transitioning() and absf(_camera.get_current_angle_degrees() - degrees) < 0.5


func _process(delta: float) -> bool:
	_elapsed += delta
	var t := _elapsed - _step_started
	var p: Vector4 = _ball.global_position
	match _step:
		0:
			if _elapsed >= 1.0:
				_shot("v3_0_start.png")
				_advance()
		1: # FIX 1a: one key, pure -z, and it should stop dead at the wall.
			Input.action_press("move_forward")
			if t >= 1.6:
				Input.action_release("move_forward")
				_check("theta0 forward is pure -z", absf(p.x) < 0.05, "x=%+.3f" % p.x)
				_check("blocked by the wall", absf(p.z - 0.70) < 0.15, "z=%+.2f" % p.z)
				_check("still on the platform", _ball.is_on_floor())
				_shot("v3_1_blocked_by_wall.png")
				_advance()
		2:
			if not _tapped:
				_tapped = true
				_tap_rotate()
			if _arrived(90.0):
				_shot("v3_2_rotated_90.png")
				_advance()
		3: # FIX 1b: one key, pure -w, into the gap - this is what v2 could not do.
			Input.action_press("move_forward")
			if t >= 1.5:
				Input.action_release("move_forward")
				_check("theta90 forward is pure -w", absf(p.x) < 0.05, "x=%+.3f" % p.x)
				_check("did not fall off", _ball.is_on_floor(), "y=%+.2f" % p.y)
				_check("inside the wall's w-gap", absf(p.w - (-6.0)) < 1.5, "w=%+.2f" % p.w)
				_shot("v3_3_in_the_w_gap.png")
				_advance()
		4:
			if not _tapped:
				_tapped = true
				_tap_rotate()
			if _arrived(0.0):
				_shot("v3_4_rotated_back.png")
				_advance()
		5: # The payoff: the wall is not in this cross-section, so walk on through.
			Input.action_press("move_forward")
			if t >= 1.6:
				Input.action_release("move_forward")
				_check("walked past the wall's z", p.z < -1.0, "z=%+.2f" % p.z)
				_check("goal banner shown", _banner._is_shown())
				_shot("v3_5_goal.png")
				_advance()
		6: # FIX 2: leave the platform on purpose and expect a respawn.
			Input.action_press("move_right")
			if t >= 3.0:
				Input.action_release("move_right")
				_advance()
		7:
			if t >= 3.0:
				_check("respawned after falling off", absf(p.z - 5.0) < 0.5 and p.y > -2.0,
						"pos=(%+.2f %+.2f %+.2f %+.2f)" % [p.x, p.y, p.z, p.w])
				_shot("v3_6_after_respawn.png")
				_advance()
		8:
			print("V3: --- %d passed, %d failed ---" % [_pass.size(), _fail.size()])
			for line in _fail:
				print("V3: STILL FAILING: ", line)
			quit(0 if _fail.is_empty() else 1)
			return true
	return false
