extends RefCounted

## BOTANY LAB, round 3 (CARRIED from WaterLab/life/loft_kit.gd, 10 Oct): what the lofted plants and
## butterflies share: bases that shape a loft's section balls, turns that pose rigid pieces, a 4D frame
## carried on from frame to frame, and the baking, merging and texture coordinates of the meshes.
##
## NO class_name (engine_gotchas.md).

## A ball scaled along the axes (the loft builder applies a section's `basis` to its finished ball,
## so an explicit scale shapes it the same whichever way the spine runs: shark_4d.gd _scale).
static func scale(sx: float, sy: float, sz: float, sw: float) -> Projection:
	return Projection(Vector4(sx, 0, 0, 0), Vector4(0, sy, 0, 0), Vector4(0, 0, sz, 0), Vector4(0, 0, 0, sw))


## A ball flattened across `n` (a direction in x, y, z) to `a` of itself, and through W to `bw`: a fin
## that does not lie along the axes.
static func flatten(n: Vector3, a: float, bw: float) -> Projection:
	var n4 := Vector4(n.x, n.y, n.z, 0.0)
	var cols: Array = []
	for i in 4:
		var e := Vector4.ZERO
		e[i] = 1.0
		var c: Vector4 = e + n4 * ((a - 1.0) * n4[i])
		if i == 3:
			c.w *= bw
		cols.append(c)
	return Projection(cols[0], cols[1], cols[2], cols[3])


## A ball flattened across `n`, any direction in 4D, to `a` of itself and left round across the
## other three (I + (a - 1) n nᵀ): a petal or a leaf whose face may lean into W.
static func flatten4(n: Vector4, a: float) -> Projection:
	var u: Vector4 = n.normalized()
	var cols: Array = []
	for i in 4:
		var e := Vector4.ZERO
		e[i] = 1.0
		cols.append(e + u * ((a - 1.0) * u[i]))
	return Projection(cols[0], cols[1], cols[2], cols[3])


## A piece turned with a bent spine whose sideways offset x grows along -z at `slope` (dx per unit
## toward the tail): its +z, toward the head, along (-slope, 0, 1).
static func yaw(slope: float) -> Projection:
	var c: float = 1.0 / sqrt(1.0 + slope * slope)
	var sn: float = -slope * c
	return Projection(Vector4(c, 0, -sn, 0), Vector4(0, 1, 0, 0), Vector4(sn, 0, c, 0), Vector4(0, 0, 0, 1))


## A turn about y (+: +x toward -z).
static func rot_y(a: float) -> Projection:
	return Projection(Vector4(cos(a), 0, -sin(a), 0), Vector4(0, 1, 0, 0), Vector4(sin(a), 0, cos(a), 0), Vector4(0, 0, 0, 1))


## A turn about z (+: +x toward +y).
static func rot_z(a: float) -> Projection:
	return Projection(Vector4(cos(a), sin(a), 0, 0), Vector4(-sin(a), cos(a), 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))


## A turn about x (+: +y toward +z).
static func rot_x(a: float) -> Projection:
	return Projection(Vector4(1, 0, 0, 0), Vector4(0, cos(a), sin(a), 0), Vector4(0, -sin(a), cos(a), 0), Vector4(0, 0, 0, 1))


## A frame (right, up, ahead, ana) for `ahead`, carried on from `prev` so it never flips or spins: up
## as near world up as the heading allows, right and ana what is left of the previous ones, kept
## right-handed. `roll` tips right toward up.
static func frame_for(ahead: Vector4, prev: Projection, roll: float = 0.0) -> Projection:
	var z: Vector4 = ahead.normalized()
	var y: Vector4 = Vector4(0, 1, 0, 0) - z * z.y
	if y.length() < 0.05:
		y = prev.y - z * prev.y.dot(z)
	y = y.normalized()
	var x: Vector4 = prev.x - z * prev.x.dot(z) - y * prev.x.dot(y)
	if x.length() < 0.05:
		x = Vector4(z.z, 0.0, -z.x, 0.0)
		x = x - z * x.dot(z) - y * x.dot(y)
	if x.length() < 0.05:
		x = Vector4(0, 0, 0, 1) - z * z.w - y * y.w
	x = x.normalized()
	var w: Vector4 = prev.w - z * prev.w.dot(z) - y * prev.w.dot(y) - x * prev.w.dot(x)
	if w.length() < 0.05:
		for cand in [Vector4(0, 0, 0, 1), Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0)]:
			w = cand - z * cand.dot(z) - y * cand.dot(y) - x * cand.dot(x)
			if w.length() > 0.1:
				break
	w = w.normalized()
	var f := Projection(x, y, z, w)
	if f.determinant() < 0.0:
		f.w = -w
	if not is_zero_approx(roll):
		var xr: Vector4 = f.x * cos(roll) + f.y * sin(roll)
		var yr: Vector4 = f.y * cos(roll) - f.x * sin(roll)
		f = Projection(xr, yr, f.z, f.w)
	return f


