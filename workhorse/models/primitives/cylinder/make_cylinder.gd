extends SaveToFiles


func _ready() -> void:
	_make_dodecahedral_cylinder()
	_make_icosahedral_cylinder(4)
	_make_truncated_icosahedral_cylinder()


func _subdivide_triangle_faces(input: ArrayPolyMesh4D) -> ArrayPolyMesh4D:
	var sub := ArrayPolyMesh4D.new()
	var input_vert: PackedVector4Array = input.poly_cell_vertices
	var input_face_vert: Array[PackedInt32Array] = input.get_all_face_vertex_indices()
	var output_faces: Array[PackedInt32Array] = []
	for face_iter in input_face_vert:
		var face_verts: PackedInt32Array = face_iter
		var midpoint0: Vector4 = (input_vert[face_verts[0]] + input_vert[face_verts[1]]).normalized()
		var midpoint1: Vector4 = (input_vert[face_verts[0]] + input_vert[face_verts[2]]).normalized()
		var midpoint2: Vector4 = (input_vert[face_verts[1]] + input_vert[face_verts[2]]).normalized()
		var edge0: int = sub.append_edge_points(input_vert[face_verts[0]], midpoint0)
		var edge1: int = sub.append_edge_points(input_vert[face_verts[0]], midpoint1)
		var edge2: int = sub.append_edge_points(input_vert[face_verts[1]], midpoint0)
		var edge3: int = sub.append_edge_points(input_vert[face_verts[1]], midpoint2)
		var edge4: int = sub.append_edge_points(input_vert[face_verts[2]], midpoint1)
		var edge5: int = sub.append_edge_points(input_vert[face_verts[2]], midpoint2)
		var edge6: int = sub.append_edge_points(midpoint0, midpoint1)
		var edge7: int = sub.append_edge_points(midpoint0, midpoint2)
		var edge8: int = sub.append_edge_points(midpoint1, midpoint2)
		output_faces.append(PackedInt32Array([edge6, edge7, edge8]))
		output_faces.append(PackedInt32Array([edge0, edge1, edge6]))
		output_faces.append(PackedInt32Array([edge2, edge3, edge7]))
		output_faces.append(PackedInt32Array([edge4, edge5, edge8]))
	var output_cell := PackedInt32Array()
	for i in range(output_faces.size()):
		output_cell.append(i)
	var output_cells: Array[PackedInt32Array] = [output_cell]
	var output_poly: Array[Array] = [output_faces, output_cells]
	sub.poly_cell_indices = output_poly
	return sub


func _make_dodecahedral_cylinder() -> void:
	var script_dir: String = get_script().get_path().get_base_dir()
	for smooth in range(2):
		var file_no_ext: String
		if smooth == 0:
			file_no_ext = "cylinder_flat_dodeca"
		else:
			file_no_ext = "cylinder_smooth_dodeca"
		var ico: ArrayPolyMesh4D = ResourceLoader.load("res://models/3d/dodecahedron/dodecahedron.off").duplicate(true)
		var vert: PackedVector4Array = ico.poly_cell_vertices
		for i in range(vert.size()):
			vert[i] = vert[i].normalized()
		# Rotate to put the long side on the Z axis for better texture mapping.
		vert = Basis4D.xform_array(Basis4D.from_zw(TAU / 4.0), vert)
		ico.poly_cell_vertices = vert
		var extruded: ArrayPolyMesh4D = PolyMeshBuilder4D.extrude_linear(ico, Vector4(0, 0, 1, 0))
		extruded.resource_name = file_no_ext
		# Texture mapping.
		extruded.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_EACH_ISLAND_FILLS, 0.0, true)
		# Scale and offset the icosahedral cells to not overlap the sides.
		if true:
			var tex_map_pos: Array[PackedVector3Array] = extruded.poly_cell_texture_map
			var first: PackedVector3Array = tex_map_pos[0]
			var second: PackedVector3Array = tex_map_pos[1]
			var scale_basis := Basis.from_scale(Vector3(0.5, 0.5, 0.5))
			var first_xform := Transform3D(scale_basis, Vector3(0.0, 0.0, 0.5))
			var second_xform := Transform3D(scale_basis, Vector3(0.5, 0.0, 0.5))
			for i in range(first.size()):
				first[i] = first_xform * first[i]
				second[i] = second_xform * second[i]
			tex_map_pos[0] = first
			tex_map_pos[1] = second
			extruded.poly_cell_texture_map = tex_map_pos
		# Rotate to put the long side on the Y axis instead.
		vert = extruded.poly_cell_vertices
		vert = Basis4D.xform_array(Basis4D.from_yz(-TAU / 4.0), vert)
		extruded.poly_cell_vertices = vert
		extruded.calculate_boundary_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
		if smooth == 1:
			extruded.set_smooth_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
		# Save the resulting mesh as a tres, g4b, g4tf, and save the texture map.
		var base_path: String = script_dir.path_join("dodeca").path_join(file_no_ext)
		save_mesh_4d_to_scene_and_g4mf(extruded, base_path)


