extends RefCounted

## WATER LAB: the koi's shape, built once in code, one body length long (snout at z = +0.45, tail tip
## at z = -0.55; +Z ahead, +X right, +Y up). The tank's koi are drawn from it by life/koi.gdshader,
## which bends it with a travelling wave every frame on the GPU, and the pedestal koi
## (room/ex_koi_4d.gd) is lofted in 4D from the same profile (PROFILE below).
##
## WHAT EACH VERTEX CARRIES FOR THE SHADER:
##   UV.x   s, the place along the fish: 0 at the snout, 0.8 where the tail fin starts, 1 at its tips.
##          The wave is a function of s.
##   UV.y   the part: 0 body, 1 tail fin, 2 dorsal fin, 3 pectoral, 4 pelvic, 5 anal, 6 eye, 7 barbel.
##   UV2.x  across a fin, 0 at its root to 1 at its edge (how much it flutters); on the body, the
##          vertex's height between belly and back, 0 to 1 (the pattern's dorsal mask).
##   UV2.y  the side for paired parts (-1 left, +1 right; 0 for unpaired), or across a fin.
##   CUSTOM0 x: s of the point a rigid part hangs from (its root), so a fin moves with the body there
##          instead of being bent by the wave across it; y: 1 for rigid parts, 0 for parts that bend.
##          (Not COLOR: a multimesh's instance colour is multiplied into it, and the koi's instance
##          colour carries its variety.)
##
## THE PROFILE is the koi's from above and from the side (photographs of show koi: a blunt round
## head, the back highest a third of the way along, a deep body tapering to a narrow peduncle). The
## half heights above and below the midline differ: the back is fuller than the belly.
##
## NO class_name (engine_gotchas.md).

## s, half height above the midline, half height below it, half width. Body lengths.
## (9 Oct, second pass: a fifth deeper and the back arched higher; the first read as a torpedo.)
const PROFILE := [
	[0.000, 0.000, 0.000, 0.000],
	[0.012, 0.026, 0.021, 0.016],
	[0.035, 0.047, 0.037, 0.031],
	[0.070, 0.072, 0.054, 0.048],
	[0.120, 0.099, 0.071, 0.067],
	[0.200, 0.124, 0.088, 0.077],
	[0.300, 0.142, 0.103, 0.083],
	[0.400, 0.144, 0.107, 0.082],
	[0.500, 0.131, 0.099, 0.074],
	[0.600, 0.108, 0.082, 0.060],
	[0.700, 0.077, 0.060, 0.043],
	[0.770, 0.053, 0.043, 0.027],
	[0.800, 0.048, 0.040, 0.022],
]
const SNOUT_Z := 0.45
const BODY_END := 0.8
## The midline drops a little at the snout: a koi's mouth is low on its face.
const MOUTH_DROP := 0.012
const RINGS := 46
const SIDES := 28
## The back's fullness: a superellipse exponent (2 is an ellipse).
const ROUNDNESS := 2.5

const BODY := 0
const CAUDAL := 1
const DORSAL := 2
const PECTORAL := 3
const PELVIC := 4
const ANAL := 5
const EYE := 6
const BARBEL := 7

## Where the eyes sit (s, height above the midline) and their radius; the shader colours them.
const EYE_S := 0.072
const EYE_UP := 0.020
const EYE_R := 0.0125
## The pectoral fins' root (s, height, half width) and the pelvic fins'.
const PECTORAL_ROOT := Vector3(0.205, -0.050, 0.060)
const PELVIC_ROOT := Vector3(0.455, -0.082, 0.032)


static func z_of(s: float) -> float:
	return SNOUT_Z - s


## The profile at `s`: [top, bottom, half width], a smooth curve through PROFILE.
static func at(s: float) -> Vector3:
	s = clampf(s, 0.0, BODY_END)
	var n: int = PROFILE.size()
	var i: int = 0
	while i < n - 2 and s > float(PROFILE[i + 1][0]):
		i += 1
	var out := Vector3.ZERO
	for c in 3:
		out[c] = _hermite(i, c + 1, s)
	return out


