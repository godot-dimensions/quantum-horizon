extends RefCounted

## The Voxel Lab: what a specimen is made of, written two ways from one recipe.
##
##   FOR THE ENGINE   generator(recipe) builds the engine's own generator stack (layered box, plane and
##                    clipped generators, 4Denthusiast's): the engine fills its VoxelWorld4D from it on
##                    worker threads and meshes it by dual contouring in C++. Recipe edits (the hidden
##                    cavity is a pair of 4D balls) are applied once the world has loaded.
##   FOR US           material_at(recipe, cuts, p) answers the same question in GDScript, for any point:
##                    the engine keeps its voxels to itself (GDScript can only ask whether a voxel is
##                    loaded), so aiming, counting the voxels a cut removes and the column's support all
##                    read this copy instead.
##
## A RECIPE is a Dictionary, in VOXELS (the world is scaled so one voxel is `voxel` metres):
##   kind      "block", "column", "crown", "plain"
##   voxel     metres a voxel
##   center    the specimen's middle, in voxel coordinates. Kept off the grid on purpose (JITTER) so no
##             face lies exactly on a row of grid points (4Denthusiast's 24-cell note: a surface through
##             grid points frays), and in the middle of an 8-voxel chunk, so a cut near the middle
##             touches one chunk rather than sixteen.
##   half      half the box, per axis (voxels)
##   crust     the crust's thickness (voxels); 0 for none
##   planes    [[normal, d], ...]: air wherever normal.dot(p) > d (the chamfers)
##   vein      {} or {"normal", "d1", "d2"}: a slab of quartz inside the core
##   cavity    {} or {"center", "radius", "lining"}: a 4D ball of air with a crystal lining
##   column    {} or {"center", "radius", "y0", "y1"}: a round column (round in x, z and w)
##
## MATERIALS: 0 crust, 1 core, 2 vein, 3 lining, 4 crown (leaves), 254 air, 255 undefined.
##
## NO class_name (engine_gotchas.md).

const CRUST := 0
const CORE := 1
const VEIN := 2
const LINING := 3
const CROWN := 4
const AIR := 254
const UNDEFINED := 255

## Every specimen sits this far off the voxel grid (voxels), per axis.
const JITTER := Vector4(0.31, 0.27, 0.23, 0.19)
## The engine's mesh chunks, voxels a side (voxel_constants_4d.h).
const CHUNK := 8

## The colours, after the old block (VoxelMining/scripts/voxel_mining_final_block.gd): grey crust, hot
## orange core; then a teal vein (a pale one read as a hole in the first frames, 6 Oct) and an amethyst
## lining, so every cut says where it went.
const COLORS := {
	CRUST: Color(0.63, 0.62, 0.60),
	CORE: Color(0.97, 0.44, 0.09),
	VEIN: Color(0.16, 0.70, 0.64),
	LINING: Color(0.58, 0.36, 0.90),
	CROWN: Color(0.36, 0.62, 0.30),
}


## The hero block: `size_m` metres (x, y, z, w) at `voxel` metres a voxel, a crust, its edges chamfered
## through all six planes of 4D, a tilted vein and a hidden cavity a little ana of the middle. The
## chamfer stays shallower than the crust (at most 1.25 times its thickness, under the sqrt(2) where it
## would cut through to the core): deeper, every edge showed an orange line (the first room, 6 Oct).
static func block(size_m: Vector4, voxel: float, opts: Dictionary = {}) -> Dictionary:
	var half: Vector4 = size_m * 0.5 / voxel
	var center: Vector4 = chunk_middle() + JITTER
	# One voxel and a bit: the old block's rule, one bite must break through or the reveal never reads
	# (0.2 m left the probe's small cuts grey, 6 Oct).
	var crust: float = float(opts.get("crust_m", 0.12)) / voxel
	var r: Dictionary = {"kind": "block", "voxel": voxel, "center": center, "half": half, "crust": crust,
		"planes": chamfers(center, half, minf(float(opts.get("chamfer_m", 0.12)), float(opts.get("crust_m", 0.12)) * 1.25) / voxel), "vein": {}, "cavity": {}, "column": {}}
	if bool(opts.get("vein", true)):
		# Tilted in x, y and W, so it moves across a cut face as you slide through W.
		var n: Vector4 = Vector4(0.35, 1.0, 0.15, 0.45).normalized()
		var at: float = n.dot(center) + float(opts.get("vein_offset_m", -0.18)) / voxel
		var t: float = float(opts.get("vein_m", 0.09)) / voxel * 0.5
		r["vein"] = {"normal": n, "d1": at - t, "d2": at + t}
	if bool(opts.get("cavity", true)):
		var off: Vector4 = opts.get("cavity_at_m", Vector4(0.25, 0.05, 0.0, 0.35))
		r["cavity"] = {"center": center + off / voxel, "radius": float(opts.get("cavity_m", 0.32)) / voxel,
			"lining": float(opts.get("lining_m", 0.08)) / voxel}
	return r


