extends Node
## TEMPORARY - confirms pressing "Play" (not "Play Scene") reaches the main
## menu, and that the new "Voxel World Showcase (Hash+Brick)" entry actually
## switches to and runs terrain4d_voxel_showcase.tscn without error.

func _ready() -> void:
	await get_tree().process_frame
	await _run()

func _run() -> void:
	var menu = get_tree().current_scene
	print("1.play_reaches_main_menu: current_scene_path=%s (expect res://menu/main_menu.tscn)" % [menu.scene_file_path])
	var mode_list: VBoxContainer = menu.get_node("CenterContainer/VBoxContainer/ModeList")
	print("2.button_count_matches_modes: buttons=%d modes=%d match=%s" % [
		mode_list.get_child_count(), menu.AVAILABLE_MODES.size(), mode_list.get_child_count() == menu.AVAILABLE_MODES.size()
	])
	var showcase_mode: Dictionary = {}
	for mode in menu.AVAILABLE_MODES:
		if mode.name == "Voxel World Showcase (Hash+Brick)":
			showcase_mode = mode
	print("3.showcase_entry_present: %s" % [not showcase_mode.is_empty()])

	var last_button: Button = mode_list.get_child(mode_list.get_child_count() - 1)
	print("4.last_button_label: '%s' (expect 'Voxel World Showcase (Hash+Brick)')" % [last_button.text])
	last_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var new_scene = get_tree().current_scene
	print("5.scene_switched_to_showcase: current_scene_path=%s (expect res://sandbox/terrain4d/terrain4d_voxel_showcase.tscn)" % [new_scene.scene_file_path])

	for i in range(30):
		await get_tree().process_frame
	print("6.showcase_ran_30_frames_without_crash: true")
	print("DONE")
	get_tree().quit()