static func _hermite(i: int, c: int, s: float) -> float:
	var s0: float = PROFILE[i][0]
	var s1: float = PROFILE[i + 1][0]
	var p0: float = PROFILE[i][c]
	var p1: float = PROFILE[i + 1][c]
	var m0: float = _slope(i, c)
	var m1: float = _slope(i + 1, c)
	var h: float = s1 - s0
	var t: float = clampf((s - s0) / maxf(h, 0.00001), 0.0, 1.0)
	var t2: float = t * t
	var t3: float = t2 * t
	var v: float = (2.0 * t3 - 3.0 * t2 + 1.0) * p0 + (t3 - 2.0 * t2 + t) * h * m0 + (-2.0 * t3 + 3.0 * t2) * p1 + (t3 - t2) * h * m1
	return maxf(v, 0.0)


static func _slope(i: int, c: int) -> float:
	var n: int = PROFILE.size()
	if i == 0:
		# The snout: round, so the profile leaves it steeply.
		return (float(PROFILE[1][c]) - float(PROFILE[0][c])) / (float(PROFILE[1][0]) - float(PROFILE[0][0])) * 1.6
	if i == n - 1:
		return (float(PROFILE[n - 1][c]) - float(PROFILE[n - 2][c])) / (float(PROFILE[n - 1][0]) - float(PROFILE[n - 2][0]))
	return (float(PROFILE[i + 1][c]) - float(PROFILE[i - 1][c])) / (float(PROFILE[i + 1][0]) - float(PROFILE[i - 1][0]))


static func midline(s: float) -> float:
	return -MOUTH_DROP * (1.0 - smoothstep(0.0, 0.12, s))


## A point on the body's skin at `s`, angle `a` round it (0 the right side, PI/2 the back).
static func skin(s: float, a: float) -> Vector3:
	var p: Vector3 = at(s)
	var c: float = cos(a)
	var sn: float = sin(a)
	var e: float = 2.0 / ROUNDNESS
	var x: float = signf(c) * pow(absf(c), e) * p.z
	var y: float = signf(sn) * pow(absf(sn), e) * (p.x if sn > 0.0 else p.y)
	return Vector3(x, midline(s) + y, z_of(s))


## `detail` 1 is the tank's koi (46 rings of 28 sides); 2 the showcase's big koi (twice as fine, its
## fins too), seen from a metre away at four times life size.
static func build(detail: int = 1) -> ArrayMesh:
	var b := Builder.new()
	b.fine = maxi(detail, 1)
	_body(b)
	_caudal(b)
	_dorsal(b)
	_anal(b)
	for side in [-1.0, 1.0]:
		_pectoral(b, side)
		_pelvic(b, side)
		_eye(b, side)
		_barbels(b, side)
	return b.commit()


## The body: rings from the snout to the peduncle, closer together at both ends, a single tip
## vertex at the mouth, the peduncle's end capped (the tail fin hides it).
static func _body(b: Builder) -> void:
	var ring_s: Array = []
	var rings: int = RINGS * b.fine
	var sides: int = SIDES * b.fine
	for k in rings:
		var t: float = float(k + 1) / float(rings)
		ring_s.append(BODY_END * (0.5 - 0.5 * cos(PI * pow(t, 0.92))))
	var tip: int = b.vertex(Vector3(0.0, midline(0.0), z_of(0.0)), Vector3(0, 0, 1), Vector2(0.0, BODY), Vector2(0.5, 0.0), 0.0, 0.0)
	var first: int = -1
	for k in ring_s.size():
		var s: float = ring_s[k]
		var prof: Vector3 = at(s)
		for j in sides:
			var a: float = TAU * float(j) / float(sides)
			var p: Vector3 = skin(s, a)
			var h: float = clampf((p.y - midline(s) + prof.y) / maxf(prof.x + prof.y, 0.0001), 0.0, 1.0)
			var idx: int = b.vertex(p, Vector3.ZERO, Vector2(s, BODY), Vector2(h, 0.0), s, 0.0)
			if k == 0 and j == 0:
				first = idx
	for j in sides:
		var j1: int = (j + 1) % sides
		b.tri(tip, first + j1, first + j)
	for k in ring_s.size() - 1:
		var r0: int = first + k * sides
		var r1: int = r0 + sides
		for j in sides:
			var j1: int = (j + 1) % sides
			b.tri(r0 + j, r0 + j1, r1 + j1)
			b.tri(r0 + j, r1 + j1, r1 + j)
	var last: int = first + (ring_s.size() - 1) * sides
	var end: int = b.vertex(Vector3(0.0, midline(BODY_END), z_of(BODY_END) - 0.004), Vector3(0, 0, -1), Vector2(BODY_END, BODY), Vector2(0.5, 0.0), BODY_END, 0.0)
	for j in sides:
		var j1: int = (j + 1) % sides
		b.tri(end, last + j, last + j1)
	b.smooth_normals_from(first - 1)


