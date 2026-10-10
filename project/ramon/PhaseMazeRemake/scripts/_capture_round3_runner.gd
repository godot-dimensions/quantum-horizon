extends SceneTree

## Round 3's look, as frames (smoke_test_output/phase_maze_remake/round3_frames/):
##   01 the lobby: the console in its corner, the prompt after choosing
##   02 the Tab panel (numbers, the spot rows) and 03 its colour looks
##   04 the three looks (ROUND 2, BLUEPRINT, SIGNAL RED) from the overlook and inside the maze
##   05 the spot's softness at 0.3, 1.2 and 3.5 (dark mood, where the spot carries the scene)
##   06 a blue plate: the glow, the card, the lit F row
##   07 the beacon from the exit's layer and from another (level 2's overlook): solid against the
##      hollow frame, and the label
##   08 level 6: the floors tinted by layer, the landmarks
##   09 the Esc box
## Your saved settings file is set aside first and put back after (as _capture_colours_runner.gd does).
##   run.sh windowed r3frames res://ramon/PhaseMazeRemake/scripts/_capture_round3_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/round3_frames/"
const SAVE := "user://phase_maze_remake_tuning.cfg"
const ASIDE := "user://phase_maze_remake_tuning.round3_aside.cfg"
const GB := preload("res://ramon/PhaseMazeRemake/carried/walker/ground_basis_4d.gd")

var _t0: int = 0
var _m: Node4D
var _had_save: bool = false


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 160000:
		print("R3FRAMES: gave up after 160 s")
		_restore_save()
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _shot(name: String) -> void:
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("R3FRAMES: frame ", name)


func _wait(seconds: float) -> void:
	var t: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(seconds * 1000.0):
		await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame
	await process_frame


func _restore_save() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(SAVE.get_file()):
		dir.remove(SAVE.get_file())
	if _had_save and dir.file_exists(ASIDE.get_file()):
		dir.rename(ASIDE.get_file(), SAVE.get_file())
		_had_save = false


func _freeze() -> void:
	(_m.get("player") as Node).set("input_enabled", false)
	(_m.get("view") as Node).set("keys_on", false)


func _down_in(i: int) -> void:
	_m.call("_load_level", i)
	await _wait(0.3)
	_m.set("on_overlook", false)
	(_m.get("overlook")["lift"] as Node4D).position.y = float(_m.get("overlook")["bottom"])
	_m.call("_overlook_framing", false)
	_freeze()


