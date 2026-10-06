extends SceneTree

## The final range from the final menu (6 Oct): the Quantum Range entry selected, its clip and words in
## the pane, launched on top of the menu, a stage played there, and both ways back (H, then Escape)
## leaving nothing of the range behind. Also prints the preview pane's size, which decides which band of
## the menu clip shows (`preview_focus`). Frames in smoke_test_output/quantum_range/menu/.
##
##   range_run.sh windowed menu res://ramon/QuantumRange/scripts/_verify_menu_range_runner.gd

const MENU := "res://ramon/menu_final.tscn"
const RANGE := "res://ramon/QuantumRange/quantum_range_final.tscn"
const OUT := "res://smoke_test_output/quantum_range/menu/"

var _menu: Node
var _t0: int = 0
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 120000:
		print("MENU: gave up after 120 s")
		return true
	return false


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("   saved ", name)


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)


func _labels_text(node: Node) -> String:
	var out: PackedStringArray = []
	for l in node.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			out.append((l as Label).text)
	return " | ".join(out)


## Launches the selected entry and waits for the range to be running on top of the menu.
func _launch() -> Node:
	_menu.call("_on_launch_pressed", 0)
	var waited: float = 0.0
	while _menu.get("_running") == null and waited < 30.0:
		await _wait(0.1)
		waited += 0.1
	await _wait(1.0)
	return _menu.get("_running")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_menu = (load(MENU) as PackedScene).instantiate()
	root.add_child(_menu)
	current_scene = _menu
	await _wait(1.5)
	var entries: Array = (_menu.get("catalogue") as Resource).get("entries")
	var index: int = -1
	for i in entries.size():
		if String((entries[i] as Resource).get("title")) == "Quantum Range":
			index = i
	_check("the catalogue has a Quantum Range entry", index >= 0)
	var entry: Resource = entries[index]
	_check("it opens the final range", String(entry.get("scene_path")) == RANGE, String(entry.get("scene_path")))
	_menu.call("_select", index)
	await _wait(2.5)
	var frame: Control = _menu.get("_preview_frame")
	print("MENU: preview pane %s (aspect %.2f), clip %s, focus %.2f" % [str(frame.size), frame.size.x / maxf(1.0, frame.size.y), entry.get("clip"), float(entry.get("preview_focus"))])
	var video: VideoStreamPlayer = _menu.get("_preview_video")
	_check("its clip plays in the pane", video != null and video.stream != null and video.is_playing(),
		str(video.stream.get("file")) if video != null and video.stream != null else "no stream")
	_check("the pane names its controls", _labels_text(_menu).contains("through w"), "")
	await _shot("1_selected")
	var before: int = root.get_child_count()

	# Launched on top of the menu, then a stage played there.
	var running: Node = await _launch()
	_check("the range runs on top of the menu", running != null and running.scene_file_path == RANGE and current_scene == _menu,
		running.scene_file_path if running != null else "never started")
	if running == null:
		print("MENU: %d failed" % (_fails + 1))
		quit()
		return
	var d: Node = running.get("director")
	_check("its director is in the lobby", d != null and String(d.get("state")) == "lobby", String(d.get("state")) if d != null else "")
	(running.get("sfx") as Node).set("muted", true)
	d.set("keep_bests", false)
	await _shot("2_lobby_in_menu")
	d.call("start", 2)
	await _wait(3.5)
	_check("a stage runs inside the menu", String(d.get("state")) == "stage", String(d.get("state")))
	await _shot("3_stage_in_menu")

	# H goes back.
	_key(KEY_H)
	await _wait(0.8)
	_check("H brings the menu back", _menu.get("_running") == null and (_menu.get("_shell") as Control).visible)
	_check("nothing of the range is left on the root", root.get_child_count() == before, "%d children, %d before" % [root.get_child_count(), before])
	_check("the mouse is free again", Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	await _shot("4_back_with_h")

	# Escape goes back too.
	_menu.call("_select", index)
	await _wait(0.5)
	running = await _launch()
	_check("it launches a second time", running != null and running.scene_file_path == RANGE)
	_key(KEY_ESCAPE)
	await _wait(0.8)
	_check("Escape brings the menu back", _menu.get("_running") == null and (_menu.get("_shell") as Control).visible)
	_check("nothing left after Escape either", root.get_child_count() == before, "%d children, %d before" % [root.get_child_count(), before])
	print("MENU: %d failed" % _fails)
	quit()
