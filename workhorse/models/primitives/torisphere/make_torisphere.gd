# Confused about the words? Here is the key:
# 3D torus: circle swept around circle
# 4D spheritorus: sphere swept around circle
# 4D torisphere (this file): circle swept around sphere
extends SaveToFiles


@export var major_radius = 2.0
@export var minor_radius = 0.5
# Use 4, 8, 12, 16, etc for a pointy top.
# Use 6, 10, 14, 18, etc for a flat top.
@export_range(4, 1024, 1) var steps: int = 10
@export_range(1, 3, 1) var source_icosphere: int = 1
@export var smooth: bool = true


func _ready() -> void:
	for child in get_children():
		if child.has_method(&"is_visible_in_tree") and not child.call(&"is_visible_in_tree"):
			return
	#if source_icosphere < 1:
	#	printerr("I don't know why, but this breaks for non-subdivided icosahedrons.")
	#	breakpoint
	var ico_glb: String = "icosphere" + str(source_icosphere) + ".glb"
	var base: ArrayMesh = load_as_array_mesh_3d("res://models/3d/icosphere/" + ico_glb)
	assert(base != null)
	var torisphere: ArrayPolyMesh4D = make_torisphere(base)
	torisphere.resource_name = "torisphere_mesh"
	var tetra: ArrayTetraMesh4D = torisphere.to_array_tetra_mesh()
	tetra.resource_name = "torisphere_mesh"
	var param_name: String = params_to_name()
	var script_dir: String = get_script().get_path().get_base_dir()
	var base_path: String = script_dir.path_join(param_name + "/" + param_name)
	save_mesh_4d_to_scene_and_g4mf(torisphere, base_path)
	# Also save a copy of the latest one so we can show it in `make_torisphere.tscn`.
	base_path = script_dir.path_join("latest/torisphere")
	save_mesh_4d_to_scene_and_g4mf(torisphere, base_path)