## The tail fin: a forked fan from the peduncle, its two lobes reaching s = 1.
static func _caudal(b: Builder) -> void:
	var root_s: float = BODY_END - 0.012
	var prof: Vector3 = at(root_s)
	var edge: Array = [Vector2(1.0, -0.128), Vector2(0.975, -0.095), Vector2(0.945, -0.055), Vector2(0.912, -0.018), Vector2(0.902, 0.004),
		Vector2(0.914, 0.026), Vector2(0.948, 0.063), Vector2(0.978, 0.103), Vector2(1.0, 0.138)]
	var lo: float = -prof.y * 0.85 + midline(root_s)
	var hi: float = prof.x * 0.85 + midline(root_s)
	var rows: int = 7 * b.fine
	var cols: int = 24 * b.fine
	var grid: Array = []
	for i in rows:
		var u: float = float(i) / float(rows - 1)
		var row: Array = []
		for j in cols:
			var v: float = float(j) / float(cols - 1)
			var e: Vector2 = _along(edge, v)
			var r := Vector2(root_s, lerpf(lo, hi, v))
			# The lobes' edges bow out a little, the way fin rays fan.
			var bow: float = sin(PI * u) * 0.012 * (1.0 if v > 0.5 else -1.0) * absf(v - 0.5) * 2.0
			var p := Vector2(lerpf(r.x, e.x, u), lerpf(r.y, e.y, u) + bow)
			row.append(b.vertex(Vector3(0.0, p.y, z_of(p.x)), Vector3(1, 0, 0), Vector2(p.x, CAUDAL), Vector2(u, v), root_s, 0.0))
		grid.append(row)
	b.sheet(grid)


## A point along a polyline by its share of the points (not of length: the edge is sampled evenly
## enough for that).
static func _along(points: Array, v: float) -> Vector2:
	var f: float = v * float(points.size() - 1)
	var i: int = clampi(int(floor(f)), 0, points.size() - 2)
	return (points[i] as Vector2).lerp(points[i + 1], f - float(i))


## The dorsal fin: long and low, from a third of the way back almost to the tail, its first rays the
## tallest, raked back.
static func _dorsal(b: Builder) -> void:
	_median_fin(b, DORSAL, 0.365, 0.705, 1.0, 0.088, 0.03)


## The anal fin: short, under the tail's root.
static func _anal(b: Builder) -> void:
	_median_fin(b, ANAL, 0.655, 0.745, -1.0, 0.058, 0.022)


static func _median_fin(b: Builder, part: int, s0: float, s1: float, up: float, tall: float, rake: float) -> void:
	var rows: int = 6 * b.fine
	var cols: int = 16 * b.fine
	var grid: Array = []
	for i in rows:
		var u: float = float(i) / float(rows - 1)
		var row: Array = []
		for j in cols:
			var t: float = float(j) / float(cols - 1)
			var sb: float = lerpf(s0, s1, t)
			var prof: Vector3 = at(sb)
			var base_y: float = midline(sb) + (prof.x - 0.006 if up > 0.0 else -(prof.y - 0.006))
			# Tallest at the front, falling away behind; the front edge rounds over.
			var h: float = tall * (1.0 - 0.62 * t) * sqrt(clampf(t * 6.0 + 0.25, 0.0, 1.0))
			var s: float = sb + u * rake * (1.0 - 0.4 * t)
			row.append(b.vertex(Vector3(0.0, base_y + up * u * h, z_of(s)), Vector3(1, 0, 0), Vector2(s, part), Vector2(u, t), sb, 0.0))
		grid.append(row)
	b.sheet(grid)