func _make_icosahedral_cylinder(max_subdivisions: int) -> void:
	var script_dir: String = get_script().get_path().get_base_dir()
	for smooth in range(2):
		for subdivisions in range(max_subdivisions):
			var file_no_ext: String
			if smooth == 0:
				file_no_ext = "cylinder_flat_ico" + str(subdivisions)
			else:
				file_no_ext = "cylinder_smooth_ico" + str(subdivisions)
			var ico: ArrayPolyMesh4D = ResourceLoader.load("res://models/3d/icosphere/icosahedron.off").duplicate(true)
			var vert: PackedVector4Array = ico.poly_cell_vertices
			for i in range(vert.size()):
				vert[i] = vert[i].normalized()
			# Rotate to put the long side on the Z axis for better texture mapping.
			vert = Basis4D.xform_array(Basis4D.from_zw(TAU / 4.0), vert)
			ico.poly_cell_vertices = vert
			for i in range(subdivisions):
				ico = _subdivide_triangle_faces(ico)
			var extruded: ArrayPolyMesh4D = PolyMeshBuilder4D.extrude_linear(ico, Vector4(0, 0, 1, 0))
			extruded.resource_name = file_no_ext
			# Texture mapping.
			extruded.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_EACH_ISLAND_FILLS, 0.0, true)
			# Scale and offset the icosahedral cells to not overlap the sides.
			if true:
				var tex_map_pos: Array[PackedVector3Array] = extruded.poly_cell_texture_map
				var first: PackedVector3Array = tex_map_pos[0]
				var second: PackedVector3Array = tex_map_pos[1]
				var scale_basis := Basis.from_scale(Vector3(0.5, 0.5, 0.5))
				var first_xform := Transform3D(scale_basis, Vector3(0.0, 0.0, 0.5))
				var second_xform := Transform3D(scale_basis, Vector3(0.5, 0.0, 0.5))
				for i in range(first.size()):
					first[i] = first_xform * first[i]
					second[i] = second_xform * second[i]
				tex_map_pos[0] = first
				tex_map_pos[1] = second
				extruded.poly_cell_texture_map = tex_map_pos
			# Rotate to put the long side on the Y axis instead.
			vert = extruded.poly_cell_vertices
			vert = Basis4D.xform_array(Basis4D.from_yz(-TAU / 4.0), vert)
			extruded.poly_cell_vertices = vert
			extruded.calculate_boundary_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
			if smooth == 1:
				extruded.set_smooth_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
			# Save the resulting mesh as a tres, g4b, g4tf, and save the texture map.
			var base_path: String = script_dir.path_join("ico").path_join(file_no_ext)
			save_mesh_4d_to_scene_and_g4mf(extruded, base_path)


func _make_truncated_icosahedral_cylinder() -> void:
	var script_dir: String = get_script().get_path().get_base_dir()
	for smooth in range(2):
		var file_no_ext: String
		if smooth == 0:
			file_no_ext = "cylinder_flat_trunc_ico"
		else:
			file_no_ext = "cylinder_smooth_trunc_ico"
		var ico: ArrayPolyMesh4D = ResourceLoader.load("res://models/3d/icosphere/truncated_icosahedron.off").duplicate(true)
		var vert: PackedVector4Array = ico.poly_cell_vertices
		for i in range(vert.size()):
			vert[i] = vert[i].normalized()
		# Rotate to put the long side on the Z axis for better texture mapping.
		vert = Basis4D.xform_array(Basis4D.from_zw(TAU / 4.0), vert)
		ico.poly_cell_vertices = vert
		var extruded: ArrayPolyMesh4D = PolyMeshBuilder4D.extrude_linear(ico, Vector4(0, 0, 1, 0))
		extruded.resource_name = file_no_ext
		# Texture mapping.
		extruded.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_EACH_ISLAND_FILLS, 0.0, true)
		# Scale and offset the icosahedral cells to not overlap the sides.
		if true:
			var tex_map_pos: Array[PackedVector3Array] = extruded.poly_cell_texture_map
			var first: PackedVector3Array = tex_map_pos[0]
			var second: PackedVector3Array = tex_map_pos[1]
			var scale_basis := Basis.from_scale(Vector3(0.5, 0.5, 0.5))
			var first_xform := Transform3D(scale_basis, Vector3(0.0, 0.0, 0.5))
			var second_xform := Transform3D(scale_basis, Vector3(0.5, 0.0, 0.5))
			for i in range(first.size()):
				first[i] = first_xform * first[i]
				second[i] = second_xform * second[i]
			tex_map_pos[0] = first
			tex_map_pos[1] = second
			extruded.poly_cell_texture_map = tex_map_pos
		# Rotate to put the long side on the Y axis instead.
		vert = extruded.poly_cell_vertices
		vert = Basis4D.xform_array(Basis4D.from_yz(-TAU / 4.0), vert)
		extruded.poly_cell_vertices = vert
		extruded.calculate_boundary_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
		if smooth == 1:
			extruded.set_smooth_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
		# Save the resulting mesh as a tres, g4b, g4tf, and save the texture map.
		var base_path: String = script_dir.path_join("ico").path_join(file_no_ext)
		save_mesh_4d_to_scene_and_g4mf(extruded, base_path)
