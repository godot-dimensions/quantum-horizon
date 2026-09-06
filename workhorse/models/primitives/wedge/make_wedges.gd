extends Node4D


func _ready() -> void:
	_make_wedge2()
	_make_wedge3()
	_make_wedge4()


func _make_wedge2() -> void:
	var mesh: ArrayPolyMesh4D = BoxPolyMesh4D.new().to_array_poly_mesh()
	mesh.poly_cell_boundary_normals = PackedVector4Array()
	mesh.poly_cell_normal_indices = []
	mesh.poly_cell_texture_map_indices = []
	mesh.resource_name = "wedge2"
	# First, delete the vertices we don't want.
	var vertices_to_delete := PackedInt32Array()
	for i in range(mesh.poly_cell_vertex_positions.size()):
		var vertex: Vector4 = mesh.poly_cell_vertex_positions[i]
		if vertex.y + vertex.z > 0.5:
			vertices_to_delete.append(i)
	for i in range(vertices_to_delete.size() - 1, -1, -1):
		mesh.delete_poly_element(0, vertices_to_delete[i])
	var edge_indices: PackedInt32Array = mesh.edge_indices
	# Vertices:
	# 0: (-0.5, -0.5, -0.5, -0.5)
	# 1: (0.5, -0.5, -0.5, -0.5)
	# 2: (-0.5, 0.5, -0.5, -0.5)
	# 3: (0.5, 0.5, -0.5, -0.5)
	# 4: (-0.5, -0.5, 0.5, -0.5)
	# 5: (0.5, -0.5, 0.5, -0.5)
	# 6: (-0.5, -0.5, -0.5, 0.5)
	# 7: (0.5, -0.5, -0.5, 0.5)
	# 8: (-0.5, 0.5, -0.5, 0.5)
	# 9: (0.5, 0.5, -0.5, 0.5)
	# 10: (-0.5, -0.5, 0.5, 0.5)
	# 11: (0.5, -0.5, 0.5, 0.5)
	# Add the wedge-specific edges.
	edge_indices.append(2)
	edge_indices.append(4)
	edge_indices.append(3)
	edge_indices.append(5)
	edge_indices.append(8)
	edge_indices.append(10)
	edge_indices.append(9)
	edge_indices.append(11)
	mesh.edge_indices = edge_indices
	# Edges:
	# 0: 0 to 1 (done)
	# 1: 2 to 3
	# 2: 4 to 5
	# 3: 6 to 7 (done)
	# 4: 8 to 9
	# 5: 10 to 11
	# 6: 0 to 2
	# 7: 1 to 3
	# 8: 6 to 8
	# 9: 7 to 9
	# 10: 0 to 4
	# 11: 1 to 5
	# 12: 6 to 10
	# 13: 7 to 11
	# 14: 0 to 6 (done)
	# 15: 1 to 7 (done)
	# 16: 2 to 8
	# 17: 3 to 9
	# 18: 4 to 10
	# 19: 5 to 11
	# 20: 2 to 4
	# 21: 3 to 5
	# 22: 8 to 10
	# 23: 9 to 11
	var poly_cell_indices: Array = mesh.poly_cell_indices
	# Add the wedge-specific faces.
	var faces: Array = poly_cell_indices[0]
	faces.append(PackedInt32Array([1, 20, 2, 21]))
	faces.append(PackedInt32Array([4, 22, 5, 23]))
	faces.append(PackedInt32Array([16, 20, 18, 22]))
	faces.append(PackedInt32Array([17, 21, 19, 23]))
	faces.append(PackedInt32Array([6, 20, 10]))
	faces.append(PackedInt32Array([7, 21, 11]))
	faces.append(PackedInt32Array([8, 22, 12]))
	faces.append(PackedInt32Array([9, 23, 13]))
	poly_cell_indices[0] = faces
	# Faces:
	# 0: [0, 6, 1, 7]
	# 1: [3, 8, 4, 9]
	# 2: [0, 11, 2, 10]
	# 3: [3, 13, 5, 12]
	# 4: [0, 14, 3, 15] (done)
	# 5: [18, 2, 19, 5]
	# 6: [1, 16, 4, 17]
	# 7: [14, 6, 16, 8]
	# 8: [15, 7, 17, 9]
	# 9: [14, 10, 18, 12]
	# 10: [11, 15, 13, 19]
	# 11: [1, 20, 2, 21]
	# 12: [4, 22, 5, 23]
	# 13: [16, 20, 18, 22]
	# 14: [17, 21, 19, 23]
	# 15: [6, 20, 10]
	# 16: [7, 21, 11]
	# 17: [8, 22, 12]
	# 18: [9, 23, 13]
	# Add the wedge-specific cells.
	var cells: Array = poly_cell_indices[1]
	cells.append(PackedInt32Array([5, 11, 6, 12, 13, 14])) # YZ
	cells.append(PackedInt32Array([7, 9, 13, 15, 17])) # -X
	cells.append(PackedInt32Array([10, 8, 14, 16, 18])) # +X
	cells.append(PackedInt32Array([2, 0, 11, 15, 16])) # -W
	cells.append(PackedInt32Array([1, 3, 12, 17, 18])) # +W
	poly_cell_indices[1] = cells
	# Create one volume that includes all cells.
	var vol := PackedInt32Array()
	vol.resize(cells.size())
	for i in range(cells.size()):
		vol[i] = i
	poly_cell_indices.append([vol])
	mesh.poly_cell_indices = poly_cell_indices
	mesh.set_flat_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
	mesh.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_TILE_ISLANDS)
	mesh.compact_normal_values()
	mesh.compact_texture_map_values()
	_print_mesh_data(mesh)
	print(mesh.is_mesh_data_valid())
	_save_mesh(mesh)


