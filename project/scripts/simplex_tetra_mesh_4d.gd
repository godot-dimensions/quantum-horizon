class_name SimplexTetraMesh4D
## Builds an ArrayTetraMesh4D representing a regular 4-simplex (the "5-cell"
## or pentachoron) - the minimal closed 4D solid, the direct 4D analog of
## how a tetrahedron is the minimal closed 3D solid (which is itself the
## analog of how a triangle is the minimal closed 2D shape). 5 vertices, 5
## tetrahedral facets (one per omitted vertex, 5 choose 4 = 5).
##
## Why this and not a single bare tetrahedron: a lone tetrahedron is not a
## closed 4D hypersurface - BoxTetraMesh4D's own tetrahedra decompose the
## box's BOUNDARY (its 8 cubic facets, each split into tets for the
## marching-tetrahedra-style Cross-Section slicing), so each tetrahedron is
## a surface patch element, not a filled volume chunk. One tetrahedron alone
## has no partner facets closing it into a solid, so it isn't guaranteed to
## behave as a proper watertight object under slicing at every rotation. The
## 5-cell is the actual minimal valid closed 4D solid - cheaper than the
## engine's built-in OrthoplexTetraMesh4D (16 tets) by more than 3x.
##
## Coordinates: a regular tetrahedron base (the standard "alternate corners
## of a cube" construction: (1,1,1), (1,-1,-1), (-1,1,-1), (-1,-1,1), edge
## length 2*sqrt(2)) sitting at w=0, plus a 5th apex vertex on the w axis at
## the one height that makes every edge equal (derived: apex-to-base
## distance^2 = 3 + h^2 must equal the base's own edge length^2 of 8, so
## h = sqrt(5)) - the standard "pyramid over a regular tetrahedron"
## construction of a regular 5-cell. Both are then shifted along w so the
## whole shape is centered at the origin, and scaled so edge_length matches
## the requested size.

static func build(edge_length: float = 1.0) -> ArrayTetraMesh4D:
	var mesh := ArrayTetraMesh4D.new()

	# Unscaled regular 5-cell, edge length 2*sqrt(2), centered at the origin -
	# see this script's own header for the derivation.
	var w_base := -sqrt(5.0) / 5.0
	var w_apex := 4.0 * sqrt(5.0) / 5.0
	var unscaled_corners: Array[Vector4] = [
		Vector4(1.0, 1.0, 1.0, w_base),
		Vector4(1.0, -1.0, -1.0, w_base),
		Vector4(-1.0, 1.0, -1.0, w_base),
		Vector4(-1.0, -1.0, 1.0, w_base),
		Vector4(0.0, 0.0, 0.0, w_apex),
	]
	var scale: float = edge_length / (2.0 * sqrt(2.0))

	var indices := PackedInt32Array()
	for corner in unscaled_corners:
		indices.append(mesh.append_vertex(corner * scale))

	# One tetrahedral facet per omitted vertex (5 choose 4 = 5 facets).
	for omit_index in range(5):
		var facet_corners := PackedInt32Array()
		for i in range(5):
			if i != omit_index:
				facet_corners.append(indices[i])
		mesh.append_tetra_cell_indices(facet_corners[0], facet_corners[1], facet_corners[2], facet_corners[3])

	return mesh
