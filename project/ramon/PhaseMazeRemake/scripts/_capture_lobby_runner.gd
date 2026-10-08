extends SceneTree

## The lobby as it reads (Ramon, 9 Oct: the teaching walls "dynamic like the walls in creatorlab"; the
## walker "dark blue, with subtle shifts, like a brighter blue for the face"): from the spawn, the live
## intro wall (left), the live research wall (right) before and after a run of level 2, the back wall's
## three pictures, and the walker from the front. Frames in smoke_test_output/phase_maze_remake/lobby/.
##   run.sh windowed lobby res://ramon/PhaseMazeRemake/scripts/_capture_lobby_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/lobby/"

var _t0: int = 0
var _m: Node4D


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("LOBBY: gave up after 90 s")
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
	print("LOBBY: ", name)


func _look(yaw_deg: float, pitch_deg: float) -> void:
	var rig: Node4D = _m.get("rig")
	rig.basis = Basis4D.from_zx(deg_to_rad(yaw_deg))
	rig.set("pitch", deg_to_rad(pitch_deg))
	rig.call("_apply")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 20:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_m.set_process_unhandled_input(false)
	(_m.get("player") as Node).set("input_enabled", false)
	(_m.get("view") as Node).set("keys_on", false)
	await _wait(1.5)
	await _shot("01_spawn")
	_look(90.0, -4.0)
	await _wait(0.8)
	await _shot("02_intro_wall_left")
	_look(-90.0, -4.0)
	await _wait(0.8)
	await _shot("03_research_wall_right")
	# A run of level 2 on record, then back: the research wall shows it.
	_m.set("results", {1: {"time": 10.2, "w_moves": 3, "turns": 1, "hints": 0}})
	_m.set("bests", {0: 27.6, 1: 10.2})
	_m.set("sel", 1)
	await _wait(0.8)
	await _shot("04_research_wall_after_level_2")
	_look(0.0, 6.0)
	await _wait(0.5)
	await _shot("05_back_wall")
	# The walker from the front, close.
	var view: Node = _m.get("view")
	view.call("set_mode", "chase")
	var rig: Node4D = _m.get("rig")
	rig.set("_zoom_target", 2.2)
	rig.set("distance", 2.2)
	rig.set("_home_pivot", 1.0)
	rig.set("pivot_height", 1.0)
	_look(180.0, -10.0)
	await _wait(0.8)
	await _shot("06_walker_front")
	_look(150.0, -14.0)
	await _wait(0.5)
	await _shot("07_walker_three_quarter")
	print("LOBBY: done")
	quit()