func make_torisphere(base: ArrayMesh) -> ArrayPolyMesh4D:
	var surf_arrays: Array = base.surface_get_arrays(0)
	assert(surf_arrays.size() == Mesh.ARRAY_MAX)
	var surf_pos: PackedVector3Array = surf_arrays[Mesh.ARRAY_VERTEX]
	var surf_tex: PackedVector2Array = surf_arrays[Mesh.ARRAY_TEX_UV]
	var surf_ind: PackedInt32Array = surf_arrays[Mesh.ARRAY_INDEX]
	assert(surf_ind.size() != 0) # In our case we only need to support indexed 3D meshes.
	var torisphere := ArrayPolyMesh4D.new()
	for ind in range(0, surf_ind.size(), 3):
		var a_dir: Vector4 = Vector4D.from_3d(surf_pos[surf_ind[ind]])
		var b_dir: Vector4 = Vector4D.from_3d(surf_pos[surf_ind[ind + 1]])
		var c_dir: Vector4 = Vector4D.from_3d(surf_pos[surf_ind[ind + 2]])
		var a_tex_base: Vector3 = Vector3(surf_tex[surf_ind[ind]].x, surf_tex[surf_ind[ind]].y, 0.0)
		var b_tex_base: Vector3 = Vector3(surf_tex[surf_ind[ind + 1]].x, surf_tex[surf_ind[ind + 1]].y, 0.0)
		var c_tex_base: Vector3 = Vector3(surf_tex[surf_ind[ind + 2]].x, surf_tex[surf_ind[ind + 2]].y, 0.0)
		var a_origin: Vector4 = a_dir * major_radius
		var b_origin: Vector4 = b_dir * major_radius
		var c_origin: Vector4 = c_dir * major_radius
		var first_a_point := Vector4()
		var first_b_point := Vector4()
		var first_c_point := Vector4()
		var prev_a_point := Vector4()
		var prev_b_point := Vector4()
		var prev_c_point := Vector4()
		var prev_a_tex: Vector3 = Vector3()
		var prev_b_tex: Vector3 = Vector3()
		var prev_c_tex: Vector3 = Vector3()
		for ring_step in range(steps):
			var angle: float = float(ring_step) * (TAU / float(steps))
			var tex_z: float = float(ring_step) / float(steps)
			var w_offset: Vector4 = Vector4(0, 0, 0, minor_radius) * sin(angle)
			var a_point: Vector4 = a_origin + w_offset + (minor_radius * cos(angle) * a_dir)
			var b_point: Vector4 = b_origin + w_offset + (minor_radius * cos(angle) * b_dir)
			var c_point: Vector4 = c_origin + w_offset + (minor_radius * cos(angle) * c_dir)
			var a_tex: Vector3 = Vector3(a_tex_base.x, a_tex_base.y, tex_z)
			var b_tex: Vector3 = Vector3(b_tex_base.x, b_tex_base.y, tex_z)
			var c_tex: Vector3 = Vector3(c_tex_base.x, c_tex_base.y, tex_z)
			if first_a_point == Vector4():
				first_a_point = a_point
				first_b_point = b_point
				first_c_point = c_point
			else:
				# Make a triangular prism between this triangle and the previous.
				append_triangular_prism(torisphere, a_point, b_point, c_point, prev_a_point, prev_b_point, prev_c_point, a_tex, b_tex, c_tex, prev_a_tex, prev_b_tex, prev_c_tex)
			if ring_step == steps - 1:
				# Make a triangular prism between the first triangle and this one.
				var final_a_tex: Vector3 = Vector3(a_tex_base.x, a_tex_base.y, 1.0)
				var final_b_tex: Vector3 = Vector3(b_tex_base.x, b_tex_base.y, 1.0)
				var final_c_tex: Vector3 = Vector3(c_tex_base.x, c_tex_base.y, 1.0)
				append_triangular_prism(torisphere, first_a_point, first_b_point, first_c_point, a_point, b_point, c_point, final_a_tex, final_b_tex, final_c_tex, a_tex, b_tex, c_tex)
			prev_a_point = a_point
			prev_b_point = b_point
			prev_c_point = c_point
			prev_a_tex = a_tex
			prev_b_tex = b_tex
			prev_c_tex = c_tex
	assert(torisphere.is_mesh_data_valid())
	# The generated torisphere's normals are not correct.
	# Fix it up by forcing outward from the major axis ring.
	torisphere.calculate_boundary_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
	var all_verts: PackedVector4Array = torisphere.poly_cell_vertex_positions
	var bad_normals: PackedVector4Array = torisphere.get_poly_cell_boundary_normals()
	var cell_vert_ind: Array[PackedInt32Array] = torisphere.get_all_poly_cell_vertex_indices(3, false)
	var poly_ind: Array[Array] = torisphere.poly_cell_indices
	var all_cell_face_ind: Array = poly_ind[1]
	assert(cell_vert_ind.size() == bad_normals.size())
	for cell_index in range(cell_vert_ind.size()):
		var norm: Vector4 = bad_normals[cell_index]
		var cell_vert_inds: PackedInt32Array = cell_vert_ind[cell_index]
		# We have to just grab a point, NOT take an average,
		# because for low-definition icospheres or a low minor radius,
		# the average may not be representative of the actual surface normal.
		var any_point: Vector4 = all_verts[cell_vert_inds[0]]
		#var sum := Vector4()
		#for i in range(cell_vert_inds.size()):
		#	sum += all_verts[cell_vert_inds[i]]
		#var average: Vector4 = sum / float(cell_vert_inds.size())
		var ring_center: Vector4 = Vector4(any_point.x, any_point.y, any_point.z, 0.0).normalized() * major_radius
		var outward: Vector4 = ring_center.direction_to(any_point)
		if outward.dot(norm) < 0.0:
			var this_cell: PackedInt32Array = all_cell_face_ind[cell_index]
			var temp: int = this_cell[0]
			this_cell[0] = this_cell[1]
			this_cell[1] = temp
			all_cell_face_ind[cell_index] = this_cell
	poly_ind[1] = all_cell_face_ind
	torisphere.poly_cell_indices = poly_ind
	# Copy over the texture map from the triangle faces to the cells.
	# NOTE: This must be done BEFORE deduplicating, because the faces
	# at the end of the ring will be merged with the first face,
	# but for texture map purposes, we want these to be separate!
	cell_vert_ind = torisphere.get_all_poly_cell_vertex_indices(3, false)
	var face_vert_ind: Array[PackedInt32Array] = torisphere.get_all_poly_cell_vertex_indices(2, false)
	var all_tex_maps: Dictionary[Vector2i, Array] = torisphere.all_poly_cell_texture_maps
	var all_face_vert_tex: Array = all_tex_maps[Vector2i(2, 0)]
	var all_cell_vert_tex: Array[PackedVector3Array] = []
	all_cell_vert_tex.resize(cell_vert_ind.size())
	assert(all_cell_face_ind.size() == cell_vert_ind.size())
	for cell_index in range(cell_vert_ind.size()):
		var this_cell_face_inds: PackedInt32Array = all_cell_face_ind[cell_index]
		var this_cell_vert_inds: PackedInt32Array = cell_vert_ind[cell_index]
		var this_cell_tex := PackedVector3Array()
		this_cell_tex.resize(this_cell_vert_inds.size())
		for face in this_cell_face_inds:
			var this_face_verts: PackedInt32Array = face_vert_ind[face]
			var this_face_tex: PackedVector3Array = all_face_vert_tex[face]
			if this_face_tex.is_empty():
				continue # Nothing to copy, this is a quad. We only use the triangles as our data source.
			assert(this_face_verts.size() == this_face_tex.size())
			for i in range(this_face_verts.size()):
				var ind_in_cell: int = this_cell_vert_inds.find(this_face_verts[i])
				if ind_in_cell != -1:
					this_cell_tex[ind_in_cell] = this_face_tex[i]
		all_cell_vert_tex[cell_index] = this_cell_tex
	all_tex_maps[Vector2i(3, 0)] = all_cell_vert_tex
	torisphere.all_poly_cell_texture_maps = all_tex_maps
	assert(torisphere.is_mesh_data_valid())
	# Deduplicate all elements in the mesh to simplify it.
	# The deduplication process preserves associated data like normals and texture coordinates.
	torisphere.deduplicate_all_elements()
	torisphere.calculate_boundary_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
	PolyMeshBuilder4D.make_boundary_normals_topologically_consistent(torisphere, PackedInt32Array([0]))
	# The above code generates the hole through the W axis, but let's move it to the Y axis.
	torisphere.transform_vertices(Vector4.ZERO, Basis4D.from_wy(TAU / 4.0))
	torisphere.calculate_boundary_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
	if smooth:
		torisphere.set_smooth_shading_normals()
	else:
		torisphere.set_flat_shading_normals()
	return torisphere