func _make_wedge3() -> void:
	var mesh: ArrayPolyMesh4D = BoxPolyMesh4D.new().to_array_poly_mesh()
	mesh.poly_cell_boundary_normals = PackedVector4Array()
	mesh.poly_cell_normal_indices = []
	mesh.poly_cell_texture_map_indices = []
	mesh.resource_name = "wedge3"
	# First, delete the vertices we don't want.
	var vertices_to_delete := PackedInt32Array()
	for i in range(mesh.poly_cell_vertex_positions.size()):
		var vertex: Vector4 = mesh.poly_cell_vertex_positions[i]
		if vertex.x + vertex.y + vertex.z > 0.0:
			vertices_to_delete.append(i)
	for i in range(vertices_to_delete.size() - 1, -1, -1):
		mesh.delete_poly_element(0, vertices_to_delete[i])
	# Vertices:
	# 0: (-0.5, -0.5, -0.5, -0.5)
	# 1: (0.5, -0.5, -0.5, -0.5)
	# 2: (-0.5, 0.5, -0.5, -0.5)
	# 3: (-0.5, -0.5, 0.5, -0.5)
	# 4: (-0.5, -0.5, -0.5, 0.5)
	# 5: (0.5, -0.5, -0.5, 0.5)
	# 6: (-0.5, 0.5, -0.5, 0.5)
	# 7: (-0.5, -0.5, 0.5, 0.5)
	var edge_indices: PackedInt32Array = mesh.edge_indices
	# Add the wedge-specific edges.
	edge_indices.append(1)
	edge_indices.append(2)
	edge_indices.append(1)
	edge_indices.append(3)
	edge_indices.append(2)
	edge_indices.append(3)
	edge_indices.append(5)
	edge_indices.append(6)
	edge_indices.append(5)
	edge_indices.append(7)
	edge_indices.append(6)
	edge_indices.append(7)
	mesh.edge_indices = edge_indices
	# Edges:
	# 0: 0 to 1
	# 1: 4 to 5
	# 2: 0 to 2
	# 3: 4 to 6
	# 4: 0 to 3
	# 5: 4 to 7
	# 6: 0 to 4
	# 7: 1 to 5
	# 8: 2 to 6
	# 9: 3 to 7
	# 10: 1 to 2
	# 11: 1 to 3
	# 12: 2 to 3
	# 13: 5 to 6
	# 14: 5 to 7
	# 15: 6 to 7
	var poly_cell_indices: Array = mesh.poly_cell_indices
	# Add the wedge-specific faces.
	var faces: Array = poly_cell_indices[0]
	faces.append(PackedInt32Array([7, 10, 8, 13])) # XY
	faces.append(PackedInt32Array([7, 11, 9, 14])) # XZ
	faces.append(PackedInt32Array([8, 12, 9, 15])) # YZ
	faces.append(PackedInt32Array([0, 10, 2])) # -Z -W
	faces.append(PackedInt32Array([1, 13, 3])) # -Z +W
	faces.append(PackedInt32Array([0, 4, 11])) # -Y -W
	faces.append(PackedInt32Array([1, 5, 14])) # -Y +W
	faces.append(PackedInt32Array([2, 12, 4])) # -X -W
	faces.append(PackedInt32Array([3, 15, 5])) # -X +W
	faces.append(PackedInt32Array([10, 12, 11])) # -W
	faces.append(PackedInt32Array([13, 15, 14])) # +W
	poly_cell_indices[0] = faces
	# Faces:
	# 0: [0, 6, 1, 7]
	# 1: [6, 2, 8, 3]
	# 2: [6, 4, 9, 5]
	# 3: [7, 10, 8, 13]
	# 4: [7, 11, 9, 14]
	# 5: [8, 12, 9, 15]
	# 6: [0, 10, 2]
	# 7: [1, 13, 3]
	# 8: [0, 4, 11]
	# 9: [1, 5, 14]
	# 10: [2, 12, 4]
	# 11: [3, 15, 5]
	# 12: [10, 12, 11]
	# 13: [13, 15, 14]
	# Add the wedge-specific cells.
	var cells: Array[PackedInt32Array] = []
	cells.append(PackedInt32Array([0, 1, 3, 6, 7])) # -Z
	cells.append(PackedInt32Array([2, 0, 4, 8, 9])) # -Y
	cells.append(PackedInt32Array([1, 2, 5, 10, 11])) # -X
	cells.append(PackedInt32Array([5, 4, 3, 12, 13])) # XYZ
	cells.append(PackedInt32Array([8, 6, 10, 12])) # -W
	cells.append(PackedInt32Array([7, 9, 11, 13])) # +W
	poly_cell_indices.append(cells)
	# Create one volume that includes all cells.
	var vol := PackedInt32Array()
	vol.resize(cells.size())
	for i in range(cells.size()):
		vol[i] = i
	poly_cell_indices.append([vol])
	mesh.poly_cell_indices = poly_cell_indices
	mesh.set_flat_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
	mesh.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_TILE_ISLANDS)
	mesh.compact_normal_values()
	mesh.compact_texture_map_values()
	_print_mesh_data(mesh)
	print(mesh.is_mesh_data_valid())
	_save_mesh(mesh)