## A plain crust-over-core box, no chamfer, vein or cavity (the limits bench, the resolution ladder).
static func plain(size_m: Vector4, voxel: float, opts: Dictionary = {}) -> Dictionary:
	var half: Vector4 = size_m * 0.5 / voxel
	var center: Vector4 = chunk_middle() + (JITTER if bool(opts.get("jitter", true)) else Vector4.ZERO)
	return {"kind": "plain", "voxel": voxel, "center": center, "half": half,
		"crust": float(opts.get("crust_m", 0.2)) / voxel, "planes": [], "vein": {}, "cavity": {}, "column": {}}


## A round column: a sphere drawn out along Y (round in x, z and W), `height_m` tall and `radius_m`
## round, centred on the recipe's middle. opts: "open_top" / "open_bottom" leave the crust off that end,
## so two columns stacked show no seam where they meet (the column station's base and top).
static func column(radius_m: float, height_m: float, voxel: float, opts: Dictionary = {}) -> Dictionary:
	var rad: float = radius_m / voxel
	var h: float = height_m / voxel
	var half := Vector4(rad + 1.0, h * 0.5, rad + 1.0, rad + 1.0)
	var center: Vector4 = chunk_middle() + JITTER
	var r: Dictionary = {"kind": "column", "voxel": voxel, "center": center, "half": half,
		"crust": float(opts.get("crust_m", 0.1)) / voxel, "planes": [], "vein": {}, "cavity": {},
		"column": {"center": center, "radius": rad, "y0": center.y - h * 0.5, "y1": center.y + h * 0.5,
			"open_top": bool(opts.get("open_top", false)), "open_bottom": bool(opts.get("open_bottom", false))}}
	if opts.has("colors"):
		r["colors"] = opts["colors"]
	return r


## A crown of leaves: nothing but balls of the crown material, `balls` [[centre_m, radius_m], ...] round
## the recipe's middle, in a box `size_m` big (the tree's top).
static func crown(size_m: Vector4, voxel: float, balls: Array) -> Dictionary:
	var half: Vector4 = size_m * 0.5 / voxel
	var center: Vector4 = chunk_middle() + JITTER
	var fills: Array = []
	for b in balls:
		fills.append([center + (b[0] as Vector4) / voxel, float(b[1]) / voxel, CROWN])
	return {"kind": "crown", "voxel": voxel, "center": center, "half": half, "crust": 0.0, "planes": [], "vein": {},
		"cavity": {}, "column": {}, "empty": true, "fill_edits": fills}


## The middle of a chunk near the origin: (4, 4, 4, 4).
static func chunk_middle() -> Vector4:
	return Vector4.ONE * float(CHUNK) * 0.5


## The 24 chamfer planes of a box: one across each edge-plane of 4D (x-y, x-z, x-w, y-z, y-w, z-w),
## four signs each, `c` voxels in from the edge along the plane's normal.
static func chamfers(center: Vector4, half: Vector4, c: float) -> Array:
	var out: Array = []
	if c <= 0.0:
		return out
	for i in 4:
		for j in range(i + 1, 4):
			for si in [-1.0, 1.0]:
				for sj in [-1.0, 1.0]:
					var n := Vector4.ZERO
					n[i] = si
					n[j] = sj
					n = n.normalized()
					var d: float = (half[i] + half[j]) / sqrt(2.0) - c
					out.append([n, n.dot(center) + d])
	return out


# -- for the engine ----------------------------------------------------------------------------------

