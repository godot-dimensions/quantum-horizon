extends RefCounted

## The talk's four-dimensional exhibits, built from their own equations straight into
## tetrahedra: a 4D ball, a tesseract, and five shapes that have no three-dimensional
## version at all - the tiger, the spheritorus, the ditorus, the duocylinder and a Klein
## bottle given thickness.
##
## PARAMETRIC, NOT CONTOURED. The terrain baker could dual-contour any of these from an
## inside/outside test, but every one of them is a product of circles (or a surface swept
## round a circle), so its boundary is a grid in three angles. Meshing that grid directly
## is exact, has no sampling noise at the thin parts, and costs a fraction of a contour:
## each shape here is well under a second of GDScript, and none of it needs a bake on disk.
##
## TWO MESHERS. A 3-parameter family of points is a grid of cubes, six tetrahedra each
## (Kuhn's paths from the lowest corner to the highest, the same split the terrain baker
## uses). A triangulated surface swept round a circle - the spheritorus, whose ball has no
## grid without poles - is a stack of prisms, three tetrahedra each, with the diagonal on
## every shared quad picked by vertex index so neighbouring prisms agree about it. Every tetrahedron is wound by terrain_bake_4d's
## Builder against an outward direction the shape supplies, which is how the renderer
## tells front from back.
##
## ORIENTED FOR THE SLICE YOU ARRIVE ON. Each shape is turned so that w = 0 cuts it
## somewhere interesting: two rings for the tiger, two balls for the spheritorus, two
## tori side by side for the ditorus, a plain cylinder for the duocylinder. Turning it
## through W is then a change you can watch rather than one you have to take on trust.
##
## THREAD-SAFE BY CONSTRUCTION. Nothing here touches the scene tree or makes a texture:
## meshes come back without a material, and the theatre gives them the shared colour-cube
## material on the main thread. So the whole set can be made on a WorkerThreadPool task
## while the room is still being walked into.
##
## EVERY TETRAHEDRON COSTS ABOUT 1.25 KB OF VIDEO MEMORY (chicken_pen_learnings.md), so the
## resolutions below are the coarsest that still read as smooth from the house.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

## The six paths from a cube's lowest corner to its highest, as orders of its three axes.
const KUHN := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]

## What the zoo shows, in order. `name` and `recipe` are the nameplate.
const ZOO := [
	{"id": "tiger", "name": "TIGER", "recipe": "a flat torus given thickness. Its slice: two rings"},
	{"id": "spheritorus", "name": "SPHERITORUS", "recipe": "a ball swept round a circle. Its slice: two balls"},
	{"id": "ditorus", "name": "DITORUS", "recipe": "a torus swept round a circle. Its slice: two tori"},
	{"id": "duocylinder", "name": "DUOCYLINDER", "recipe": "round in two planes at once, and no flat side anywhere"},
	{"id": "klein", "name": "KLEIN BOTTLE", "recipe": "no inside and no outside. In 4D it never crosses itself"},
]


# ---------------------------------------------------------------- the meshers

## A 3-parameter family of points, meshed as a grid of cubes, six tetrahedra each.
##
## [param counts] is cells along each parameter, and [param wraps] says which parameters
## close on themselves (1) and which run from 0 to 1 and stop (0). [param point] maps
## (s, t, r), each in [0, 1], to [position, outward, colour].
##
## Pass [param into] to add to a builder that already holds another piece: keys are tagged
## with where this piece starts, so the two never weld by accident.
static func _grid(counts: Vector3i, wraps: Vector3i, point: Callable,
		into: TerrainBake.Builder = null) -> TerrainBake.Builder:
	var b: TerrainBake.Builder = into if into != null else TerrainBake.Builder.new()
	var outs := {}
	var index := {}
	var tag: int = b.positions.size()
	for i in counts.x + 1:
		for j in counts.y + 1:
			for k in counts.z + 1:
				var key := Vector4i(tag, i % counts.x if wraps.x == 1 else i,
					j % counts.y if wraps.y == 1 else j, k % counts.z if wraps.z == 1 else k)
				if b.has_vertex(key):
					index[Vector3i(i, j, k)] = b.vertex(key, Vector4.ZERO)
					continue
				var p: Array = point.call(float(i) / float(counts.x),
					float(j) / float(counts.y), float(k) / float(counts.z))
				var at: int = b.vertex(key, p[0], p[2])
				index[Vector3i(i, j, k)] = at
				outs[at] = p[1]
	var corner := PackedInt32Array()
	corner.resize(8)
	for i in counts.x:
		for j in counts.y:
			for k in counts.z:
				for bits in 8:
					corner[bits] = index[Vector3i(i + (bits & 1), j + ((bits >> 1) & 1),
						k + ((bits >> 2) & 1))]
				for path in KUHN:
					var one: int = 1 << int(path[0])
					var two: int = one | (1 << int(path[1]))
					var a: int = corner[0]
					var c1: int = corner[one]
					var c2: int = corner[two]
					var d: int = corner[7]
					b.tet(a, c1, c2, d, outs[a] + outs[c1] + outs[c2] + outs[d])
	return b


