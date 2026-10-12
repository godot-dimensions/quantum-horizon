extends SceneTree

## Round 2's journey, photographed (R8 to R11): the overlook, bright and dark (B), the maze below turned
## (F on the overlook), level 2's stair through W turned, level 5 from its overlook, and the reward hall
## with each reward during the stage-complete beat and the slow orbit after it, the card see-through.
## Frames in smoke_test_output/phase_maze_remake/journey/.
##   run.sh windowed journey res://ramon/PhaseMazeRemake/scripts/_capture_journey_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/journey/"

var _t0: int = 0
var _m: Node4D


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 240000:
		print("JOURNEY: gave up after 240 s")
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
	print("JOURNEY: ", name)


func _hands_off() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_m.set_process_unhandled_input(false)
	(_m.get("view") as Node).set("keys_on", false)
	(_m.get("rig") as Node).set_process_unhandled_input(false)
	(_m.get("player") as Node).set("input_enabled", false)


func _mood(m: String) -> void:
	(_m.get_node("Light") as Node).call("set_mood", m, true, false)
	await _wait(0.4)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 20:
		await process_frame
	await _mood("bright")
	_m.call("_load_level", 0)
	_hands_off()
	await _wait(1.0)
	await _shot("01_l1_overlook_bright")
	await _mood("dark")
	await _shot("02_l1_overlook_dark")
	await _mood("bright")
	var view: Node = _m.get("view")
	view.call("quarter_turn")
	await _wait(0.8)
	await _shot("03_l1_overlook_turned")
	view.call("quarter_turn")
	await _wait(0.8)
	# Level 5 from its overlook: the giant maze.
	_m.call("_load_level", 4)
	_hands_off()
	await _wait(1.2)
	await _shot("04_l5_overlook_bright")
	await _mood("dark")
	await _shot("05_l5_overlook_dark")
	await _mood("bright")
	# Level 2: down, at its stair, turned: the stair through W ahead.
	_m.call("_load_level", 1)
	_hands_off()
	var lv = _m.get("lattice")
	_m.set("on_overlook", false)
	(_m.get("overlook")["lift"] as Node4D).position.y = float(_m.get("overlook")["bottom"])
	_m.call("_place_player", lv.cell_centre(Vector3i(1, 1, 0)) + Vector4(0, 0.1, 0, 0), Vector4(0, 0, -1, 0))
	await _wait(0.5)
	await _shot("06_l2_at_the_stair_level")
	view.call("quarter_turn")
	await _wait(0.8)
	await _shot("07_l2_stair_through_w")
	await _mood("dark")
	await _shot("08_l2_stair_dark")
	await _mood("bright")
	view.call("quarter_turn")
	await _wait(0.6)
	# The halls: each reward, mid-beat and in the orbit after.
	for r in [[0, "chickens"], [2, "wolves"], [4, "dreamer"]]:
		_m.call("_load_level", int(r[0]))
		_hands_off()
		lv = _m.get("lattice")
		_m.set("on_overlook", false)
		_m.call("_place_player", lv.cell_centre(lv.exit) + Vector4(0, 0.1, 0, 0), Vector4(0, 0, -1, 0))
		await _wait(2.6)
		_hands_off()
		await _shot("1%d_hall_%s_beat" % [int(r[0]), String(r[1])])
		await _wait(3.4)
		await _shot("1%d_hall_%s_orbit" % [int(r[0]), String(r[1])])
		await _mood("dark")
		await _shot("1%d_hall_%s_orbit_dark" % [int(r[0]), String(r[1])])
		await _mood("bright")
	print("JOURNEY: done")
	quit()
