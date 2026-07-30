extends SaveToFiles


func _ready() -> void:
	var script_dir: String = get_script().get_path().get_base_dir()
	var base_path: String = script_dir.path_join("120_cell")
	var mesh: ArrayPolyMesh4D = load_as_array_poly_mesh_4d(base_path + ".off")
	mesh.resource_name = "120_cell_mesh"
	# Scale by the longest length.
	var verts: PackedVector4Array = mesh.poly_cell_vertices
	var longest_length: float = 0.0
	for vert in verts:
		if vert.length() > longest_length:
			longest_length = vert.length()
	for i in range(verts.size()):
		verts[i] = verts[i] / longest_length
	mesh.poly_cell_vertices = verts
	# Save.
	save_mesh_4d_to_scene_and_g4mf(mesh, base_path)
	# Smooth and save again.
	mesh.set_smooth_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_FORCE_OUTWARD_FIX_CELL_ORIENTATION)
	base_path = script_dir.path_join("120_cell_smooth")
	save_mesh_4d_to_scene_and_g4mf(mesh, base_path)
