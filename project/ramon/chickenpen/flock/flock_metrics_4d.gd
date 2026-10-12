extends RefCounted

## The ruler for the murmuration: the numbers field studies measure on real starling
## flocks, computed on ours, so tuning is a comparison against data rather than taste.
## Preloaded by path, no class_name, like the rest of the pen's scripts.
##
## The targets, and where they come from:
##   order        |mean heading|, 1 = all one way. STARFLAG flocks cruise at 0.96-0.99
##                (Cavagna et al. 2010, "Scale-free correlations in starling flocks").
##   nearest      mean nearest-neighbour distance: 0.7-1.5 m, starlings 0.4 m across
##                (Ballerini et al. 2008, "Empirical investigation of starling flocks").
##   shape        thickness : width : length, from the three principal axes: 1 : 2.8 : 5.6
##                on average, the thin axis close to vertical - flocks are flat and level.
##   edge/middle  nearest-neighbour distance at the border over the middle: below 1, the
##                border is DENSER (the same paper; Hemelrijk & Hildenbrandt reproduce it).
##   milling      how much the flock circles about its own centre: 0 when it travels,
##                towards 1 for a torus. Murmurations turn but should not mill for long.
##   wave speed   how fast a turn started at one edge crosses the flock. Real turns
##                travel at 20-40 m/s without fading (Attanasi et al. 2014); agitation
##                waves at ~13 m/s (Hemelrijk et al. 2015).
##   in slice     the share of birds the camera's slice cuts through - the 4D number.


## |mean heading|.
static func order(headings: PackedVector4Array) -> float:
	var sum := Vector4.ZERO
	for h in headings:
		sum += h
	return sum.length() / maxf(float(headings.size()), 1.0)


static func centre(positions: PackedVector4Array) -> Vector4:
	var sum := Vector4.ZERO
	for p in positions:
		sum += p
	return sum / maxf(float(positions.size()), 1.0)


## How much the flock turns about its own centre in the horizontal (x, z) plane - the
## normalised angular momentum. In 4D angular momentum is a bivector; the milling a
## player sees is the part in the ground plane.
static func milling(positions: PackedVector4Array, headings: PackedVector4Array) -> float:
	var c := centre(positions)
	var sum: float = 0.0
	var n: int = 0
	for i in positions.size():
		var dx: float = positions[i].x - c.x
		var dz: float = positions[i].z - c.z
		var d: float = sqrt(dx * dx + dz * dz)
		var hx: float = headings[i].x
		var hz: float = headings[i].z
		var hl: float = sqrt(hx * hx + hz * hz)
		if d < 0.001 or hl < 0.001:
			continue
		sum += (dx * hz - dz * hx) / (d * hl)
		n += 1
	return absf(sum) / maxf(float(n), 1.0)


## Nearest-neighbour distance of each bird in [param sample] (all birds if empty), by
## brute force - this is for tests, not for frames.
static func nearest_distances(positions: PackedVector4Array, sample: PackedInt32Array = PackedInt32Array()) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var ids: PackedInt32Array = sample
	if ids.is_empty():
		ids.resize(positions.size())
		for i in positions.size():
			ids[i] = i
	for i in ids:
		var best: float = INF
		var p: Vector4 = positions[i]
		for j in positions.size():
			if j == i:
				continue
			var dd: float = (positions[j] - p).length_squared()
			if dd < best:
				best = dd
		out.append(sqrt(best))
	return out


## The share of birds in the biggest group, a group being birds chained together by gaps
## under [param link] metres. A flock that has split still averages to sensible numbers,
## so every other metric is only worth reading when this is close to 1.
static func largest_group(positions: PackedVector4Array, link: float = 3.0) -> float:
	var n: int = positions.size()
	if n == 0:
		return 0.0
	var parent := PackedInt32Array()
	parent.resize(n)
	for i in n:
		parent[i] = i
	var l2: float = link * link
	for i in n:
		var p: Vector4 = positions[i]
		for j in range(i + 1, n):
			if (positions[j] - p).length_squared() < l2:
				var a: int = i
				while parent[a] != a:
					a = parent[a]
				var b: int = j
				while parent[b] != b:
					b = parent[b]
				if a != b:
					parent[b] = a
	var sizes: Dictionary = {}
	var best: int = 0
	for i in n:
		var a: int = i
		while parent[a] != a:
			a = parent[a]
		sizes[a] = int(sizes.get(a, 0)) + 1
		best = maxi(best, int(sizes[a]))
	return float(best) / float(n)


static func mean(values: PackedFloat32Array) -> float:
	var s: float = 0.0
	for v in values:
		s += v
	return s / maxf(float(values.size()), 1.0)