## A triangulated surface swept round a circle: a stack of prisms, three tetrahedra each.
##
## [param triangles] index the surface's own vertices, [param segments] is how many steps
## round the circle, and [param point] maps (surface vertex, angle 0..1) to [position,
## outward, colour]. The circle always closes.
static func _swept(vertex_count: int, triangles: PackedInt32Array, segments: int,
		point: Callable, into: TerrainBake.Builder = null) -> TerrainBake.Builder:
	var b: TerrainBake.Builder = into if into != null else TerrainBake.Builder.new()
	var outs := {}
	var tag: int = b.positions.size()
	for v in vertex_count:
		for s in segments:
			var p: Array = point.call(v, float(s) / float(segments))
			var at: int = b.vertex(Vector3i(tag, v, s), p[0], p[2])
			outs[at] = p[1]
	for f in triangles.size() / 3:
		var tri: Array = [triangles[f * 3], triangles[f * 3 + 1], triangles[f * 3 + 2]]
		tri.sort()
		for s in segments:
			var s1: int = (s + 1) % segments
			var a0: int = b.vertex(Vector3i(tag, tri[0], s), Vector4.ZERO)
			var b0: int = b.vertex(Vector3i(tag, tri[1], s), Vector4.ZERO)
			var c0: int = b.vertex(Vector3i(tag, tri[2], s), Vector4.ZERO)
			var a1: int = b.vertex(Vector3i(tag, tri[0], s1), Vector4.ZERO)
			var b1: int = b.vertex(Vector3i(tag, tri[1], s1), Vector4.ZERO)
			var c1: int = b.vertex(Vector3i(tag, tri[2], s1), Vector4.ZERO)
			b.tet(a0, b0, c0, a1, outs[a0] + outs[b0] + outs[c0] + outs[a1])
			b.tet(b0, c0, a1, b1, outs[b0] + outs[c0] + outs[a1] + outs[b1])
			b.tet(c0, a1, b1, c1, outs[c0] + outs[a1] + outs[b1] + outs[c1])
	return b


