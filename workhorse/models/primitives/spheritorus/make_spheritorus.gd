# Confused about the words? Here is the key:
# 3D torus: circle swept around circle
# 4D spheritorus (this file): sphere swept around circle
# 4D torisphere: circle swept around sphere
extends SaveToFiles


@export var major_radius = 2.0
@export var minor_radius = 0.5
@export var steps: int = 32
@export_range(0, 3, 1) var source_icosphere: int = 1
@export var smooth: bool = true


func _ready() -> void:
	for child in get_children():
		if child.has_method(&"is_visible_in_tree") and not child.call(&"is_visible_in_tree"):
			return
	var ico_glb: String = "icosphere" + str(source_icosphere) + ".glb"
	var base: ArrayPolyMesh4D = load_as_array_poly_mesh_4d("res://models/3d/icosphere/" + ico_glb)
	var spheritorus: ArrayPolyMesh4D = make_spheritorus(base)
	spheritorus.resource_name = "spheritorus_mesh"
	var tetra: ArrayTetraMesh4D = spheritorus.to_array_tetra_mesh()
	tetra.resource_name = "spheritorus_mesh"
	var param_name: String = params_to_name()
	var script_dir: String = get_script().get_path().get_base_dir()
	var base_path: String = script_dir.path_join(param_name + "/" + param_name)
	save_mesh_4d_to_scene_and_g4mf(tetra, base_path)
	# Also save a copy of the latest one so we can show it in `make_spheritorus.tscn`.
	base_path = script_dir.path_join("latest/spheritorus")
	save_mesh_4d_to_scene_and_g4mf(tetra, base_path)


func make_spheritorus(base: ArrayPolyMesh4D) -> ArrayPolyMesh4D:
	var scale: Projection = Basis4D.from_scale_uniform(minor_radius)
	base.transform_vertices(Vector4(major_radius, 0.0, 0.0, 0.0), scale)
	var extruded: ArrayPolyMesh4D = PolyMeshBuilder4D.extrude_spin_from_faces_xw(base, steps)
	extruded.transform_vertices(Vector4.ZERO, Basis4D.from_zw(TAU / 4.0))
	if smooth:
		extruded.set_smooth_shading_normals()
	else:
		extruded.set_flat_shading_normals()
	return extruded


func params_to_name() -> String:
	var ret: String = "spheritorus"
	ret += "_smooth" if smooth else "_flat"
	ret += "_ma" + str(major_radius)
	ret += "_mi" + str(minor_radius)
	ret += "_step" + str(steps)
	ret = ret.replace(".0_", "_").replace(".", "pt")
	return ret
