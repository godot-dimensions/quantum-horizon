extends RefCounted

## Designed-cut stones: each one exactly the intersection of a few flat cuts (PenLayout/
## PLAN_REF_LOCK.md step 12; Ramon, 6 Oct: "the rocks of the tower ... can be even more low poly,
## showing clear designed cut rock surface faces").
##
## A STONE IS ITS PLANES. Each plane is a half-space, n . p <= d, and the stone is what all of
## them keep: a convex 4D polytope. Its surface is one flat 3D cell per plane that touches it,
## and flat shading turns every cell into one clean face in any slice. Nothing is noise: every
## face is a cut that was put there.
##
## HOW IT IS BUILT. Every corner lies on four planes, so every four planes are solved for their
## meeting point and kept if no other plane cuts it away. A plane's cell is the corners on it; the
## cell's faces are the corners it shares with each other plane, put in order round their middle
## and fanned into triangles; each triangle and the cell's middle make a tetrahedron, wound to face
## out along the plane (TerrainBake.Builder does the winding). Each cell keeps its own copies of its
## corners, so its colour stops at its edges.
##
## Brute force (a few thousand fours per stone), so stones are baked once to files
## (_bake_terrain_runner.gd what=stone_<n>), never built when a scene opens.
##
## RECIPES (recipe()): a box, then the cuts that make it a designed stone, in the order a mason
## would: the four vertical edges taken off (the rounded look), the top edges bevelled, the
## corners where those meet, and the same in W so it is round in W as well and a turned slice
## still cuts clean faces. Each cut leans a few degrees off true and sits a little in or out, from
## the recipe's seed, so no two stones are the same and none looks machined.
##
## NO class_name (engine_gotchas.md).

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

const EPS := 1e-5


## The corners of the polytope [param planes] ([normal, distance] pairs): [positions, the planes
## each lies on].
static func corners(planes: Array) -> Array:
	var n: int = planes.size()
	var pos: Array[Vector4] = []
	var on: Array = []
	var seen := {}
	for a in n:
		for b in range(a + 1, n):
			for c in range(b + 1, n):
				for d in range(c + 1, n):
					var na: Vector4 = planes[a][0]
					var nb: Vector4 = planes[b][0]
					var nc: Vector4 = planes[c][0]
					var nd: Vector4 = planes[d][0]
					# Rows are the normals; Projection takes columns.
					var m := Projection(Vector4(na.x, nb.x, nc.x, nd.x), Vector4(na.y, nb.y, nc.y, nd.y),
						Vector4(na.z, nb.z, nc.z, nd.z), Vector4(na.w, nb.w, nc.w, nd.w))
					if absf(m.determinant()) < 1e-9:
						continue
					var p: Vector4 = m.inverse() * Vector4(planes[a][1], planes[b][1], planes[c][1], planes[d][1])
					var inside := true
					for k in n:
						if (planes[k][0] as Vector4).dot(p) > float(planes[k][1]) + EPS:
							inside = false
							break
					if not inside:
						continue
					var key := Vector4i(roundi(p.x * 1e4), roundi(p.y * 1e4), roundi(p.z * 1e4), roundi(p.w * 1e4))
					if seen.has(key):
						continue
					seen[key] = true
					var lies := PackedInt32Array()
					for k in n:
						if absf((planes[k][0] as Vector4).dot(p) - float(planes[k][1])) < 1e-4:
							lies.append(k)
					pos.append(p)
					on.append(lies)
	return [pos, on]