## The engine's generator stack for `r`. Upper layers win wherever they are not UNDEFINED.
static func generator(r: Dictionary):
	if r.has("layers"):
		var custom = ClassDB.instantiate("LayeredVoxelGenerator4D")
		custom.set("layers", r["layers"])
		return custom
	var layers: Array = []
	var c: Vector4 = r["center"]
	var half: Vector4 = r["half"]
	var col: Dictionary = r.get("column", {})
	if bool(r.get("empty", false)):
		layers.append(_box(c, half * 2.0, AIR, AIR))
	elif col.is_empty():
		layers.append(_box(c, half * 2.0, CRUST if float(r["crust"]) > 0.0 else CORE, AIR))
	else:
		# The column: crust round, core inside; air everywhere else (its foot is the scene's plinth).
		var cyl = ClassDB.instantiate("CylinderVoxelGenerator4D")
		cyl.set("center", Vector4(c.x, (float(col["y0"]) + float(col["y1"])) * 0.5, c.z, c.w))
		cyl.set("height", float(col["y1"]) - float(col["y0"]))
		cyl.set("radius", float(col["radius"]))
		cyl.set("material_inner", CRUST)
		cyl.set("material_outer", AIR)
		layers.append(cyl)
	var t: float = float(r["crust"])
	if t > 0.0 and not bool(r.get("empty", false)):
		var core
		if col.is_empty():
			core = _box(c, half * 2.0 - Vector4.ONE * t * 2.0, CORE, UNDEFINED)
		else:
			core = ClassDB.instantiate("CylinderVoxelGenerator4D")
			var cy0: float = float(col["y0"]) + (0.0 if bool(col.get("open_bottom", false)) else t)
			var cy1: float = float(col["y1"]) - (0.0 if bool(col.get("open_top", false)) else t)
			core.set("center", Vector4(c.x, (cy0 + cy1) * 0.5, c.z, c.w))
			core.set("height", cy1 - cy0)
			core.set("radius", float(col["radius"]) - t)
			core.set("material_inner", CORE)
			core.set("material_outer", UNDEFINED)
		var vein: Dictionary = r.get("vein", {})
		if not vein.is_empty():
			# Inside the core only: the core's region (base) with the slab over it (modifier). The slab
			# is itself clipped: defined above d1 (quartz), and back to core above d2.
			var below = _plane(vein["normal"], float(vein["d1"]), VEIN, UNDEFINED)
			var above = _plane(vein["normal"], float(vein["d2"]), CORE, UNDEFINED)
			var slab = ClassDB.instantiate("ClippedVoxelGenerator4D")
			slab.set("base", below)
			slab.set("modifier", above)
			var clipped = ClassDB.instantiate("ClippedVoxelGenerator4D")
			clipped.set("base", core)
			clipped.set("modifier", slab)
			core = clipped
		layers.append(core)
	for p in r.get("planes", []):
		layers.append(_plane(p[0], float(p[1]), AIR, UNDEFINED))
	var layered = ClassDB.instantiate("LayeredVoxelGenerator4D")
	layered.set("layers", layers)
	return layered


## Edits the recipe needs once the world has loaded (generators have no ball): the cavity, a ball of
## lining with a smaller ball of air in it. [[center, radius, material], ...].
static func recipe_edits(r: Dictionary) -> Array:
	var out: Array = (r.get("fill_edits", []) as Array).duplicate()
	var cav: Dictionary = r.get("cavity", {})
	if not cav.is_empty():
		out.append([cav["center"], float(cav["radius"]) + float(cav["lining"]), LINING])
		out.append([cav["center"], float(cav["radius"]), AIR])
	return out


static func palette(r: Dictionary, colors: Dictionary = COLORS):
	var pal = ClassDB.instantiate("VoxelMaterialPalette4D")
	var list := PackedColorArray()
	for i in 5:
		list.append(colors.get(i, Color.WHITE))
	pal.set("colors", list)
	return pal


static func _box(center: Vector4, size: Vector4, inner: int, outer: int):
	var g = ClassDB.instantiate("BoxVoxelGenerator4D")
	g.set("center", center)
	g.set("size", size)
	g.set("material_inner", inner)
	g.set("material_outer", outer)
	return g


static func _plane(normal: Vector4, d: float, over: int, under: int):
	var g = ClassDB.instantiate("PlaneVoxelGenerator4D")
	g.set("normal", normal)
	g.set("distance", d)
	g.set("material_over", over)
	g.set("material_under", under)
	return g


## The world's bounds in voxels, [position, size], with a margin of `m`.
static func bounds(r: Dictionary, m: int = 2) -> Array:
	var c: Vector4 = r["center"]
	var h: Vector4 = r["half"]
	var lo := Vector4i(floori(c.x - h.x) - m, floori(c.y - h.y) - m, floori(c.z - h.z) - m, floori(c.w - h.w) - m)
	var hi := Vector4i(ceili(c.x + h.x) + m, ceili(c.y + h.y) + m, ceili(c.z + h.z) + m, ceili(c.w + h.w) + m)
	return [lo, hi - lo]


