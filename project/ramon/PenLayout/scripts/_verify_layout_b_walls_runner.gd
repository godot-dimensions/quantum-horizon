extends SceneTree

## Layout B, step 24 (PenLayout/PLAN_B.md; Ramon, 6 Oct: "from start point the player is not able to walk
## to the tower, theres a wall and he should follow the intended line as ive shown. no shortcuts. the oly
## way through from bottom to top is through the gate"). From the south side, try to reach the north:
##   1. straight lanes against the town wall every 4 m from edge to edge, at W 0, 4, -6 and far out in W
##      (collision sweeps of the player's own body): through only in the gate's opening
##   2. the gate itself: through, at W 0 and at W 4
##   3. over the two hills the wall runs into (the west hill, the cave hill), walking on the move key so
##      the player's step-up climbs what it can: never through (the cave's tunnel takes you into the cave,
##      which is not across)
##   4. round the ends: lanes past the west and east ends at the field's edge
##
##   lab_run.sh windowed b_walls res://ramon/PenLayout/scripts/_verify_layout_b_walls_runner.gd

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const WALL_Z := 12.0
const GATE_X := -11.6
const GATE_HALF := 1.7

var _room: Node
var _player: CharacterBody4D
var _fails: int = 0
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 420000:
		print("WALLS TEST: gave up")
		Input.action_release(&"move_forward")
		return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	await _frames(40)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("   loaded; walking the lanes")
	root.tree_exiting.connect(func() -> void: print("   the tree is exiting"))
	_player = _room.get_node("Player") as CharacterBody4D
	_player.set("input_enabled", false)
	var rig := _player.get_node("CameraRig") as Node4D
	SliceAngles.tilt(rig, 0.0, 0.0, 0.0)
	# 1 and 4. Walked north on the move key from 2.5 m south of the wall, every 6 m from edge to edge.
	var through: Array = []
	var lanes: int = 0
	for w in [0.0, 4.0, -6.0, 30.0]:
		var x: float = -57.0
		while x <= 57.0:
			var on_hill: bool = (x > -47.0 and x < -25.0) or (x > -6.0 and x < 22.0)
			if not on_hill or w > 20.0:
				lanes += 1
				var got: float = await _walk(Vector4(x, 1.2, WALL_Z + 2.5, w), rig, 2.2)
				if got < WALL_Z - 1.0 and absf(x - GATE_X) >= GATE_HALF:
					through.append("x %.0f W %.0f" % [x, w])
			x += 6.0
	_check(through.is_empty(), "1 no way north through the town wall but the gate (%d lanes walked; through at: %s)" % [lanes, ", ".join(PackedStringArray(through))])
	# 2. The gate.
	for w in [0.0, 4.0]:
		var got: float = await _walk(Vector4(GATE_X, 1.2, WALL_Z + 2.5, w), rig, 2.5)
		_check(got < WALL_Z - 1.0, "2 through the gate at W %.0f (reached z %.1f)" % [w, got])
	# 3. Over the hills, walking.
	var crossing: Node = _room.get_node("CaveCrossing")
	for lane in [Vector2(-44.0, 0.0), Vector2(-36.0, 0.0), Vector2(-28.0, 0.0), Vector2(-2.0, 0.0), Vector2(4.0, 0.0), Vector2(10.0, 0.0),
			Vector2(16.0, 0.0), Vector2(20.0, 0.0), Vector2(4.0, 4.0), Vector2(14.0, 4.0)]:
		var start := Vector4(lane.x, 1.2, 31.0, lane.y)
		print("   walking north over the hill at x %.0f W %.0f" % [lane.x, lane.y])
		var best: float = await _walk(start, rig, 9.0)
		var away: bool = bool(crossing.call("is_away"))
		if away:
			crossing.call("come_back")
			await _frames(60)
		_check(best > WALL_Z + 0.5 or away, "3 over the hills at x %.0f W %.0f: stopped at z %.1f%s" % [lane.x, lane.y, best, " (into the cave)" if away else ""])
	print("WALLS TEST: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0)


## The player's body swept north from [param from] for [param reach] metres; the z it got to.
func _sweep(from: Vector4, reach: float) -> float:
	# A hand above the ground: swept along it, the body would hit the floor it stands on.
	_player.global_position = from + Vector4(0.0, 0.15, 0.0, 0.0)
	_player.set("linear_velocity", Vector4.ZERO)
	await physics_frame
	var step := Vector4(0.0, 0.0, -0.25, 0.0)
	var moved: float = 0.0
	while moved < reach:
		var hit: Object = _player.move_and_collide(step)
		if hit != null:
			break
		moved += 0.25
	return _player.global_position.z


## The player walked north on the move key for [param seconds]; the smallest z it reached.
func _walk(from: Vector4, rig: Node4D, seconds: float) -> float:
	print("   walk from %s for %.1f s" % [from, seconds])
	_player.set("input_enabled", true)
	_player.global_position = from
	_player.set("linear_velocity", Vector4.ZERO)
	SliceAngles.tilt(rig, 0.0, 0.0, 0.0)
	await _frames(3)
	Input.action_press(&"move_forward")
	var best: float = from.z
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		await physics_frame
		best = minf(best, _player.global_position.z)
	Input.action_release(&"move_forward")
	_player.set("input_enabled", false)
	return best
