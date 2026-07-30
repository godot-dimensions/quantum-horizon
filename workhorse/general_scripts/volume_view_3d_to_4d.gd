extends SaveToFiles


@export var depth_meters: float = 50.0

# TODO: Maybe instead of a hard-coded hack, we can later add an "is convex" check?
var hack_use_existing_vert_on_these_meshes := PackedStringArray([
	"ponds_Part7_mesh"
])


func _ready() -> void:
	for child in get_children():
		if child.has_method(&"is_visible_in_tree") and not child.call(&"is_visible_in_tree"):
			return
	var input_node: Node3D = get_child(0)
	var base_path: String = input_node.scene_file_path.get_basename()
	var poly_mesh: ArrayPolyMesh4D = reassemble_all_3d_meshes_in_scene_to_4d_vertical_prism(input_node)
	poly_mesh.resource_name = base_path.get_file() + "_mesh"
	poly_mesh.set_smooth_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
	poly_mesh.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_TILE_ISLANDS)
	texture_map_ground_cells_by_spatial_position(poly_mesh)
	# Collapse the final result from poly to tetra to avoid
	# complications with the non-convex star-shaped cells being used.
	var tetra_mesh: ArrayTetraMesh4D = poly_mesh.to_array_tetra_mesh()
	print(tetra_mesh.get_simplex_cell_indices().size())
	#tetra_mesh.remove_opposite_overlapping_tetrahedra()
	print(tetra_mesh.get_simplex_cell_indices().size())
	save_mesh_4d_to_scene_and_g4mf(tetra_mesh, base_path)


func reassemble_all_3d_meshes_in_scene_to_4d_vertical_prism(input_node: Node) -> ArrayPolyMesh4D:
	var mesh_3d_nodes: Array[Node] = input_node.find_children("*", "MeshInstance3D", true, true)
	var combined_mesh_4d := ArrayPolyMesh4D.new()
	for node in mesh_3d_nodes:
		var this_node_3d: MeshInstance3D = node as MeshInstance3D
		var this_mesh_3d: ArrayMesh = this_node_3d.mesh as ArrayMesh
		assert(this_mesh_3d != null)
		var this_transform_3d: Transform3D = this_node_3d.global_transform
		var this_mesh_4d: ArrayPolyMesh4D = centroid_based_3d_mesh_to_4d(this_mesh_3d, this_transform_3d)
		assert(this_mesh_4d != null)
		combined_mesh_4d.merge_with(this_mesh_4d, Vector4D.from_3d(-this_transform_3d.origin))
	combined_mesh_4d.deduplicate_all_elements()
	rotate_and_flatten_mesh_to_xzw(combined_mesh_4d)
	return combined_mesh_4d


func centroid_based_3d_mesh_to_4d(mesh_3d: ArrayMesh, transform_3d: Transform3D) -> ArrayPolyMesh4D:
	# Start by building tetrahedra from the origin combined with triangles.
	var tetra_mesh_4d := ArrayTetraMesh4D.new()
	tetra_mesh_4d.append_vertex(Vector4.ZERO)
	var faces: PackedVector3Array = mesh_3d.get_faces()
	if mesh_3d.resource_name in hack_use_existing_vert_on_these_meshes:
		var first_vert: Vector4 = Vector4D.from_3d(transform_3d * faces[0])
		for vert_index in range(0, faces.size(), 3):
			var a: Vector4 = Vector4D.from_3d(transform_3d * faces[vert_index])
			var b: Vector4 = Vector4D.from_3d(transform_3d * faces[vert_index + 1])
			var c: Vector4 = Vector4D.from_3d(transform_3d * faces[vert_index + 2])
			if a == first_vert or b == first_vert or c == first_vert:
				continue
			tetra_mesh_4d.append_tetra_cell_points(first_vert, a, b, c, true)
	else:
		for vert_index in range(0, faces.size(), 3):
			var a: Vector4 = Vector4D.from_3d(transform_3d * faces[vert_index])
			var b: Vector4 = Vector4D.from_3d(transform_3d * faces[vert_index + 1])
			var c: Vector4 = Vector4D.from_3d(transform_3d * faces[vert_index + 2])
			tetra_mesh_4d.append_tetra_cell_points(Vector4.ZERO, a, b, c, true)
	# Reconstruct those tetrahedra into poly mesh data for processing.
	# This is easier than starting by building poly mesh data because that
	# would mean we have to manually build the 1D edges and 2D faces first.
	var poly_mesh_4d: ArrayPolyMesh4D = PolyMeshBuilder4D.reconstruct_from_tetra_mesh(tetra_mesh_4d)
	assert(poly_mesh_4d.is_mesh_data_valid())
	poly_mesh_4d.calculate_boundary_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_FORCE_OUTWARD_FIX_CELL_ORIENTATION)
	# Extrude that along the W axis to start.
	return PolyMeshBuilder4D.extrude_linear(poly_mesh_4d, Vector4(0.0, 0.0, 0.0, 0.5 * depth_meters))


