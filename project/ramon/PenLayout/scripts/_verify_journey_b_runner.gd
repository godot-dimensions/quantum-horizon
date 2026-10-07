extends SceneTree

## LAYOUT B, FRONT TO BACK, WALKED (PenLayout/PLAN_B_ROUND2.md step 39-47; Ramon, 7 Oct: "a good thorough
## playtest in the end. see if all works for going in and out of cave, other sequences and animations..
## if all works well. front to back"). The route the paths draw (paths/pen_b.tres), walked on the move key
## with the camera steered at the next point, as a player walks it: start, Trym's house, the pen, the bend,
## through the gate, the range, the camp, the tower; then the cave, up its path through W to the door,
## in, out, and in and out again in the dev look. At each stop a frame (smoke_test_output/pen_layout/
## journey/) and at each leg a check that you got there and were never stuck (5 s without getting closer).
## The old opening runner (_verify_opening_runner.gd) is layout A's.
##
##   lab_run.sh windowed journey res://ramon/PenLayout/scripts/_verify_journey_b_runner.gd

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")
const OUT := "res://smoke_test_output/pen_layout/journey/"
## [name, x, z, frame here (facing yaw in degrees, or NAN for none)]
const ROUTE := [
	["to the junction", 24.9, 36.0, NAN],
	["Trym's house", 24.9, 40.0, 180.0],
	["back to the junction", 24.9, 37.1, NAN],
	["past the cave's turn", 7.3, 37.1, NAN],
	["the far junction", -4.0, 37.1, NAN],
	["the pen", -13.2, 37.1, 90.0],
	["back to the far junction", -5.0, 36.0, NAN],
	["the bend", -11.1, 23.1, NAN],
	["through the gate", -11.8, 8.0, 0.0],
	["the range's turn", -12.3, 2.1, NAN],
	["the range", -18.3, 2.1, 90.0],
	["back to the range's turn", -12.3, 2.1, NAN],
	["the camp's turn", -12.7, -3.9, NAN],
	["the camp", 5.4, -4.0, -90.0],
	["back to the camp's turn", -12.0, -3.9, NAN],
	["the tower", -17.5, -26.5, 20.0],
]

var _room: Node
var _player: CharacterBody4D
var _rig: Node4D
var _fails: int = 0
var _t0: int = 0
var _shot: int = 0
var _state_said: bool = false


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 600000:
		print("JOURNEY: gave up after 600 s")
		_release()
		return true
	return false