## The boundary of a tesseract, eight cubes, each cut into n^3 little cubes. [param round]
## pushes every vertex out onto the sphere of [param radius], which is how the 4D ball is
## made: a cube-sphere one dimension up, so it has no poles to pinch. [param colour] maps
## (position, which cell) to a colour; cells are welded only when [param weld] is set.
static func _cells(n: int, radius: float, round: bool, weld: bool, colour: Callable) -> TerrainBake.Builder:
	var b := TerrainBake.Builder.new()
	var outs := PackedVector4Array()
	var cell: int = 0
	for axis in 4:
		for side in [0, 1]:
			var free: Array = [0, 1, 2, 3]
			free.erase(axis)
			var index := {}
			for i in n + 1:
				for j in n + 1:
					for k in n + 1:
						var lattice := Vector4i.ZERO
						lattice[axis] = side * n
						lattice[free[0]] = i
						lattice[free[1]] = j
						lattice[free[2]] = k
						# Unwelded cells keep their own corners: the cell number is folded into
						# the key, well clear of any lattice coordinate (n is never near 100).
						var key := lattice if weld else lattice + Vector4i(cell * 100, 0, 0, 0)
						if b.has_vertex(key):
							index[Vector3i(i, j, k)] = b.vertex(key, Vector4.ZERO)
							continue
						var p := Vector4(lattice) * (2.0 / float(n)) - Vector4.ONE
						var out: Vector4 = p.normalized() if round else Vector4.ZERO
						if not round:
							out[axis] = -1.0 if side == 0 else 1.0
						var at: Vector4 = p.normalized() * radius if round else p * radius
						index[Vector3i(i, j, k)] = b.vertex(key, at, colour.call(at, cell))
						outs.append(out)
			var corner := PackedInt32Array()
			corner.resize(8)
			for i in n:
				for j in n:
					for k in n:
						for bits in 8:
							corner[bits] = index[Vector3i(i + (bits & 1), j + ((bits >> 1) & 1),
								k + ((bits >> 2) & 1))]
						for path in KUHN:
							var one: int = 1 << int(path[0])
							var two: int = one | (1 << int(path[1]))
							b.tet(corner[0], corner[one], corner[two], corner[7],
								outs[corner[0]] + outs[corner[one]] + outs[corner[two]] + outs[corner[7]])
			cell += 1
	return b


## A unit sphere as a triangulated cube, [param n] squares a side on each face. Returns
## [positions (PackedVector3Array), triangles (PackedInt32Array)].
static func _sphere(n: int) -> Array:
	var points := PackedVector3Array()
	var tris := PackedInt32Array()
	var index := {}
	for axis in 3:
		for side in [0, 1]:
			var free: Array = [0, 1, 2]
			free.erase(axis)
			var here := {}
			for i in n + 1:
				for j in n + 1:
					var lattice := Vector3i.ZERO
					lattice[axis] = side * n
					lattice[free[0]] = i
					lattice[free[1]] = j
					if not index.has(lattice):
						index[lattice] = points.size()
						points.append((Vector3(lattice) * (2.0 / float(n)) - Vector3.ONE).normalized())
					here[Vector2i(i, j)] = index[lattice]
			for i in n:
				for j in n:
					var a: int = here[Vector2i(i, j)]
					var bb: int = here[Vector2i(i + 1, j)]
					var c: int = here[Vector2i(i + 1, j + 1)]
					var d: int = here[Vector2i(i, j + 1)]
					tris.append_array(PackedInt32Array([a, bb, c, a, c, d]))
	return [points, tris]


# ---------------------------------------------------------------- the shapes

## The 4D ball: a 3-sphere of [param radius], coloured by its own w so its slice changes
## colour as it travels through yours - blue coming in, white at its widest, magenta going.
static func hyperball(radius: float = 0.95, n: int = 6) -> ArrayTetraMesh4D:
	var b := _cells(n, radius, true, true, func(p: Vector4, _cell: int) -> Color:
		var t: float = clampf(p.w / radius, -1.0, 1.0)
		var cool := Color(0.25, 0.55, 1.0)
		var warm := Color(1.0, 0.35, 0.75)
		var mid := Color(0.95, 0.95, 1.0)
		return mid.lerp(warm, t) if t > 0.0 else mid.lerp(cool, -t))
	return TerrainBake.mesh_of(b, false)


## The tesseract, each of its eight cubes its own colour, so every face of a slice says
## which cube it came from: x red, y green, z blue, and the two cubes along W gold.
static func tesseract(half: float = 0.65) -> ArrayTetraMesh4D:
	var palette := [Color(1.0, 0.36, 0.40), Color(0.85, 0.30, 0.55),
		Color(0.40, 0.90, 0.45), Color(0.30, 0.75, 0.60),
		Color(0.35, 0.55, 1.0), Color(0.45, 0.40, 0.95),
		Color(1.0, 0.80, 0.30), Color(0.95, 0.62, 0.22)]
	var b := _cells(1, half, false, false, func(_p: Vector4, cell: int) -> Color:
		return palette[cell])
	return TerrainBake.mesh_of(b, false)