# -- for us --------------------------------------------------------------------------------------------

## The material at `p` (voxel coordinates) of recipe `r` after `cuts` (vl_cut.gd dictionaries), in the
## order they were made. Mirrors generator() and recipe_edits().
static func material_at(r: Dictionary, cuts: Array, p: Vector4) -> int:
	var m: int = base_material(r, p)
	for cut in cuts:
		if m == AIR and int(cut.get("fill", AIR)) == AIR:
			continue
		if _cut_has(cut, p):
			m = int(cut.get("fill", AIR))
	return m


## The recipe alone, before any cut.
static func base_material(r: Dictionary, p: Vector4) -> int:
	var c: Vector4 = r["center"]
	var t: float = float(r["crust"])
	var col: Dictionary = r.get("column", {})
	var m: int = AIR
	if bool(r.get("empty", false)):
		for f in r.get("fill_edits", []):
			if p.distance_to(f[0]) < float(f[1]):
				m = int(f[2])
		return m
	if col.is_empty():
		var d: Vector4 = (p - c).abs()
		var h: Vector4 = r["half"]
		if d.x >= h.x or d.y >= h.y or d.z >= h.z or d.w >= h.w:
			return AIR
		m = CORE if t <= 0.0 or (d.x < h.x - t and d.y < h.y - t and d.z < h.z - t and d.w < h.w - t) else CRUST
	else:
		var q := Vector3(p.x - c.x, p.z - c.z, p.w - c.w)
		if p.y <= float(col["y0"]) or p.y >= float(col["y1"]) or q.length() >= float(col["radius"]):
			return AIR
		var cy0: float = float(col["y0"]) + (0.0 if bool(col.get("open_bottom", false)) else t)
		var cy1: float = float(col["y1"]) - (0.0 if bool(col.get("open_top", false)) else t)
		m = CORE if (t <= 0.0 or (q.length() < float(col["radius"]) - t and p.y > cy0 and p.y < cy1)) else CRUST
	if m == CORE:
		var vein: Dictionary = r.get("vein", {})
		if not vein.is_empty():
			var s: float = (vein["normal"] as Vector4).dot(p)
			if s > float(vein["d1"]) and s <= float(vein["d2"]):
				m = VEIN
	for pl in r.get("planes", []):
		if (pl[0] as Vector4).dot(p) > float(pl[1]):
			return AIR
	var cav: Dictionary = r.get("cavity", {})
	if not cav.is_empty():
		var dist: float = p.distance_to(cav["center"])
		if dist < float(cav["radius"]):
			return AIR
		if dist < float(cav["radius"]) + float(cav["lining"]):
			return LINING
	return m


static func solid(r: Dictionary, cuts: Array, p: Vector4) -> bool:
	var m: int = material_at(r, cuts, p)
	return m != AIR and m != UNDEFINED


static func _cut_has(cut: Dictionary, p: Vector4) -> bool:
	return bool(cut["has"].call(p)) if cut.has("has") else false


## The first solid point along a ray (voxel coordinates), or {} if it misses: marched in steps of
## `step` voxels from `from` for `length` voxels, then narrowed down by halving.
static func raycast(r: Dictionary, cuts: Array, from: Vector4, dir: Vector4, length: float, step: float = 0.35) -> Dictionary:
	var d: Vector4 = dir.normalized()
	# Start where the ray enters the specimen's box (nothing is solid outside it).
	var span: Vector2 = _ray_box(from, d, r["center"], (r["half"] as Vector4) + Vector4.ONE)
	if span.x > span.y or span.y < 0.0:
		return {}
	var t: float = maxf(span.x, 0.0)
	var end: float = minf(span.y, length)
	var was: bool = solid(r, cuts, from + d * t)
	if was:
		return {"point": from + d * t, "t": t, "material": material_at(r, cuts, from + d * t)}
	while t < end:
		var t1: float = t + step
		if solid(r, cuts, from + d * t1):
			var a: float = t
			var b: float = t1
			for k in 8:
				var mid: float = (a + b) * 0.5
				if solid(r, cuts, from + d * mid):
					b = mid
				else:
					a = mid
			var hit: Vector4 = from + d * b
			return {"point": hit, "t": b, "material": material_at(r, cuts, hit), "normal": normal_at(r, cuts, hit)}
		t = t1
	return {}