func _make_wedge4() -> void:
	var mesh: ArrayPolyMesh4D = BoxPolyMesh4D.new().to_array_poly_mesh()
	mesh.poly_cell_boundary_normals = PackedVector4Array()
	mesh.poly_cell_normal_indices = []
	mesh.poly_cell_texture_map_indices = []
	mesh.resource_name = "wedge4"
	# First, delete the vertices we don't want.
	var vertices_to_delete := PackedInt32Array()
	for i in range(mesh.poly_cell_vertex_positions.size()):
		var vertex: Vector4 = mesh.poly_cell_vertex_positions[i]
		if vertex.x + vertex.y + vertex.z + vertex.w > -0.5:
			vertices_to_delete.append(i)
	for i in range(vertices_to_delete.size() - 1, -1, -1):
		mesh.delete_poly_element(0, vertices_to_delete[i])
	# Vertices:
	# 0: (-0.5, -0.5, -0.5, -0.5)
	# 1: (0.5, -0.5, -0.5, -0.5)
	# 2: (-0.5, 0.5, -0.5, -0.5)
	# 3: (-0.5, -0.5, 0.5, -0.5)
	# 4: (-0.5, -0.5, -0.5, 0.5)
	var edge_indices: PackedInt32Array = mesh.edge_indices
	# Add the wedge-specific edges.
	edge_indices.append(1)
	edge_indices.append(2)
	edge_indices.append(1)
	edge_indices.append(3)
	edge_indices.append(1)
	edge_indices.append(4)
	edge_indices.append(2)
	edge_indices.append(3)
	edge_indices.append(2)
	edge_indices.append(4)
	edge_indices.append(3)
	edge_indices.append(4)
	mesh.edge_indices = edge_indices
	# Edges:
	# 0: 0 to 1
	# 1: 0 to 2
	# 2: 0 to 3
	# 3: 0 to 4
	# 4: 1 to 2
	# 5: 1 to 3
	# 6: 1 to 4
	# 7: 2 to 3
	# 8: 2 to 4
	# 9: 3 to 4
	var poly_cell_indices: Array = mesh.poly_cell_indices
	# Add the wedge-specific faces.
	var faces: Array[PackedInt32Array] = []
	faces.append(PackedInt32Array([0, 4, 1])) # -Z -W
	faces.append(PackedInt32Array([0, 2, 5])) # -Y -W
	faces.append(PackedInt32Array([1, 7, 2])) # -X -W
	faces.append(PackedInt32Array([0, 6, 3])) # -Z -Y
	faces.append(PackedInt32Array([1, 3, 8])) # -Z -X
	faces.append(PackedInt32Array([2, 9, 3])) # -Y -X
	faces.append(PackedInt32Array([4, 8, 6])) # -Z
	faces.append(PackedInt32Array([5, 6, 9])) # -Y
	faces.append(PackedInt32Array([7, 9, 8])) # -X
	faces.append(PackedInt32Array([4, 7, 5])) # -W
	poly_cell_indices.append(faces)
	# Add the wedge-specific cells.
	var cells: Array[PackedInt32Array] = []
	cells.append(PackedInt32Array([2, 4, 5, 8]))
	cells.append(PackedInt32Array([3, 1, 5, 7]))
	cells.append(PackedInt32Array([0, 3, 4, 6]))
	cells.append(PackedInt32Array([1, 0, 2, 9]))
	cells.append(PackedInt32Array([7, 6, 8, 9]))
	poly_cell_indices.append(cells)
	# Create one volume that includes all cells.
	var vol := PackedInt32Array()
	vol.resize(cells.size())
	for i in range(cells.size()):
		vol[i] = i
	poly_cell_indices.append([vol])
	mesh.poly_cell_indices = poly_cell_indices
	mesh.set_flat_shading_normals(ArrayPolyMesh4D.COMPUTE_NORMALS_MODE_CELL_ORIENTATION_ONLY)
	mesh.unwrap_texture_map(ArrayPolyMesh4D.UNWRAP_MODE_TILE_ISLANDS)
	mesh.compact_normal_values()
	mesh.compact_texture_map_values()
	_print_mesh_data(mesh)
	print(mesh.is_mesh_data_valid())
	_save_mesh(mesh)