## The level frame for a heading in the slice (right = (h.z, 0, -h.x), as the old herds had it).
static func level_frame(h: Vector4) -> Projection:
	var r := Vector4(h.z, 0.0, -h.x, 0.0)
	if r.length() < 0.05:
		r = Vector4(1, 0, 0, 0)
	return frame_for(h, Projection(r.normalized(), Vector4(0, 1, 0, 0), h, Vector4(0, 0, 0, 1)))


## Several meshes as one. Texture coordinates come along when every part has them one a vertex (as
## paint() leaves them); otherwise paint after merging.
static func merge(parts: Array) -> ArrayTetraMesh4D:
	var pos := PackedVector4Array()
	var cells := PackedInt32Array()
	var tex := PackedVector3Array()
	var keep_tex: bool = true
	for m in parts:
		if m == null:
			continue
		var mm: ArrayTetraMesh4D = m
		var mp: PackedVector4Array = mm.get_vertex_positions()
		var mt: PackedVector3Array = mm.get_texture_map_values()
		if mt.size() != mp.size() or mm.get_simplex_cell_texture_map_indices() != mm.get_simplex_cell_vertex_indices():
			keep_tex = false
		var off: int = pos.size()
		pos.append_array(mp)
		tex.append_array(mt)
		for c in mm.get_simplex_cell_vertex_indices():
			cells.append(c + off)
	var out := ArrayTetraMesh4D.new()
	out.set_vertex_positions(pos)
	out.set_simplex_cell_vertex_indices(cells)
	if keep_tex and tex.size() == pos.size():
		out.set_texture_map_values(tex)
		out.set_simplex_cell_texture_map_indices(cells)
	return out


## Every vertex its texture coordinates, from where it is: `coord` maps a position to a Vector3.
static func paint(m: ArrayTetraMesh4D, coord: Callable) -> void:
	if m == null:
		return
	var pos: PackedVector4Array = m.get_vertex_positions()
	var tex := PackedVector3Array()
	tex.resize(pos.size())
	for i in pos.size():
		tex[i] = coord.call(pos[i])
	m.set_texture_map_values(tex)
	m.set_simplex_cell_texture_map_indices(m.get_simplex_cell_vertex_indices())


## A mesh baked once under `path` (built by `build` the first time, its normals worked out).
static func cached(path: String, build: Callable) -> ArrayTetraMesh4D:
	if ResourceLoader.exists(path):
		var r: Resource = load(path)
		if r is ArrayTetraMesh4D:
			return r
	var m: ArrayTetraMesh4D = build.call()
	if m != null:
		m.calculate_boundary_normals(false)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		ResourceSaver.save(m, path)
	return m


## A MeshInstance4D of `mesh` under `holder`; returns its tetrahedra.
static func add_mesh(holder: Node, nm: String, mesh: ArrayTetraMesh4D, mat: Material4D) -> int:
	if mesh == null:
		return 0
	var mi := MeshInstance4D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	holder.add_child(mi)
	return mesh.get_simplex_cell_vertex_indices().size() / 4


## A material that looks its colour up in a 3D texture made of `slices` (Images, one size) at each
## point's texture coordinates: the engine's own multi-colour path (shark_4d.gd _tex_material).
static func tex_material(slices: Array) -> TetraMaterial4D:
	var imgs: Array[Image] = []
	for s in slices:
		imgs.append(s)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, imgs[0].get_width(), imgs[0].get_height(), imgs.size(), false, imgs)
	var m := TetraMaterial4D.new()
	m.albedo_source = TetraMaterial4D.TETRA_COLOR_SOURCE_TEXTURE3D_CELL_UVW_ONLY
	m.albedo_texture_3d = tex
	return m


static func flat(c: Color) -> TetraMaterial4D:
	var m := TetraMaterial4D.new()
	m.albedo_color = c
	return m


static func white_texture() -> ImageTexture3D:
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, 1, 1, 1, false, [img])
	return tex
