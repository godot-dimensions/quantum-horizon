extends SceneTree

## Walks the one room, using the real controller and the real input actions.
##
## Not a physics reimplementation and not headless: this presses the same keys a
## person presses, lets `ascent_player_4d.gd` do everything, and runs with a
## rendering device so each phase can be looked at afterwards.
##
## The route it attempts is the intended solution, and nothing else:
##
##   1. walk forward to the near lip of the gap
##   2. hold `move_ana` until standing in the bridge's w band
##   3. walk forward across the bridge
##   4. hold `move_kata` back to w = 0
##
## It PASSES only if the player ends up on the far ledge, back in the home band,
## still standing. Falling, sticking, or crossing without shifting all fail.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/ObstacleCourse/_w_gap_test.gd

const SCENE := "res://ramon/ObstacleCourse/w_gap.tscn"
const WARMUP_FRAMES := 30
const PHASE_TIMEOUT := 14.0

enum Phase { TO_EDGE, SHIFT_ANA, CROSS, SHIFT_KATA, UP_THE_RAMP, DONE }

var _player: CharacterBody4D = null
var _course: Node4D = null
var _phase: int = Phase.TO_EDGE
var _frames: int = 0
var _elapsed: float = 0.0
var _failed: bool = false
var _bridge_w: float = 0.0
var _gap_near: float = 0.0
var _gap_far: float = 0.0
var _min_y: float = 1e9
var _ramp_top: float = 0.0
var _landing_x: float = 0.0


func _initialize() -> void:
	print("=== W-GAP: can the room be walked? ===")
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


## Read the room's real numbers off the generated tree rather than duplicating
## the builder's exports here, so the test cannot drift from what was built.
func _measure_room() -> void:
	var bridge: Node4D = _course.get_node_or_null(^"Bridge") as Node4D
	if bridge == null:
		push_error("no Bridge in the room")
		quit(1)
		return
	_bridge_w = bridge.global_position.w
	for child in bridge.get_children():
		var collider := child as CollisionShape4D
		if collider == null:
			continue
		var box := collider.shape as BoxShape4D
		if box != null:
			_gap_near = bridge.global_position.x - box.size.x * 0.5
			_gap_far = bridge.global_position.x + box.size.x * 0.5
	# The landing at the top of the ramp, in the player's own w band.
	#
	# Hard-failing on a missing landing rather than leaving _ramp_top at 0 is the
	# whole point: with it left at zero the "walked up the ramp" check became
	# `y > 0.5`, which was already true standing on the ground floor, and the test
	# reported a PASS while the player never climbed a centimetre. A test that
	# cannot fail is worse than no test.
	var landing: Node4D = _course.get_node_or_null(^"Landing1") as Node4D
	if landing == null:
		push_error("no Landing1 in the room - cannot measure the ramp")
		quit(1)
		return
	_landing_x = landing.global_position.x
	for child in landing.get_children():
		var collider := child as CollisionShape4D
		if collider == null:
			continue
		var box := collider.shape as BoxShape4D
		if box != null:
			_ramp_top = landing.global_position.y + box.size.y * 0.5
	if _ramp_top <= 0.5:
		push_error("ramp landing measured at y %.2f, which is not above the floor" % _ramp_top)
		quit(1)
		return
	print("gap spans x %.1f .. %.1f, bridge at w %.1f; ramp landing top y %.1f at x %.1f\n" % [
			_gap_near, _gap_far, _bridge_w, _ramp_top, _landing_x])


func _hold(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


## The player is spawned facing +x, so "forward" is `move_forward` and ana/kata
## map straight onto +/- w. Deliberately no mouse look: one variable at a time.
func _drive(forward: bool, ana: bool, kata: bool) -> void:
	_hold(&"move_forward", forward)
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
		_measure_room()

	var here: Vector4 = _player.global_position
	_min_y = minf(_min_y, here.y)
	_elapsed += delta

	match _phase:
		Phase.TO_EDGE:
			_drive(true, false, false)
			# Stop a stride short of the lip rather than at it, so the shift
			# happens on solid ground.
			if here.x > _gap_near - 1.5:
				_next("reached the lip at x %.2f" % here.x)
		Phase.SHIFT_ANA:
			_drive(false, true, false)
			if absf(here.w - _bridge_w) < 0.4:
				_next("shifted to w %.2f, in the bridge's band" % here.w)
		Phase.CROSS:
			_drive(true, false, false)
			if here.x > _gap_far + 1.5:
				_next("crossed to x %.2f" % here.x)
		Phase.SHIFT_KATA:
			_drive(false, false, true)
			if absf(here.w) < 0.4:
				_next("returned to w %.2f" % here.w)
		Phase.UP_THE_RAMP:
			# No jump input at all. If this reaches the landing, the ramp is
			# genuinely WALKED, which is the whole claim being tested.
			_drive(true, false, false)
			if here.y > _ramp_top + 0.5 and here.x > _landing_x - 2.0:
				_next("walked up the ramp to y %.2f (no jumping)" % here.y)
		Phase.DONE:
			_drive(false, false, false)
			_report()
			return true

	if _elapsed > PHASE_TIMEOUT:
		_failed = true
		print("  FAIL  phase %d timed out at (%.2f, %.2f, %.2f, %.2f)" % [_phase, here.x, here.y, here.z, here.w])
		_shoot("fail%d" % _phase)
		_report()
		return true
	return false


func _next(message: String) -> void:
	print("  ok    %s" % message)
	_shoot("phase%d" % _phase)
	_phase += 1
	_elapsed = 0.0


func _shoot(tag: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path("res://ramon/ObstacleCourse/wgap_%s.png" % tag))


func _report() -> void:
	var here: Vector4 = _player.global_position
	# Standing, not falling: the ledge top is y = 0 and the capsule half-height
	# is 0.875, so a standing player sits at about 0.875.
	# Standing on the ramp's landing now, not the ground floor.
	var standing: bool = absf(here.y - (_ramp_top + 0.875)) < 0.4
	var across: bool = here.x > _gap_far
	var home_band: bool = absf(here.w) < 0.4
	var climbed: bool = here.y > _ramp_top + 0.5
	print("\nfinal: (%.2f, %.2f, %.2f, %.2f)  lowest y reached %.2f" % [here.x, here.y, here.z, here.w, _min_y])
	if _failed or not (standing and across and home_band and climbed):
		print("=== FAIL: across=%s standing=%s home_band=%s climbed=%s ===" % [across, standing, home_band, climbed])
		quit(1)
	else:
		print("=== PASS: crossed an unjumpable gap using w, came back, and walked up the ramp ===")
		quit(0)