## A pectoral fin: a rounded paddle low behind the gill, swept back, out and down. Rigid: it hangs
## from its root and the shader turns it there (sculling, spreading to brake).
static func _pectoral(b: Builder, side: float) -> void:
	var root := Vector3(side * PECTORAL_ROOT.z, PECTORAL_ROOT.y + midline(PECTORAL_ROOT.x), z_of(PECTORAL_ROOT.x))
	var d := Vector3(side * 0.62, -0.30, -0.72).normalized()
	var n := Vector3(side * 0.15, 1.0, 0.25).normalized()
	_paddle(b, PECTORAL, root, d, n, 0.135, 0.078, PECTORAL_ROOT.x, side)


static func _pelvic(b: Builder, side: float) -> void:
	var root := Vector3(side * PELVIC_ROOT.z, PELVIC_ROOT.y, z_of(PELVIC_ROOT.x))
	var d := Vector3(side * 0.45, -0.42, -0.79).normalized()
	var n := Vector3(side * 0.2, 1.0, 0.3).normalized()
	_paddle(b, PELVIC, root, d, n, 0.082, 0.045, PELVIC_ROOT.x, side)


static func _paddle(b: Builder, part: int, root: Vector3, d: Vector3, n: Vector3, length: float, width: float, root_s: float, side: float) -> void:
	var e: Vector3 = n.cross(d).normalized()
	var rows: int = 6 * b.fine
	var cols: int = 7 * b.fine
	var grid: Array = []
	for i in rows:
		var u: float = float(i) / float(rows - 1)
		var row: Array = []
		# Narrow at the root, broad and round at the end.
		var w: float = width * (0.35 + 0.65 * sin(PI * (0.18 + 0.62 * u)))
		var reach: float = length * u
		for j in cols:
			var v: float = float(j) / float(cols - 1) - 0.5
			# The rounded tip: the outer edge's middle reaches furthest.
			var round_off: float = length * 0.18 * (1.0 - cos(PI * v)) * u * u
			var p: Vector3 = root + d * (reach - round_off) + e * (v * w)
			row.append(b.vertex(p, n, Vector2(root_s, part), Vector2(u, side), root_s, 1.0))
		grid.append(row)
	b.sheet(grid)


static func _eye(b: Builder, side: float) -> void:
	var prof: Vector3 = at(EYE_S)
	var centre := Vector3(side * (prof.z * 0.80), midline(EYE_S) + EYE_UP, z_of(EYE_S))
	var lat: int = 8 * b.fine
	var lon: int = 12 * b.fine
	var grid: Array = []
	for i in lat + 1:
		var th: float = PI * float(i) / float(lat)
		var row: Array = []
		for j in lon + 1:
			var ph: float = TAU * float(j) / float(lon)
			var dir := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			# Turned so the sphere's pole (where the pupil is drawn) looks out sideways.
			var look := Vector3(side * dir.y, dir.x, dir.z)
			row.append(b.vertex(centre + look * EYE_R, look, Vector2(EYE_S, EYE), Vector2(dir.y, side), EYE_S, 1.0))
		grid.append(row)
	b.sheet(grid, true)


