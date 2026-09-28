extends RefCounted

## Bakes 4D ground offline into a few big meshes with the light already painted on.
##
## ONE TOOL, TWO FRONT ENDS. Ground you only look at is a height, y = h(x, z, w), and gets
## a grid over (x, z, w) lifted to that height - exact, and no voxels. Ground with holes and
## overhangs (the cave) is a density field and goes through the voxel port's dual contouring.
## Both end in the same place: one ArrayTetraMesh4D, one colour per vertex, saved as a
## resource and loaded like any other mesh. Nothing is generated when the scene opens.
##
## WHY FEW AND BIG. Trym's Experiment B, 27 Sept: one merged mesh drew 24 times cheaper than
## a thousand instances of the same thing. Scenery here is built as a handful of large
## meshes for that reason.
##
## COLOUR PER VERTEX, BY WAY OF A 2x2x2 TEXTURE. The engine has per-vertex colour arrays on
## TetraMaterial4D, but the cross-section shader the pen draws with never reads them: its
## albedo is one colour times a Texture3D looked up at a coordinate carried on each corner of
## each tetrahedron (tetra_cross_section_shader.glsl, fragment()). So every vertex gets a
## coordinate that IS its colour, and the texture is the colour cube itself - eight texels,
## black at one corner, white at the other. Linear filtering between those eight corners is
## exactly linear in the coordinate, so what comes out is the vertex colour, interpolated
## across the slice like any vertex colour would be. The coordinates are squeezed into
## 0.25..0.75, the texel centres of a two-texel axis, so the filtering never clamps.
##
## THE COLOUR IS LINEAR. The corners are 0 and 1, which read the same whether or not the
## sampler decodes sRGB, so the texture hands back exactly the coordinate - and the shader
## treats albedo as linear light. [method uvw_of] converts from the sRGB colours people pick.
##
## DARKNESS WITHOUT SHADOWS: 4D VERTEX OCCLUSION. The surface-nets trick (jedjoud10's
## voxel notes), one dimension up: look at the 3x3x3x3 = 81 points around a vertex and count
## how many are solid. A vertex on open flat ground has half its neighbourhood solid; in a
## valley or a crease more, on a ridge fewer. That fraction, remapped, darkens the colour.
## It is ambient light only - which is what the pen lacks, since there are no 4D shadows.

## A cell's eight corners are numbered by their offsets, bit 0 along its first axis, bit 1
## the second, bit 2 the third. These four have an even number of bits set.
const EVEN_CORNERS := [0, 3, 5, 6]
const ODD_CORNERS := [1, 2, 4, 7]

static var _cube: ImageTexture3D


## The eight-texel colour cube. Shared, so every baked mesh can use one material setup.
static func colour_cube() -> ImageTexture3D:
	if _cube != null:
		return _cube
	var layers: Array[Image] = []
	for z in 2:
		var img: Image = Image.create_empty(2, 2, false, Image.FORMAT_RGB8)
		for y in 2:
			for x in 2:
				img.set_pixel(x, y, Color(float(x), float(y), float(z)))
		layers.append(img)
	_cube = ImageTexture3D.new()
	_cube.create(Image.FORMAT_RGB8, 2, 2, 2, false, layers)
	return _cube


## A material that shows the baked colours. [param tint] multiplies all of them.
static func material(tint: Color = Color.WHITE) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	m.albedo_texture_3d = colour_cube()
	m.albedo_color = tint
	return m


## The texture coordinate that reads back as this (sRGB) colour.
static func uvw_of(c: Color) -> Vector3:
	var l: Color = c.clamp().srgb_to_linear()
	return Vector3(0.25 + 0.5 * l.r, 0.25 + 0.5 * l.g, 0.25 + 0.5 * l.b)