func _save_mesh(mesh: ArrayPolyMesh4D) -> void:
	if not mesh.is_mesh_data_valid():
		return
	var mesh_name: String = mesh.resource_name
	var script_dir: String = get_script().get_path().get_base_dir()
	var base_path: String = script_dir.path_join(mesh_name)
	ResourceSaver.save(mesh, base_path + ".res")
	var g4mf_doc := G4MFDocument4D.new()
	var g4mf_state := G4MFState4D.new()
	g4mf_doc.export_append_from_godot_mesh(g4mf_state, mesh)
	g4mf_doc.export_write_to_file(g4mf_state, base_path + ".g4b")
	g4mf_doc.export_write_to_file(g4mf_state, base_path + ".g4tf")
	var texmap: Mesh = mesh.export_texture_map_mesh()
	ResourceSaver.save(texmap, base_path + "_texmap.mesh")
	print(base_path)


func _print_mesh_data(mesh: ArrayPolyMesh4D) -> void:
	print("Vertices:")
	for i in range(mesh.poly_cell_vertex_positions.size()):
		print(str(i) + ": " + str(mesh.poly_cell_vertex_positions[i]))
	print("Edges:")
	for i in range(0, mesh.edge_indices.size(), 2):
		@warning_ignore("integer_division")
		print(str(i / 2) + ": " + str(mesh.edge_indices[i]) + " to " + str(mesh.edge_indices[i + 1]))
	if mesh.poly_cell_indices.size() > 0:
		print("Faces:")
		var face_edge_indices: Array = mesh.poly_cell_indices[0]
		for i in range(face_edge_indices.size()):
			print(str(i) + ": " + str(face_edge_indices[i]))
	if mesh.poly_cell_indices.size() > 1:
		print("Cells:")
		var cell_face_indices: Array = mesh.poly_cell_indices[1]
		for i in range(cell_face_indices.size()):
			print(str(i) + ": " + str(cell_face_indices[i]))
	if mesh.poly_cell_indices.size() > 2:
		print("Volumes:")
		var vol_cell_indices: Array = mesh.poly_cell_indices[2]
		for i in range(vol_cell_indices.size()):
			print(str(i) + ": " + str(vol_cell_indices[i]))