## Which way the surface faces at `p` (pointing out of the solid), by sampling round it.
static func normal_at(r: Dictionary, cuts: Array, p: Vector4, e: float = 0.6) -> Vector4:
	var n := Vector4.ZERO
	for axis in 4:
		var o := Vector4.ZERO
		o[axis] = e
		var a: float = 1.0 if solid(r, cuts, p + o) else 0.0
		var b: float = 1.0 if solid(r, cuts, p - o) else 0.0
		n[axis] = b - a
	return n.normalized() if n.length() > 0.0 else Vector4(0, 0, 1, 0)


## Where a ray enters and leaves a box: (t_in, t_out); t_in > t_out means it misses.
static func _ray_box(o: Vector4, d: Vector4, c: Vector4, h: Vector4) -> Vector2:
	var t0: float = -INF
	var t1: float = INF
	for axis in 4:
		var lo: float = c[axis] - h[axis]
		var hi: float = c[axis] + h[axis]
		if absf(d[axis]) < 1e-9:
			if o[axis] < lo or o[axis] > hi:
				return Vector2(1, 0)
			continue
		var a: float = (lo - o[axis]) / d[axis]
		var b: float = (hi - o[axis]) / d[axis]
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	return Vector2(t0, t1)


## The grid points (voxel centres as the engine samples them: whole numbers) inside `lo`..`hi` that a
## cut turns from solid to air, given the cuts made before it.
static func voxels_removed(r: Dictionary, before: Array, cut: Dictionary) -> int:
	var b: Array = cut["aabb"]
	var lo: Vector4 = b[0]
	var hi: Vector4 = b[1]
	var n: int = 0
	for w in range(ceili(lo.w), floori(hi.w) + 1):
		for z in range(ceili(lo.z), floori(hi.z) + 1):
			for y in range(ceili(lo.y), floori(hi.y) + 1):
				for x in range(ceili(lo.x), floori(hi.x) + 1):
					var p := Vector4(x, y, z, w)
					if _cut_has(cut, p) and solid(r, before, p):
						n += 1
	return n


## Solid voxels of the recipe alone (for the counts on the cards), counted on every `stride`-th grid
## point per axis and scaled up: a 24 x 18 x 16 x 18 block is 124,000 points, too many to test one by
## one in GDScript at load; a stride of 2 tests one in sixteen and lands within a percent.
static func voxel_count(r: Dictionary, stride: int = 2) -> int:
	var c: Vector4 = r["center"]
	var h: Vector4 = r["half"]
	var n: int = 0
	for w in range(ceili(c.w - h.w), floori(c.w + h.w) + 1, stride):
		for z in range(ceili(c.z - h.z), floori(c.z + h.z) + 1, stride):
			for y in range(ceili(c.y - h.y), floori(c.y + h.y) + 1, stride):
				for x in range(ceili(c.x - h.x), floori(c.x + h.x) + 1, stride):
					if base_material(r, Vector4(x, y, z, w)) != AIR:
						n += 1
	return n * stride * stride * stride * stride


# -- Andrew's test cases (4Denthusiast, project/sandbox/voxel_test.tscn and voxel_24cell_test.tscn) --------

## His landscape, clipped to a 4D box `size_m` big: fractal-noise terrain in height bands (stone, dirt,
## grass), caves carved through it, and an ocean below sea level. His own composition (an ocean plane
## under the landscape clipped against the caves) and his own numbers, scaled from his 1 m voxels to
## ours, then everything outside the box made air. Built from noise in C++, which our copy cannot follow:
## "mirror" false (aimed through the meshes, vl_tet_ray.gd).
## Materials are his: 0 grass, 1 dirt, 2 stone, 3 water.
static func terrain(size_m: Vector4, voxel: float, opts: Dictionary = {}) -> Dictionary:
	var half: Vector4 = size_m * 0.5 / voxel
	var center: Vector4 = chunk_middle() + JITTER + (opts.get("shift", Vector4.ZERO) as Vector4)
	# His heights are in his voxels (1 m); ours are `voxel` m, so scale his numbers by `k` to keep the
	# land's shape and shrink it into the box.
	var k: float = float(opts.get("k", 0.55))
	var sea: float = center.y + float(opts.get("sea_m", -0.15)) / voxel
	var ocean = _plane(Vector4(0, 1, 0, 0), sea, AIR, 3)
	var land = ClassDB.instantiate("LandscapeVoxelGenerator4D")
	land.set("seed", int(opts.get("seed", 2)))
	land.set("intensity", 12.32 * k)
	land.set("materials", PackedInt32Array([2, 1, 0, UNDEFINED]))
	var ground: float = center.y + float(opts.get("ground_m", 0.0)) / voxel
	land.set("material_cutoffs", PackedFloat32Array([ground - 6.0 * k, ground - 1.5 * k, ground]))
	if opts.has("horizontal_scale"):
		land.set("horizontal_scale", float(opts["horizontal_scale"]))
	var caves = ClassDB.instantiate("CaveVoxelGenerator4D")
	caves.set("seed", int(opts.get("cave_seed", 1)))
	caves.set("persistence", 0.4)
	caves.set("diameter", 6.18 * float(opts.get("cave_k", 0.7)))
	var clipped = ClassDB.instantiate("ClippedVoxelGenerator4D")
	clipped.set("base", land)
	clipped.set("modifier", caves)
	var r: Dictionary = {"kind": "terrain", "voxel": voxel, "center": center, "half": half, "crust": 0.0, "planes": [], "vein": {},
		"cavity": {}, "column": {}, "mirror": false,
		"layers": [ocean, clipped, _box(center, half * 2.0, UNDEFINED, AIR)],
		"colors": {0: Color(0.40, 0.74, 0.22), 1: Color(0.56, 0.32, 0.12), 2: Color(0.34, 0.34, 0.34), 3: Color(0.25, 0.47, 1.0)}}
	return r