## The tiger: every point within [param c] of a flat torus that has one circle (radius
## [param a]) in the y-w plane and the other ([param b]) in x-z. A flat torus is a surface
## that only fits in 4D; thickened, it is this. At w = 0 it cuts as two horizontal rings,
## one above the other. Striped, because it is a tiger.
static func tiger(a: float = 0.72, b: float = 0.92, c: float = 0.26,
		n: Vector3i = Vector3i(18, 30, 6)) -> ArrayTetraMesh4D:
	var orange := Color(1.0, 0.56, 0.16)
	var dark := Color(0.16, 0.10, 0.06)
	var b_out := _grid(n, Vector3i(1, 1, 1), func(s: float, t: float, r: float) -> Array:
		var u: float = TAU * s
		var v: float = TAU * t
		var f: float = TAU * r
		var ryw: float = a + c * cos(f)
		var rxz: float = b + c * sin(f)
		var p := Vector4(rxz * cos(v), ryw * cos(u), rxz * sin(v), ryw * sin(u))
		var out := Vector4(sin(f) * cos(v), cos(f) * cos(u), sin(f) * sin(v), cos(f) * sin(u))
		var stripe: float = smoothstep(0.35, 0.85, sin(v * 5.0))
		return [p, out, orange.lerp(dark, stripe * 0.85)])
	return TerrainBake.mesh_of(b_out, false)


## The spheritorus: a ball of [param b] swept round a circle of [param a] in the x-w
## plane. At w = 0 the circle is cut at two points, so the slice is two balls side by side;
## tip it through W and they stretch towards each other and close into a torus.
static func spheritorus(a: float = 0.92, b: float = 0.42, n: int = 4,
		segments: int = 28) -> ArrayTetraMesh4D:
	var sphere: Array = _sphere(n)
	var points: PackedVector3Array = sphere[0]
	var green := Color(0.30, 0.88, 0.62)
	var pale := Color(0.78, 1.0, 0.86)
	var b_out := _swept(points.size(), sphere[1], segments, func(i: int, t: float) -> Array:
		var s: Vector3 = points[i]
		var u: float = TAU * t
		var radial: float = a + b * s.x
		var p := Vector4(radial * cos(u), b * s.y, b * s.z, radial * sin(u))
		var out := Vector4(s.x * cos(u), s.y, s.z, s.x * sin(u))
		return [p, out, green.lerp(pale, 0.5 + 0.5 * s.y)])
	return TerrainBake.mesh_of(b_out, false)


## The ditorus: a torus (radii [param b], [param c]) swept round a circle of [param a] in
## the x-w plane. At w = 0 that circle is cut at two points again, so the slice is two
## tori side by side, their rings facing you.
static func ditorus(a: float = 1.0, b: float = 0.46, c: float = 0.15,
		n: Vector3i = Vector3i(28, 16, 6)) -> ArrayTetraMesh4D:
	var violet := Color(0.62, 0.45, 1.0)
	var rose := Color(1.0, 0.55, 0.85)
	var b_out := _grid(n, Vector3i(1, 1, 1), func(s: float, t: float, r: float) -> Array:
		var u: float = TAU * s
		var v: float = TAU * t
		var f: float = TAU * r
		var ring: float = b + c * cos(f)
		var radial: float = a + ring * cos(v)
		var p := Vector4(radial * cos(u), ring * sin(v), c * sin(f), radial * sin(u))
		var out := Vector4(cos(f) * cos(v) * cos(u), cos(f) * sin(v), sin(f),
			cos(f) * cos(v) * sin(u))
		return [p, out, violet.lerp(rose, 0.5 + 0.5 * sin(v))])
	return TerrainBake.mesh_of(b_out, false)