## How much of the 3^4 neighbourhood of [param p] is solid, spaced [param spacing] apart:
## 0.5 on open flat ground, more in hollows, less on crests. [param density] is positive
## inside, the voxel port's convention. A sample exactly on the surface counts half.
static func solid_fraction(density: Callable, p: Vector4, spacing: float) -> float:
	var solid := 0.0
	for a in 3:
		for b in 3:
			for c in 3:
				for d in 3:
					var q := p + Vector4(a - 1, b - 1, c - 1, d - 1) * spacing
					var v: float = density.call(q)
					solid += 1.0 if v > 1e-5 else (0.5 if v > -1e-5 else 0.0)
	return solid / 81.0


## The same count for ground that is a height: the 27 offsets in (x, z, w) each need the
## height once, and the three steps in y are then a comparison. Three times cheaper than
## going through a density, and it is the case every hill is.
static func height_solid_fraction(height: Callable, p: Vector4, spacing: float) -> float:
	var solid := 0.0
	for a in 3:
		for c in 3:
			for d in 3:
				var h: float = height.call(p.x + (a - 1) * spacing, p.z + (c - 1) * spacing, p.w + (d - 1) * spacing)
				for b in 3:
					var v: float = h - (p.y + (b - 1) * spacing)
					solid += 1.0 if v > 1e-5 else (0.5 if v > -1e-5 else 0.0)
	return solid / 81.0


## Brightness from a solid fraction: 1 on flat ground, darker as the neighbourhood fills,
## a touch brighter on crests. [param strength] is how dark a fully enclosed vertex gets.
static func shade_of(fraction: float, strength: float = 0.8, crest: float = 0.12) -> float:
	var f: float = (fraction - 0.5) * 2.0
	if f >= 0.0:
		return clampf(1.0 - strength * pow(f, 0.75), 0.0, 1.0)
	return 1.0 + crest * minf(-f, 1.0)


## Accumulates vertices and tetrahedra, welds shared vertices by key, winds every
## tetrahedron the way the renderer expects, and turns it all into a mesh.
class Builder:
	var positions := PackedVector4Array()
	var colours := PackedColorArray()
	var cells := PackedInt32Array()
	var _weld := {}
	var skipped := 0

	## Index of the vertex known as [param key], adding it if it is new.
	func vertex(key: Variant, position: Vector4, colour: Color = Color.WHITE) -> int:
		if _weld.has(key):
			return _weld[key]
		var i: int = positions.size()
		positions.append(position)
		colours.append(colour)
		_weld[key] = i
		return i

	func has_vertex(key: Variant) -> bool:
		return _weld.has(key)

	## Adds a tetrahedron wound so its 4D normal (Vector4D.perpendicular of its three edges
	## from the first corner) points along [param outward], out of the ground into the air.
	## Found by looking, not derived: wound the other way the hills vanished and the far
	## sides of the mountains showed through the near ones, which is what back faces do.
	func tet(a: int, b: int, c: int, d: int, outward: Vector4) -> void:
		var o: Vector4 = positions[a]
		var n: Vector4 = Vector4D.perpendicular(positions[b] - o, positions[c] - o, positions[d] - o)
		if n.length_squared() < 1e-14:
			skipped += 1
			return
		if n.dot(outward) < 0.0:
			var s: int = c
			c = d
			d = s
		cells.append_array(PackedInt32Array([a, b, c, d]))

	func tet_count() -> int:
		return cells.size() / 4

	## Takes everything [param other] holds, so several bakes can become one mesh - one
	## draw instead of several (Experiment B). Its vertices are not welded to these.
	func append(other: Builder) -> void:
		var base: int = positions.size()
		positions.append_array(other.positions)
		colours.append_array(other.colours)
		for i in other.cells:
			cells.append(i + base)
		skipped += other.skipped