## The principal axes of the flock's (x, y, z) spread, longest last, as standard
## deviations along each - plus how vertical the thinnest axis is (1 = straight up) and the
## spread along W on its own. Returns [thin, mid, long, verticality, w_spread].
static func shape(positions: PackedVector4Array) -> PackedFloat32Array:
	var c := centre(positions)
	var xx: float = 0.0
	var yy: float = 0.0
	var zz: float = 0.0
	var xy: float = 0.0
	var xz: float = 0.0
	var yz: float = 0.0
	var ww: float = 0.0
	for p in positions:
		var d: Vector4 = p - c
		xx += d.x * d.x
		yy += d.y * d.y
		zz += d.z * d.z
		xy += d.x * d.y
		xz += d.x * d.z
		yz += d.y * d.z
		ww += d.w * d.w
	var n: float = maxf(float(positions.size()), 1.0)
	var m := Basis(Vector3(xx, xy, xz) / n, Vector3(xy, yy, yz) / n, Vector3(xz, yz, zz) / n)
	var values: Array = _symmetric_eigen(m)
	var out := PackedFloat32Array()
	for k in 3:
		out.append(sqrt(maxf(float(values[k][0]), 0.0)))
	var thin_axis: Vector3 = values[0][1]
	out.append(absf(thin_axis.normalized().y))
	out.append(sqrt(ww / n))
	return out


## Eigenvalues and eigenvectors of a symmetric 3x3, smallest first, by Jacobi sweeps.
static func _symmetric_eigen(m: Basis) -> Array:
	var a: Array = [[m.x.x, m.y.x, m.z.x], [m.x.y, m.y.y, m.z.y], [m.x.z, m.y.z, m.z.z]]
	var v: Array = [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
	for _sweep in 24:
		var off: float = absf(a[0][1]) + absf(a[0][2]) + absf(a[1][2])
		if off < 1e-12:
			break
		for pair in [[0, 1], [0, 2], [1, 2]]:
			var p: int = pair[0]
			var q: int = pair[1]
			if absf(a[p][q]) < 1e-15:
				continue
			var theta: float = (float(a[q][q]) - float(a[p][p])) / (2.0 * float(a[p][q]))
			var t: float = signf(theta) / (absf(theta) + sqrt(theta * theta + 1.0))
			if theta == 0.0:
				t = 1.0
			var c: float = 1.0 / sqrt(t * t + 1.0)
			var s: float = t * c
			for k in 3:
				var akp: float = a[k][p]
				var akq: float = a[k][q]
				a[k][p] = c * akp - s * akq
				a[k][q] = s * akp + c * akq
			for k in 3:
				var apk: float = a[p][k]
				var aqk: float = a[q][k]
				a[p][k] = c * apk - s * aqk
				a[q][k] = s * apk + c * aqk
			for k in 3:
				var vkp: float = v[k][p]
				var vkq: float = v[k][q]
				v[k][p] = c * vkp - s * vkq
				v[k][q] = s * vkp + c * vkq
	var pairs: Array = []
	for k in 3:
		pairs.append([float(a[k][k]), Vector3(v[0][k], v[1][k], v[2][k])])
	pairs.sort_custom(func(l: Array, r: Array) -> bool: return l[0] < r[0])
	return pairs


## Share of birds within [param depth] of the camera's slice, measured along the camera's
## own W axis - not raw w, which is wrong once the slice is turned (chicken_pen_learnings).
static func in_slice(positions: PackedVector4Array, camera: Camera4D, depth: float) -> float:
	if positions.is_empty() or camera == null:
		return 0.0
	var normal: Vector4 = (camera.global_basis * Vector4(0, 0, 0, 1)).normalized()
	var origin: Vector4 = camera.global_position
	var hit: int = 0
	for p in positions:
		if absf((p - origin).dot(normal)) < depth:
			hit += 1
	return float(hit) / float(positions.size())


## Border birds versus the rest, by how lopsided their neighbours are (the centrality
## Hemelrijk uses): returns [mean nearest distance at the border, in the middle].
static func edge_and_middle(positions: PackedVector4Array, centrality: PackedFloat32Array) -> Vector2:
	var edge := PackedInt32Array()
	var middle := PackedInt32Array()
	for i in positions.size():
		if centrality[i] > 0.55:
			edge.append(i)
		elif centrality[i] < 0.25:
			middle.append(i)
	if edge.size() > 80:
		edge = edge.slice(0, 80)
	if middle.size() > 80:
		middle = middle.slice(0, 80)
	return Vector2(mean(nearest_distances(positions, edge)), mean(nearest_distances(positions, middle)))
