extends SceneTree

## The braided corridor: two paths, one corridor, and neither one complete.
##
## Structural first, because it is instant and decides whether the obstacle
## exists at all: each lane must be MISSING a segment, and the two must be missing
## DIFFERENT ones. If either lane is whole, the corridor can be walked without
## ever changing band and the braid is scenery.
##
## Then played: walk lane A, switch band at its gap, carry on, reach the end.
##
##   godot.windows.editor.double.x86_64.console.exe --path project \
##       --script res://ramon/ObstacleCourse/_braid_test.gd

const SCENE := "res://ramon/ObstacleCourse/w_gap.tscn"
const WARMUP_FRAMES := 30
const HALF_HEIGHT := 0.875
const PHASE_TIMEOUT := 12.0

enum Phase { WALK_A, SWITCH, WALK_B, DONE }

var _player: CharacterBody4D = null
var _course: Node4D = null
var _phase: int = Phase.WALK_A
var _frames: int = 0
var _elapsed: float = 0.0
var _failed: bool = false

var _lane_a: Array = []
var _lane_b: Array = []
## The actual segment nodes, so the test can STEER along the path. The first
## version only pressed forward, and since the lanes drift 5.2 m sideways across
## the run it walked straight off the edge and the fall-reset put it back at
## spawn - which read as the corridor being broken when it was the driver that
## could not follow a curve.
var _nodes_a: Array = []
var _nodes_b: Array = []
var _fell: bool = false
var _deck_top: float = 0.0
var _end_x: float = 0.0
var _w_a: float = 0.0
var _w_b: float = 0.0


func _initialize() -> void:
	print("=== BRAIDED CORRIDOR ===")
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


## Neither lane may be complete, and their gaps must not coincide.
func _check_structure() -> bool:
	for child in _course.get_children():
		var name := String(child.name)
		if name.begins_with("Braid0_"):
			_lane_a.append(int(name.trim_prefix("Braid0_")))
			_nodes_a.append(child)
		elif name.begins_with("Braid1_"):
			_lane_b.append(int(name.trim_prefix("Braid1_")))
			_nodes_b.append(child)
	if _lane_a.is_empty() or _lane_b.is_empty():
		print("  FAIL  the braid was not built")
		return false
	_lane_a.sort()
	_lane_b.sort()
	var total: int = maxi(_lane_a[_lane_a.size() - 1], _lane_b[_lane_b.size() - 1]) + 1
	var missing_a: Array = []
	var missing_b: Array = []
	for index in total:
		if not _lane_a.has(index):
			missing_a.append(index)
		if not _lane_b.has(index):
			missing_b.append(index)
	print("  lane A has %d/%d segments, missing %s" % [_lane_a.size(), total, missing_a])
	print("  lane B has %d/%d segments, missing %s" % [_lane_b.size(), total, missing_b])
	if missing_a.is_empty() or missing_b.is_empty():
		print("  FAIL  a lane is complete - the corridor can be walked in one band, so the braid is scenery")
		return false
	for index: int in missing_a:
		if missing_b.has(index):
			print("  FAIL  both lanes are missing segment %d - that stretch is impassable in either band" % index)
			return false
	# A gap inside the jump reach can simply be jumped, which makes the band
	# switch optional and the whole corridor decoration. Segment length comes off
	# the built geometry so this cannot drift from what exists.
	var seg_length: float = _segment_length()
	var widest_a: float = _run_length(missing_a) * seg_length
	var widest_b: float = _run_length(missing_b) * seg_length
	print("  widest gap: lane A %.1f m, lane B %.1f m (walk-jump reach 4.59 m)" % [widest_a, widest_b])
	if widest_a <= 4.59 or widest_b <= 4.59:
		print("  FAIL  a gap is jumpable, so the band switch is optional")
		return false
	print("  ok    neither lane is complete, gaps do not coincide, and both are too wide to jump")
	return true


## Length of one segment, measured off two adjacent built segments.
func _segment_length() -> float:
	if _nodes_a.size() < 2:
		return 0.0
	var xs: Array[float] = []
	for node: Node4D in _nodes_a:
		xs.append(node.global_position.x)
	xs.sort()
	var smallest: float = 1e9
	for index in range(1, xs.size()):
		smallest = minf(smallest, xs[index] - xs[index - 1])
	return smallest


## Longest run of consecutive missing indices.
func _run_length(missing: Array) -> int:
	var best: int = 0
	var run: int = 0
	var previous: int = -99
	for index: int in missing:
		run = run + 1 if index == previous + 1 else 1
		best = maxi(best, run)
		previous = index
	return best


