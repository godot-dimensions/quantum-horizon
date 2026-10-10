extends SceneTree

## RAMON'S 10 OCT WALKTHROUGH, PLAYED THROUGH (follow_up/pen_feedback_10oct.md): every gameplay change of that round,
## driven as a player would and checked, with a frame at each beat (smoke_test_output/feedback_10oct/<look>/).
##
##   lab_run.sh windowed fb_verify res://ramon/chickenpen/discovery/_verify_feedback_runner.gd [look=art|dev]

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const WSense := preload("res://ramon/chickenpen/discovery/w_sense_4d.gd")
const Guide := preload("res://ramon/chickenpen/discovery/pen_w_guide_4d.gd")
const Balloon := preload("res://ramon/chickenpen/lookout/balloon_4d.gd")
const Pivot := preload("res://ramon/chickenpen/discovery/pen_wall_pivot_4d.gd")

var _room: Node
var _player: CharacterBody4D
var _rig: Node4D
var _cam: Camera4D
var _out: String = "res://smoke_test_output/feedback_10oct/"
var _fails: int = 0
var _t0: int = 0


class RunnerGuard extends Node:
	func _input(event: InputEvent) -> void:
		if event.has_meta(&"runner"):
			return
		if event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 420000:
		print("FEEDBACK: gave up after 420 s")
		return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	for i in 100000:
		if Time.get_ticks_msec() >= until:
			break
		await process_frame


func _save(name: String) -> void:
	_tidy_hud()
	await _frames(1)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out + name + ".png"))
	print("FRAME %s" % name)


func _place(p: Vector4, yaw: float, pitch: float = -8.0, dist: float = 6.0, xw: float = 0.0, zw: float = 0.0) -> void:
	_player.global_position = p
	_player.linear_velocity = Vector4.ZERO
	SliceAngles.tilt(_rig, deg_to_rad(xw), deg_to_rad(zw), deg_to_rad(yaw))
	_rig.set("pitch", deg_to_rad(pitch))
	_rig.set("distance", dist)
	_rig.set("_zoom_target", dist)
	_rig.call("_apply")


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	down.set_meta(&"runner", true)
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	up.set_meta(&"runner", true)
	Input.parse_input_event(up)
	await _frames(2)


func _shot(from: Vector4, at: Vector4) -> void:
	var cam := _room.get_node("World/TalkCam") as Node4D
	cam.global_position = from
	cam.global_basis = _look_basis(at - from)
	cam.set("current", true)


static func _look_basis(gap: Vector4) -> Projection:
	var forward: Vector3 = Vector3(gap.x, gap.y, gap.z).normalized()
	var zc: Vector3 = -forward
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc).normalized()
	var yc: Vector3 = zc.cross(xc)
	return Projection(Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0), Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


## Space until the talk at [param path] has closed (at most eight presses).
func _close_talk(path: String) -> void:
	for i in 8:
		if not _talking(path):
			return
		await _key(KEY_SPACE)
		await _wait(0.9)


func _talking(path: String) -> bool:
	var talk: Node = _room.get_node_or_null(path)
	return talk != null and bool(talk.call("is_running"))


