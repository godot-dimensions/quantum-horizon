extends Node


func _ready() -> void:
	var verts := PackedVector4Array([
		# Shared triangle.
		Vector4(0, -1, 0, 1),
		Vector4(0, 1, 0, 1),
		Vector4(0, 0, 0, -0.5),
		# Non-shared points.
		Vector4(0.1, 0, -1, 0),
		Vector4(-0.1, 0, -1, 0),
	])
	var ind := PackedInt32Array([0, 1, 2, 3, 0, 1, 4, 2])
	var mesh := ArrayTetraMesh4D.new()
	mesh.vertices = verts
	mesh.simplex_cell_indices = ind
	mesh.calculate_boundary_normals()
	assert(mesh.is_mesh_data_valid())
	mesh.resource_name = "tet_sdf_edge_case_mesh"
	ResourceSaver.save(mesh, "res://models/tet_sdf_edge_case/tet_sdf_edge_case_mesh.tres")
