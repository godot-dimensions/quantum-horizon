extends SceneTree

## Plays one of the levels in levels/ end to end with a real rendering device and
## asserts it is actually solvable, screenshotting each beat.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/MiegakureLook/_visual_probe_levels.gd -- 3
##
## The argument is the level number (default 1). Each level's route is a list of
## timed key-holds and rotations, walked with ONE key at a time - if a route ever
## needs two keys held together to follow a world axis, the camera and the
## movement basis have come back out of alignment and that is the bug to chase.
##
## Input injection: the rotation is an EVENT action (`_input` +
## is_action_pressed) so it needs Input.parse_input_event() with a real
## InputEventMouseButton; movement is POLLED (Input.get_axis) so that needs
## Input.action_press(). parse_input_event also lands a frame late, so each
## rotation step waits for the slice angle to actually arrive rather than trusting
## is_transitioning() - which is false in the gap BEFORE the transition starts too.
##
## At 90 degrees "forward" moves toward -w, so a leg that has to travel toward +w
## is walked with move_back. Level 3's second leg does exactly that.

const OUT_DIR := "res://ramon/MiegakureLook/"

## Each entry is either {"rotate": true} or {"key": <action>, "time": <seconds>}.
const ROUTES := {
	1: [
		{"key": "move_forward", "time": 1.2, "shot": "stopped at the wall"},
		{"rotate": true, "shot": "rotated - lanes visible"},
		{"key": "move_forward", "time": 1.5, "shot": "walked to the yellow lane"},
		{"rotate": true, "shot": "wall is gone from this slice"},
		{"key": "move_forward", "time": 2.4, "shot": "through the wall, on the goal"},
	],
	2: [
		{"key": "move_forward", "time": 1.2, "shot": "at the chasm lip"},
		{"rotate": true, "shot": "rotated - lanes visible"},
		{"key": "move_forward", "time": 1.5, "shot": "walked to the cyan lane"},
		{"rotate": true, "shot": "bridge exists in this slice"},
		{"key": "move_forward", "time": 1.8, "shot": "crossed, on the goal"},
	],
	3: [
		{"key": "move_forward", "time": 1.2, "shot": "stopped at the wall"},
		{"rotate": true, "shot": "rotated - both lanes visible"},
		{"key": "move_forward", "time": 1.5, "shot": "walked to the yellow lane"},
		{"rotate": true, "shot": "wall is gone"},
		{"key": "move_forward", "time": 0.75, "shot": "past the wall, at the chasm lip"},
		{"rotate": true, "shot": "rotated again"},
		# The other way along w this time - hence move_back, not move_forward.
		{"key": "move_back", "time": 2.5, "shot": "travelled back to the cyan lane"},
		{"rotate": true, "shot": "bridge exists"},
		{"key": "move_forward", "time": 1.7, "shot": "crossed, on the goal"},
	],
}

const SCENES := {
	1: "res://ramon/MiegakureLook/levels/level_1_wall.tscn",
	2: "res://ramon/MiegakureLook/levels/level_2_bridge.tscn",
	3: "res://ramon/MiegakureLook/levels/level_3_detour.tscn",
}

var _level: int = 1
var _route: Array = []
var _root_node: Node = null
var _ball: Node = null
var _camera: Node = null
var _banner: Node = null
var _elapsed: float = 0.0
var _index: int = -1
var _step_started: float = 0.0
var _tapped: bool = false
var _expect_angle: float = 0.0
var _pass: PackedStringArray = PackedStringArray()
var _fail: PackedStringArray = PackedStringArray()
var _awaiting_advance: bool = false
var _expected_next: String = ""
var _advance_deadline: float = 0.0

const LevelFlow = preload("res://ramon/MiegakureLook/scripts/level_flow.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_level = int(args[0]) if args.size() > 0 else 1
	if not SCENES.has(_level):
		printerr("LVL: no such level ", _level)
		quit(1)
		return
	_route = ROUTES[_level]

	var packed: PackedScene = load(SCENES[_level])
	if packed == null:
		printerr("LVL: could not load ", SCENES[_level])
		quit(1)
		return
	_root_node = packed.instantiate()
	root.add_child(_root_node)
	set_current_scene(_root_node)
	_ball = _root_node.get_node("Ball")
	_camera = _root_node.get_node("CameraRig")
	_banner = _root_node.get_node("GoalBanner")
	print("LVL %d: %s" % [_level, SCENES[_level]])
	_check("gauge script loaded", _root_node.get_node("WReadout").get_script() != null)


func _check(what: String, ok: bool, detail: String = "") -> void:
	var line := "%s%s" % [what, "" if detail.is_empty() else " (" + detail + ")"]
	if ok:
		_pass.append(line)
		print("LVL%d PASS: %s" % [_level, line])
	else:
		_fail.append(line)
		print("LVL%d FAIL: %s" % [_level, line])


func _tap_rotate() -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		Input.parse_input_event(event)


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)


