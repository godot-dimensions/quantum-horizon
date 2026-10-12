extends SceneTree

## Plays miegakure_look_2.tscn WITH a rendering device and screenshots each
## beat of the puzzle, so the mechanic can actually be looked at rather than
## inferred from source. Same reason Demo/_screenshot.gd exists - everything
## else in this repo's tooling runs --headless, which never creates a
## rendering device, so nothing is drawn and no visual claim can be checked.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/MiegakureLook/_visual_probe_2.gd
##
## Drives the real input path, not the camera's internals, so what is captured
## is what a player would get:
## - The 90-degree rotation is an EVENT-based action (`_input` +
##   is_action_pressed), so it needs Input.parse_input_event() with a genuine
##   InputEventMouseButton - Input.action_press() alone never reaches _input.
## - Movement is POLLED (Input.get_axis in _physics_process), so for that
##   Input.action_press()/action_release() is the correct injection.
## Getting those two backwards is why an earlier attempt looked like the
## rotation input was broken when it was only never delivered.

const WARMUP_SECONDS := 1.0
const SHOT_WIDTH := 1280
const SHOT_HEIGHT := 720
const OUT_DIR := "res://ramon/MiegakureLook/"

var _root_node: Node = null
var _ball: Node = null
var _camera: Node = null
var _elapsed: float = 0.0
var _step: int = 0
var _step_started: float = 0.0
var _tapped: bool = false
var _substep: int = 0
var _log: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	root.set_size(Vector2i(SHOT_WIDTH, SHOT_HEIGHT))
	var packed: PackedScene = load("res://ramon/MiegakureLook/miegakure_look_2.tscn")
	if packed == null:
		printerr("PROBE: could not load miegakure_look_2.tscn")
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	set_current_scene(_root_node)
	_ball = _root_node.get_node("Ball")
	_camera = _root_node.get_node("CameraRig")
	print("PROBE: loaded, ball at ", _ball.position)


## Right mouse button = the `rotate_4d` action in project.godot.
func _tap_rotate() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	Input.parse_input_event(release)


func _shot(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("PROBE: no viewport image - running headless by mistake?")
		quit(1)
		return
	var absolute := ProjectSettings.globalize_path(OUT_DIR + name)
	image.save_png(absolute)
	var p: Vector4 = _ball.global_position
	var state := "%s | ball xyzw=(%+.2f %+.2f %+.2f %+.2f) floor=%s vel_y=%+.2f | cam=%.1fdeg%s" % [
		name,
		p.x, p.y, p.z, p.w,
		"Y" if _ball.is_on_floor() else "N",
		_ball.linear_velocity.y,
		_camera.get_current_angle_degrees(),
		" TRANSITIONING" if _camera.is_transitioning() else "",
	]
	_log.append(state)
	print("PROBE: ", state)


func _elapsed_in_step() -> float:
	return _elapsed - _step_started


func _advance() -> void:
	_step += 1
	_step_started = _elapsed
	_tapped = false
	_substep = 0


## True once the slice rotation has both stopped AND landed on the expected
## angle, so a screenshot labelled "rotated_90" really is at 90 degrees.
func _arrived(degrees: float) -> bool:
	return not _camera.is_transitioning() and absf(_camera.get_current_angle_degrees() - degrees) < 0.5


func _process(delta: float) -> bool:
	_elapsed += delta
	var t := _elapsed_in_step()
	match _step:
		0: # Let shaders compile and the builder finish before believing anything.
			if _elapsed >= WARMUP_SECONDS:
				_shot("probe_0_start.png")
				_advance()
		1: # Walk forward in the un-rotated slice: should be BLOCKED by the wall.
			Input.action_press("move_forward")
			if t >= 3.0:
				Input.action_release("move_forward")
				_shot("probe_1_blocked_by_wall.png")
				_advance()
		2: # Fire the 90-degree slice rotation, catch it mid-morph.
			if not _tapped:
				_tapped = true
				_tap_rotate()
			if t >= 0.35:
				_shot("probe_2_mid_rotation.png")
				_advance()
		3: # Settled at 90 degrees - "forward" now means walking along w.
			# Wait for the angle to ACTUALLY arrive, not merely for the
			# transition flag - parse_input_event is delivered a frame late, so
			# "not transitioning" is also true in the gap before it starts.
			if _arrived(90.0):
				_shot("probe_3_rotated_90.png")
				_advance()
		4: # Walk along w toward the wall's w-gap, sampling as we go: a single
			# end-of-walk shot hid the fact that the floor leaves the frame.
			Input.action_press("move_forward")
			if t >= 0.8 and _substep == 0:
				_substep = 1
				_shot("probe_4a_walking_w_0.8s.png")
			elif t >= 1.6 and _substep == 1:
				_substep = 2
				_shot("probe_4b_walking_w_1.6s.png")
			elif t >= 2.5:
				Input.action_release("move_forward")
				_shot("probe_4c_walked_along_w.png")
				_advance()
		5: # Rotate back - now at a different w, so a different cross-section.
			if not _tapped:
				_tapped = true
				_tap_rotate()
			if _arrived(0.0):
				_shot("probe_5_rotated_back.png")
				_advance()
		6: # Walk forward again: the wall should no longer be in the way.
			Input.action_press("move_forward")
			if t >= 1.6:
				Input.action_release("move_forward")
				_shot("probe_6_after_wall.png")
				_advance()
		7:
			print("PROBE: --- summary ---")
			for line in _log:
				print("PROBE: ", line)
			quit(0)
			return true
	return false
