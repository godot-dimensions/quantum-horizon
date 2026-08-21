extends SceneTree

## Does the W lift work, and is it necessary?
##
##   NEGATIVE - walking along w from the near pad must FALL. If the void can be
##              walked across, the lift is decoration.
##   POSITIVE - standing on the disc must carry you to the far pad, and you must
##              be able to step off onto solid ground.
##
## The negative half is the one that decides whether this obstacle exists.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/ObstacleCourse/_lift_test.gd

const SCENE := "res://ramon/ObstacleCourse/w_gap.tscn"
const WARMUP_FRAMES := 30
const HALF_HEIGHT := 0.875

enum Phase { WALK_INTO_VOID, BOARD, RIDE, STEP_OFF, DONE }

var _player: CharacterBody4D = null
var _course: Node4D = null
var _lift: Node4D = null
var _phase: int = Phase.WALK_INTO_VOID
var _frames: int = 0
var _elapsed: float = 0.0
var _failed: bool = false

var _pad_top: float = 0.0
var _near_x: float = 0.0
var _far_w: float = 0.0
var _lowest_y: float = 1e9
var _timeout: float = 9.0


func _initialize() -> void:
	print("=== W LIFT: does it work, and is it needed? ===")
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


func _measure() -> void:
	var near_pad: Node4D = _course.get_node_or_null(^"LiftPadNear") as Node4D
	var far_pad: Node4D = _course.get_node_or_null(^"LiftPadFar") as Node4D
	_lift = _course.get_node_or_null(^"WLift") as Node4D
	if near_pad == null or far_pad == null or _lift == null:
		push_error("room is missing LiftPadNear / LiftPadFar / WLift")
		quit(1)
		return
	_near_x = near_pad.global_position.x
	_far_w = far_pad.global_position.w
	for child in near_pad.get_children():
		var collider := child as CollisionShape4D
		if collider == null:
			continue
		var box := collider.shape as BoxShape4D
		if box != null:
			_pad_top = near_pad.global_position.y + box.size.y * 0.5
	print("pads at x %.1f, top y %.2f; near w 0.0, far w %.1f" % [_near_x, _pad_top, _far_w])
	print("void spans roughly w 2.5 .. %.1f\n" % (_far_w - 2.5))
	_stand_on_near_pad()


func _stand_on_near_pad() -> void:
	_player.global_position = Vector4(_near_x, _pad_top + HALF_HEIGHT + 0.1, 0.0, 0.0)
	_player.linear_velocity = Vector4()
	_lowest_y = _player.global_position.y


func _hold(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _drive(ana: bool) -> void:
	_hold(&"move_ana", ana)


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
	_lowest_y = minf(_lowest_y, here.y)
	_elapsed += delta

	match _phase:
		Phase.WALK_INTO_VOID:
			# Try to cross the void on foot. This SHOULD fail.
			_drive(true)
			if _elapsed > 5.0:
				var fell: bool = _lowest_y < _pad_top - 3.0
				var crossed: bool = absf(here.w - _far_w) < 1.5 and here.y > _pad_top - 1.0
				if crossed:
					_failed = true
					print("  FAIL  walked across the void at w %.1f - the lift is not needed" % here.w)
				elif fell:
					print("  ok    walking into the void fell (lowest y %.2f, from a pad at %.2f)" % [_lowest_y, _pad_top])
				else:
					print("  ok    walking into the void got stuck at w %.1f, never reached w %.1f" % [here.w, _far_w])
				_advance()
		Phase.BOARD:
			# Wait on the pad for the disc to come home, then stand on it.
			_drive(false)
			if absf(_lift.position.w) < 0.6:
				_player.global_position = Vector4(_near_x, _pad_top + HALF_HEIGHT + 0.1, 0.0, _lift.position.w)
				_player.linear_velocity = Vector4()
				print("  ok    boarded with the disc at w %.2f" % _lift.position.w)
				_advance()
		Phase.RIDE:
			# Hands off. If the lift carries, w rises on its own.
			_drive(false)
			if absf(here.w - _far_w) < 1.2:
				print("  ok    carried to w %.2f without touching a key" % here.w)
				_advance()
		Phase.STEP_OFF:
			_drive(true)
			if here.y > _pad_top - 0.5 and absf(here.w - _far_w) < 2.5 and _player.is_on_floor():
				print("  ok    stepped off onto the far pad, standing at w %.2f" % here.w)
				_advance()
		Phase.DONE:
			_drive(false)
			_report(here)
			return true

	if _elapsed > _timeout and _phase != Phase.WALK_INTO_VOID:
		_failed = true
		print("  FAIL  phase %d timed out at w %.2f, y %.2f" % [_phase, here.w, here.y])
		_report(here)
		return true
	return false


func _advance() -> void:
	_phase += 1
	_elapsed = 0.0
	# Boarding waits for the disc to come back round, which can take a full
	# traverse plus its dwell at each end.
	_timeout = 22.0 if _phase == Phase.BOARD else 12.0
	if _phase == Phase.BOARD:
		_stand_on_near_pad()


func _report(here: Vector4) -> void:
	_drive(false)
	var arrived: bool = absf(here.w - _far_w) < 2.5 and here.y > _pad_top - 0.5
	print("\nfinal w %.2f (target %.1f), y %.2f" % [here.w, _far_w, here.y])
	if _failed or not arrived:
		print("=== FAIL ===")
		quit(1)
	else:
		print("=== PASS: the void blocks walking, the lift carries across it ===")
		quit(0)