## The duocylinder: round in the x-z plane (radius [param a]) and in the y-w plane
## ([param b]) at once. Its boundary is two solid tori - a circle times a disc, and a disc
## times a circle - glued along a flat torus. At w = 0 it is a plain cylinder: the first
## torus is its curved side and the second its two caps, which is why they are two colours.
##
## BOTH HALVES ON ONE GRID OF ANGLES. Each is a polar grid (angle round the circle, radius
## out across the disc, angle round the disc), and along the flat torus where they meet
## both are cut by the same (theta, phi) lines with Kuhn's diagonal running the same way,
## so the join closes exactly. The first version swept a triangulated disc instead and left
## 2,496 unpaired faces along that join, because the two halves split its quads opposite
## ways. The centre of each disc collapses to a point; the tetrahedra that flattens are the
## zero-volume ones the Builder drops.
static func duocylinder(a: float = 0.78, b: float = 0.62, round_count: int = 26,
		across: int = 2) -> ArrayTetraMesh4D:
	var side := Color(1.0, 0.72, 0.28)
	var cap := Color(1.0, 0.92, 0.70)
	# The curved side at w = 0: the x-z circle times the y-w disc.
	var b_out := _grid(Vector3i(round_count, across, round_count), Vector3i(1, 0, 1),
		func(s: float, t: float, q: float) -> Array:
			var u: float = TAU * s
			var v: float = TAU * q
			return [Vector4(a * cos(u), t * b * cos(v), a * sin(u), t * b * sin(v)),
				Vector4(cos(u), 0.0, sin(u), 0.0), side])
	# The caps: the x-z disc times the y-w circle. Radius first, so the angles are the same
	# two axes of the cube as they are above.
	_grid(Vector3i(across, round_count, round_count), Vector3i(0, 1, 1),
		func(t: float, s: float, q: float) -> Array:
			var u: float = TAU * s
			var v: float = TAU * q
			return [Vector4(t * a * cos(u), b * cos(v), t * a * sin(u), b * sin(v)),
				Vector4(0.0, cos(v), 0.0, sin(v)), cap], b_out)
	return TerrainBake.mesh_of(b_out, false)


## The Klein bottle, sitting in 4D without crossing itself, given a tube of [param t].
##
## THE EMBEDDING: a torus whose tube turns half a revolution through the z-w plane as it
## goes round, so it meets itself turned inside out - which is exactly a Klein bottle - and
## the half turn happens in a direction 3D does not have, so nothing has to pass through
## anything. Its surface normals are worked out by hand (see _klein_frame), because a
## frame picked by projecting fixed axes would flip wherever an axis went tangent, and the
## tube would twist into itself there.
##
## Not welded across its seam: the seam is where the surface meets itself mirrored, so the
## vertices on either side are the same points reached from opposite ends of the grid.
static func klein(big: float = 0.86, small: float = 0.38, t: float = 0.13,
		n: Vector3i = Vector3i(36, 16, 6)) -> ArrayTetraMesh4D:
	var cyan := Color(0.30, 0.85, 1.0)
	var magenta := Color(1.0, 0.40, 0.85)
	var b_out := _grid(n, Vector3i(0, 1, 1), func(s: float, q: float, r: float) -> Array:
		var u: float = TAU * s
		var v: float = TAU * q
		var f: float = TAU * r
		var frame: Array = _klein_frame(big, small, u, v)
		var out: Vector4 = frame[1] * cos(f) + frame[2] * sin(f)
		return [frame[0] + out * t, out, cyan.lerp(magenta, 0.5 - 0.5 * cos(u))])
	return TerrainBake.mesh_of(b_out, false)


## The Klein bottle's point at (u, v) and two unit normals there: [point, n1, n2].
static func _klein_frame(big: float, small: float, u: float, v: float) -> Array:
	var h: float = u * 0.5
	var ring: float = big + small * cos(v)
	var p := Vector4(ring * cos(u), ring * sin(u), small * sin(v) * cos(h), small * sin(v) * sin(h))
	# Radial out of the tube: orthogonal to both tangents by construction.
	var n1 := Vector4(cos(v) * cos(u), cos(v) * sin(u), sin(v) * cos(h), sin(v) * sin(h))
	# The z-w direction the tube is NOT leaning into, with its share of the u tangent taken
	# out. It is never parallel to that tangent, so this never degenerates.
	var du := Vector4(-ring * sin(u), ring * cos(u), -0.5 * small * sin(v) * sin(h),
		0.5 * small * sin(v) * cos(h))
	var n2 := Vector4(0.0, 0.0, -sin(h), cos(h))
	n2 = (n2 - du * (n2.dot(du) / du.length_squared())).normalized()
	return [p, n1, n2]