func append_triangular_prism(poly_mesh_4d: ArrayPolyMesh4D, a1: Vector4, b1: Vector4, c1: Vector4, a2: Vector4, b2: Vector4, c2: Vector4, a1_tex: Vector3, b1_tex: Vector3, c1_tex: Vector3, a2_tex: Vector3, b2_tex: Vector3, c2_tex: Vector3) -> void:
	# Get data out of the mesh.
	var poly_ind: Array[Array] = poly_mesh_4d.poly_cell_indices
	if poly_ind.size() < 2:
		poly_ind.resize(2)
	var faces: Array = poly_ind[0]
	var cells: Array = poly_ind[1]
	var all_tex_maps: Dictionary[Vector2i, Array] = poly_mesh_4d.all_poly_cell_texture_maps
	var face_vert_tex: Array = all_tex_maps.get_or_add(Vector2i(2, 0), [])
	# Append the 9 edges of the triangular prism.
	var a1i: int = poly_mesh_4d.append_vertex(a1, false)
	var b1i: int = poly_mesh_4d.append_vertex(b1, false)
	var c1i: int = poly_mesh_4d.append_vertex(c1, false)
	var a2i: int = poly_mesh_4d.append_vertex(a2, false)
	var b2i: int = poly_mesh_4d.append_vertex(b2, false)
	var c2i: int = poly_mesh_4d.append_vertex(c2, false)
	var tri1_edge1: int = poly_mesh_4d.append_edge_indices(a1i, b1i, false)
	var tri1_edge2: int = poly_mesh_4d.append_edge_indices(b1i, c1i, false)
	var tri1_edge3: int = poly_mesh_4d.append_edge_indices(c1i, a1i, false)
	var tri2_edge1: int = poly_mesh_4d.append_edge_indices(a2i, b2i, false)
	var tri2_edge2: int = poly_mesh_4d.append_edge_indices(b2i, c2i, false)
	var tri2_edge3: int = poly_mesh_4d.append_edge_indices(c2i, a2i, false)
	var edge_a: int = poly_mesh_4d.append_edge_indices(a1i, a2i, false)
	var edge_b: int = poly_mesh_4d.append_edge_indices(b1i, b2i, false)
	var edge_c: int = poly_mesh_4d.append_edge_indices(c1i, c2i, false)
	var face_count: int = faces.size()
	# Append the 5 faces of the triangular prism cell.
	faces.append(PackedInt32Array([tri1_edge1, tri1_edge2, tri1_edge3]))
	faces.append(PackedInt32Array([tri1_edge1, edge_a, tri2_edge1, edge_b]))
	faces.append(PackedInt32Array([tri1_edge2, edge_b, tri2_edge2, edge_c]))
	faces.append(PackedInt32Array([tri1_edge3, edge_c, tri2_edge3, edge_a]))
	faces.append(PackedInt32Array([tri2_edge1, tri2_edge2, tri2_edge3]))
	# Append the cell referencing those 5 faces.
	cells.append(PackedInt32Array([
		face_count, face_count + 1, face_count + 2, face_count + 3, face_count + 4
	]))
	# Append the texture coordinates for the triangles, but emptiness for the quads.
	# In order to properly do this, we need to query the edges and vertices.
	# We MUST deduplicate above so that the triangle edges are connected to themselves,
	# but this deduplication may cause ordering changes that we need to handle here,
	# because the first edge may be the reverse of what we tried to append.
	face_vert_tex.append(PackedVector3Array([a1_tex, b1_tex, c1_tex]))
	face_vert_tex.append(PackedVector3Array())
	face_vert_tex.append(PackedVector3Array())
	face_vert_tex.append(PackedVector3Array())
	face_vert_tex.append(PackedVector3Array([a2_tex, b2_tex, c2_tex]))
	# Set that data back into the mesh.
	poly_ind[0] = faces
	poly_ind[1] = cells
	poly_mesh_4d.poly_cell_indices = poly_ind
	all_tex_maps[Vector2i(2, 0)] = face_vert_tex
	poly_mesh_4d.all_poly_cell_texture_maps = all_tex_maps


func params_to_name() -> String:
	var ret: String = "torisphere" + str(source_icosphere)
	ret += "_smooth" if smooth else "_flat"
	ret += "_ma" + str(major_radius)
	ret += "_mi" + str(minor_radius)
	ret += "_step" + str(steps)
	ret = ret.replace(".0_", "_").replace(".", "pt")
	return ret