func _run() -> void:
	var look: String = "art"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("look="):
			look = a.substr(5)
	OS.set_environment("PEN_LOOK", look)
	_out += look + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	print("FEEDBACK (look %s)" % look)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	var guard := RunnerGuard.new()
	guard.name = "RunnerGuard"
	root.add_child(guard)
	await _frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player = _room.get_node("Player") as CharacterBody4D
	_rig = _player.get_node("CameraRig") as Node4D
	_cam = WSense.camera_of(_player)
	await _wait(2.0)
	_quiet_tutor()
	var inv: Node = _room.get_node("UI/Inventory")
	var lookout: Node = _room.get_node("Systems/Lookout")
	var balloon: Node4D = lookout.get("balloon") as Node4D

	# --- 25. The door: through the slit at W 0, and V to stand it whole --------------------------------------------
	_place(Vector4(45.0, 1.2, 7.0, 0.0), 0.0, 0.0, 5.0)
	await _wait(0.8)
	await _save("01_door_slit")
	_place(Vector4(45.0, 1.2, 2.3, 0.0), 0.0, 0.0, 5.0)
	await _wait(1.6)
	_check(_player.global_position.y > 12.0, "walked into the slit at W 0: on top of the Watchstone (y %.1f)" % _player.global_position.y)
	await _wait(0.8)
	var door: Node = _room.get_node("World/WDoor")
	door.call("reset")
	_rig.call("align_to", 0.0)
	await _wait(0.6)
	_place(Vector4(45.0, 1.2, 8.0, 0.0), 0.0, 0.0, 5.0, 22.0, 0.0)
	await _wait(0.5)
	_check(bool(door.call("can_align")), "turned a little toward it, V is offered (whole %.2f)" % float(door.call("wholeness")))
	await _save("02_door_v_prompt")
	await _key(KEY_V)
	await _wait(1.0)
	_check(float(door.call("wholeness")) > 0.95, "V stood the door whole (%.2f)" % float(door.call("wholeness")))
	await _save("03_door_whole_after_v")
	_rig.call("align_to", 0.0)
	_place(Vector4(0.0, 1.2, 20.0, 0.0), 0.0)
	await _wait(0.8)

	# --- 18. The balloon, grounded at its W; Tamsin at the fire ----------------------------------------------------
	_check(absf(balloon.global_position.w - 5.0) < 0.05 and absf(balloon.global_position.y) < 0.3, "the balloon sits on the ground 5 m ana (%s)" % str(balloon.global_position))
	_place(Vector4(-29.2, 1.2, -27.4, 0.0), 0.0, -6.0, 4.0)
	await _wait(1.0)
	await _save("04_tamsin_fire")
	await _key(KEY_F)
	await _wait(1.6)
	_check(_talking("Systems/BalloonCrewTalk"), "F at her fire talks to Tamsin (from 3 m)")
	await _save("05_tamsin_talk")
	await _key(KEY_SPACE)
	await _wait(1.8)
	await _save("06_tamsin_price")
	await _key(KEY_DOWN)
	await _key(KEY_SPACE)
	await _wait(1.6)
	await _close_talk("Systems/BalloonCrewTalk")
	_check(not _talking("Systems/BalloonCrewTalk"), "Deal. ends it")
	var solid: Node = _room.get_node_or_null("World/BalloonCrew/Crew")
	_check(solid != null and solid.find_child("Solid", true, false) != null, "Tamsin has a collider now")
	# Found: turned forward from the road until V comes up, V, the toast.
	var finder: Node = _room.get_node("Systems/BalloonFinder")
	var got: float = NAN
	for zw in range(0, 61, 2):
		for sgn in [1.0, -1.0]:
			_place(Vector4(-29.6, 1.2, -18.0, 0.0), 0.0, 10.0, 6.0, 0.0, float(zw) * sgn)
			await _frames(1)
			if bool(finder.call("can_align")):
				got = float(zw) * sgn
				break
		if not is_nan(got):
			break
	_check(not is_nan(got), "turned forward, V comes up for the balloon (at %s degrees)" % str(got))
	await _key(KEY_V)
	await _wait(0.8)
	_check(Balloon.found, "V found the balloon")
	var toast: Node = _room.get_node_or_null("DiscoveryToastLayer/DiscoveryToast")
	_check(toast != null, "the discovery toast came up")
	await _save("07_balloon_found_toast")
	await _wait(1.6)
	_place(Vector4(-27.0, 1.2, -24.0, 5.0), 30.0, 4.0, 7.0)
	await _wait(0.8)
	await _save("08_balloon_grounded_w5")

	# --- 20. Tamsin's twin by the basket: no azoth, then 3, pay 2, the ride -----------------------------------------
	_place(Vector4(-28.4, 1.2, -27.8, 5.0), 0.0, -6.0, 4.0)
	await _wait(0.8)
	_check(not bool(lookout.call("can_board")), "not paid: no boarding")
	await _key(KEY_F)
	await _wait(1.6)
	_check(_talking("Systems/BalloonRideTalk"), "F by the basket talks to her twin")
	await _save("09_twin_short")
	await _key(KEY_SPACE)
	await _wait(1.0)
	await _close_talk("Systems/BalloonRideTalk")
	for i in 3:
		inv.call("add_item", "found_azoth")
	var before: int = int(inv.call("count_of", "found_azoth"))
	await _key(KEY_F)
	await _wait(1.6)
	await _save("10_twin_offer")
	await _key(KEY_SPACE)
	await _wait(1.6)
	await _close_talk("Systems/BalloonRideTalk")
	await _wait(0.8)
	_check(int(inv.call("count_of", "found_azoth")) == before - 2, "paid 2 azoth (%d to %d)" % [before, int(inv.call("count_of", "found_azoth"))])
	_check(bool(balloon.get("riding")), "the ride started")
	await _wait(2.5)
	await _save("11_ride_up")
	balloon.call("_land")
	await _wait(1.2)
	_check(bool(balloon.get("parked")) and absf(balloon.global_position.w - 5.0) < 0.05, "after the ride it is back on its sand at W 5")
	_check(not bool(lookout.call("can_board")), "and another ride needs paying again")
	_rig.call("align_to", 0.0)
	await _wait(0.8)

	# --- 14. The pen's eggs, 13. its hint ---------------------------------------------------------------------------
	_place(Vector4(-14.2, 1.2, 38.6, 0.0), 90.0, -8.0, 6.0)
	await _wait(2.0)
	_check(Guide.spent.has("pen_eggs"), "the pen's card came up at its entrance")
	await _save("12_pen_card")
	await _wait(5.0)
	var whites: int = int(inv.call("count_of", "found_egg_white"))
	var golds: int = int(inv.call("count_of", "found_egg"))
	for egg in ["PenEggA", "PenEggB", "PenEggGold"]:
		var e: Node4D = _room.get_node("World/Pickups/" + egg) as Node4D
		_place(e.global_position + Vector4(0.0, 0.85, 0.0, 0.0), 90.0, -20.0, 3.5)
		await _wait(0.7)
		_check(not e.visible, "%s collected at its W (%.1f)" % [egg, e.global_position.w])
		await _save("13_egg_" + egg)
		await _wait(0.6)
	_check(int(inv.call("count_of", "found_egg_white")) == whites + 2 and int(inv.call("count_of", "found_egg")) == golds + 1, "two eggs and a golden egg in the belt")
	_place(Vector4(-16.0, 1.2, 33.0, 0.0), 0.0, -16.0, 3.0)
	await _wait(0.6)
	await _save("14_belt_with_eggs")

	# --- 3. The cave's card ---------------------------------------------------------------------------------------
	_place(Vector4(7.33, 1.2, 35.6, 0.0), 180.0, -6.0, 6.0)
	await _wait(3.0)
	_check(Guide.spent.has("cave_road"), "the cave road's card came up")
	await _save("15_cave_card")
	await _wait(2.5)
	await _save("16_cave_card_second_beat")

	# --- 16. The wall's pivot: the camera round the wall, the card; the wall solid ------------------------------------
	_place(Vector4(-11.5, 1.2, 18.0, 0.0), 0.0, -6.0, 6.0)
	await _wait(0.8)
	await _save("17_pivot_ahead")
	_place(Vector4(-11.5, 1.2, 14.6, 0.0), 0.0, -6.0, 6.0)
	await _wait(1.2)
	_check(_player.get("input_enabled") == false, "at the pivot the camera move started")
	await _save("18_pivot_orbit_a")
	await _wait(1.2)
	await _save("19_pivot_orbit_b")
	await _wait(2.4)
	_check(_player.get("input_enabled") == true, "control back after the move")
	await _save("20_pivot_card")
	_place(Vector4(-11.5, 1.2, 13.2, 0.0), 0.0, -6.0, 5.0)
	await _wait(0.3)
	Input.action_press(&"move_forward")
	await _wait(2.0)
	Input.action_release(&"move_forward")
	await _wait(0.3)
	_check(_player.global_position.z > 11.9, "walking into the wall at W 0: held at z %.2f (the wall is at 11.6)" % _player.global_position.z)
	await _save("21_wall_solid")

	# --- 23. The cache's V ------------------------------------------------------------------------------------------
	_place(Vector4(25.0, 1.2, -24.5, 6.2), 0.0, -2.0, 6.0)
	await _wait(0.6)
	var cache: Node = _room.get_node("World/KataCache")
	_check(bool(cache.call("can_align")), "near the cache with part of the chamber in the slice, V is offered")
	await _save("22_cache_v_prompt")
	await _key(KEY_V)
	await _wait(1.6)
	_check(absf(_player.global_position.w - 7.5) < 0.3, "V took you to the chamber's W (%.2f)" % _player.global_position.w)
	await _save("23_cache_after_v")
	_rig.call("align_to", 0.0)
	await _wait(0.6)

	# --- 21. The sky balloons; 29. the wall's stone; 22. the camp's side path ------------------------------------------
	for w in [0.0, 9.0]:
		_player.global_position = Vector4(10.0, 1.2, -36.0, w)
		_shot(Vector4(6.0, 16.0, -30.0, w), Vector4(24.0, 58.0, -160.0, w))
		await _wait(0.6)
		await _save("24_sky_w0" if w == 0.0 else "25_sky_w9")
	_player.global_position = Vector4(-8.0, 1.2, 24.0, 0.0)
	_shot(Vector4(-6.0, 3.0, 20.0, 0.0), Vector4(-11.5, 2.4, 11.6, 0.0))
	await _wait(0.8)
	await _save("26_wall_stone")
	_player.global_position = Vector4(14.0, 1.2, -2.0, -2.5)
	_shot(Vector4(12.0, 9.0, 2.0, -2.5), Vector4(17.0, 0.0, -12.0, -2.5))
	await _wait(0.8)
	await _save("27_camp_side_path")
	_cam.set("current", true)

	# --- 2. The bookshelf in the dev look -------------------------------------------------------------------------
	var look_node: Node = _room.get_node("Systems/Look")
	look_node.call("set_dev", true)
	await _wait(0.8)
	_place(Vector4(25.6, 1.2, 45.0, 0.0), 200.0, -22.0, 2.6)
	var shed: Node = _room.get_node_or_null("World/TrymCabin/Shed")
	if shed != null and shed.has_method("set_cutaway"):
		shed.call("set_cutaway", true)
	await _wait(0.8)
	await _save("28_bookshelf_dev")
	print("FEEDBACK: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)


func _tidy_hud() -> void:
	for node in _room.find_children("*", "Control", true, false):
		var s: Script = node.get_script() as Script
		if s == null:
			continue
		var f: String = s.resource_path.get_file()
		if f in ["flock_stats_panel_4d.gd", "pen_paths_panel_4d.gd", "pen_camera_picker_4d.gd", "pen_controls_4d.gd"]:
			(node as Control).visible = false


func _quiet_tutor() -> void:
	var tutor: Node = _room.get_node_or_null("Systems/Tutor")
	if tutor == null:
		return
	var shown: Dictionary = tutor.get("_shown")
	for k in ["move", "ana", "moved", "home", "deliver"]:
		shown[k] = true
	tutor.set("_showing", "")
	var label: Label = _room.get_node_or_null("UI/Hint") as Label
	if label != null:
		label.text = ""
