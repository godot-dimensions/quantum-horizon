@tool
extends Node

## THE W TOOLS IN THE EDITOR, AS SCREENSHOTS (Ramon, 7 Oct: "take screenshots of the editor itself and
## explain the basics of the interface tooling ... also in regards to what you can see in volume view"). Open
## this scene in the editor and it drives the editor: the pen opened, the W tool nodes selected and framed,
## Preview and Analyse pressed, the 4D view switched between Combined (the editor's setting here), the slice
## (Cross-section) and the volume view (Projected), a screenshot of the whole editor at each step; then all
## put back (Preview off, the view as it was, this scene closed) and the editor quits.
##
## It runs only when the editor is started with "wt_shots" after "--", so this scene left open in a tab can
## never take the editor over:
##   godot --path project -e res://ramon/WTools/tests/_editor_shots.tscn -- wt_shots      (behind the lock)
## Shots: res://smoke_test_output/wtools/editor/*.png

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const OUT := "res://smoke_test_output/wtools/editor/"

var _tree: SceneTree


func _ready() -> void:
	if not Engine.is_editor_hint() or not OS.get_cmdline_user_args().has("wt_shots") or owner != null:
		return
	_tree = get_tree()
	_run.call_deferred()


func _wait(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _wait(30)
	var me: String = scene_file_path
	EditorInterface.open_scene_from_path(PEN)
	await _wait(120)
	var pen: Node = EditorInterface.get_edited_scene_root()
	if pen == null or pen.scene_file_path != PEN:
		print("SHOTS: the pen did not open")
		_quit()
		return
	EditorInterface.set_main_screen_editor("4D")
	await _wait(20)
	var cam: Camera4D = _editor_camera()
	var engine_was: String = cam.rendering_engine_name if cam != null else ""
	print("SHOTS: editor camera %s, engine %s" % [str(cam != null), engine_was])
	var trees: Node = pen.get_node("World/Trees")
	var stone: Node = pen.get_node("World/WatchstoneW")
	var range_w: Node = pen.get_node("World/RangeW")
	if OS.get_cmdline_user_args().has("ring"):
		# The Wrap Style dropdown on Ring: the inspector, the Scene dock's warning mark, the About Ring box.
		await _select_and_frame(range_w, pen.get_node("World/Range"), 2, cam, -0.3)
		pen.get_node("World/Trees").set_display_folded(true)
		range_w.set("wrap_style", 1)
		range_w.update_configuration_warnings()
		EditorInterface.edit_node(range_w)
		await _wait(20)
		_unfold_script_groups(3)
		await _wait(10)
		_scroll_inspector(0.0)
		await _shot("8_ring_inspector", cam, engine_was)
		range_w.call("show_ring_note")
		await _wait(20)
		await _shot("9_ring_note", cam, engine_was)
		for d in EditorInterface.get_base_control().find_children("*", "AcceptDialog", true, false):
			if (d as AcceptDialog).title.begins_with("Ring"):
				(d as AcceptDialog).queue_free()
		range_w.set("wrap_style", 0)
		pen.get_node("World/Trees").set_display_folded(false)
		print("SHOTS DONE")
		_quit(me)
		return
	# 1-4: the trees.
	await _select_and_frame(trees, pen.get_node("World/Trees/OakL03"), 3, cam, -0.2)
	await _shot("1_trees_combined", cam, engine_was)
	trees.call("toggle_preview")
	await _wait(30)
	EditorInterface.edit_node(trees)
	await _shot("2_trees_preview_combined", cam, engine_was)
	await _shot("3_trees_preview_slice", cam, "Cross-section")
	await _shot("4_trees_preview_volume", cam, "Projected")
	trees.call("toggle_preview")
	await _wait(10)
	# 5: the Watchstone's Optimiser, its report.
	await _select_and_frame(stone, pen.get_node("World/LookoutSite/Lookout"), 2, cam, -0.15)
	stone.call("analyse")
	await _wait(5)
	EditorInterface.edit_node(stone)
	await _wait(10)
	_unfold_script_groups(3)
	await _wait(10)
	_scroll_inspector(0.18)
	await _shot("5_watchstone_report", cam, engine_was)
	_scroll_inspector(0.0)
	await _shot("6_watchstone_top", cam, engine_was)
	# 7: the range's.
	await _select_and_frame(range_w, pen.get_node("World/Range"), 2, cam, -0.3)
	range_w.call("analyse")
	await _wait(5)
	EditorInterface.edit_node(range_w)
	await _wait(10)
	_unfold_script_groups(3)
	await _wait(10)
	_scroll_inspector(0.18)
	await _shot("7_range_report", cam, engine_was)
	# Put back.
	if cam != null and engine_was != "":
		cam.rendering_engine_name = engine_was
	stone.call("clear")
	range_w.call("clear")
	print("SHOTS DONE")
	_quit(me)


## The editor's own 4D camera (the Camera4D under the editor's EditorCamera4D).
func _editor_camera() -> Camera4D:
	for n in EditorInterface.get_base_control().find_children("*", "Camera4D", true, false):
		if n.get_parent() != null and n.get_parent().get_class() == "EditorCamera4D":
			return n as Camera4D
	return null


## [param node] in the inspector, and the 4D view framed on [param frame] (F, as the editor's own key), then
## the view pulled back [param out] turns of the mouse wheel.
func _select_and_frame(node: Node, frame: Node, out: int = 0, cam: Camera4D = null, pitch: float = -0.5) -> void:
	var sel: EditorSelection = EditorInterface.get_selection()
	sel.clear()
	sel.add_node(frame)
	await _wait(5)
	var surface: Control = null
	for n in EditorInterface.get_base_control().find_children("*", "", true, false):
		if n.get_class() == "EditorInputSurface4D" and (n as Control).is_visible_in_tree():
			surface = n as Control
			break
	if surface != null:
		surface.grab_focus()
		var key := InputEventKey.new()
		key.keycode = KEY_F
		key.physical_keycode = KEY_F
		key.pressed = true
		surface.get_viewport().push_input(key)
		var up: InputEventKey = key.duplicate()
		up.pressed = false
		surface.get_viewport().push_input(up)
		await _wait(40)
		var middle: Vector2 = surface.get_global_rect().get_center()
		for i in out:
			for pressed in [true, false]:
				var wheel := InputEventMouseButton.new()
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = pressed
				wheel.position = middle
				wheel.global_position = middle
				surface.get_viewport().push_input(wheel)
			await _wait(2)
	# A lower look than the editor's own (it orbits from above): the camera's turn is its own to set.
	if cam != null and cam.get_parent() is Node4D:
		(cam.get_parent() as Node4D).basis = Basis4D.from_zx(0.5) * Basis4D.from_yz(pitch)
	await _wait(60)
	sel.clear()
	sel.add_node(node)
	EditorInterface.edit_node(node)
	await _wait(10)


## The script's own groups (the first [param count] sections) unfolded, so the report shows.
func _unfold_script_groups(count: int) -> void:
	var sections: Array = EditorInterface.get_inspector().find_children("*", "EditorInspectorSection", true, false)
	for i in mini(count, sections.size()):
		sections[i].call("unfold")


func _scroll_inspector(where: float) -> void:
	var insp: EditorInspector = EditorInterface.get_inspector()
	var bar: VScrollBar = insp.get_v_scroll_bar()
	insp.scroll_vertical = int(where * bar.max_value)


func _shot(name: String, cam: Camera4D, engine: String) -> void:
	if cam != null and engine != "" and cam.rendering_engine_name != engine:
		cam.rendering_engine_name = engine
	await _wait(30)
	await RenderingServer.frame_post_draw
	var img: Image = EditorInterface.get_base_control().get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("SHOT %s (%dx%d, %s)" % [name, img.get_width(), img.get_height(), cam.rendering_engine_name if cam != null else "?"])


## The editor quit, and this scene's tab closed (the quit queued first: closing the tab frees this node).
func _quit(me: String = "") -> void:
	if me != "":
		for i in 4:
			var root: Node = EditorInterface.get_edited_scene_root()
			if root != null and root.scene_file_path == me:
				break
			EditorInterface.open_scene_from_path(me)
			await _wait(10)
	_tree.quit.call_deferred()
	if me != "":
		EditorInterface.close_scene()