## Two pairs of barbels at the corners of the mouth, the upper pair longer: thin tapering strips.
static func _barbels(b: Builder, side: float) -> void:
	for k in 2:
		var root := Vector3(side * (0.016 + 0.006 * float(k)), midline(0.012) - 0.010 - 0.004 * float(k), z_of(0.012 + 0.008 * float(k)))
		var d := Vector3(side * 0.35, -0.55, 0.45 - 0.25 * float(k)).normalized()
		var length: float = 0.036 if k == 0 else 0.022
		var e := Vector3(1.0, 0.0, 0.0).cross(d).normalized()
		var grid: Array = []
		for i in 4:
			var u: float = float(i) / 3.0
			var w: float = 0.0035 * (1.0 - 0.8 * u)
			var row: Array = []
			for j in 2:
				var v: float = float(j) - 0.5
				row.append(b.vertex(root + d * (length * u) + e * (v * w), Vector3(0, 0, 1), Vector2(0.012, BARBEL), Vector2(u, side), 0.012, 1.0))
			grid.append(row)
		b.sheet(grid)


## Collects vertices and triangles; sheets are grids of vertex indices.
class Builder:
	var fine: int = 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colours := PackedColorArray()
	var custom := PackedFloat32Array()
	var indices := PackedInt32Array()

	func vertex(p: Vector3, n: Vector3, uv: Vector2, uv2: Vector2, root_s: float, rigid: float) -> int:
		verts.append(p)
		normals.append(n)
		uvs.append(uv)
		uv2s.append(uv2)
		colours.append(Color.WHITE)
		custom.append_array([root_s, rigid, 0.0, 0.0])
		return verts.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		indices.append_array([a, b, c])

	## A grid of vertex indices as two triangles a cell. With `own_normals` the vertices keep the
	## normals they were given (the eyes); otherwise the sheet's normals are worked out from it.
	func sheet(grid: Array, own_normals: bool = false) -> void:
		var start: int = indices.size()
		for i in grid.size() - 1:
			var r0: Array = grid[i]
			var r1: Array = grid[i + 1]
			for j in r0.size() - 1:
				tri(r0[j], r0[j + 1], r1[j + 1])
				tri(r0[j], r1[j + 1], r1[j])
		if not own_normals:
			_normals_for(start)

	## Every vertex used by triangles from `start` on gets the average of their face normals.
	func _normals_for(start: int) -> void:
		var acc: Dictionary = {}
		for t in range(start, indices.size(), 3):
			var a: int = indices[t]
			var b: int = indices[t + 1]
			var c: int = indices[t + 2]
			var fn: Vector3 = (verts[b] - verts[a]).cross(verts[c] - verts[a])
			for k in [a, b, c]:
				acc[k] = (acc.get(k, Vector3.ZERO) as Vector3) + fn
		for k in acc:
			var v: Vector3 = acc[k]
			normals[k] = v.normalized() if v.length() > 0.0 else Vector3.UP

	## The body's normals, smoothed over every triangle that uses its vertices (from index `from`),
	## pointing out of the body.
	func smooth_normals_from(from: int) -> void:
		var acc: Dictionary = {}
		for t in range(0, indices.size(), 3):
			var a: int = indices[t]
			if a < from:
				continue
			var b: int = indices[t + 1]
			var c: int = indices[t + 2]
			var fn: Vector3 = (verts[b] - verts[a]).cross(verts[c] - verts[a])
			for k in [a, b, c]:
				acc[k] = (acc.get(k, Vector3.ZERO) as Vector3) + fn
		for k in acc:
			var v: Vector3 = (acc[k] as Vector3).normalized()
			# Out of the body: away from the midline at this point.
			var s: float = uvs[k].x
			var out: Vector3 = verts[k] - Vector3(0.0, KoiMid.mid(s), verts[k].z)
			if s <= 0.0005:
				out = Vector3(0, 0, 1)
			elif s >= 0.7995 and absf(verts[k].x) < 0.0001 and normals[k].z < -0.5:
				out = Vector3(0, 0, -1)
			if v.dot(out) < 0.0:
				v = -v
			normals[k] = v

	func commit() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_CUSTOM0] = custom
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.custom_aabb = AABB(Vector3(-5000, -5000, -5000), Vector3(10000, 10000, 10000))
		return mesh


## The midline for the Builder (an inner class cannot call the outer script's statics by name).
class KoiMid:
	static func mid(s: float) -> float:
		return -0.012 * (1.0 - smoothstep(0.0, 0.12, s))
