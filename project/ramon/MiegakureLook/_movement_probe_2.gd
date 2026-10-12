extends SceneTree

## Measures what each movement key ACTUALLY does to the 4D position, at both
## slice angles, and whether the wall is visible from the rotated view.
##
## Exists because _visual_probe_2.gd showed the ball falling off the platform
## instead of solving the puzzle, and the cause was not decidable from the
## source alone: "forward" is camera-relative, the camera carries a 45-degree
## yaw, and the level is axis-aligned - so the question is whether forward
## produces motion along one world axis or a diagonal across two. That is a
## measurement, not an argument.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/MiegakureLook/_movement_probe_2.gd
##
## The ball is teleported between trials. That is legitimate here because each
## trial only reads the DIRECTION of a displacement over a fixed interval, but
## it does mean nothing here proves the level is completable - that is what
## _visual_probe_2.gd is for.

const OUT_DIR := "res://ramon/MiegakureLook/"
const TRIAL_SECONDS := 0.6
const SPAWN := Vector4(0.0, 1.0, 5.0, 0.0)

var _root_node: Node = null
var _ball: Node = null
var _camera: Node = null
var _elapsed: float = 0.0
var _step: int = 0
var _step_started: float = 0.0
var _tapped: bool = false
var _trial_origin: Vector4 = Vector4.ZERO
var _log: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	root.set_size(Vector2i(1280, 720))
	var packed: PackedScene = load("res://ramon/MiegakureLook/miegakure_look_2.tscn")
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	set_current_scene(_root_node)
	_ball = _root_node.get_node("Ball")
	_camera = _root_node.get_node("CameraRig")


func _tap_rotate() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		Input.parse_input_event(event)


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)


## Put the ball back somewhere known and stop it dead, so the next trial's
## displacement is caused only by that trial's input.
func _reset_ball(where: Vector4) -> void:
	_release_all()
	_ball.global_position = where
	_ball.linear_velocity = Vector4.ZERO
	_trial_origin = where


func _report(label: String, keys: Array) -> void:
	var delta: Vector4 = _ball.global_position - _trial_origin
	var horizontal := Vector4(delta.x, 0.0, delta.z, delta.w)
	var length: float = horizontal.length()
	var unit := horizontal / length if length > 0.001 else Vector4.ZERO
	var line := "%-28s keys=%-24s d=(x%+.2f y%+.2f z%+.2f w%+.2f) dir=(x%+.2f z%+.2f w%+.2f)" % [
		label, ",".join(keys), delta.x, delta.y, delta.z, delta.w, unit.x, unit.z, unit.w,
	]
	_log.append(line)
	print("MOVE: ", line)


func _shot(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("MOVE: no viewport image")
		return
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + name))
	print("MOVE: wrote ", name, " ball=", _ball.global_position, " cam=", _camera.get_current_angle_degrees())


func _advance() -> void:
	_step += 1
	_step_started = _elapsed
	_tapped = false


func _arrived(degrees: float) -> bool:
	return not _camera.is_transitioning() and absf(_camera.get_current_angle_degrees() - degrees) < 0.5


func _process(delta: float) -> bool:
	_elapsed += delta
	var t := _elapsed - _step_started
	match _step:
		0:
			if _elapsed >= 1.0:
				_reset_ball(SPAWN)
				_advance()
		1: # THETA 0: what does plain "forward" do?
			Input.action_press("move_forward")
			if t >= TRIAL_SECONDS:
				_report("theta0 forward", ["W"])
				_reset_ball(SPAWN)
				_advance()
		2: # THETA 0: forward+right, in case the level axes need a diagonal press.
			Input.action_press("move_forward")
			Input.action_press("move_right")
			if t >= TRIAL_SECONDS:
				_report("theta0 forward+right", ["W", "D"])
				_reset_ball(SPAWN)
				_advance()
		3:
			if not _tapped:
				_tapped = true
				_tap_rotate()
			if _arrived(90.0):
				_reset_ball(SPAWN)
				_advance()
		4: # THETA 90: plain "forward" - is this pure w, or a diagonal?
			Input.action_press("move_forward")
			if t >= TRIAL_SECONDS:
				_report("theta90 forward", ["W"])
				_reset_ball(SPAWN)
				_advance()
		5: # THETA 90: forward+right.
			Input.action_press("move_forward")
			Input.action_press("move_right")
			if t >= TRIAL_SECONDS:
				_report("theta90 forward+right", ["W", "D"])
				_reset_ball(SPAWN)
				_advance()
		6: # THETA 90: forward+left.
			Input.action_press("move_forward")
			Input.action_press("move_left")
			if t >= TRIAL_SECONDS:
				_report("theta90 forward+left", ["W", "A"])
				_release_all()
				_advance()
		7: # Can the wall be SEEN from the rotated view, standing where the
			# collision actually stops you (z = +0.70, wall face + ball radius)?
			_reset_ball(Vector4(0.0, 1.0, 0.70, 0.0))
			if t >= 0.4:
				_shot("move_a_theta90_at_wall_face.png")
				_advance()
		8: # And standing exactly ON the wall's own z, which collision forbids
			# but which shows what the slice WOULD contain if it were reachable.
			_reset_ball(Vector4(0.0, 1.0, 0.0, 0.0))
			if t >= 0.4:
				_shot("move_b_theta90_at_wall_centre.png")
				_advance()
		9: # Rotate back while sitting inside the wall's w-gap: the wall should
			# be absent from THIS cross-section, which is the puzzle's payoff.
			_reset_ball(Vector4(0.0, 1.0, 5.0, -6.0))
			if not _tapped:
				_tapped = true
				_tap_rotate()
			if _arrived(0.0) and t >= 0.6:
				_shot("move_c_theta0_inside_w_gap.png")
				_advance()
		10:
			print("MOVE: --- summary ---")
			for line in _log:
				print("MOVE: ", line)
			quit(0)
			return true
	return false
