extends RefCounted

## The Voxel Lab's cuts, each written two ways at once: the engine's edits (4Denthusiast's
## SphereVoxelEdit4D, BoxVoxelEdit4D, ParallelogramVoxelEdit4D, filling with air) and the same shape
## for our own copy of the specimen (vl_recipe.gd material_at), so aiming and counting agree with
## what the engine carved.
##
## A CUT is a Dictionary, in VOXELS of the specimen's world:
##   kind     "ball", "block", "drill", "saw"
##   fill     the material written (254, air, for every cut here)
##   edits    [[class name, {property: value}], ...]
##   has      Callable(p: Vector4) -> bool: is p inside the cut
##   aabb     [lo, hi]: the box round it
##   label    what the cost screen calls it
##
## THE FOUR, and what each shows in 4D:
##   ball    a 4D ball. In your slice a round crater; slide through W and it shrinks and closes.
##   block   an axis-aligned 4D box. A square notch that keeps its size through W, then stops dead.
##   drill   a chain of 4D balls along your view: a tunnel, as deep as its size; a tube in 4D, so a
##           step aside in W and it is solid rock.
##   saw     a thin slab between two points, cut as deep as its size and right through the specimen
##           in W: a clean channel that is there in every slice.
##
## NO class_name (engine_gotchas.md).

const AIR := 254


static func ball(center: Vector4, radius: float) -> Dictionary:
	var c := center
	var r := radius
	return {"kind": "ball", "fill": AIR, "label": "Ball  r %.1f" % r,
		"edits": [["SphereVoxelEdit4D", {"center": c, "radius": r, "fill_material": AIR}]],
		"has": func(p: Vector4) -> bool: return p.distance_to(c) < r,
		"aabb": [c - Vector4.ONE * r, c + Vector4.ONE * r],
		"center": c, "radius": r}


## `half` is half the notch, per axis (voxels).
static func block(center: Vector4, half: Vector4) -> Dictionary:
	var c := center
	var h := half
	return {"kind": "block", "fill": AIR, "label": "Block  %.1f" % (h.x * 2.0),
		"edits": [["BoxVoxelEdit4D", {"position": c - h, "size": h * 2.0, "fill_material": AIR}]],
		"has": func(p: Vector4) -> bool:
			var d: Vector4 = (p - c).abs()
			return d.x < h.x and d.y < h.y and d.z < h.z and d.w < h.w,
		"aabb": [c - h, c + h],
		"center": c, "half": h}


## A tunnel from `from` along `dir`, `length` deep and `radius` round: balls half a radius apart.
static func drill(from: Vector4, dir: Vector4, radius: float, length: float) -> Dictionary:
	var a := from
	var d: Vector4 = dir.normalized()
	var r := radius
	var b: Vector4 = a + d * length
	var edits: Array = []
	var n: int = maxi(1, int(ceil(length / maxf(r * 0.5, 0.25))))
	for k in n + 1:
		edits.append(["SphereVoxelEdit4D", {"center": a.lerp(b, float(k) / float(n)), "radius": r, "fill_material": AIR}])
	var lo := Vector4(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z), minf(a.w, b.w)) - Vector4.ONE * r
	var hi := Vector4(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z), maxf(a.w, b.w)) + Vector4.ONE * r
	return {"kind": "drill", "fill": AIR, "label": "Drill  r %.1f" % r, "edits": edits,
		"has": func(p: Vector4) -> bool:
			var t: float = clampf((p - a).dot(d), 0.0, length)
			return p.distance_to(a + d * t) < r,
		"aabb": [lo, hi], "from": a, "to": b, "radius": r}


## A slab from `a` to `b` (both on the surface), `kerf` wide across `kerf_dir`, `depth` deep along
## `depth_dir` (into the solid) and `w_extent` long along `w_dir`, centred on the line a-b in all
## three. The engine's ParallelogramVoxelEdit4D: the unit hypercube mapped by four edge vectors.
static func saw(a: Vector4, b: Vector4, kerf_dir: Vector4, kerf: float, depth_dir: Vector4, depth: float, w_dir: Vector4, w_extent: float) -> Dictionary:
	var e_len: Vector4 = b - a
	var e_kerf: Vector4 = kerf_dir.normalized() * kerf
	var e_depth: Vector4 = depth_dir.normalized() * depth
	var e_w: Vector4 = w_dir.normalized() * w_extent
	# Start half a kerf and half the W length back, and a little out of the surface, so the slab's
	# mouth is clean.
	var pos: Vector4 = a - e_kerf * 0.5 - e_w * 0.5 - e_depth * 0.08
	var basis := Projection(e_len, e_kerf, e_depth, e_w)
	var inv: Projection = basis.inverse()
	var corners: Array = []
	for i in 16:
		corners.append(pos + e_len * float(i & 1) + e_kerf * float((i >> 1) & 1) + e_depth * float((i >> 2) & 1) + e_w * float((i >> 3) & 1))
	var lo: Vector4 = corners[0]
	var hi: Vector4 = corners[0]
	for q in corners:
		lo = Vector4(minf(lo.x, q.x), minf(lo.y, q.y), minf(lo.z, q.z), minf(lo.w, q.w))
		hi = Vector4(maxf(hi.x, q.x), maxf(hi.y, q.y), maxf(hi.z, q.z), maxf(hi.w, q.w))
	return {"kind": "saw", "fill": AIR, "label": "Saw  %.1f long" % e_len.length(),
		"edits": [["ParallelogramVoxelEdit4D", {"position": pos, "basis": basis, "fill_material": AIR}]],
		"has": func(p: Vector4) -> bool:
			var u: Vector4 = inv * (p - pos)
			return u.x > 0.0 and u.x < 1.0 and u.y > 0.0 and u.y < 1.0 and u.z > 0.0 and u.z < 1.0 and u.w > 0.0 and u.w < 1.0,
		"aabb": [lo, hi], "from": a, "to": b}


## The engine's edit objects for `cut`, ready for VoxelWorld4D.apply_edit (the type names are never
## written as types: ClassDB.instantiate, as Crosswise and the Arboretum do).
static func engine_edits(cut: Dictionary) -> Array:
	var out: Array = []
	for e in cut["edits"]:
		var ed = ClassDB.instantiate(String(e[0]))
		var props: Dictionary = e[1]
		for k in props:
			ed.set(k, props[k])
		out.append(ed)
	return out
