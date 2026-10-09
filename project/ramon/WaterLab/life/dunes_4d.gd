extends Node4D

## WATER LAB: the tank's sand as 4D hills (Ramon, 9 Oct: "the tank is huge, so maybe make some unique 4d
## geo to create some kind of sandy hills"). A height field over the tank's whole 3D floor, x, z AND W:
## the sand's top is y = height_at(x, z, w), so the level slice shows one landscape of dunes and a
## slice turned through W (or the tank's contents turned, the room's gizmo) another.
##
## BUILT AS A CLOSED 4D SOLID, one mesh: the floor's (x, z, w) grid cut into cubes, each cube into six
## tetrahedra the same way round (Kuhn's split, so neighbours agree); the top is those tetrahedra lifted
## to the sand's height, the bottom the same at the base, and round the four... six sides of the floor's
## box, each boundary square's two triangles stood up as prisms from base to top, three tetrahedra each
## (the loft builder's diagonal rule, so neighbouring prisms agree). Closed, as the cross-section
## renderer needs (a hole breaks it far beyond its own size: lofting_gotchas.md).
##
## Low at the glass, so the view in stays open; rising toward the back. In the water's own frame.
## NO class_name (engine_gotchas.md).

const Loft := preload("res://ramon/WaterLab/carried/chickenpen/scripts/loft_builder_4d.gd")

var half_extents: Vector4 = Vector4(9.2, 2.4, 1.6, 3.5)
## The flat sand's top (the tank's own sand box), the dunes' foot.
var floor_y: float = -2.14
## Grid steps, metres: x, z, W.
var step := Vector3(0.6, 0.5, 0.8)
var tets: int = 0
var build_ms: float = 0.0
var _noise := FastNoiseLite.new()
var _fine := FastNoiseLite.new()


func _init() -> void:
	_noise.seed = 1207
	_noise.frequency = 0.16
	_noise.fractal_octaves = 3
	_fine.seed = 88
	_fine.frequency = 0.9


func _ready() -> void:
	var t0: int = Time.get_ticks_usec()
	# Baked under life/baked/ after the first build (as the reef is): the height field is the same
	# every time, and building it took a third of a second. Named by the tank's size, so a bigger
	# tank bakes its own (the 9 Oct round 2 tank kept the old shelf half way up the water).
	var he: Vector4 = half_extents
	var path: String = "res://ramon/WaterLab/life/baked/dunes_v1_%d_%d_%d_%d.res" % [roundi(he.x * 100.0), roundi(floor_y * 100.0), roundi(he.z * 100.0), roundi(he.w * 100.0)]
	var mesh: ArrayTetraMesh4D = null
	if ResourceLoader.exists(path):
		mesh = load(path) as ArrayTetraMesh4D
	if mesh == null:
		mesh = _build()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://ramon/WaterLab/life/baked/"))
		ResourceSaver.save(mesh, path)
	var mi := MeshInstance4D.new()
	mi.name = "Sand"
	mi.mesh = mesh
	mi.material_override = _sand_material()
	add_child(mi)
	tets = mesh.get_simplex_cell_vertex_indices().size() / 4
	build_ms = float(Time.get_ticks_usec() - t0) / 1000.0


## The sand's top at (x, z, w), in this node's frame.
func height_at(x: float, z: float, w: float) -> float:
	var he: Vector4 = half_extents
	# Low at the glass (+z), rising to the back.
	var front: float = smoothstep(he.z - 0.15, he.z - 1.1, z)
	var back: float = smoothstep(-0.2, -he.z, z)
	var hills: float = maxf(_noise.get_noise_3d(x, z * 1.4, w * 1.2) + 0.15, 0.0) * 1.15
	var ripple: float = 0.035 * (0.5 + 0.5 * sin(x * 3.1 + w * 1.7 + _fine.get_noise_3d(x, z, w) * 3.0))
	return floor_y + front * (hills * (0.55 + 0.6 * back) + back * 0.28) + ripple * front