func _shot(label: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("LVL: no viewport image - running headless by mistake?")
		return
	var name := "level%d_%d_%s.png" % [_level, maxi(_index, 0), label.replace(" ", "_").replace(",", "")]
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + name))
	# The hand-off screenshot is taken AFTER change_scene_to_file has freed the
	# old scene, so these references are dead by then - hence the validity guard
	# rather than an unconditional read.
	if not is_instance_valid(_ball) or not is_instance_valid(_camera):
		print("LVL%d: %-34s (previous scene freed)" % [_level, label])
		return
	var p: Vector4 = _ball.global_position
	print("LVL%d: %-34s ball=(%+.2f %+.2f %+.2f %+.2f) floor=%s cam=%.0fdeg" % [
		_level, label, p.x, p.y, p.z, p.w,
		"Y" if _ball.is_on_floor() else "N", _camera.get_current_angle_degrees(),
	])


func _arrived(degrees: float) -> bool:
	return not _camera.is_transitioning() and absf(_camera.get_current_angle_degrees() - degrees) < 0.5


## Checks the level was solved, then - the part that was missing until the level
## flow existed - waits for it to actually hand over to the next level, instead
## of assuming the banner appearing is the end of the story.
func _finish() -> void:
	var p: Vector4 = _ball.global_position
	_check("reached the goal", _banner._is_shown())
	_check("never ended up falling", _ball.is_on_floor(), "y=%+.2f" % p.y)
	_check("stayed between the rails", absf(p.x) < 6.5, "x=%+.2f" % p.x)

	_expected_next = LevelFlow.next_scene_path(SCENES[_level])
	if _expected_next.is_empty():
		_check("last level, so nothing to advance to", LevelFlow.level_number(SCENES[_level]) == LevelFlow.total())
		_report()
		return
	# Everything below must stop touching _ball/_camera/_banner: the scene change
	# frees them.
	_awaiting_advance = true
	_advance_deadline = _elapsed + 6.0
	print("LVL%d: waiting for hand-off to %s" % [_level, _expected_next])


func _report() -> void:
	print("LVL%d: --- %d passed, %d failed ---" % [_level, _pass.size(), _fail.size()])
	for line in _fail:
		print("LVL%d: STILL FAILING: %s" % [_level, line])
	quit(0 if _fail.is_empty() else 1)


func _process(delta: float) -> bool:
	_elapsed += delta

	if _awaiting_advance:
		# This script IS the SceneTree, so current_scene is read directly - there
		# is no get_tree() on self.
		var scene: Node = current_scene
		var path: String = scene.scene_file_path if scene != null else ""
		if path == _expected_next:
			_check("handed over to the next level", true, path.get_file())
			# Prove the new level is actually live, not just loaded: it must have
			# built its own geometry and rebound its own gauge.
			var builder: Node = scene.get_node_or_null("Builder")
			_check("next level built its geometry", builder != null and builder.get_child_count() > 0,
					"children=%d" % (builder.get_child_count() if builder != null else -1))
			_shot("next level running")
			_report()
			return true
		if _elapsed > _advance_deadline:
			_check("handed over to the next level", false, "still on %s after 6 s" % path.get_file())
			_report()
			return true
		return false

	if _index < 0:
		if _elapsed >= 1.0:
			_shot("start")
			_index = 0
			_step_started = _elapsed
			_tapped = false
		return false

	if _index >= _route.size():
		_finish()
		# Returning true from _process quits the SceneTree. When _finish has armed
		# the hand-off check we must keep ticking, or the tree exits before the
		# level's own transition timer has had a chance to fire - which looks
		# exactly like the transition being broken.
		return not _awaiting_advance

	var step: Dictionary = _route[_index]
	var t := _elapsed - _step_started

	if step.has("rotate"):
		if not _tapped:
			_tapped = true
			_expect_angle = 90.0 if _camera.get_current_angle_degrees() < 45.0 else 0.0
			_tap_rotate()
		if _arrived(_expect_angle):
			_shot(step["shot"])
			_index += 1
			_step_started = _elapsed
			_tapped = false
		return false

	Input.action_press(step["key"])
	if t >= float(step["time"]):
		_release_all()
		_shot(step["shot"])
		_index += 1
		_step_started = _elapsed
		_tapped = false
	return false
