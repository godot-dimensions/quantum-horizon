extends SceneTree

## Plays the chasm level (miegakure_look_4.tscn) with a real rendering device and
## asserts the whole route, one key at a time.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/MiegakureLook/_visual_probe_4.gd
##
## Route: walk to the chasm edge, rotate 90 degrees, walk along w into the cyan
## bridge band, rotate back, walk across the bridge onto the goal. Then the
## negative case, which is the part worth proving as much as the positive one:
## from the same starting point, rotating back in the WRONG band and walking
## forward must drop the ball into the chasm and respawn it.
##
## Input injection, same as the v3 probe: the rotation is an EVENT action so it
## needs Input.parse_input_event() with a real InputEventMouseButton; movement is
## POLLED so it needs Input.action_press(). parse_input_event also arrives a frame
## late, so gate on the slice angle actually arriving.

const OUT_DIR := "res://ramon/MiegakureLook/"
## Chasm near edge is z = -1, so this stops the ball short of it rather than
## testing the fall by accident.
const APPROACH_SECONDS := 1.2
const BRIDGE_W := -5.0

var _root_node: Node = null
var _ball: Node = null
var _camera: Node = null
var _banner: Node = null
var _builder: Node = null
var _elapsed: float = 0.0
var _step: int = 0
var _step_started: float = 0.0
var _tapped: bool = false
var _pass: PackedStringArray = PackedStringArray()
var _fail: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	var packed: PackedScene = load("res://ramon/MiegakureLook/miegakure_look_4.tscn")
	if packed == null:
		printerr("V4: could not load miegakure_look_4.tscn")
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	set_current_scene(_root_node)
	_ball = _root_node.get_node("Ball")
	_camera = _root_node.get_node("CameraRig")
	_banner = _root_node.get_node("GoalBanner")
	_builder = _root_node.get_node("Builder")

	_check("w-gauge HUD script loaded", _root_node.get_node("WReadout").get_script() != null)
	_check("gauge reads the bridge band off the builder",
			is_equal_approx(_builder.get_gap_w(), BRIDGE_W),
			"gap_w=%.1f" % _builder.get_gap_w())


func _check(what: String, ok: bool, detail: String = "") -> void:
	var line := "%s%s" % [what, "" if detail.is_empty() else " (" + detail + ")"]
	if ok:
		_pass.append(line)
		print("V4 PASS: ", line)
	else:
		_fail.append(line)
		print("V4 FAIL: ", line)


func _tap_rotate() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		Input.parse_input_event(event)


func _shot(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("V4: no viewport image - running headless by mistake?")
		return
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + name))
	var p: Vector4 = _ball.global_position
	print("V4: %s | ball=(%+.2f %+.2f %+.2f %+.2f) floor=%s cam=%.1fdeg" % [
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
				_check("spawned outside the bridge band", absf(p.w - BRIDGE_W) > 1.0, "w=%+.2f" % p.w)
				_shot("v4_0_start.png")
				_advance()
		1: # Up to the chasm's near lip, still on solid ground.
			Input.action_press("move_forward")
			if t >= APPROACH_SECONDS:
				Input.action_release("move_forward")
				_check("stopped short of the chasm", p.z > -1.0, "z=%+.2f" % p.z)
				_check("still on the floor", _ball.is_on_floor())
				_shot("v4_1_at_chasm_edge.png")
				_advance()
		2:
			if not _tapped:
				_tapped = true
				_tap_rotate()
			if _arrived(90.0):
				# THE POINT OF THIS LEVEL: the rotated view is floor, and floor is
				# in every slice, so the bridge band is visible from here.
				_shot("v4_2_rotated_bands_visible.png")
				_advance()
		3: # Along w into the cyan band. Ground is solid at all w at this z.
			Input.action_press("move_forward")
			if t >= 1.5:
				Input.action_release("move_forward")
				_check("walked along w without falling", _ball.is_on_floor(), "y=%+.2f" % p.y)
				_check("standing in the bridge band", absf(p.w - BRIDGE_W) <= 1.0, "w=%+.2f" % p.w)
				_shot("v4_3_in_bridge_band.png")
				_advance()
		4:
			if not _tapped:
				_tapped = true
				_tap_rotate()
			if _arrived(0.0):
				_shot("v4_4_bridge_exists.png")
				_advance()
		5: # Across ground that was not there before, onto the goal.
			Input.action_press("move_forward")
			if t >= 1.8:
				Input.action_release("move_forward")
				_check("crossed the chasm", p.z < -5.0, "z=%+.2f" % p.z)
				_check("never fell while crossing", _ball.is_on_floor(), "y=%+.2f" % p.y)
				_check("goal banner shown", _banner._is_shown())
				_shot("v4_5_goal.png")
				_advance()
		6: # NEGATIVE CASE: same route, wrong band - the chasm must be real.
			_ball.global_position = Vector4(0.0, 1.0, 0.0, 1.0)
			_ball.linear_velocity = Vector4.ZERO
			if t >= 0.4:
				_advance()
		7:
			Input.action_press("move_forward")
			if t >= 1.2:
				Input.action_release("move_forward")
				_check("fell into the chasm outside the bridge band",
						not _ball.is_on_floor() or p.y < 0.0, "y=%+.2f" % p.y)
				_shot("v4_6_fell_in_chasm.png")
				_advance()
		8: # And the fall bound recovers it.
			if t >= 3.0:
				_check("respawned after falling in", p.y > -2.0 and absf(p.z - 5.0) < 0.5,
						"pos=(%+.2f %+.2f %+.2f %+.2f)" % [p.x, p.y, p.z, p.w])
				_advance()
		9:
			print("V4: --- %d passed, %d failed ---" % [_pass.size(), _fail.size()])
			for line in _fail:
				print("V4: STILL FAILING: ", line)
			quit(0 if _fail.is_empty() else 1)
			return true
	return false
