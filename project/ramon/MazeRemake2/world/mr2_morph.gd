extends RefCounted
## MORPH BOXES: the one building block of the Annex.
##
## A morph box is a 4D solid whose cut at any W is an ordinary 3D box, and that box changes smoothly
## along W. It is given as KEYS, each a W and the 3D box at that W ([w, min: Vector3, max: Vector3]),
## in ascending W. Between two keys the box is interpolated linearly (every corner moves in a straight
## line through W), and outside the first and last key the solid does not exist. So:
##   - a wall that stands from W a to W b and sinks into the floor over the last 0.5 m at each end:
##       [a - 0.5, top at the floor], [a, full height], [b, full height], [b + 0.5, top at the floor]
##   - a door leaf that slides aside as you move ana:
##       [lo, closed], [w_open_start, closed], [w_open_end, parked in the jamb], [hi, parked]
## Every segment between two keys is a real 4D polytope (the convex hull of the two 3D boxes): the
## engine's own box mesh with its 16 corners moved, eight on the box at the lower W and eight on the
## box at the upper W. Its cross-section is exactly the interpolated box, so what you see as you move
## through W is the true slice, not an effect.
##
## THE COLLIDER IS THE SAME SHAPE IN STEPS (the engine's physics is axis-aligned boxes only): a
## segment whose box does not change is one BoxShape4D across its whole W span; a changing one is cut
## into steps of STEP metres of W, each the union of the boxes at its two ends, so a collider is never
## smaller than what you see (at most one step's travel larger).
##
## NO class_name (engine_gotchas.md): preload it.

## Metres of W per collider step on a changing segment.
const STEP := 0.1
## Never quite flat: a box this thin is still a valid solid (no zero-volume tetrahedra).
const MIN_SIZE := 0.01
## A collider step lower or thinner than this is left out: nothing to bump into.
const MIN_COLLIDE := 0.05


## One key: the 3D box from `lo` to `hi` (corners) at W `w`.
static func key(w: float, lo: Vector3, hi: Vector3) -> Array:
	return [w, lo, hi]


## The keys of a box that stands unchanged from W `w0` to `w1`, rising out of the floor over `taper`
## metres of W before `w0` and sinking back over `taper` after `w1` (0: it simply starts and stops).
## `floor_y` is where it sinks to (its top goes just under it).
static func standing(lo: Vector3, hi: Vector3, w0: float, w1: float, taper: float = 0.0, floor_y: float = 0.0) -> Array:
	if taper <= 0.0:
		return [key(w0, lo, hi), key(w1, lo, hi)]
	var sunk_hi := Vector3(hi.x, floor_y - 0.02, hi.z)
	var sunk_lo := Vector3(lo.x, floor_y - 0.02 - MIN_SIZE * 2.0, lo.z)
	return [key(w0 - taper, sunk_lo, sunk_hi), key(w0, lo, hi), key(w1, lo, hi), key(w1 + taper, sunk_lo, sunk_hi)]


## The 3D box of `keys` at W `w`, as [lo, hi], or [] where the solid does not exist.
static func box_at(keys: Array, w: float) -> Array:
	if keys.size() < 2 or w < float(keys[0][0]) or w > float(keys[keys.size() - 1][0]):
		return []
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		var wa: float = float(a[0])
		var wb: float = float(b[0])
		if w >= wa and w <= wb:
			var t: float = 0.0 if wb - wa < 0.00001 else (w - wa) / (wb - wa)
			return [(a[1] as Vector3).lerp(b[1], t), (a[2] as Vector3).lerp(b[2], t)]
	return []


## The mesh of `keys`, in the coordinates the keys are given in (a level builds in world space).
static func mesh(keys: Array) -> ArrayTetraMesh4D:
	var out: ArrayTetraMesh4D = null
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if float(b[0]) - float(a[0]) < 0.0005:
			continue
		var seg: ArrayTetraMesh4D = segment(float(a[0]), a[1], a[2], float(b[0]), b[1], b[2])
		if out == null:
			out = seg
		else:
			out.merge_with(seg)
	return out


