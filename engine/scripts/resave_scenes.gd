extends SceneTree


var _failure_count := 0


func _initialize() -> void:
	_resave_scenes.call_deferred()


func _resave_scenes() -> void:
	# Let the editor begin its initial filesystem scan before checking its state.
	await process_frame
	var editor_file_system := EditorInterface.get_resource_filesystem()
	while editor_file_system.is_scanning():
		await process_frame

	var scene_paths: Array[String] = []
	_collect_scene_paths(editor_file_system.get_filesystem(), scene_paths)
	scene_paths.sort()

	print("Found %d .tscn scenes to re-save." % scene_paths.size())
	# Assign every scene a UID before saving any references to those scenes.
	for scene_path in scene_paths:
		ResourceSaver.get_resource_id_for_path(scene_path, true)

	await _wait_for_deferred_editor_work()
	await _close_open_scenes()

	var saved_count := 0
	for scene_path in scene_paths:
		print("Re-saving: %s" % scene_path)
		EditorInterface.open_scene_from_path(scene_path)
		await _wait_for_deferred_editor_work()

		var scene_root := EditorInterface.get_edited_scene_root()
		if scene_root == null or scene_root.scene_file_path != scene_path:
			push_error("Could not open scene: %s" % scene_path)
			_failure_count += 1
		else:
			# Headless mode cannot generate editor thumbnails reliably. This still
			# uses the editor's complete scene packing and save path.
			EditorInterface.save_scene_as(scene_path, false)
			saved_count += 1
			await _wait_for_deferred_editor_work()

		await _close_open_scenes()

	# Let notifications and deferred editor work complete before shutting down.
	await _wait_for_deferred_editor_work()

	if _failure_count == 0:
		print("Successfully re-saved %d scenes." % saved_count)
		quit(0)
	else:
		push_error("Re-saved %d scenes; %d scenes failed." % [saved_count, _failure_count])
		quit(1)


func _collect_scene_paths(directory: EditorFileSystemDirectory, scene_paths: Array[String]) -> void:
	for file_index in range(directory.get_file_count()):
		var file_path := directory.get_file_path(file_index)
		if file_path.get_extension().to_lower() == "tscn":
			scene_paths.append(file_path)

	for directory_index in range(directory.get_subdir_count()):
		_collect_scene_paths(directory.get_subdir(directory_index), scene_paths)


func _close_open_scenes() -> void:
	while EditorInterface.get_edited_scene_root() != null:
		var close_error := EditorInterface.close_scene()
		if close_error != OK:
			push_error("Could not close the current scene (error %d)." % close_error)
			_failure_count += 1
			return
		await _wait_for_deferred_editor_work()


func _wait_for_deferred_editor_work() -> void:
	# At least 2 are required, 3 is safer.
	for i in range(3):
		await process_frame