func _build() -> ArrayTetraMesh4D:
	var he: Vector4 = half_extents
	var nx: int = maxi(int(round(he.x * 2.0 / step.x)), 2)
	var nz: int = maxi(int(round(he.z * 2.0 / step.y)), 2)
	var nw: int = maxi(int(round(he.w * 2.0 / step.z)), 2)
	var lo := Vector3(-he.x, -he.z, -he.w)
	var dx: float = he.x * 2.0 / float(nx)
	var dz: float = he.z * 2.0 / float(nz)
	var dw: float = he.w * 2.0 / float(nw)
	var base: float = floor_y - 0.05
	var pos := PackedVector4Array()
	# Top vertices then bottom ones, index = ((i * (nz+1)) + j) * (nw+1) + k.
	var count: int = (nx + 1) * (nz + 1) * (nw + 1)
	pos.resize(count * 2)
	for i in nx + 1:
		for j in nz + 1:
			for k in nw + 1:
				var x: float = lo.x + float(i) * dx
				var z: float = lo.y + float(j) * dz
				var w: float = lo.z + float(k) * dw
				var id: int = (i * (nz + 1) + j) * (nw + 1) + k
				pos[id] = Vector4(x, height_at(x, z, w), z, w)
				pos[count + id] = Vector4(x, base, z, w)
	var vid := func(i: int, j: int, k: int) -> int: return (i * (nz + 1) + j) * (nw + 1) + k
	var cells := PackedInt32Array()
	# The six tetrahedra of a cube: the main diagonal 000 to 111, one per order of the three axes.
	var orders: Array = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
	for i in nx:
		for j in nz:
			for k in nw:
				for o in orders:
					var c := Vector3i(i, j, k)
					var quad: Array = [vid.call(c.x, c.y, c.z)]
					for a in o:
						c[a] += 1
						quad.append(vid.call(c.x, c.y, c.z))
					cells.append_array(quad)
					cells.append_array([int(quad[0]) + count, int(quad[2]) + count, int(quad[1]) + count, int(quad[3]) + count])
	# The sides: each boundary square's two triangles (the same diagonal the cubes use), stood up as
	# prisms from the base to the top.
	var tris: Array = []
	for side in [0, nx]:
		for j in nz:
			for k in nw:
				_square(tris, vid.call(side, j, k), vid.call(side, j + 1, k), vid.call(side, j, k + 1), vid.call(side, j + 1, k + 1))
	for side in [0, nz]:
		for i in nx:
			for k in nw:
				_square(tris, vid.call(i, side, k), vid.call(i + 1, side, k), vid.call(i, side, k + 1), vid.call(i + 1, side, k + 1))
	for side in [0, nw]:
		for i in nx:
			for j in nz:
				_square(tris, vid.call(i, j, side), vid.call(i + 1, j, side), vid.call(i, j + 1, side), vid.call(i + 1, j + 1, side))
	for t in tris:
		var s: Array = (t as Array).duplicate()
		s.sort()
		var a0: int = s[0] + count
		var b0: int = s[1] + count
		var c0: int = s[2] + count
		var a1: int = s[0]
		var b1: int = s[1]
		var c1: int = s[2]
		cells.append_array([a0, b0, c0, c1])
		cells.append_array([a0, b0, c1, b1])
		cells.append_array([a0, b1, c1, a1])
	Loft.make_winding_consistent(cells, pos, false)
	var m := ArrayTetraMesh4D.new()
	m.set_vertex_positions(pos)
	m.set_simplex_cell_vertex_indices(cells)
	# Texture coordinates from where each point is: the sand's grain and its ripples.
	var tex := PackedVector3Array()
	tex.resize(pos.size())
	for n in pos.size():
		var p: Vector4 = pos[n]
		tex[n] = Vector3(fposmod(p.x * 0.25 + p.w * 0.1, 1.0), clampf((p.y - floor_y) / 1.6, 0.0, 1.0), fposmod(p.z * 0.25, 1.0))
	m.set_texture_map_values(tex)
	m.set_simplex_cell_texture_map_indices(cells)
	m.calculate_boundary_normals(false)
	return m


## A square of the floor's box face (corners a, b along one axis, c, d the next row) as the two
## triangles the cubes' split gives it: the diagonal from its low corner to its high one.
static func _square(tris: Array, a: int, b: int, c: int, d: int) -> void:
	tris.append([a, b, d])
	tris.append([a, c, d])


## Pale sand with darker grains, a little darker in the hollows (the y axis of its texture).
func _sand_material() -> TetraMaterial4D:
	var n := FastNoiseLite.new()
	n.seed = 51
	n.frequency = 0.5
	var slices: Array[Image] = []
	var size: int = 24
	for k in size:
		var img: Image = Image.create(size, 8, false, Image.FORMAT_RGBA8)
		for j in 8:
			for i in size:
				var v: float = n.get_noise_3d(float(i), float(j) * 3.0, float(k))
				var c := Color(0.58, 0.51, 0.40).lerp(Color(0.70, 0.63, 0.50), float(j) / 7.0)
				c = c.lerp(Color(0.40, 0.35, 0.27), clampf(-v * 1.5, 0.0, 0.5))
				if v > 0.5:
					c = c.lightened(0.12)
				img.set_pixel(i, j, c)
		slices.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGBA8, size, 8, size, false, slices)
	var m := TetraMaterial4D.new()
	m.set("albedo_source", 3)
	m.set("albedo_texture_3d", tex)
	return m
