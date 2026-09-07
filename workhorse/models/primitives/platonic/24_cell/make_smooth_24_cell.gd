extends SaveToFiles


func _ready() -> void:
	var script_dir: String = get_script().get_path().get_base_dir()
	var source_path: String = script_dir.path_join("24_cell.off")
	var mesh: ArrayPolyMesh4D = load_as_array_poly_mesh_4d(source_path)
	mesh.resource_name = ""
	_make_smooth_24_cell(mesh.duplicate_deep())
	_make_flat_24_cell(mesh.duplicate_deep())


func _make_smooth_24_cell(mesh: ArrayPolyMesh4D) -> void:
	var script_dir: String = get_script().get_path().get_base_dir()
	var base_path: String = script_dir.path_join("24_cell_smooth")
	mesh.set_smooth_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_FORCE_OUTWARD_FIX_CELL_ORIENTATION)
	mesh.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_TILE_ISLANDS)
	# Deduplicate and compact the normals and texture map values.
	mesh.compact_normal_values()
	mesh.compact_texture_map_values()
	# Save.
	mesh.resource_name = "24_cell_smooth_mesh"
	ResourceSaver.save(mesh, base_path + ".tres")
	save_mesh_4d_to_scene_and_g4mf(mesh, base_path)


func _make_flat_24_cell(mesh: ArrayPolyMesh4D) -> void:
	var script_dir: String = get_script().get_path().get_base_dir()
	var base_path: String = script_dir.path_join("24_cell")
	mesh.set_flat_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_FORCE_OUTWARD_FIX_CELL_ORIENTATION)
	mesh.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_TILE_ISLANDS)
	# Deduplicate and compact the normals and texture map values.
	mesh.compact_normal_values()
	mesh.compact_texture_map_values()
	# Save.
	mesh.resource_name = "24_cell_mesh"
	ResourceSaver.save(mesh, base_path + ".tres")
	save_mesh_4d_to_scene_and_g4mf(mesh, base_path)
