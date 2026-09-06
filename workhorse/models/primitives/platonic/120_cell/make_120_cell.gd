extends SaveToFiles


func _ready() -> void:
	var script_dir: String = get_script().get_path().get_base_dir()
	var base_path: String = script_dir.path_join("120_cell")
	var mesh: ArrayPolyMesh4D = load_as_array_poly_mesh_4d(base_path + ".off")
	mesh.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_TILE_ISLANDS)
	mesh.resource_name = "120_cell_mesh"
	# Scale by the longest length.
	var verts: PackedVector4Array = mesh.poly_cell_vertex_positions
	var longest_length: float = 0.0
	for vert in verts:
		if vert.length() > longest_length:
			longest_length = vert.length()
	for i in range(verts.size()):
		verts[i] = verts[i] / longest_length
	mesh.poly_cell_vertex_positions = verts
	mesh.calculate_boundary_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
	# Deduplicate and compact the normals and texture map values.
	mesh.compact_normal_values()
	mesh.compact_texture_map_values()
	# Save.
	save_mesh_4d_to_scene_and_g4mf(mesh, base_path)
	# Smooth and save again.
	mesh.set_smooth_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_FORCE_OUTWARD_FIX_CELL_ORIENTATION)
	mesh.compact_normal_values()
	base_path = script_dir.path_join("120_cell_smooth")
	save_mesh_4d_to_scene_and_g4mf(mesh, base_path)