func rotate_and_flatten_mesh_to_xzw(mesh_4d: ArrayPolyMesh4D) -> void:
	# Transform all of the vertices to bring XYZ into XZW.
	var w_to_y_basis: Projection = Basis4D.from_wy(TAU / 4.0)
	# Transform the mesh to have one side at Y=0 and the other at Y=-depth.
	var offset := Vector4(0.0, -0.5 * depth_meters, 0.0, 0.0)
	mesh_4d.transform_vertices(offset, w_to_y_basis)


func texture_map_ground_cells_by_spatial_position(mesh_4d: ArrayPolyMesh4D) -> void:
	# Gather all cells that have the same Y coordinate everywhere on them.
	var all_cell_vert_ind: Array[PackedInt32Array] = mesh_4d.get_all_cell_vertex_indices(false)
	var all_cell_vert_val: PackedVector4Array = mesh_4d.poly_cell_vertices
	var ground_cells := PackedInt32Array()
	for cell_index in range(all_cell_vert_ind.size()):
		var this_cell_vert_ind: PackedInt32Array = all_cell_vert_ind[cell_index]
		var y: float = all_cell_vert_val[this_cell_vert_ind[0]].y
		var all_in_same_y: bool = true
		for vert_index in this_cell_vert_ind:
			if not is_equal_approx(y, all_cell_vert_val[vert_index].y):
				all_in_same_y = false
				break
		if all_in_same_y:
			ground_cells.append(cell_index)
	# Find the max and min values of vertices in those cells.
	var rect_max := Vector4(-INF, -INF, -INF, -INF)
	var rect_min := Vector4(INF, INF, INF, INF)
	for cell_index in ground_cells:
		var this_cell_vert_ind: PackedInt32Array = all_cell_vert_ind[cell_index]
		for vert_index in this_cell_vert_ind:
			rect_max = rect_max.max(all_cell_vert_val[vert_index])
			rect_min = rect_min.min(all_cell_vert_val[vert_index])
	# Remap the spatial coordinates into spatial coordinates, fitting the whole range into a 0 to 1 space.
	# Discard Y, and use spatial X -> texture X, spatial Z -> texture Y, spatial W -> texture Z.
	var tex_map: Array[PackedVector3Array] = mesh_4d.poly_cell_texture_map
	var rect_size: Vector4 = rect_max - rect_min
	for cell_index in ground_cells:
		var this_cell_vert_ind: PackedInt32Array = all_cell_vert_ind[cell_index]
		var this_cell_tex_map: PackedVector3Array = tex_map[cell_index]
		this_cell_tex_map.resize(this_cell_vert_ind.size())
		for vert_index in range(this_cell_vert_ind.size()):
			var vert_pos: Vector4 = all_cell_vert_val[this_cell_vert_ind[vert_index]]
			var vert_pos_in_rect: Vector4 = (vert_pos - rect_min) / rect_size
			var tex_coord: Vector3 = Vector3(vert_pos_in_rect.x, vert_pos_in_rect.z, vert_pos_in_rect.w)
			this_cell_tex_map[vert_index] = tex_coord
		tex_map[cell_index] = this_cell_tex_map
	mesh_4d.poly_cell_texture_map = tex_map
	mesh_4d.poly_mesh_clear_cache()
