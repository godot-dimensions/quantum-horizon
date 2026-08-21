extends SceneTree

## The ascent primitive: is the way UP genuinely only available through w?
##
## Two halves, and the first matters more than the second:
##
##   NEGATIVE - in the home band, running and jumping at the high ledge must FAIL.
##              A puzzle that can be brute-forced is not a puzzle, and this is the
##              check that catches it.
##   POSITIVE - shifting to the helper's band, jumping the helper, and walking off
##              it onto the high ledge must SUCCEED.
##
## Both are needed. Testing only that the solution works would happily pass a
## room whose "solution" was optional.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/ObstacleCourse/_w_step_test.gd

const SCENE := "res://ramon/ObstacleCourse/w_gap.tscn"
const WARMUP_FRAMES := 30
const PHASE_TIMEOUT := 9.0
const HALF_HEIGHT := 0.875

enum Phase { BRUTE_FORCE, SHIFT, JUMP_HELPER, WALK_UP, DONE }

var _player: CharacterBody4D = null
var _course: Node4D = null
var _phase: int = Phase.BRUTE_FORCE
var _frames: int = 0
var _elapsed: float = 0.0
var _failed: bool = false

var _landing_top: float = 0.0
var _high_top: float = 0.0
var _helper_top: float = 0.0
var _helper_w: float = 0.0
var _approach_x: float = 0.0
var _brute_best: float = -1e9


func _initialize() -> void:
	print("=== W STEP: is the way up only available through w? ===")
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


func _top_of(node: Node4D) -> float:
	for child in node.get_children():
		var collider := child as CollisionShape4D
		if collider == null:
			continue
		var box := collider.shape as BoxShape4D
		if box != null:
			return node.global_position.y + box.size.y * 0.5
	return 0.0


func _measure() -> void:
	var landing: Node4D = _course.get_node_or_null(^"Landing1") as Node4D
	var high: Node4D = _course.get_node_or_null(^"HighLedge1") as Node4D
	var helper: Node4D = _course.get_node_or_null(^"HelperStep") as Node4D
	if landing == null or high == null or helper == null:
		push_error("room is missing Landing1 / HighLedge1 / HelperStep")
		quit(1)
		return
	_landing_top = _top_of(landing)
	_high_top = _top_of(high)
	_helper_top = _top_of(helper)
	_helper_w = helper.global_position.w
	# Start on the landing, a run-up short of the high ledge.
	var high_near: float = high.global_position.x
	for child in high.get_children():
		var collider := child as CollisionShape4D
		if collider == null:
			continue
		var box := collider.shape as BoxShape4D
		if box != null:
			high_near = high.global_position.x - box.size.x * 0.5
	_approach_x = high_near - 5.0
	print("landing top %.2f, high ledge %.2f (+%.2f), helper %.2f (+%.2f) in band w %.1f" % [
			_landing_top, _high_top, _high_top - _landing_top,
			_helper_top, _helper_top - _landing_top, _helper_w])
	print("helper -> high ledge is %.2f m\n" % (_high_top - _helper_top))
	_reset_to_approach(0.0)


func _reset_to_approach(w: float) -> void:
	_player.global_position = Vector4(_approach_x, _landing_top + HALF_HEIGHT + 0.1, 0.0, w)
	_player.linear_velocity = Vector4()


func _hold(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _drive(forward: bool, jump: bool, ana: bool, kata: bool) -> void:
	_hold(&"move_forward", forward)
	# Pulsed, never held: the controller jumps on `is_action_just_pressed`, so a
	# held key gives exactly one jump for the whole run.
	_hold(&"move_jump", jump and _player.is_on_floor())
	_hold(&"move_ana", ana)
	_hold(&"move_kata", kata)


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
	var feet: float = here.y - HALF_HEIGHT
	_elapsed += delta

	match _phase:
		Phase.BRUTE_FORCE:
			# Everything a determined player would try, in the wrong band.
			_drive(true, true, false, false)
			# Only count height the player is actually STANDING at. The first
			# version took the peak of a jump, which reached 4.07 m - the landing
			# at 3.00 plus the 1.03 m apex - and called a ledge at 4.50 climbable.
			# Reaching a height mid-air is not getting up there.
			if _player.is_on_floor():
				_brute_best = maxf(_brute_best, feet)
			if _elapsed > PHASE_TIMEOUT:
				var got_up: bool = _brute_best > _landing_top + 0.3 # standing, not airborne
				if got_up:
					_failed = true
					print("  FAIL  brute force reached feet %.2f - the high ledge is climbable WITHOUT w" % _brute_best)
				else:
					print("  ok    brute force blocked: best STANDING feet %.2f against a ledge at %.2f" % [_brute_best, _high_top])
				_next_phase(_helper_w)
		Phase.SHIFT:
			var toward_ana: bool = _helper_w > 0.0
			_drive(false, false, toward_ana, not toward_ana)
			if absf(here.w - _helper_w) < 0.4:
				print("  ok    shifted to w %.2f, the helper's band" % here.w)
				_next_phase(here.w)
		Phase.JUMP_HELPER:
			_drive(true, true, false, false)
			if absf(feet - _helper_top) < 0.15 and _player.is_on_floor():
				print("  ok    jumped onto the helper at feet %.2f" % feet)
				_next_phase(here.w)
		Phase.WALK_UP:
			# No jump: the last move must be a WALK, via step-up.
			_drive(true, false, false, false)
			if absf(feet - _high_top) < 0.15 and _player.is_on_floor():
				print("  ok    walked up onto the high ledge at feet %.2f (no jump)" % feet)
				_next_phase(here.w)
		Phase.DONE:
			_drive(false, false, false, false)
			_report(feet)
			return true

	if _elapsed > PHASE_TIMEOUT and _phase != Phase.BRUTE_FORCE:
		_failed = true
		print("  FAIL  phase %d timed out at feet %.2f, w %.2f" % [_phase, feet, here.w])
		_report(feet)
		return true
	return false


func _next_phase(w: float) -> void:
	_phase += 1
	_elapsed = 0.0
	if _phase == Phase.SHIFT:
		# Back to the approach for the real attempt, still in the home band.
		_reset_to_approach(0.0)


func _report(feet: float) -> void:
	_drive(false, false, false, false)
	var on_high: bool = absf(feet - _high_top) < 0.2
	print("\nfinal feet %.2f, high ledge %.2f" % [feet, _high_top])
	if _failed or not on_high:
		print("=== FAIL ===")
		quit(1)
	else:
		print("=== PASS: unreachable in the home band, reachable through w ===")
		quit(0)
