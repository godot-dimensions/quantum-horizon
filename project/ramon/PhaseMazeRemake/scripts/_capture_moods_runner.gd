extends SceneTree

## Bright against dark (B), the same views side by side (Ramon, 9 Oct: "check how the dark toggle looks in
## relation to the bright"): the lobby, level 1 from the overlook and inside its indoor stretch, level 2's
## stair through W turned, level 4's indoor ring, and the Dreamer's hall. Frames in
## smoke_test_output/phase_maze_remake/moods/, named <view>_bright and <view>_dark.
##   run.sh windowed moods res://ramon/PhaseMazeRemake/scripts/_capture_moods_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/moods/"

var _t0: int = 0
var _m: Node4D


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 200000:
		print("MOODS: gave up after 200 s")
		return true
	return false


func _wait(seconds: float) -> void:
	var t: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(seconds * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("MOODS: ", name)


func _both(name: String) -> void:
	for m in ["bright", "dark"]:
		(_m.get_node("Light") as Node).call("set_mood", m, true, false)
		await _wait(0.35)
		await _shot("%s_%s" % [name, m])
	(_m.get_node("Light") as Node).call("set_mood", "bright", true, false)


func _hands_off() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_m.set_process_unhandled_input(false)
	(_m.get("view") as Node).set("keys_on", false)
	(_m.get("rig") as Node).set_process_unhandled_input(false)
	(_m.get("player") as Node).set("input_enabled", false)


func _down() -> void:
	_m.set("on_overlook", false)
	(_m.get("overlook")["lift"] as Node4D).position.y = float(_m.get("overlook")["bottom"])
	_m.call("_overlook_framing", false)


func _put(cell: Vector3i, face: Vector4) -> void:
	var lv = _m.get("lattice")
	_m.call("_place_player", lv.cell_centre(cell) + Vector4(0, 0.1, 0, 0), face)
	await _wait(0.5)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 20:
		await process_frame
	_hands_off()
	await _wait(1.0)
	await _both("1_lobby")
	_m.call("_load_level", 0)
	_hands_off()
	await _wait(1.0)
	await _both("2_l1_overlook")
	_down()
	await _put(Vector3i(0, 1, 0), Vector4(0, 0, -1, 0))
	await _both("3_l1_indoor")
	_m.call("_load_level", 1)
	_hands_off()
	_down()
	await _put(Vector3i(1, 1, 0), Vector4(0, 0, -1, 0))
	(_m.get("view") as Node).call("quarter_turn")
	await _wait(0.8)
	await _both("4_l2_stair_turned")
	_m.call("_load_level", 3)
	_hands_off()
	_down()
	await _put(Vector3i(0, 1, 0), Vector4(0, 0, -1, 0))
	await _both("5_l4_indoor_ring")
	_m.call("_load_level", 4)
	_hands_off()
	_down()
	var lv = _m.get("lattice")
	_m.call("_place_player", lv.cell_centre(lv.exit) + Vector4(0, 0.1, 0, 0), Vector4(0, 0, -1, 0))
	await _wait(6.5)
	_hands_off()
	await _both("6_dreamer_hall")
	print("MOODS: done")
	quit()