## The finished mesh. Each corner looks its colour up through its own vertex, so the
## texture map is one entry per vertex and the corner indices are the cells themselves.
## A mesh meant for saving is built without its material - see baked_ground_4d.gd.
static func mesh_of(b: Builder, with_material: bool = true) -> ArrayTetraMesh4D:
	var mesh := ArrayTetraMesh4D.new()
	mesh.vertex_positions = b.positions
	mesh.simplex_cell_vertex_indices = b.cells
	var uvws := PackedVector3Array()
	uvws.resize(b.colours.size())
	for i in b.colours.size():
		uvws[i] = uvw_of(b.colours[i])
	mesh.texture_map_values = uvws
	mesh.simplex_cell_texture_map_indices = b.cells
	if with_material:
		mesh.material = material()
	return mesh


## HEIGHT FRONT END: a solid shell of ground around the origin, R_in to R_out in (x, z, w).
##
## THE DOMAIN IS A CUBE-SPHERE IN THREE DIMENSIONS. Every 3D slice the player can see is a
## plane through (x, z, w) passing near the origin, and it meets this shell in an annulus
## of hills all the way round - which is what makes a ring that turns with the slice rather
## than a backdrop that only exists in x and z. Six cube faces, each an N by N grid of
## directions, times radial layers; every cell a hexahedron split into five tetrahedra
## ([method _five_tets]).
##
## WHY [param n] MUST BE EVEN. The five-way split cuts each face of a cell along the diagonal
## joining its two even-parity corners, parity being i + j + layer of the vertex. Two cells
## sharing a face must cut it the same way or the lifted surface cracks open there, and
## within one cube face they do. Across the edge between two cube faces a vertex is i = n on
## one side and i = 0 on the other, with the same j and layer - so the two sides agree on its
## parity exactly when n is even.
##
## [param radii] the layer radii, inner to outer. [param n] grid cells per cube face edge.
## [param height] Callable(x, z, w) -> y. [param colour] Callable(p: Vector4, normal: Vector4,
## r: float) -> Color, before shading. [param ao] occlusion passes, applied in turn - see
## [method _spacing].
static func bake_height_shell(radii: PackedFloat32Array, n: int, height: Callable, colour: Callable, ao: Array = []) -> Builder:
	assert(n % 2 == 0, "the cube-sphere needs an even number of cells per face edge")
	var out := Builder.new()
	var faces := []
	for axis in 3:
		for s in [-1.0, 1.0]:
			faces.append([axis, s])
	var grid: Array = []
	for face in faces:
		var axis: int = face[0]
		var s: float = face[1]
		var others: Array = [0, 1, 2]
		others.erase(axis)
		# ids[l][i][j] for this face.
		var ids: Array = []
		for l in radii.size():
			var layer: Array = []
			for i in n + 1:
				var row := PackedInt32Array()
				for j in n + 1:
					var c := Vector3.ZERO
					c[axis] = s
					c[others[0]] = _warp(i, n)
					c[others[1]] = _warp(j, n)
					var key := Vector4i(l, roundi(c.x * 1e5), roundi(c.y * 1e5), roundi(c.z * 1e5))
					if out.has_vertex(key):
						row.append(out.vertex(key, Vector4.ZERO))
						continue
					var dir: Vector3 = c.normalized() * radii[l]
					# c is (x, z, w); the 4D point puts the height in y.
					var y: float = height.call(dir.x, dir.y, dir.z)
					var p := Vector4(dir.x, y, dir.y, dir.z)
					row.append(out.vertex(key, p, _shaded(height, colour, ao, p, radii[l])))
				layer.append(row)
			ids.append(layer)
		grid.append(ids)
	var up := Vector4(0.0, 1.0, 0.0, 0.0)
	for f in grid.size():
		var ids: Array = grid[f]
		for l in radii.size() - 1:
			for i in n:
				for j in n:
					var corners := PackedInt32Array()
					for k in 8:
						corners.append((ids[l + (k >> 2 & 1)][i + (k & 1)] as PackedInt32Array)[j + (k >> 1 & 1)])
					_five_tets(out, corners, (i + j + l) % 2 == 1, up)
	return out