func _measure() -> void:
	if not _check_structure():
		_failed = true
		_report()
		return
	var first: Node4D = _course.get_node_or_null(NodePath("Braid0_%02d" % _lane_a[0])) as Node4D
	var end_pad: Node4D = _course.get_node_or_null(^"BraidEnd") as Node4D
	var lane_b_first: Node4D = _course.get_node_or_null(NodePath("Braid1_%02d" % _lane_b[0])) as Node4D
	if first == null or end_pad == null or lane_b_first == null:
		_failed = true
		print("  FAIL  cannot find the braid's ends")
		_report()
		return
	_w_a = first.global_position.w
	_w_b = lane_b_first.global_position.w
	_end_x = end_pad.global_position.x
	for child in first.get_children():
		var collider := child as CollisionShape4D
		if collider == null:
			continue
		var box := collider.shape as BoxShape4D
		if box != null:
			_deck_top = first.global_position.y + box.size.y * 0.5
	print("\n  lane A at w %.1f, lane B at w %.1f, end pad at x %.1f, deck top %.2f\n" % [
			_w_a, _w_b, _end_x, _deck_top])
	_player.global_position = Vector4(first.global_position.x, _deck_top + HALF_HEIGHT + 0.1,
			first.global_position.z, _w_a)
	_player.linear_velocity = Vector4()


func _hold(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


## Forward, plus strafe to stay on the lane, plus w when switching.
##
## The player faces +x, so `move_left`/`move_right` strafe along z - which is
## exactly the axis the lanes drift along.
func _drive(forward: bool, toward_b: bool, steer_lane: Array) -> void:
	_hold(&"move_forward", forward)
	var ana: bool = toward_b and _w_b > _w_a
	var kata: bool = toward_b and _w_b < _w_a
	_hold(&"move_ana", ana)
	_hold(&"move_kata", kata)

	var drift: float = 0.0
	if not steer_lane.is_empty():
		var here: Vector4 = _player.global_position
		# Aim a little ahead, the way a person looks where they are going.
		var look_at_x: float = here.x + 2.0
		var best: Node4D = null
		var best_gap: float = 1e9
		for node: Node4D in steer_lane:
			var gap: float = absf(node.global_position.x - look_at_x)
			if gap < best_gap:
				best_gap = gap
				best = node
		if best != null:
			drift = best.global_position.z - here.z
	_hold(&"move_right", drift > 0.25)
	_hold(&"move_left", drift < -0.25)


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
		if _failed:
			return true

	var here: Vector4 = _player.global_position
	var feet: float = here.y - HALF_HEIGHT
	_elapsed += delta

	if _phase != Phase.DONE and here.x < _end_x - braid_span() and not _fell:
		_fell = true
		_failed = true
		print("  FAIL  fell off and respawned (now at x %.1f) - the corridor was not survivable" % here.x)
		_report()
		return true

	match _phase:
		Phase.WALK_A:
			# Stop AT the lip, not in the hole. Walking for a fixed time instead
			# marched straight off the edge and the fall-reset hid the result.
			var ahead: float = _distance_to_next(_nodes_a, here.x)
			var at_lip: bool = ahead > _segment_length() * 1.6
			_drive(not at_lip, false, _nodes_a)
			if at_lip:
				print("  ok    walked lane A to its lip at x %.1f" % here.x)
				_advance()
		Phase.SWITCH:
			_drive(false, true, _nodes_b)
			if absf(here.w - _w_b) < 0.5:
				print("  ok    switched to lane B's band, w %.2f" % here.w)
				_advance()
		Phase.WALK_B:
			_drive(true, false, _nodes_b)
			if here.x > _end_x - 3.0 and feet > _deck_top - 0.6:
				print("  ok    reached the end pad at x %.1f, still standing" % here.x)
				_advance()
		Phase.DONE:
			_drive(false, false, [])
			_report()
			return true

	if _elapsed > PHASE_TIMEOUT and _phase != Phase.WALK_A:
		_failed = true
		print("  FAIL  phase %d timed out at x %.1f, w %.2f, feet %.2f" % [_phase, here.x, here.w, feet])
		_report()
		return true
	return false


## Gap in x to the nearest segment ahead of [param from_x]. Large when standing at
## the lip of a hole.
func _distance_to_next(lane: Array, from_x: float) -> float:
	var nearest: float = 1e9
	for node: Node4D in lane:
		var dx: float = node.global_position.x - from_x
		if dx > 0.3:
			nearest = minf(nearest, dx)
	return nearest


## Roughly how long the braid is, used only to notice a respawn.
func braid_span() -> float:
	return 60.0


func _advance() -> void:
	_phase += 1
	_elapsed = 0.0


func _report() -> void:
	_drive(false, false, [])
	if _failed:
		print("\n=== FAIL ===")
		quit(1)
	else:
		var here: Vector4 = _player.global_position
		print("\nfinal x %.1f, w %.2f, y %.2f" % [here.x, here.w, here.y])
		print("=== PASS: two paths in one corridor, neither complete alone ===")
		quit(0)
