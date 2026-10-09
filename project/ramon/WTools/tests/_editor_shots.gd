@tool
extends Node

## THE W TOOLS IN THE EDITOR, AS SCREENSHOTS (Ramon, 7 Oct: "take screenshots of the editor itself and
## explain the basics of the interface tooling ... also in regards to what you can see in volume view"). Open
## this scene in the editor and it drives the editor: the pen opened, the W tool nodes selected and framed,
## Preview pressed, the 4D view switched between Combined (the editor's setting here), the slice
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
	if OS.get_cmdline_user_args().has("paths"):
		# The paths in the volume view, coloured by W type, at three solidities (Ramon, 7 Oct: "can you make them
		# less transparent in volume view?"), seen three ways: flat (W collapsed), W across, W up. And the
		# trees' copies, there by themselves when the pen opens (show_preview).
		var copies: int = trees.get_children().filter(func(c: Node) -> bool: return c.has_meta(&"w_copy")).size()
		print("SHOTS: tree copies on opening: %d (show_preview %s)" % [copies, str(trees.get("show_preview"))])
		var paths: Node = pen.get_node("World/Paths")
		await _select_and_frame(paths, pen.get_node("World/Trees/OakL03"), 6, cam, -0.6)
		var rig := cam.get_parent() as Node4D if cam != null else null
		var views := {
			"flat": Basis4D.from_zx(0.5) * Basis4D.from_yz(-0.6),
			"w_across": Basis4D.from_zx(0.5) * Basis4D.from_xw(1.2) * Basis4D.from_yz(-0.6),
			"w_up": Basis4D.from_zx(0.5) * Basis4D.from_yz(-0.6) * Basis4D.from_wy(1.2),
		}
		for view in views:
			if rig != null:
				rig.basis = views[view]
			for solidity in [1, 30, 200, 1000]:
				paths.set("editor_volume_solidity", float(solidity))
				await _wait(10)
				await _shot("p_%s_s%04d" % [view, solidity], cam, engine_was)
		paths.set("editor_volume_solidity", 200.0)
		if rig != null:
			rig.basis = views["flat"]
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
	# Put back.
	if cam != null and engine_was != "":
		cam.rendering_engine_name = engine_was
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
