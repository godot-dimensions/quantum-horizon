extends Node
## TEMPORARY - verifies the menu <-> gallery scene-transition flow end to
## end (mode-button press, escape-returns-to-menu). Not part of the shipped
## game; wired in as a temporary autoload only for this verification run,
## specifically because it needs to survive change_scene_to_file() calls
## that a plain child of the affected scene would not.

const GALLERY_PATH := "res://sandbox/shooting_gallery/shooting_gallery.tscn"
const MENU_PATH := "res://menu/main_menu.tscn"


func _press_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var menu: Control = get_tree().current_scene
	print("1.starts_at_menu: current_scene=%s (expect %s) match=%s" % [
		menu.scene_file_path, MENU_PATH, menu.scene_file_path == MENU_PATH,
	])
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/menu_overview.png")

	var mode_list: VBoxContainer = menu.get_node("CenterContainer/VBoxContainer/ModeList")
	print("2.mode_button_count: %d (expect %d)" % [mode_list.get_child_count(), menu.AVAILABLE_MODES.size()])
	for i in mode_list.get_child_count():
		var button: Button = mode_list.get_child(i)
		print("2b.mode_button[%d]: text=%s (expect %s)" % [i, button.text, menu.AVAILABLE_MODES[i].name])

	var quit_button: Button = menu.get_node("CenterContainer/VBoxContainer/QuitButton")
	print("3.quit_button_exists: %s text=%s" % [quit_button != null, quit_button.text])

	# 4. Pressing the first mode button (a real signal emission, not a
	# direct function call) should navigate to that mode's scene.
	var first_button: Button = mode_list.get_child(0)
	first_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var after_press_path: String = get_tree().current_scene.scene_file_path
	print("4.button_press_navigates: current_scene=%s (expect %s) match=%s" % [
		after_press_path, GALLERY_PATH, after_press_path == GALLERY_PATH,
	])

	# 5. Escape inside a gameplay scene should return to the menu (not quit
	# the whole application, which is what ui_cancel used to do before the
	# menu existed).
	await _press_action(&"ui_cancel")
	await get_tree().process_frame
	var after_escape_path: String = get_tree().current_scene.scene_file_path
	print("5.escape_returns_to_menu: current_scene=%s (expect %s) match=%s" % [
		after_escape_path, MENU_PATH, after_escape_path == MENU_PATH,
	])

	get_tree().quit()
