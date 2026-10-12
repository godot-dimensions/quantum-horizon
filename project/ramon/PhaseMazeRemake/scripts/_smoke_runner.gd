extends SceneTree

## The remake opened for real and photographed (PLAN.md steps 9, 32 and 46): the lobby, level 1 from the
## start, at its W door, turned into W (F), in first person and over the shoulder, the map, 4D sight at
## level 4's sealed room, and the finish with the console and the card. Frames in
## smoke_test_output/phase_maze_remake/smoke/. Nobody's mouse or keys reach it (unfocusable window, the
## walker's and the scene's input off); bests are not saved.
##   run.sh windowed smoke res://ramon/PhaseMazeRemake/scripts/_smoke_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/smoke/"

var _t0: int = 0
var _m: Node4D
var _errors_before: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 120000:
		print("SMOKE: gave up after 120 s")
		return true
	return false


func _shot(name: String, frames: int = 6) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("SMOKE: ", name)


func _wait(seconds: float) -> void:
	var t: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(seconds * 1000.0):
		await process_frame


func _hands_off() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_m.set_process_unhandled_input(false)
	var view: Node = _m.get("view")
	view.set("keys_on", false)
	view.set_process_unhandled_input(false)
	(_m.get("rig") as Node).set_process_unhandled_input(false)
	(_m.get("player") as Node).set_process_unhandled_input(false)


func _put(cell: Vector3i, face: Vector4) -> void:
	var lv = _m.get("lattice")
	_m.call("_place_player", lv.cell_centre(cell) + Vector4(0, 0.1, 0, 0), face)
	for i in 20:
		await physics_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 20:
		await process_frame
	_hands_off()
	(_m.get("player") as Node).set("input_enabled", false)
	await _wait(1.0)
	await _shot("01_lobby", 4)
	# Level 1 from its start, then at its W door (the dead end at the far left).
	_m.call("_load_level", 0)
	_hands_off()
	(_m.get("player") as Node).set("input_enabled", false)
	await _wait(0.6)
	await _shot("02_l1_start")
	await _put(Vector3i(0, 0, 0), Vector4(0, 0, -1, 0))
	await _shot("03_l1_w_door")
	var view: Node = _m.get("view")
	view.call("quarter_turn")
	await _wait(0.7)
	await _shot("04_l1_turned")
	view.call("set_mode", "first")
	await _wait(0.6)
	await _shot("05_l1_turned_first")
	view.call("quarter_turn")
	await _wait(0.7)
	await _shot("06_l1_first_level")
	view.call("set_mode", "shoulder")
	await _wait(0.6)
	await _shot("07_l1_shoulder")
	view.call("set_mode", "chase")
	(_m.get("map") as Control).visible = true
	await _shot("08_l1_map")
	(_m.get("map") as Control).visible = false
	# 4D sight at level 1's start: layer 1 has a wall across the corridor you can see, so its ghost stands in it.
	await _put(Vector3i(0, 2, 0), Vector4(0, 0, -1, 0))
	(_m.get("sight") as Node).call("set_on", true)
	await _wait(0.5)
	await _shot("08b_l1_sight", 10)
	(_m.get("sight") as Node).call("set_on", false)
	# Level 4: next to the sealed room in layer 1, 4D sight on.
	_m.call("_load_level", 3)
	_hands_off()
	(_m.get("player") as Node).set("input_enabled", false)
	await _put(Vector3i(1, 2, 1), Vector4(0, 0, -1, 0))
	await _shot("09_l4_sealed")
	(_m.get("sight") as Node).call("set_on", true)
	await _wait(0.5)
	await _shot("10_l4_sight", 10)
	(_m.get("sight") as Node).call("set_on", false)
	# Level 2's shaft, turned: the corridor through W ahead.
	_m.call("_load_level", 1)
	_hands_off()
	(_m.get("player") as Node).set("input_enabled", false)
	await _put(Vector3i(1, 1, 0), Vector4(0, 0, -1, 0))
	view.call("quarter_turn")
	await _wait(0.7)
	await _shot("11_l2_shaft_turned")
	# The finish: level 1's exit.
	_m.call("_load_level", 0)
	_hands_off()
	(_m.get("player") as Node).set("input_enabled", false)
	await _put(Vector3i(2, 0, 0), Vector4(0, 0, -1, 0))
	await _wait(1.2)
	await _shot("12_l1_finish")
	print("SMOKE: state %s" % String(_m.get("state")))
	print("SMOKE: done")
	quit()