func _stand(cell: Vector3i, face: Vector4) -> void:
	var lv = _m.get("lattice")
	_m.call("_place_player", lv.cell_centre(cell) + Vector4(0, 0.1, 0, 0), face)
	_freeze()
	await _wait(0.5)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(SAVE.get_file()):
		_had_save = true
		dir.rename(SAVE.get_file(), ASIDE.get_file())
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 15:
		await process_frame
	_freeze()
	await _wait(1.0)
	var rig: Node4D = _m.get("rig")
	var console: Node4D = _m.get("console")
	var panel: Control = _m.get("dev_panel")

	# 01 the lobby, then looking at the console after choosing 2.
	await _shot("01_lobby_arrive")
	var to_console: Vector4 = (console.global_position - Vector4(0, 0, 44.6, 0))
	to_console.y = 0.0
	rig.basis = GB.faced(rig.basis, to_console.normalized(), 1.0)
	rig.call("_apply")
	_m.call("_place_player", Vector4(-3.4, 0.1, 40.5, 0.0), to_console.normalized())
	rig.basis = GB.faced(rig.basis, to_console.normalized(), 1.0)
	rig.call("_apply")
	await _wait(0.4)
	await _key(KEY_2)
	await _shot("01_lobby_chose_2")

	# 02 / 03 the Tab panel.
	panel.call("set_open", true)
	await _shot("02_tab_numbers")
	var sc: ScrollContainer = panel.find_child("Numbers", true, false)
	if sc != null:
		sc.scroll_vertical = 100000
	await _shot("02_tab_numbers_spot")
	var tabs: TabContainer = panel.find_child("*", true, false) as TabContainer
	for c in panel.find_children("*", "TabContainer", true, false):
		tabs = c
	if tabs != null:
		tabs.current_tab = 1
	await _shot("03_tab_colours_looks")
	panel.call("set_open", false)

	# 04 the three looks.
	for look in ["ROUND 2", "BLUEPRINT", "SIGNAL RED"]:
		panel.call("apply_preset", look)
		_m.call("_load_level", 4)
		await _wait(0.6)
		_freeze()
		var slug: String = look.to_lower().replace(" ", "_")
		await _shot("04_%s_overlook" % slug)
		await _down_in(2)
		var lv = _m.get("lattice")
		await _stand(lv.start, Vector4(0, 0, -1, 0))
		await _shot("04_%s_inside" % slug)
	panel.call("apply_preset", "ROUND 2")

	# 05 the spot's softness, dark mood.
	var light: Node = _m.get_node("Light")
	light.call("set_mood", "dark", true, false)
	await _down_in(0)
	await _stand((_m.get("lattice")).start, Vector4(0, 0, -1, 0))
	for soft in [0.3, 1.2, 3.5]:
		var t: Dictionary = (_m.get("tuning") as Dictionary).duplicate()
		t["spot_softness"] = soft
		_m.call("apply_tuning", t)
		await _wait(0.3)
		await _shot("05_spot_softness_%s" % str(soft).replace(".", "_"))
	var t2: Dictionary = (_m.get("tuning") as Dictionary).duplicate()
	t2["spot_softness"] = 1.2
	_m.call("apply_tuning", t2)
	light.call("set_mood", "bright", true, false)

	# 06 a blue plate in level 2 (a door through W), level view.
	await _down_in(1)
	var lv2 = _m.get("lattice")
	var door: Vector3i = lv2.start
	for key in lv2.open:
		var e: Vector4i = key
		if e.w == 2 and not lv2.stairs.has(Vector3i(e.x, e.y, e.z)):
			door = Vector3i(e.x, e.y, e.z)
			break
	_m.set("_cards_shown", 0)
	await _stand(door, Vector4(0, 0, -1, 0))
	await _wait(1.6)
	await _shot("06_blue_plate_card")
	await _wait(1.4)
	await _shot("06_blue_plate_card_qe")

	# 07 the beacon, from level 2's overlook (its exit is three layers ana of the start): the hollow frame
	# and its label from the start's layer, then the solid beacon from the exit's own layer.
	_m.call("_load_level", 1)
	await _wait(0.6)
	_freeze()
	await _shot("07_beacon_other_layer")
	var lv3 = _m.get("lattice")
	var pl: Node4D = _m.get("player")
	pl.global_position = Vector4(pl.global_position.x, pl.global_position.y, pl.global_position.z, lv3.cell_centre(lv3.exit).w)
	await _wait(0.4)
	await _shot("07_beacon_exit_layer")

	# 08 level 6: tinted floors, landmarks, from the overlook and inside.
	_m.call("_load_level", 5)
	await _wait(0.6)
	_freeze()
	await _shot("08_level6_overlook")
	await _down_in(5)
	var lv6 = _m.get("lattice")
	await _stand(lv6.start, Vector4(0, 0, -1, 0))
	await _shot("08_level6_inside_layer_%d" % lv6.start.z)
	var other := Vector3i(lv6.start.x, lv6.start.y, (lv6.start.z + 1) % lv6.nw)
	await _stand(other, Vector4(0, 0, -1, 0))
	await _shot("08_level6_inside_layer_%d" % other.z)

	# 09 the Esc box.
	await _key(KEY_ESCAPE)
	await _shot("09_escape_box")
	await _key(KEY_ESCAPE)
	print("R3FRAMES: done")
	_restore_save()
	quit()