## One segment: the solid joining box (`alo`, `ahi`) at W `wa` to box (`blo`, `bhi`) at W `wb`.
static func segment(wa: float, alo: Vector3, ahi: Vector3, wb: float, blo: Vector3, bhi: Vector3) -> ArrayTetraMesh4D:
	var unit := BoxTetraMesh4D.new()
	unit.size = Vector4.ONE
	var m: ArrayTetraMesh4D = unit.to_array_tetra_mesh()
	var a := _safe(alo, ahi)
	var b := _safe(blo, bhi)
	var verts: PackedVector4Array = m.get_vertex_positions()
	for i in verts.size():
		var v: Vector4 = verts[i]
		var low: bool = v.w < 0.0
		var lo: Vector3 = a[0] if low else b[0]
		var hi: Vector3 = a[1] if low else b[1]
		verts[i] = Vector4(lo.x if v.x < 0.0 else hi.x, lo.y if v.y < 0.0 else hi.y, lo.z if v.z < 0.0 else hi.z, wa if low else wb)
	m.set_vertex_positions(verts)
	m.calculate_boundary_normals()
	return m


## The collider boxes of `keys`: an Array of [centre: Vector4, size: Vector4].
static func collider_boxes(keys: Array) -> Array:
	var out: Array = []
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		var wa: float = float(a[0])
		var wb: float = float(b[0])
		if wb - wa < 0.0005:
			continue
		var same: bool = (a[1] as Vector3).is_equal_approx(b[1]) and (a[2] as Vector3).is_equal_approx(b[2])
		var steps: int = 1 if same else clampi(int(ceil((wb - wa) / STEP)), 1, 400)
		for k in steps:
			var w0: float = lerpf(wa, wb, float(k) / steps)
			var w1: float = lerpf(wa, wb, float(k + 1) / steps)
			var t0: float = float(k) / steps
			var t1: float = float(k + 1) / steps
			var lo0: Vector3 = (a[1] as Vector3).lerp(b[1], t0)
			var hi0: Vector3 = (a[2] as Vector3).lerp(b[2], t0)
			var lo1: Vector3 = (a[1] as Vector3).lerp(b[1], t1)
			var hi1: Vector3 = (a[2] as Vector3).lerp(b[2], t1)
			var lo: Vector3 = lo0.min(lo1)
			var hi: Vector3 = hi0.max(hi1)
			var size: Vector3 = hi - lo
			if size.x < MIN_COLLIDE or size.y < MIN_COLLIDE or size.z < MIN_COLLIDE:
				continue
			# A sinking wall's last sliver at the floor is never a thing to bump into (floors themselves
			# never change along W, so they are kept).
			if not same and hi.y < 0.06:
				continue
			out.append([Vector4((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, (lo.z + hi.z) * 0.5, (w0 + w1) * 0.5),
				Vector4(size.x, size.y, size.z, w1 - w0)])
	return _merged(out)


## Adjacent steps with the same 3D box become one collider (fewer shapes for the physics to test).
static func _merged(boxes: Array) -> Array:
	if boxes.size() < 2:
		return boxes
	var out: Array = [boxes[0].duplicate()]
	for i in range(1, boxes.size()):
		var prev: Array = out[out.size() - 1]
		var cur: Array = boxes[i]
		var pc: Vector4 = prev[0]
		var ps: Vector4 = prev[1]
		var cc: Vector4 = cur[0]
		var cs: Vector4 = cur[1]
		var same3: bool = absf(pc.x - cc.x) < 0.0005 and absf(pc.y - cc.y) < 0.0005 and absf(pc.z - cc.z) < 0.0005 \
			and absf(ps.x - cs.x) < 0.0005 and absf(ps.y - cs.y) < 0.0005 and absf(ps.z - cs.z) < 0.0005
		var p_hi: float = pc.w + ps.w * 0.5
		var c_lo: float = cc.w - cs.w * 0.5
		if same3 and absf(p_hi - c_lo) < 0.0005:
			var lo_w: float = pc.w - ps.w * 0.5
			var hi_w: float = cc.w + cs.w * 0.5
			prev[0] = Vector4(pc.x, pc.y, pc.z, (lo_w + hi_w) * 0.5)
			prev[1] = Vector4(ps.x, ps.y, ps.z, hi_w - lo_w)
		else:
			out.append(cur.duplicate())
	return out


static func _safe(lo: Vector3, hi: Vector3) -> Array:
	var a: Vector3 = lo.min(hi)
	var b: Vector3 = lo.max(hi)
	for axis in 3:
		if b[axis] - a[axis] < MIN_SIZE:
			var mid: float = (a[axis] + b[axis]) * 0.5
			a[axis] = mid - MIN_SIZE * 0.5
			b[axis] = mid + MIN_SIZE * 0.5
	return [a, b]
