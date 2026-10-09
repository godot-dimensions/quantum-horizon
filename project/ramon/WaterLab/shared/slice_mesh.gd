extends RefCounted

## WATER LAB: a 4D tetrahedral mesh cut by a slice into a 3D mesh, on the CPU, once. For showing a 4D
## body where no 4D camera can go (a Camera4D is the one current camera of the whole game: one put in a
## SubViewport for the fish wall's turntables took over the main view, 9 Oct): the fish wall shows the
## hammerhead as this, its true cut at w = 0.
##
## Each tetrahedron the hyperplane w = w0 passes through is cut in a triangle (one corner on the far side)
## or a quad (two and two), its corners where the slice crosses the tetrahedron's edges. The cut of a
## closed 4D body is a closed 3D surface; each piece gets a flat normal, turned away from the middle of
## its tetrahedron's part on the near side... simpler and good enough here: away from the mesh's centre.
##
## NO class_name (engine_gotchas.md).


## `parts`: [[ArrayTetraMesh4D, Projection basis, Vector4 origin, Color], ...] placed in one frame.
## Where a mesh has texture coordinates (a loft's), they are carried across to the cut: UV is their x
## and y, UV2.x their z (the lofted koi's picture paints from them, life/koi_picture.gdshader).
static func cut(parts: Array, w0: float = 0.0) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var centre := Vector3.ZERO
	var n_c: int = 0
	var tris: Array = []
	for part in parts:
		var m: ArrayTetraMesh4D = part[0]
		var b: Projection = part[1]
		var o: Vector4 = part[2]
		var col: Color = part[3] if (part as Array).size() > 3 else Color.WHITE
		var pos: PackedVector4Array = m.get_vertex_positions()
		var placed := PackedVector4Array()
		placed.resize(pos.size())
		for i in pos.size():
			placed[i] = b * pos[i] + o
		var cells: PackedInt32Array = m.get_simplex_cell_vertex_indices()
		var tex: PackedVector3Array = m.get_texture_map_values()
		var tix: PackedInt32Array = m.get_simplex_cell_texture_map_indices()
		var has_uvw: bool = tex.size() > 0 and tix.size() == cells.size()
		for c in range(0, cells.size(), 4):
			var q: Array = [placed[cells[c]], placed[cells[c + 1]], placed[cells[c + 2]], placed[cells[c + 3]]]
			var pts: Array = []
			var uvws: Array = []
			for a in 4:
				for bb in range(a + 1, 4):
					var pa: Vector4 = q[a]
					var pb: Vector4 = q[bb]
					var da: float = pa.w - w0
					var db: float = pb.w - w0
					if (da < 0.0) != (db < 0.0):
						var t: float = da / (da - db)
						var p: Vector4 = pa.lerp(pb, t)
						pts.append(Vector3(p.x, p.y, p.z))
						uvws.append(tex[tix[c + a]].lerp(tex[tix[c + bb]], t) if has_uvw else Vector3.ZERO)
			if pts.size() == 3:
				tris.append([pts[0], pts[1], pts[2], col, uvws[0], uvws[1], uvws[2]])
			elif pts.size() == 4:
				# The quad's corners in order round it: the edge pairs (01,23) and (02,13) are opposite.
				tris.append([pts[0], pts[1], pts[3], col, uvws[0], uvws[1], uvws[3]])
				tris.append([pts[0], pts[3], pts[2], col, uvws[0], uvws[3], uvws[2]])
	for t in tris:
		for k in 3:
			centre += t[k]
			n_c += 1
	if n_c > 0:
		centre /= float(n_c)
	for t in tris:
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		var ua: Vector3 = t[4]
		var ub: Vector3 = t[5]
		var uc: Vector3 = t[6]
		var n: Vector3 = (b - a).cross(c - a)
		if n.length() < 1e-9:
			continue
		n = n.normalized()
		# Away from the body's long axis (z through its middle): right for a long body, which one
		# centre point is not.
		var m3: Vector3 = (a + b + c) / 3.0
		if n.dot(m3 - Vector3(centre.x, centre.y, m3.z)) < 0.0:
			n = -n
			var swap: Vector3 = b
			b = c
			c = swap
			var uswap: Vector3 = ub
			ub = uc
			uc = uswap
		for p in [a, b, c]:
			verts.append(p)
			normals.append(n)
			colours.append(t[3])
		for u in [ua, ub, uc]:
			uvs.append(Vector2(u.x, u.y))
			uv2s.append(Vector2(u.z, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	var mesh := ArrayMesh.new()
	if verts.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