## One hexahedral cell as five tetrahedra: the four corners of one parity make the middle
## one, and each corner of the other parity cuts off the tetrahedron with its three
## neighbours. [param corners] are the eight vertex indices in the order of EVEN_CORNERS'
## numbering; [param odd] says corner 0 has odd parity in the whole grid, which swaps the
## roles so that the middle tetrahedron is always the globally even corners - the rule that
## makes neighbouring cells agree on their shared faces. Five rather than the more common
## six saves a sixth of the tetrahedra, and every tetrahedron costs video memory whether it
## is on screen or not.
static func _five_tets(out: Builder, corners: PackedInt32Array, odd: bool, outward: Vector4) -> void:
	var middle: Array = ODD_CORNERS if odd else EVEN_CORNERS
	var cut: Array = EVEN_CORNERS if odd else ODD_CORNERS
	out.tet(corners[middle[0]], corners[middle[1]], corners[middle[2]], corners[middle[3]], outward)
	for k in cut:
		out.tet(corners[k], corners[k ^ 1], corners[k ^ 2], corners[k ^ 4], outward)


## Cube-face coordinate for grid line [param i] of [param n], tangent-warped so the cells are
## close to even in angle. The two ends are exactly -1 and 1, so neighbouring faces agree on
## their shared vertices to the last bit and weld.
static func _warp(i: int, n: int) -> float:
	if i == 0:
		return -1.0
	if i == n:
		return 1.0
	return tan(PI * 0.25 * (-1.0 + 2.0 * float(i) / float(n)))


static func _shaded(height: Callable, colour: Callable, ao: Array, p: Vector4, r: float) -> Color:
	var e: float = maxf(r * 0.004, 0.05)
	var dx: float = (float(height.call(p.x + e, p.z, p.w)) - float(height.call(p.x - e, p.z, p.w))) / (2.0 * e)
	var dz: float = (float(height.call(p.x, p.z + e, p.w)) - float(height.call(p.x, p.z - e, p.w))) / (2.0 * e)
	var dw: float = (float(height.call(p.x, p.z, p.w + e)) - float(height.call(p.x, p.z, p.w - e))) / (2.0 * e)
	var normal := Vector4(-dx, 1.0, -dz, -dw).normalized()
	var c: Color = colour.call(p, normal, r)
	var light := 1.0
	for pass_ in ao:
		light *= shade_of(height_solid_fraction(height, p, _spacing(pass_, r)), pass_[1])
	return Color(c.r * light, c.g * light, c.b * light, c.a)


## An occlusion pass is [spacing, strength] or [spacing, strength, growth]: growth adds that
## many metres of spacing per metre of distance from the origin, for shells whose far cells
## are tens of metres across.
static func _spacing(pass_: Array, r: float) -> float:
	return float(pass_[0]) + (float(pass_[2]) * r if pass_.size() > 2 else 0.0)


## HEIGHT FRONT END, SQUARE: a box of ground over x0..x1, z0..z1, w0..w1 with cells about
## [param cell] across - for a patch near the player that wants finer detail than the shell.
## Cells whose every corner is below [param hidden_below] are left out: they would only be
## drawn underneath the field, and every tetrahedron costs video memory.
static func bake_height_box(lo: Vector3, hi: Vector3, cell: float, height: Callable, colour: Callable, ao: Array = [], hidden_below: float = -INF) -> Builder:
	var out := Builder.new()
	var counts := Vector3i(maxi(1, ceili((hi.x - lo.x) / cell)), maxi(1, ceili((hi.y - lo.y) / cell)), maxi(1, ceili((hi.z - lo.z) / cell)))
	var step := Vector3((hi.x - lo.x) / counts.x, (hi.y - lo.y) / counts.y, (hi.z - lo.z) / counts.z)
	for a in counts.x + 1:
		for b in counts.y + 1:
			for c in counts.z + 1:
				var x: float = lo.x + a * step.x
				var z: float = lo.y + b * step.y
				var w: float = lo.z + c * step.z
				var p := Vector4(x, height.call(x, z, w), z, w)
				out.vertex(Vector3i(a, b, c), p, _shaded(height, colour, ao, p, Vector3(x, z, w).length()))
	var up := Vector4(0.0, 1.0, 0.0, 0.0)
	for a in counts.x:
		for b in counts.y:
			for c in counts.z:
				var corners := PackedInt32Array()
				var shown := false
				for k in 8:
					var v: int = out.vertex(Vector3i(a + (k & 1), b + (k >> 1 & 1), c + (k >> 2 & 1)), Vector4.ZERO)
					corners.append(v)
					shown = shown or out.positions[v].y >= hidden_below
				if shown:
					_five_tets(out, corners, (a + b + c) % 2 == 1, up)
	return out


