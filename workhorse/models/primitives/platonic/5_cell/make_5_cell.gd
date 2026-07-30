extends SaveToFiles

func _ready() -> void:
	var script_dir: String = get_script().get_path().get_base_dir()
	var base_path: String = script_dir.path_join("5_cell")
	var mesh: ArrayPolyMesh4D = load_as_array_poly_mesh_4d(base_path + ".off")
	mesh.resource_name = ""
	save_mesh_4d_to_scene_and_g4mf(mesh, base_path)