## Adds the stone to [param out] (a TerrainBake.Builder), each cell coloured by
## [param colour] (Callable(normal: Vector4, centre: Vector4) -> Color). [param tag] keeps its
## corners apart from other stones' in the same builder. Returns the number of cells.
static func bake_into(out: TerrainBake.Builder, planes: Array, colour: Callable, tag: int = 0) -> int:
	var cs: Array = corners(planes)
	var pos: Array[Vector4] = cs[0]
	var on: Array = cs[1]
	var cells: int = 0
	for i in planes.size():
		var mine := PackedInt32Array()
		for v in pos.size():
			if (on[v] as PackedInt32Array).has(i):
				mine.append(v)
		if mine.size() < 4:
			continue
		var centre := Vector4.ZERO
		for v in mine:
			centre += pos[v]
		centre /= float(mine.size())
		var normal: Vector4 = planes[i][0]
		var col: Color = colour.call(normal, centre)
		# Fanned from one of the cell's own corners rather than its middle: the faces through that
		# corner need no tetrahedra at all, which halves the count (a cube cell: 6, not 12).
		var apex_v: int = mine[0]
		var apex: int = out.vertex([tag, i, apex_v], pos[apex_v], col)
		var made: bool = false
		for j in planes.size():
			if j == i:
				continue
			var face := PackedInt32Array()
			for v in mine:
				if (on[v] as PackedInt32Array).has(j):
					face.append(v)
			if face.size() < 3 or face.has(apex_v):
				continue
			var ring: Array = _ordered(face, pos)
			if ring.is_empty():
				continue
			var first: int = out.vertex([tag, i, ring[0]], pos[ring[0]], col)
			for t in range(1, ring.size() - 1):
				var b: int = out.vertex([tag, i, ring[t]], pos[ring[t]], col)
				var c: int = out.vertex([tag, i, ring[t + 1]], pos[ring[t + 1]], col)
				out.tet(apex, first, b, c, normal)
			made = true
		if made:
			cells += 1
	return cells


## The face's corners in order round their middle, or [] if they do not span a face.
static func _ordered(face: PackedInt32Array, pos: Array[Vector4]) -> Array:
	var mid := Vector4.ZERO
	for v in face:
		mid += pos[v]
	mid /= float(face.size())
	var e1: Vector4 = pos[face[0]] - mid
	if e1.length() < 1e-7:
		e1 = pos[face[1]] - mid
	e1 = e1.normalized()
	var e2 := Vector4.ZERO
	for v in face:
		var r: Vector4 = pos[v] - mid
		var o: Vector4 = r - e1 * r.dot(e1)
		if o.length() > e2.length():
			e2 = o
	if e2.length() < 1e-6:
		return []
	e2 = e2.normalized()
	var keyed: Array = []
	for v in face:
		var r: Vector4 = pos[v] - mid
		keyed.append([atan2(r.dot(e2), r.dot(e1)), v])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var ring: Array = []
	for k in keyed:
		ring.append(k[1])
	return ring


# --- Recipes -----------------------------------------------------------------------------------

## The stones the reference paints (PenLayout/refs/measure/watchstone_front_stones.json: 43 stones,
## face blocks 1.0-2.4 m wide by 1.1-2.8 m tall, upright; debris 1-2 m wide, flatter), and the
## painted shape: a rounded pillow with a bulging face, not a squared block (rewatching the
## reference, 6 Oct: the first recipe's flat-faced blocks read as masonry).
##
## A PILLOW FROM PLANES. Each cut is a tangent plane of a rounded box (between an ellipsoid and a
## box, [member KINDS] squareness): six faces along the axes, eight at the corners, four on the
## vertical edges, so the stone shows about eighteen faces in a slice, big where the box is flat and
## small where it rounds over: the hierarchy of a hand-cut stone, big faces first, then the
## chamfers. In W: two end faces and the W bevels, so it rounds over in W as well.
## [kind: half size, squareness 0 round .. 1 box, how far the cuts wander].
const KINDS := {
	"block": [Vector4(0.5, 0.62, 0.42, 0.45), 0.42, 0.10],
	"slab": [Vector4(0.38, 0.75, 0.32, 0.4), 0.5, 0.09],
	"cap": [Vector4(0.62, 0.36, 0.5, 0.5), 0.45, 0.10],
	"wedge": [Vector4(0.5, 0.55, 0.45, 0.45), 0.38, 0.12],
	"round": [Vector4(0.55, 0.55, 0.5, 0.5), 0.22, 0.10],
	"ledge": [Vector4(0.55, 0.28, 0.45, 0.45), 0.35, 0.10],
	"chip": [Vector4(0.45, 0.32, 0.4, 0.4), 0.3, 0.14],
}

## The directions of the cuts in a slice: the six faces, the eight corners, the four vertical edges.
const DIRECTIONS_3D := [
	Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1),
	Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, 1), Vector3(-1, 1, -1),
	Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, -1, -1),
	Vector3(1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(-1, 0, -1),
]