## His caves on their own: a 4D block of stone with his winding tunnels carved through it (where three
## noise fields are all near zero), the tunnels opening on its faces.
static func caves(size_m: Vector4, voxel: float, opts: Dictionary = {}) -> Dictionary:
	var half: Vector4 = size_m * 0.5 / voxel
	var center: Vector4 = chunk_middle() + JITTER
	var caves_gen = ClassDB.instantiate("CaveVoxelGenerator4D")
	caves_gen.set("seed", int(opts.get("seed", 1)))
	caves_gen.set("persistence", float(opts.get("persistence", 0.4)))
	caves_gen.set("diameter", float(opts.get("diameter", 4.2)))
	if opts.has("horizontal_scale"):
		caves_gen.set("horizontal_scale", float(opts["horizontal_scale"]))
	if opts.has("vertical_scale"):
		caves_gen.set("vertical_scale", float(opts["vertical_scale"]))
	if opts.has("octaves"):
		caves_gen.set("octaves", int(opts["octaves"]))
	var block = _box(center, half * 2.0, 2, AIR)
	var clipped = ClassDB.instantiate("ClippedVoxelGenerator4D")
	clipped.set("base", _box(center, half * 2.0, 2, UNDEFINED))
	clipped.set("modifier", caves_gen)
	return {"kind": "caves", "voxel": voxel, "center": center, "half": half, "crust": 0.0, "planes": [], "vein": {},
		"cavity": {}, "column": {}, "mirror": false, "layers": [block, clipped],
		"colors": {2: Color(0.62, 0.60, 0.58), 0: Color(0.40, 0.74, 0.22), 1: Color(0.56, 0.32, 0.12), 3: Color(0.25, 0.47, 1.0)}}


## His 24-cell: the 4D solid bounded by 24 octahedra, built from 24 planes (one across each edge-plane of
## 4D, four signs each). With `on_grid`, its middle on a whole voxel and its size such that its corners
## land on grid points: his note in the scene says the mesher must then pick between several normals
## at once, and fringes its edges. Off the grid (our jitter, and a size that misses the grid), it does not.
static func cell24(radius_m: float, voxel: float, on_grid: bool) -> Dictionary:
	var a: float = radius_m / voxel
	var center: Vector4 = chunk_middle() + (Vector4.ZERO if on_grid else JITTER)
	if on_grid:
		a = round(a * 0.5) * 2.0
	else:
		a += 0.37
	# Corners at (+-a, 0, 0, 0) and (+-a/2, ...): the planes |x_i| + |x_j| <= a.
	var d: float = a / sqrt(2.0)
	var planes: Array = []
	for i in 4:
		for j in range(i + 1, 4):
			for si in [-1.0, 1.0]:
				for sj in [-1.0, 1.0]:
					var n := Vector4.ZERO
					n[i] = si
					n[j] = sj
					n = n.normalized()
					planes.append([n, n.dot(center) + d])
	var half := Vector4.ONE * (a + 1.0)
	return {"kind": "24cell", "voxel": voxel, "center": center, "half": half, "crust": 0.0, "planes": planes, "vein": {},
		"cavity": {}, "column": {}, "on_grid": on_grid, "colors": {CORE: Color(0.86, 0.36, 0.26) if on_grid else Color(0.30, 0.60, 0.95)}}
