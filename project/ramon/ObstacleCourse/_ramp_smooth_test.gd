extends SceneTree

## Is walking up the ramp SMOOTH, or is it a staircase?
##
## "Feels like stairs" is a measurable claim, not a matter of taste: it means the
## body's height jumps in visible increments instead of rising steadily. So this
## walks the ramp with real input and records the per-frame change in y, then
## reports the worst single jump and the average.
##
## Reference: the hidden treads are ~0.09 m apart at the default tread size. If
## the biggest per-frame rise is around that, the body is hopping tread to tread.
## If it is a few centimetres, it is gliding.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/ObstacleCourse/_ramp_smooth_test.gd

const SCENE := "res://ramon/ObstacleCourse/w_gap.tscn"
const WARMUP_FRAMES := 30
const TIMEOUT := 25.0

## Anything above this in one frame reads as a hop rather than a stride.
const SMOOTH_LIMIT := 0.06

var _player: CharacterBody4D = null
var _course: Node4D = null
var _ramp_start: float = 0.0
var _ramp_top: float = 0.0
var _frames: int = 0
var _elapsed: float = 0.0
var _last_y: float = 0.0
var _climbing: bool = false
var _jumps: Array[float] = []
var _camera: Node4D = null


func _initialize() -> void:
	print("=== RAMP SMOOTHNESS (measured at the eye) ===")
	var packed: PackedScene = load(SCENE)
	if packed == null:
		push_error("could not load %s" % SCENE)
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	set_current_scene(scene)
	_player = scene.get_node_or_null(^"Player") as CharacterBody4D
	_course = scene.get_node_or_null(^"Course") as Node4D
	# Sample the CAMERA, not the body. The collider necessarily steps; the
	# question "does it feel like stairs" is about what the eye does.
	_camera = scene.get_node_or_null(^"Player/PlayerHead/FirstPersonCamera") as Node4D


func _measure() -> void:
	var landing: Node4D = _course.get_node_or_null(^"Landing1") as Node4D
	if landing == null:
		push_error("no Landing1 - cannot find the ramp")
		quit(1)
		return
	for child in landing.get_children():
		var collider := child as CollisionShape4D
		if collider == null:
			continue
		var box := collider.shape as BoxShape4D
		if box != null:
			_ramp_top = landing.global_position.y + box.size.y * 0.5
	# The lowest ramp step marks where the climb begins.
	var steps: Node = _course.get_node_or_null(^"Ramp1_Steps")
	if steps == null:
		push_error("no Ramp1_Steps - cannot find the ramp")
		quit(1)
		return
	_ramp_start = 1e9
	for step in steps.get_children():
		_ramp_start = minf(_ramp_start, (step as Node4D).global_position.x)
	print("ramp starts at x %.2f, landing top y %.2f\n" % [_ramp_start, _ramp_top])
	# Drop the player straight onto the ramp's approach so the test is only about
	# the climb, with the w puzzle and the jump boxes out of the way.
	_player.global_position = Vector4(_ramp_start - 3.0, 1.0, 0.0, 0.0)
	_player.linear_velocity = Vector4()
	_last_y = _eye_y()


func _eye_y() -> float:
	return _camera.global_position.y if _camera != null else _player.global_position.y


func _hold(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _physics_process(delta: float) -> bool:
	if _player == null or _course == null:
		push_error("scene is missing Player or Course")
		quit(1)
		return true
	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	if _frames == WARMUP_FRAMES:
		_measure()

	var here: Vector4 = _player.global_position
	_elapsed += delta
	_hold(&"move_forward", true)

	# Only sample while actually on the slope, so the flat approach and the
	# landing do not dilute the numbers.
	if here.x > _ramp_start and here.y < _ramp_top + 0.5:
		var eye: float = _eye_y()
		if not _climbing:
			_climbing = true
			_last_y = eye
		else:
			var rise: float = eye - _last_y
			if rise > 0.0005:
				_jumps.append(rise)
			_last_y = eye

	if here.y > _ramp_top + 0.6:
		_report(true)
		return true
	if _elapsed > TIMEOUT:
		_report(false)
		return true
	return false


func _report(reached: bool) -> void:
	_hold(&"move_forward", false)
	if _jumps.is_empty():
		print("no upward motion recorded - the ramp was never climbed")
		quit(1)
		return
	var worst: float = 0.0
	var total: float = 0.0
	var hops: int = 0
	for rise: float in _jumps:
		worst = maxf(worst, rise)
		total += rise
		if rise > SMOOTH_LIMIT:
			hops += 1
	var average: float = total / float(_jumps.size())
	print("reached the landing: %s" % reached)
	print("upward frames      : %d" % _jumps.size())
	print("average rise/frame : %.4f m" % average)
	print("worst rise/frame   : %.4f m" % worst)
	print("frames over %.2f m : %d" % [SMOOTH_LIMIT, hops])
	if reached and worst <= SMOOTH_LIMIT:
		print("\n=== SMOOTH: no single frame rose more than %.2f m ===" % SMOOTH_LIMIT)
		quit(0)
	else:
		print("\n=== NOT SMOOTH: %d frame(s) hopped, worst %.3f m ===" % [hops, worst])
		quit(1)