## How many of each kind are baked.
const VARIANTS := 4

## The painting's stone: a warm light grey (refs/measure/watchstone_measure.json: rock 163, 153, 144
## as painted, lit and shaded together). Set so a render under the ref stage's neutral light lands
## on it (PLAN_REF_LOCK.md step 17).
const STONE := Color(0.57, 0.555, 0.535)
const MOSS := Color(0.47, 0.52, 0.16)
## The grass: olive, as painted (refs/measure: grass 116, 120, 22), the tips lighter.
const GRASS := Color(0.44, 0.47, 0.08)
const GRASS_TIP := Color(0.62, 0.63, 0.14)
const GRASS_DARK := Color(0.27, 0.31, 0.05)


## A face's colour: the stone grey, each face a shade apart ([param shade] -1..1, the mason's
## tool marks), the tops a little lighter, a moss stain on what faces straight up.
static func face_colour(normal: Vector4, shade: float) -> Color:
	var c: Color = STONE * (1.0 + 0.06 * shade)
	c = c.lerp(STONE.lightened(0.12), clampf(normal.y, 0.0, 1.0) * 0.5)
	c = c.lerp(MOSS, smoothstep(0.85, 0.98, normal.y) * 0.18)
	c.a = 1.0
	return c


## How far a rounded box of half size [param h] reaches along unit [param n]: between the
## ellipsoid's reach and the box's, by [param square].
static func reach(n: Vector4, h: Vector4, square: float) -> float:
	var ell: float = sqrt(pow(n.x * h.x, 2) + pow(n.y * h.y, 2) + pow(n.z * h.z, 2) + pow(n.w * h.w, 2))
	var box: float = absf(n.x) * h.x + absf(n.y) * h.y + absf(n.z) * h.z + absf(n.w) * h.w
	return lerpf(ell, box, square)


## The planes of a stone of [param kind], from [param seed].
static func recipe(kind: String, seed: int, light: bool = false) -> Array:
	var spec: Array = KINDS.get(kind, KINDS["block"])
	var h: Vector4 = spec[0]
	var square: float = spec[1]
	var wander: float = spec[2]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var planes: Array = []
	var dirs: Array = []
	# [param light]: the faces and the upper corners only, no W bevels (a grass mound).
	for d in DIRECTIONS_3D:
		if light and (d.y < -0.5 and absf(d.x) + absf(d.z) > 0.5 or (d.y == 0.0 and absf(d.x) > 0.5 and absf(d.z) > 0.5)):
			continue
		# A direction in the stone's own proportions (a corner of a tall stone points steeply up).
		dirs.append(Vector4(d.x / h.x, d.y / h.y, d.z / h.z, 0.0).normalized())
	dirs.append(Vector4(0, 0, 0, 1))
	dirs.append(Vector4(0, 0, 0, -1))
	# The W bevels: the top leaning into W either way, so a stone rounds over as the slice moves
	# off it (only the top: the sides' bevels cost a third of the stone and showed little).
	if not light:
		for d in [Vector3(0, 1, 0)]:
			for sw in [-1.0, 1.0]:
				dirs.append(Vector4(d.x / h.x, d.y / h.y, d.z / h.z, sw / h.w).normalized())
	for n0 in dirs:
		var n: Vector4 = n0
		var bottom: bool = n.y < -0.9
		if not bottom:
			n = (n + Vector4(rng.randf_range(-wander, wander), rng.randf_range(-wander, wander) * 0.6,
				rng.randf_range(-wander, wander), rng.randf_range(-wander, wander) * 0.6)).normalized()
		var d: float = reach(n, h, square)
		if not bottom:
			# Some faces stand proud, some are taken back: the stone's own lumps.
			d *= rng.randf_range(0.93, 1.04)
		planes.append([n, d])
	if kind == "wedge":
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var n := Vector4(side * 0.85, 0.55, 0.0, 0.0).normalized()
		planes.append([n, n.dot(Vector4(side * h.x * 0.55, h.y, 0, 0))])
	return planes


# --- Grass tufts --------------------------------------------------------------------------------

