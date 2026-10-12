extends SceneTree

## The two asks of 9 Oct afternoon, checked (Ramon: "when pressing tab, can you make a hud and allow me to
## change all the colors used in the scene? and save", and "the corners of the wall still clip in to each
## other. find a sensible solution"):
##   corners   close views where walls meet, level and turned, the posts between them
##   colours   the Tab panel's Colours page open; walls, W walls, the marks and the walker recoloured live
##             through the panel's own handler; SAVE, the scene opened again, the colours back
## Ramon's own settings file is copied aside first and put back after, so nothing of his changes.
## Prints "COLOURS: PASS" or what did not hold. Frames in smoke_test_output/phase_maze_remake/colours/.
##   run.sh windowed colours res://ramon/PhaseMazeRemake/scripts/_capture_colours_runner.gd

const SCENE := "res://ramon/PhaseMazeRemake/phase_maze_remake.tscn"
const OUT := "res://smoke_test_output/phase_maze_remake/colours/"
const CFG := "user://phase_maze_remake_tuning.cfg"
const LabGrid := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_grid.gd")

var _t0: int = 0
var _m: Node4D
var _fails: Array = []
var _backup: PackedByteArray = PackedByteArray()
var _had_cfg: bool = false


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 150000:
		print("COLOURS: gave up after 150 s")
		_restore()
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
	print("COLOURS: frame ", name)


func _check(ok: bool, what: String) -> void:
	print("COLOURS: %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails.append(what)


func _restore() -> void:
	if _had_cfg:
		var f := FileAccess.open(CFG, FileAccess.WRITE)
		f.store_buffer(_backup)
		f.close()
	elif FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))


func _open() -> void:
	_m = (load(SCENE) as PackedScene).instantiate()
	_m.set("keep_bests", false)
	root.add_child(_m)
	current_scene = _m
	for i in 20:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_m.set_process_unhandled_input(false)
	(_m.get("view") as Node).set("keys_on", false)
	(_m.get("rig") as Node).set_process_unhandled_input(false)
	(_m.get("player") as Node).set("input_enabled", false)


func _down_at(cell: Vector3i, face: Vector4) -> void:
	_m.set("on_overlook", false)
	(_m.get("overlook")["lift"] as Node4D).position.y = float(_m.get("overlook")["bottom"])
	_m.call("_overlook_framing", false)
	var lv = _m.get("lattice")
	_m.call("_place_player", lv.cell_centre(cell) + Vector4(0, 0.1, 0, 0), face)
	await _wait(0.5)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_had_cfg = FileAccess.file_exists(CFG)
	if _had_cfg:
		_backup = FileAccess.get_file_as_bytes(CFG)
	await _open()
	# Corners: level 3's ground floor (a T junction), level and turned, close.
	_m.call("_load_level", 2)
	await _down_at(Vector3i(1, 1, 0), Vector4(0, 0, -1, 0))
	var rig: Node4D = _m.get("rig")
	rig.set("_zoom_target", 2.4)
	rig.set("distance", 2.4)
	await _wait(0.5)
	await _shot("01_corner_level")
	(_m.get("view") as Node).call("quarter_turn")
	await _wait(0.8)
	await _shot("02_corner_turned")
	(_m.get("view") as Node).call("quarter_turn")
	await _wait(0.6)
	# Level 5 from above: every corner a post.
	_m.call("_load_level", 4)
	(_m.get("view") as Node).set("keys_on", false)
	(_m.get("player") as Node).set("input_enabled", false)
	await _wait(1.0)
	await _shot("03_posts_from_the_overlook")
	# The Colours page.
	var panel: Node = _m.get("dev_panel")
	panel.call("toggle")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(panel.get("_tabs") as TabContainer).current_tab = 1
	await _shot("04_colours_page")
	var picks := {"sw:maze_wall": Color(0.86, 0.74, 0.62), "sw:maze_wall_w": Color(0.36, 0.72, 0.48), "role:start": Color(0.95, 0.45, 0.70),
		"role:exit": Color(0.55, 0.30, 0.95), "walker:skin": Color(0.70, 0.16, 0.14), "light:bright:sky_top": Color(0.85, 0.55, 0.35)}
	for k in picks:
		panel.call("_colour_changed", k, picks[k])
	await _wait(0.4)
	panel.call("toggle")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _shot("05_recoloured")
	var wall: Array = LabGrid.values("maze_wall")
	_check((wall[0] as Color).is_equal_approx(picks["sw:maze_wall"]), "the walls take the new colour live")
	var body: MeshInstance4D = (_m.get("avatar") as Node).find_child("Tunic", true, false)
	_check(body != null and (body.material_override as TetraMaterial4D).albedo_color.is_equal_approx(picks["walker:skin"]), "the walker's body is painted in place")
	panel.call("save_values")
	_m.queue_free()
	await _wait(0.5)
	# Opened again: the save is read back before anything is built.
	await _open()
	var again: Dictionary = _m.get("colours")
	var held: bool = true
	for k in picks:
		if not (again.get(k, Color.BLACK) as Color).is_equal_approx(picks[k]):
			held = false
	_check(held, "SAVE keeps every colour across a restart")
	_check((LabGrid.values("maze_wall")[0] as Color).is_equal_approx(picks["sw:maze_wall"]), "the saved wall colour is in force on opening")
	await _shot("06_reopened_lobby")
	# Reset the page, and put Ramon's file back.
	var p2: Node = _m.get("dev_panel")
	(p2.get("_tabs") as TabContainer).current_tab = 1
	p2.call("_reset_page")
	var default_wall: Color = load("res://ramon/PhaseMazeRemake/maze/maze_style.gd").SWATCHES["maze_wall"][0]
	_check((LabGrid.values("maze_wall")[0] as Color).is_equal_approx(default_wall), "RESET puts the colours back")
	_restore()
	print("COLOURS: %s" % ("PASS" if _fails.is_empty() else "FAIL " + str(_fails)))
	quit()
