extends SaveToFiles


func _ready() -> void:
	var script_dir: String = get_script().get_path().get_base_dir()
	var files: PackedStringArray = get_files_recursive(script_dir, "off")
	for file_path in files:
		var base_path: String = file_path.trim_suffix(".off")
		var off_doc := OFFDocument4D.import_load_from_file(file_path)
		# Scale by the longest length.
		var verts: PackedVector4Array = off_doc.vertices
		var longest_length: float = 0.0
		for vert in verts:
			if vert.length() > longest_length:
				longest_length = vert.length()
		for i in range(verts.size()):
			verts[i] = verts[i] / longest_length
		off_doc.vertices = verts
		# Make 3D scene.
		var mesh_3d: ArrayMesh = off_doc.import_generate_mesh_3d(true, true)
		mesh_3d.resource_name = base_path.get_file() + "_mesh"
		var mesh_inst_3d := MeshInstance3D.new()
		mesh_inst_3d.mesh = mesh_3d
		mesh_inst_3d.name = base_path.get_file().capitalize()
		# Save to glTF `.glb` file.
		var glb_path: String = base_path + ".glb"
		var gltf_doc := GLTFDocument.new()
		var gltf_state := GLTFState.new()
		gltf_doc.append_from_scene(mesh_inst_3d, gltf_state)
		gltf_doc.write_to_filesystem(gltf_state, glb_path)


func get_files_recursive(path: String, target_extension: String = "") -> PackedStringArray:
	var files := PackedStringArray()
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					var sub_folder_path = path.path_join(file_name)
					files.append_array(get_files_recursive(sub_folder_path, target_extension))
			else:
				if target_extension == "" or file_name.ends_with(target_extension):
					files.append(path.path_join(file_name))
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Failed to access path: ", path)
	return files