func _check(ok: bool, what: String, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _frame(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	_shot += 1
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%02d_%s.png" % [_shot, name.replace(" ", "_").replace("'", "")]))


func _release() -> void:
	for a in [&"move_forward", &"move_ana", &"move_kata"]:
		Input.action_release(a)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_journey_test.cfg")
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	var guard := Node.new()
	guard.set_script(load("res://ramon/PenLayout/scripts/input_guard.gd"))
	root.add_child(guard)
	await _frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player = _room.get_node("Player") as CharacterBody4D
	_rig = _room.get_node("Player/CameraRig") as Node4D
	_player.set("input_enabled", true)
	var look: Node = Look.current
	if look != null and bool(look.get("dev")):
		look.call("set_dev", false)
		await _frames(10)
	print("THE JOURNEY (layout B)")
	var at: Vector4 = _player.global_position
	_check(Vector2(at.x - 24.9, at.z - 19.1).length() < 1.5, "you start at the path's start", str(at))
	var objective := _room.get_node_or_null("UI/Objective") as Label
	_check(objective != null and objective.text.length() > 0, "an objective is up", "\"%s\"" % (objective.text if objective != null else ""))
	await _frame("start")
	for leg in ROUTE:
		var ok: bool = await _walk_to(Vector2(float(leg[1]), float(leg[2])), String(leg[0]))
		if not ok:
			# Put where the leg ends, so one stuck leg does not fail the rest.
			_player.global_position = Vector4(float(leg[1]), 1.2, float(leg[2]), 0.0)
			_player.linear_velocity = Vector4.ZERO
			await _frames(10)
		if not is_nan(float(leg[3])):
			_release()
			SliceAngles.tilt(_rig, 0.0, 0.0, deg_to_rad(float(leg[3])))
			_rig.set("pitch", -0.15)
			await _frames(20)
			await _frame(String(leg[0]))
	# The cave, twice: in the art look and in the dev look.
	for dev in [false, true]:
		if look != null:
			look.call("set_dev", dev)
		await _cave(dev)
	_release()
	print("JOURNEY: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails > 0 else 0)


## Walked to (x, z) on the move key, the camera turned toward it; false if stuck or too slow.
func _walk_to(to: Vector2, what: String) -> bool:
	var best: float = INF
	var since: float = Time.get_ticks_msec() / 1000.0
	var start: int = Time.get_ticks_msec()
	var from := Vector2(_player.global_position.x, _player.global_position.z)
	var limit: float = from.distance_to(to) / 1.5 + 12.0
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	while true:
		# A scene playing (the Watchstone's arrival, Wren): you watch it, as a player does, then walk on.
		if lookout != null and lookout.has_method("story_busy") and bool(lookout.call("story_busy")):
			_release()
			if not _state_said:
				_state_said = true
				print("      a scene plays on the way (%s); waiting for it" % what)
				await _frame("scene_on_the_way")
			since = Time.get_ticks_msec() / 1000.0
			start += 16
			await process_frame
			continue
		var here := Vector2(_player.global_position.x, _player.global_position.z)
		var gap: Vector2 = to - here
		if gap.length() < 1.3:
			_check(true, "walked to %s" % what, "%.0f s" % ((Time.get_ticks_msec() - start) / 1000.0))
			return true
		if gap.length() < best - 0.1:
			best = gap.length()
			since = Time.get_ticks_msec() / 1000.0
		if Time.get_ticks_msec() / 1000.0 - since > 5.0 or (Time.get_ticks_msec() - start) / 1000.0 > limit:
			_release()
			_check(false, "walked to %s" % what, "stuck at (%.1f, %.1f), %.1f m short" % [here.x, here.y, gap.length()])
			await _frame("stuck_" + what)
			return false
		SliceAngles.tilt(_rig, 0.0, 0.0, atan2(-gap.x, -gap.y))
		_rig.set("pitch", -0.2)
		Input.action_press(&"move_forward")
		await process_frame
	return false


## Up the cave's path through W to its door, in, and out again.
func _cave(dev: bool) -> void:
	var tag: String = "dev" if dev else "art"
	var crossing: Node = _room.get_node("CaveCrossing")
	_release()
	_player.global_position = Vector4(7.3, 1.2, 37.1, 0.0)
	_player.linear_velocity = Vector4.ZERO
	await _frames(15)
	await _frame("cave_path_%s" % tag)
	# North up the path, rising ana as the path does (follow: from W 0 at the junction to W 4 at the door).
	var start: int = Time.get_ticks_msec()
	var went_in: bool = false
	while (Time.get_ticks_msec() - start) < 20000:
		if bool(crossing.call("is_away")):
			went_in = true
			break
		var p: Vector4 = _player.global_position
		# Aimed through the mouth (z 26.4) and on into the tunnel, where the way in is.
		var gap := Vector2(7.4 - p.x, 12.0 - p.z)
		SliceAngles.tilt(_rig, 0.0, 0.0, atan2(-gap.x, -gap.y))
		_rig.set("pitch", -0.15)
		Input.action_press(&"move_forward")
		var want_w: float = clampf((37.1 - p.z) / (37.1 - 31.5), 0.0, 1.0) * 4.0
		if p.w < want_w - 0.15:
			Input.action_press(&"move_ana")
		else:
			Input.action_release(&"move_ana")
		await process_frame
	_release()
	_check(went_in, "%s: up the path through W and in at the cave's door" % tag, "W %.2f at (%.1f, %.1f)" % [_player.global_position.w,
		_player.global_position.x, _player.global_position.z])
	if not went_in:
		await _frame("cave_not_in_%s" % tag)
		return
	await _frames(150)
	await _frame("cave_inside_%s" % tag)
	crossing.call("come_back")
	await _frames(150)
	_check(not bool(crossing.call("is_away")), "%s: and out again, back on the farm" % tag, str(_player.global_position))
	await _frame("cave_out_%s" % tag)
