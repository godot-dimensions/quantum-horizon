extends SaveToFiles


@export var y_height: float = 2.0
@export var w_thickness: float = 2.0
@export var radius: float = 0.5
@export var radial_segments: int = 16
@export var smooth: bool = true


func _ready() -> void:
	for child in get_children():
		if child.has_method(&"is_visible_in_tree") and not child.call(&"is_visible_in_tree"):
			return
	var cubinder_shape := CubinderShape4D.new()
	cubinder_shape.radius = radius
	cubinder_shape.height = y_height
	cubinder_shape.thickness = w_thickness
	var cubinder_mesh: ArrayPolyMesh4D = convert_cubinder_to_poly_mesh(cubinder_shape)
	var param_name: String = params_to_name()
	var script_dir: String = get_script().get_path().get_base_dir()
	var base_path: String = script_dir.path_join(param_name + "/" + param_name)
	save_physics_shape_and_mesh_to_scene_and_g4mf(cubinder_shape, cubinder_mesh, base_path, "Cubinder")


func convert_cubinder_to_poly_mesh(cubinder_shape: CubinderShape4D) -> ArrayPolyMesh4D:
	var mesh_options: Dictionary = {
		"segments": radial_segments
	}
	var cubinder_mesh: ArrayPolyMesh4D = cubinder_shape.to_poly_mesh(mesh_options)
	assert(cubinder_mesh.is_mesh_data_valid())
	if smooth:
		cubinder_mesh.set_smooth_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
	else:
		cubinder_mesh.set_flat_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
	cubinder_mesh.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_AUTOMATIC)
	# The texture map gets generated in an XZ-symmetric way in texture space,
	# but it would be better if this was XY-symmetric for usability with 2D textures.
	var rot_yz := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
	assert(is_equal_approx(rot_yz.determinant(), 1.0))
	cubinder_mesh.transform_texture_map(Transform3D(rot_yz, Vector3(0.0, 1.0, 0.0)))
	assert(cubinder_mesh.is_mesh_data_valid())
	return cubinder_mesh


func params_to_name() -> String:
	var ret: String = "cubinder"
	ret += "_smooth" if smooth else "_flat"
	ret += "_y" + str(y_height)
	ret += "_w" + str(w_thickness)
	ret += "_r" + str(radius)
	ret += "_seg" + str(radial_segments)
	ret = ret.replace(".0_", "_").replace(".", "pt")
	return ret