## The painting's grass: lush clumps half a metre to a metre across in every joint and along every
## ledge (refs/measure: grass is 28-31% of the front and side views; rewatching, 6 Oct: the first
## spiky tufts were too thin to read). A clump is a low mound (a flattened rounded stone in grass
## colours) with nine to twelve blades fanned round it and out of its top, leaning out 20-60
## degrees. Baked as stones are, into baked/stones/tuft_<n>.res.
## A blade's planes, upright at the origin: [param width] across, [param tall] high.
static func blade(width: float, depth: float, tall: float, wdepth: float) -> Array:
	var planes: Array = []
	for s in [-1.0, 1.0]:
		var n := Vector4(s * tall, width * 0.5, 0, 0).normalized()
		planes.append([n, n.dot(Vector4(s * width * 0.5, 0, 0, 0))])
		var m := Vector4(0, depth * 0.5, s * tall, 0).normalized()
		planes.append([m, m.dot(Vector4(0, 0, s * depth * 0.5, 0))])
		planes.append([Vector4(0, 0, 0, s), wdepth * 0.5])
	planes.append([Vector4(0, -1, 0, 0), 0.0])
	# The point, cut flat a hair below where the sides would meet, so no face is a sliver.
	planes.append([Vector4(0, 1, 0, 0), tall * 0.92])
	return planes


## [param planes] turned by [param basis] and moved by [param at].
static func moved(planes: Array, basis: Projection, at: Vector4) -> Array:
	var out: Array = []
	# Normals turn with the rotation's inverse transpose; for a pure rotation that is itself.
	for p in planes:
		var n: Vector4 = (basis * (p[0] as Vector4)).normalized()
		out.append([n, float(p[1]) + n.dot(at)])
	return out


## Adds a tuft to [param out]: [param seed] decides its blades.
static func bake_tuft(out: TerrainBake.Builder, seed: int, tag: int = 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# The mound under the blades: what makes it read as a clump from afar.
	var mound: Array = recipe("round", seed + 5, true)
	var mound_planes: Array = []
	var mx: float = rng.randf_range(0.5, 0.62)
	var my: float = rng.randf_range(0.26, 0.34)
	for p in mound:
		# A plane under a scaling: the normal by the inverse transpose, the distance kept.
		var n: Vector4 = Vector4((p[0] as Vector4).x / mx, (p[0] as Vector4).y / my, (p[0] as Vector4).z / mx, (p[0] as Vector4).w / mx)
		var l: float = n.length()
		mound_planes.append([n / l, float(p[1]) / l + (n / l).dot(Vector4(0, my * 0.35, 0, 0))])
	bake_into(out, mound_planes, func(normal: Vector4, centre: Vector4) -> Color: return GRASS_DARK.lerp(GRASS, 0.35 + 0.4 * clampf(normal.y, 0.0, 1.0)), tag * 100 + 99)
	var blades: int = rng.randi_range(4, 6)
	var spin: float = rng.randf_range(0.0, TAU)
	for i in blades:
		var tall: float = rng.randf_range(0.28, 0.48)
		var lean: float = rng.randf_range(0.6, 1.2)
		var turn: float = spin + TAU * float(i) / float(blades) + rng.randf_range(-0.3, 0.3)
		var wlean: float = rng.randf_range(-0.5, 0.5)
		var basis: Projection = Basis4D.from_zx(turn) * Basis4D.from_xy(-lean) * Basis4D.from_wy(wlean)
		# From the mound's shoulder, so the blades break its outline rather than stand on its top.
		var ra: float = turn + rng.randf_range(-0.2, 0.2)
		var root := Vector4(cos(ra) * mx * 0.55, my * 0.4, sin(ra) * mx * 0.55, rng.randf_range(-0.12, 0.12))
		var planes: Array = moved(blade(rng.randf_range(0.09, 0.14), 0.06, tall, rng.randf_range(0.07, 0.11)), basis, root)
		var colour := func(normal: Vector4, centre: Vector4) -> Color:
			var c: Color = GRASS_DARK.lerp(GRASS, clampf(centre.y / 0.25, 0.0, 1.0))
			c = c.lerp(GRASS_TIP, clampf((centre.y - 0.2) / 0.25, 0.0, 1.0) * 0.8)
			return c.lightened(0.08 * clampf(normal.y, 0.0, 1.0))
		bake_into(out, planes, colour, tag * 100 + i)