## BOX FRONT END: a solid 4D box, for anything that is really a block - steps, slabs. Its
## surface is its eight cubic faces, each cut in five like every other cell here, with
## parity taken over the box's sixteen corners so the faces agree where they meet. 40
## tetrahedra a box. [param colour] Callable(p: Vector4, outward: Vector4) -> Color.
static func bake_box(centre: Vector4, size: Vector4, colour: Callable) -> Builder:
	var out := Builder.new()
	var half: Vector4 = size * 0.5
	for axis in 4:
		for s in [-1, 1]:
			var outward := Vector4.ZERO
			outward[axis] = s
			var free: Array = [0, 1, 2, 3]
			free.erase(axis)
			var corners := PackedInt32Array()
			var parity0 := 0
			for k in 8:
				var bits := Vector4i.ZERO
				bits[axis] = 1 if s > 0 else 0
				bits[free[0]] = k & 1
				bits[free[1]] = k >> 1 & 1
				bits[free[2]] = k >> 2 & 1
				var p: Vector4 = centre + Vector4(bits.x * 2 - 1, bits.y * 2 - 1, bits.z * 2 - 1, bits.w * 2 - 1) * half
				if k == 0:
					parity0 = (bits.x + bits.y + bits.z + bits.w) % 2
				# Keyed per face, not per corner, so each face can take its own colour: a
				# step's tread and its riser want different shades.
				corners.append(out.vertex(Vector3i(axis, s, k), p, colour.call(p, outward)))
			_five_tets(out, corners, parity0 == 1, outward)
	return out


## DENSITY FRONT END: dual-contour a VoxelField4D and colour it the same way. [param to_world]
## maps a grid-space vertex to where it goes; [param density] (positive inside, in world
## space) drives the occlusion; [param colour] as for the shell, with r the distance from
## the origin.
## Cells entirely below [param hidden_below] are dropped, as for the height box.
static func bake_density(field: VoxelField4D, to_world: Callable, density: Callable, colour: Callable, ao: Array = [], hidden_below: float = -INF) -> Builder:
	var contour := MultiVertexDualContour4D.new(field)
	contour.generate()
	var out := Builder.new()
	for i in contour.vertices.size():
		var p: Vector4 = to_world.call(contour.vertices[i])
		# Already outward: they are summed from the cells' own normals, and the cells are
		# wound the way the renderer draws them, which is outward (see Builder.tet). Negating
		# them - on the guess that they were density gradients - made every slope read as
		# vertical and browned the whole hillside round the cave mouth.
		var normal: Vector4 = contour.vertex_normals[i]
		var c: Color = colour.call(p, normal, p.length())
		var light := 1.0
		for pass_ in ao:
			light *= shade_of(solid_fraction(density, p, _spacing(pass_, p.length())), pass_[1])
		out.vertex(i, p, Color(c.r * light, c.g * light, c.b * light, c.a))
	# The contour already winds its cells; keep them as they are.
	var cells: PackedInt32Array = contour.ground_cells
	for t in range(0, cells.size(), 4):
		var shown := false
		for k in 4:
			shown = shown or out.positions[cells[t + k]].y >= hidden_below
		if shown:
			out.cells.append_array(cells.slice(t, t + 4))
	return out