## One of the zoo's shapes by its id.
static func zoo_mesh(id: String) -> ArrayTetraMesh4D:
	match id:
		"tiger":
			return tiger()
		"spheritorus":
			return spheritorus()
		"ditorus":
			return ditorus()
		"duocylinder":
			return duocylinder()
		"klein":
			return klein()
	return null


# ---------------------------------------------------------------- the shadows

## Lines drawn on each shape's own skeleton, for the screen that shows its shadow: the flat
## torus under the tiger, the surface of the Klein bottle, and so on. Each line is a
## PackedVector4Array in the shape's own frame; the screen turns and projects them.
static func shadow_lines(id: String) -> Array:
	var lines: Array = []
	match id:
		"tiger":
			lines = _torus_lines(func(u: float, v: float) -> Vector4:
				return Vector4(0.92 * cos(v), 0.72 * cos(u), 0.92 * sin(v), 0.72 * sin(u)), 10, 12)
		"spheritorus":
			for k in 10:
				var u: float = TAU * float(k) / 10.0
				for plane in 2:
					var line := PackedVector4Array()
					for i in 33:
						var a: float = TAU * float(i) / 32.0
						var s := Vector3(cos(a), sin(a), 0.0) if plane == 0 else Vector3(cos(a), 0.0, sin(a))
						var radial: float = 0.92 + 0.42 * s.x
						line.append(Vector4(radial * cos(u), 0.42 * s.y, 0.42 * s.z, radial * sin(u)))
					lines.append(line)
		"ditorus":
			lines = _torus_lines(func(u: float, v: float) -> Vector4:
				var radial: float = 1.0 + 0.46 * cos(v)
				return Vector4(radial * cos(u), 0.46 * sin(v), 0.0, radial * sin(u)), 14, 8)
		"duocylinder":
			lines = _torus_lines(func(u: float, v: float) -> Vector4:
				return Vector4(0.78 * cos(u), 0.62 * cos(v), 0.78 * sin(u), 0.62 * sin(v)), 12, 12)
		"klein":
			lines = _torus_lines(func(u: float, v: float) -> Vector4:
				return _klein_frame(0.86, 0.38, u, v)[0], 16, 8)
		"tesseract":
			for i in 16:
				for axis in 4:
					if i & (1 << axis):
						continue
					var a := Vector4()
					for k in 4:
						a[k] = 0.65 if i & (1 << k) else -0.65
					var b := a
					b[axis] = 0.65
					lines.append(PackedVector4Array([a, b]))
		"hyperball":
			for k in 6:
				var tilt: float = PI * (float(k) + 0.5) / 6.0
				var line := PackedVector4Array()
				for i in 41:
					var a: float = TAU * float(i) / 40.0
					line.append(Vector4(cos(a) * sin(tilt), sin(a) * sin(tilt), 0.0, cos(tilt)) * 0.95)
				lines.append(line)
				var ring := PackedVector4Array()
				for i in 41:
					var a: float = TAU * float(i) / 40.0
					ring.append(Vector4(0.0, cos(a) * sin(tilt), sin(a) * sin(tilt), cos(tilt)) * 0.95)
				lines.append(ring)
	return lines


## Both families of lines on a surface given by f(u, v), u and v both round a full turn.
static func _torus_lines(f: Callable, along_u: int, along_v: int) -> Array:
	var lines: Array = []
	for k in along_v:
		var v: float = TAU * float(k) / float(along_v)
		var line := PackedVector4Array()
		for i in 49:
			line.append(f.call(TAU * float(i) / 48.0, v))
		lines.append(line)
	for k in along_u:
		var u: float = TAU * float(k) / float(along_u)
		var line := PackedVector4Array()
		for i in 33:
			line.append(f.call(u, TAU * float(i) / 32.0))
		lines.append(line)
	return lines
