extends SceneTree

## Every key and option, used the way a player would (keys sent as events), with a frame after each
## (PLAN.md steps 44, 50, 52, 56, 57, 60, 65, 73):
##   lobby: 2 then ENTER starts level 2; the console's tiles picked by a ray (pick())
##   T three times: the three hint steps, with the map open on the third
##   BACKSPACE restarts (the clock goes back to zero); 4 while playing switches level
##   F1 the dev panel; the renderers Projected and Wireframe; V first person; G 4D sight
##   the door prompt; L back to the lobby
## Prints "FEATURES: PASS" or what did not happen. Frames in smoke_test_output/phase_maze_remake/features/.
##   run.sh windowed features res://ramon/PhaseMazeRemake/scripts/_features_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/features/"

var _t0: int = 0
var _m: Node4D
var _fails: Array = []


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 150000:
		print("FEATURES: gave up after 150 s")
		return true
	return false


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("FEATURES: frame ", name)


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


func _check(ok: bool, what: String) -> void:
	print("FEATURES: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _free_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 15:
		await process_frame
	_free_mouse()
	var player: Node4D = _m.get("player")
	player.set("input_enabled", false)
	await _wait(0.8)
	# The console's tiles, by a ray from the camera through each tile's middle.
	var console: Node4D = _m.get("console")
	var cam: Camera4D = _m.get("camera")
	var picked: Array = []
	for i in 7:
		var node: Node4D = console.get_node("Button%d" % i)
		var dir: Vector4 = (node.global_position - cam.global_position).normalized()
		var hit: Dictionary = console.call("pick", cam.global_position, dir)
		picked.append(int(hit.get("button", -1)))
	_check(picked == [0, 1, 2, 3, 4, 5, 6], "console pick finds each tile (%s)" % str(picked))
	await _key(KEY_2)
	_check(int(_m.get("sel")) == 1, "2 selects level 2 in the lobby")
	await _shot("01_lobby_selected_2")
	await _key(KEY_ENTER)
	await _wait(1.0)
	_free_mouse()
	player.set("input_enabled", false)
	_check(String(_m.get("state")) == "playing" and int(_m.get("level_index")) == 1, "ENTER starts level 2")
	await _shot("02_level2")
	# Hints.
	for t in 3:
		await _key(KEY_T)
		if t == 2:
			await _key(KEY_M)
		await _shot("03_hint_%d" % (t + 1))
	_check(int(_m.get("_hint_tier")) == 3, "T three times reaches the third hint")
	_check(bool((_m.get("map") as Control).visible), "M opens the map")
	await _key(KEY_M)
	# The door prompt: walk onto level 2's door cell (1, 1, 0) by placing.
	var lv = _m.get("lattice")
	player.set("input_enabled", true)
	_m.call("_place_player", lv.cell_centre(Vector3i(0, 1, 0)) + Vector4(0, 0.1, 0, 0), Vector4(1, 0, 0, 0))
	await _wait(0.2)
	player.global_position = lv.cell_centre(Vector3i(1, 1, 0)) + Vector4(0, 0.1, 0, 0)
	await _wait(0.3)
	player.set("input_enabled", false)
	_check((_m.get("_prompted") as Dictionary).has("door"), "the door prompt shows on a W door")
	await _shot("04_door_prompt")
	# Restart.
	await _wait(0.5)
	var before: float = float(_m.get("time"))
	await _key(KEY_BACKSPACE)
	await _wait(0.8)
	_free_mouse()
	player.set("input_enabled", false)
	_check(before > 0.0 and float(_m.get("time")) == 0.0 and int(_m.get("level_index")) == 1, "BACKSPACE restarts (%.1f s -> %.1f s)" % [before, float(_m.get("time"))])
	# Switch level while playing.
	await _key(KEY_4)
	await _wait(0.8)
	_free_mouse()
	player.set("input_enabled", false)
	_check(int(_m.get("level_index")) == 3, "4 while playing switches to level 4")
	# The dev panel.
	await _key(KEY_F1)
	await _shot("05_dev_panel")
	_check(bool((_m.get("dev_panel") as Control).visible), "F1 opens the dev panel")
	await _key(KEY_F1)
	_free_mouse()
	# The renderers.
	var tuning: Dictionary = (_m.get("tuning") as Dictionary).duplicate()
	for r in [[2.0, "06_projected"], [3.0, "07_wireframe"], [1.0, "08_combined"]]:
		tuning["renderer"] = r[0]
		_m.call("apply_tuning", tuning)
		await _wait(0.3)
		await _shot(String(r[1]))
	tuning["renderer"] = 0.0
	_m.call("apply_tuning", tuning)
	_check(String(cam.get("rendering_engine_name")) == "Cross-section", "back to the cross-section")
	# W walls white, for comparison.
	tuning["w_cyan"] = 0.0
	_m.call("apply_tuning", tuning)
	var view: Node = _m.get("view")
	await _key(KEY_F)
	await _wait(0.6)
	await _shot("09_turned_w_walls_white")
	tuning["w_cyan"] = 1.0
	_m.call("apply_tuning", tuning)
	await _shot("10_turned_w_walls_cyan")
	_check((_m.get("_prompted") as Dictionary).has("turn"), "the first turn's prompt shows")
	await _key(KEY_F)
	await _wait(0.6)
	_check(int(view.get("hidden_axis")) == 2, "F again turns back to level")
	await _key(KEY_V)
	await _wait(0.5)
	_check(String(view.get("mode")) == "first", "V switches to first person")
	await _shot("11_first_person")
	await _key(KEY_V)
	await _key(KEY_TAB)
	_check(String(view.get("mode")) == "shoulder", "TAB switches to the shoulder camera")
	await _key(KEY_TAB)
	await _key(KEY_G)
	await _wait(0.4)
	_check(bool((_m.get("sight") as Node).get("on")), "G switches 4D sight on")
	await _shot("12_sight")
	await _key(KEY_G)
	await _key(KEY_L)
	await _wait(1.0)
	_check(String(_m.get("state")) == "lobby", "L goes back to the lobby")
	await _shot("13_back_in_lobby")
	print("FEATURES: %s" % ("PASS" if _fails.is_empty() else "FAIL " + str(_fails)))
	quit()
