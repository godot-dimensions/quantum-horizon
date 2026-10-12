extends SceneTree

## The HUD on Ramon's screen (PLAN.md step 77; HUD at 4K, 145% UI: the pen's hud4k check does the same):
## a 3840 x 2160 window, the HUD, the map and the results card, saved at full size. Short, and the window
## takes no input.
##   run.sh windowed hud4k res://ramon/PhaseMazeRemake/scripts/_hud4k_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/hud4k/"

var _t0: int = 0
var _m: Node4D


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(3840, 2160))
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 60000:
		print("HUD4K: gave up after 60 s")
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
	var img: Image = root.get_texture().get_image()
	print("HUD4K: %s at %dx%d" % [name, img.get_width(), img.get_height()])
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 10:
		await process_frame
	_m.call("_load_level", 2)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_m.set_process_unhandled_input(false)
	(_m.get("player") as Node).set("input_enabled", false)
	(_m.get("view") as Node).set("keys_on", false)
	await _wait(1.0)
	await _shot("01_hud")
	(_m.get("map") as Control).visible = true
	await _shot("02_map")
	(_m.get("map") as Control).visible = false
	var lv = _m.get("lattice")
	_m.call("_place_player", lv.cell_centre(lv.exit) + Vector4(0, 0.1, 0, 0), Vector4(0, 0, -1, 0))
	await _wait(1.2)
	await _shot("03_finish")
	print("HUD4K: done")
	quit()
