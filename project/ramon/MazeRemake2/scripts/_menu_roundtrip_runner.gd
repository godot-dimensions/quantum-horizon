extends SceneTree

## The Annex from the menu and back, once (PLAN.md steps 97 to 99): menu_final with the Annex's row
## selected; launched through the menu's own launch; Esc heard by the Annex's guard first, which hands
## it to the menu's one shared question (WayHome); YES closes the Annex and the menu is back.
## Frames in smoke_test_output/maze_remake_2/menu/. One launch only (Ramon objected to mass launches).
##   run.sh windowed menu res://ramon/MazeRemake2/scripts/_menu_roundtrip_runner.gd

const MENU := "res://ramon/menu_final.tscn"
const OUT := "res://smoke_test_output/maze_remake_2/menu/"

var _t0: int = 0
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 120000:
		print("MENU FAIL: gave up after 120 s")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _check(ok: bool, what: String) -> void:
	print("MENU %s: %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _wait(seconds: float) -> void:
	var t: int = Time.get_ticks_msec()
	for i in 20000:
		if Time.get_ticks_msec() - t >= int(seconds * 1000.0):
			return
		await process_frame


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("MENU frame ", name)


func _annex() -> Node:
	for c in root.get_children():
		var s: Script = c.get_script()
		if s != null and s.resource_path.ends_with("maze_remake_2_4d.gd"):
			return c
	return null


func _run() -> void:
	var menu: Node = (load(MENU) as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await _wait(2.5)
	var entries: Array = menu.call("_entries")
	var idx: int = -1
	for i in entries.size():
		if String((entries[i] as Resource).get("title")) == "The Annex":
			idx = i
	_check(idx >= 0, "the menu lists The Annex (row %d)" % idx)
	if idx < 0:
		quit(1)
		return
	menu.call("_select", idx)
	await _wait(1.5)
	await _shot("01_menu_annex_selected")
	menu.call("_launch", idx)
	var annex: Node = null
	for i in 3000:
		annex = _annex()
		if annex != null and String(annex.get("mode")) == "play":
			break
		await process_frame
	_check(annex != null and String(annex.get("mode")) == "play", "launched from the menu, playing")
	await _wait(2.0)
	await _shot("02_launched_from_menu")
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.physical_keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _wait(0.6)
	var way: Node = root.get_node_or_null(^"WayHome")
	_check(way != null and bool(way.call("is_asking")), "Esc asks the menu's one question (WayHome)")
	_check(is_instance_valid(annex) and annex.is_inside_tree(), "the Annex is still running while it asks")
	await _shot("03_way_home_question")
	if way != null:
		way.call("_answer", true)
	await _wait(2.5)
	_check(_annex() == null, "YES closed the Annex")
	_check(current_scene == menu, "the menu is the current scene again")
	await _shot("04_back_in_menu")
	print("MENU DONE fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
