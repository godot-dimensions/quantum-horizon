extends Node
## TEMPORARY - isolates whether ShrubMeshBuilderBlocky4D's single-voxel
## box construction produces correct outward boundary normals on its
## own, before blaming the "criss-cross"/see-through look on inter-voxel
## culling (many touching un-culled boxes) rather than a per-box bug.
##
## For a box centered at the origin, a tetrahedron's computed boundary
## normal should have a POSITIVE dot product with the direction from the
## box center to that tet's own centroid - any tet whose normal points
## backward (negative dot) is a real classification bug, not a
## consequence of missing hidden-face culling between separate voxels
## (this test uses exactly ONE box, no neighbors at all).

func _ready() -> void:
	var half_extents := Vector4(0.05, 0.05, 0.05, 0.05) # Matches a 0.1 voxel_size box.
	var target_cell_size: float = 0.05 * 4.0
	var box_mesh: ArrayTetraMesh4D = SubdividedBoxTetraMesh4D.build(half_extents, target_cell_size)
	box_mesh.calculate_boundary_normals()

	var positions: PackedVector4Array = box_mesh.get_vertex_positions()
	var indices: PackedInt32Array = box_mesh.get_simplex_cell_vertex_indices()
	var boundary_normals: PackedVector4Array = box_mesh.get_simplex_cell_boundary_normals()
	var tet_count: int = indices.size() / 4

	print("tet_count=%d vertex_count=%d boundary_normal_count=%d" % [tet_count, positions.size(), boundary_normals.size()])

	var backward_count := 0
	for t in range(tet_count):
		var base := t * 4
		var p0: Vector4 = positions[indices[base + 0]]
		var p1: Vector4 = positions[indices[base + 1]]
		var p2: Vector4 = positions[indices[base + 2]]
		var p3: Vector4 = positions[indices[base + 3]]
		var centroid: Vector4 = (p0 + p1 + p2 + p3) * 0.25
		var expected_outward: Vector4 = centroid # Box center is the origin, so centroid IS the outward direction.
		var normal: Vector4 = boundary_normals[t] if t < boundary_normals.size() else Vector4.ZERO
		var d: float = normal.dot(expected_outward)
		var status: String = "OK" if d > 0.0 else "BACKWARD"
		if d <= 0.0:
			backward_count += 1
		print("tet %d centroid=%s normal=%s dot=%.4f %s" % [t, centroid, normal, d, status])

	print("=== backward_count=%d / %d ===" % [backward_count, tet_count])
	print("DONE")
	get_tree().quit()
