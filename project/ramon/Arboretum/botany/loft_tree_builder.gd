extends RefCounted

## The Arboretum: a tree lofted from its skeleton with the loft tool that builds our animals
## (carried/LabKit/carried/chickenpen/scripts/loft_builder_4d.gd). Each branch is lofted root to
## tip as one chain of cross-sections (in 4D a cross-section is a 3D ball, and the loft skins
## between them: a triangular prism between two rings is three tetrahedra), every ring square to
## the branch (parallel-transport frames), the tip closed by a cone and the base sunk into its
## parent. Branches are built one by one and appended into one mesh.
##
##   build(sk, opts)      the wood: {"mesh", "tets", "ms", "sections"}; opts may set "sides" (an
##                        array of [rings, sides] by order), "smoothing" (or "smooth_by_order", an
##                        array by order: twigs need none), or "by_radius" ([[from radius, rings,
##                        sides, smoothing], ...] thickest first, picked by the branch's base radius:
##                        a thin limb is cheap whatever its order), "span_ratio", "min_r",
##                        "material", "root_sink" (how far the trunk goes on under the floor, m),
##                        "max_order" (only branches of that order or lower: the trunk alone is 0)
##   stations(sk)         the cross-sections as thin gold rings round the branches (the story's
##                        "the balls" part): one band each where the loft has a section
##   bones(sk, radius)    the skeleton as thin gold tubes, every node up to `upto` (the growth stages)
##   clumps(sk, opts)     leaf clumps for the lofted tree: lofted ellipsoids at the twig ends
##
## Every mesh carries its branch in its texture coordinates (tree_pivots.gd uvw()), so the wind in
## botany_bark.gdshader finds it.
##
## NO class_name (engine_gotchas.md): preload it.

const Loft := preload("res://ramon/Arboretum/carried/LabKit/carried/chickenpen/scripts/loft_builder_4d.gd")
const Pivots := preload("res://ramon/Arboretum/botany/tree_pivots.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")

## [rings, sides] of the cross-section by branch order: the trunk roundest, twigs the fewest.
const PROFILES := [[4, 8], [3, 6], [3, 5], [2, 4]]


## Appends `m` (a built mesh) into the accumulators, its texture coordinates rewritten as
## (material, branch, how far along) from the loft's own per-section ramp.
static func _append(acc: Dictionary, m: ArrayTetraMesh4D, material: int, branch: int, along0: float = 0.0, along1: float = 1.0) -> void:
	# (Typed locals share the arrays in `acc`; a cast such as (acc["pos"] as PackedVector4Array) would
	# append to a copy and lose it. Measured, scripts/_probe_packed_runner.gd.)
	var pos: PackedVector4Array = acc["pos"]
	var cpack: PackedInt32Array = acc["cells"]
	var normals: PackedVector4Array = acc["normals"]
	var tex: PackedVector3Array = acc["tex"]
	var tind: PackedInt32Array = acc["tind"]
	var base: int = pos.size()
	pos.append_array(m.get_vertex_positions())
	for c in m.get_simplex_cell_vertex_indices():
		cpack.append(c + base)
	normals.append_array(m.get_simplex_cell_boundary_normals())
	var tbase: int = tex.size()
	for v in m.get_texture_map_values():
		tex.append(Pivots.uvw(material, branch, lerpf(along0, along1, v.x)))
	for i in m.get_simplex_cell_texture_map_indices():
		tind.append(i + tbase)
	acc["pos"] = pos
	acc["cells"] = cpack
	acc["normals"] = normals
	acc["tex"] = tex
	acc["tind"] = tind


static func _new_acc() -> Dictionary:
	return {"pos": PackedVector4Array(), "cells": PackedInt32Array(), "normals": PackedVector4Array(), "tex": PackedVector3Array(), "tind": PackedInt32Array()}


static func _finish(acc: Dictionary) -> ArrayTetraMesh4D:
	var out := ArrayTetraMesh4D.new()
	out.set_vertex_positions(acc["pos"])
	out.set_simplex_cell_vertex_indices(acc["cells"])
	out.set_texture_map_values(acc["tex"])
	out.set_simplex_cell_texture_map_indices(acc["tind"])
	out.set_simplex_cell_boundary_normals(acc["normals"])
	return out


static func build(sk: Resource, opts: Dictionary = {}) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var profiles: Array = opts.get("sides", PROFILES)
	var smoothing: int = int(opts.get("smoothing", 2))
	var span_ratio: float = float(opts.get("span_ratio", 10.0))
	var min_r: float = float(opts.get("min_r", 0.012))
	var material: int = int(opts.get("material", Style.WOOD))
	var sink: float = float(opts.get("root_sink", 0.35))
	var max_order: int = int(opts.get("max_order", 99))
	var smooth_by: Array = opts.get("smooth_by_order", [])
	var by_r: Array = opts.get("by_radius", [])
	var wd: Array = _wd(opts)
	var acc: Dictionary = _new_acc()
	var branches: Array = sk.get("branches")
	var sections_total: int = 0
	for bi in branches.size():
		var pts: PackedVector4Array = sk.call("branch_points", bi)
		var rads: PackedFloat32Array = sk.call("branch_radii", bi)
		if pts.size() < 2:
			continue
		var order: int = int(branches[bi]["order"])
		if order > max_order:
			continue
		var prof: Array = profiles[mini(order, profiles.size() - 1)]
		var secs: Array = []
		if bi == 0 and sink > 0.0:
			secs.append(_sec(pts[0] - Vector4(0, sink, 0, 0), maxf(rads[0], min_r) * 1.08, wd))
		for k in pts.size():
			secs.append(_sec(pts[k], maxf(rads[k], min_r), wd))
		var sm: int = smoothing if smooth_by.is_empty() else int(smooth_by[mini(order, smooth_by.size() - 1)])
		if not by_r.is_empty():
			var r0: float = rads[0] if rads.size() < 2 else rads[1]
			for row in by_r:
				if r0 >= float(row[0]) or row == by_r[by_r.size() - 1]:
					prof = [int(row[1]), int(row[2])]
					sm = int(row[3])
					break
		var m: ArrayTetraMesh4D = Loft.build(secs, int(prof[0]), int(prof[1]), true, false, true, sm, false, span_ratio)
		if m == null:
			continue
		sections_total += secs.size()
		_append(acc, m, material, bi)
	var mesh: ArrayTetraMesh4D = _finish(acc)
	return {"mesh": mesh, "tets": (acc["cells"] as PackedInt32Array).size() / 4, "ms": (Time.get_ticks_usec() - t0) / 1000.0, "sections": sections_total}


static func _sec(c: Vector4, r: float, wd: Array = []) -> Dictionary:
	var s: Dictionary = {"center": c, "radius": r, "v_scale": 1.0, "w_scale": 1.0}
	if not wd.is_empty() and float(wd[0]) != 1.0:
		# Wood deeper in W than across: the cross-section's W reach is r x stretch, kept between a
		# floor and a cap, applied to the finished cross-section in world space (the loft's own
		# per-section basis, exact for any branch direction).
		var want: float = clampf(r * float(wd[0]), float(wd[1]), maxf(float(wd[2]), float(wd[1])))
		var b := Projection.IDENTITY
		b.w = Vector4(0, 0, 0, want / maxf(r, 0.0001))
		s["basis"] = b
	return s


## The W depth options of `opts`: [stretch, floor (m), cap (m)].
static func _wd(opts: Dictionary) -> Array:
	return [float(opts.get("w_stretch", 1.0)), float(opts.get("w_floor", 0.0)), float(opts.get("w_cap", 99.0))]


## The loft's cross-sections drawn as thin gold bands round each branch, where the loft places a
## section (before its own smoothing): what a designer sets.
static func stations(sk: Resource, opts: Dictionary = {}) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var acc: Dictionary = _new_acc()
	var grow: float = float(opts.get("grow", 1.12))
	var thick: float = float(opts.get("thick", 0.012))
	var min_r: float = float(opts.get("min_r", 0.012))
	var wd: Array = _wd(opts)
	var branches: Array = sk.get("branches")
	var count: int = 0
	for bi in branches.size():
		var pts: PackedVector4Array = sk.call("branch_points", bi)
		var rads: PackedFloat32Array = sk.call("branch_radii", bi)
		for k in pts.size():
			if k == 0 and bi > 0:
				continue
			var a: Vector4 = pts[maxi(k - 1, 0)]
			var b: Vector4 = pts[mini(k + 1, pts.size() - 1)]
			var t: Vector4 = (b - a).normalized() if a.distance_to(b) > 0.0001 else Vector4(0, 1, 0, 0)
			var r: float = maxf(rads[k], min_r) * grow
			var secs: Array = [_sec(pts[k] - t * thick, r, wd), _sec(pts[k] + t * thick, r, wd)]
			var m: ArrayTetraMesh4D = Loft.build(secs, 2, 8, false, false, true, 1, false, 1000.0)
			if m == null:
				continue
			_append(acc, m, Style.BALL, bi, float(k) / maxf(pts.size() - 1, 1), float(k) / maxf(pts.size() - 1, 1))
			count += 1
	return {"mesh": _finish(acc), "tets": (acc["cells"] as PackedInt32Array).size() / 4, "count": count, "ms": (Time.get_ticks_usec() - t0) / 1000.0}


## The skeleton as thin gold tubes: every branch, but only its nodes whose index is below `upto`
## (the generator's growth order, so a smaller `upto` is an earlier moment of growth).
static func bones(sk: Resource, radius: float = 0.02, upto: int = -1, w_depth: float = 0.0) -> Dictionary:
	var acc: Dictionary = _new_acc()
	var branches: Array = sk.get("branches")
	for bi in branches.size():
		var nodes: PackedInt32Array = branches[bi]["nodes"]
		var pts := PackedVector4Array()
		for i in nodes:
			if upto >= 0 and i >= upto:
				break
			pts.append((sk.get("positions") as PackedVector4Array)[i])
		if pts.size() < 2:
			continue
		var secs: Array = []
		for p in pts:
			secs.append(_sec(p, radius, [w_depth / radius, w_depth, w_depth] if w_depth > 0.0 else []))
		var m: ArrayTetraMesh4D = Loft.build(secs, 2, 4, true, false, true, 1, false, 1000.0)
		if m != null:
			_append(acc, m, Style.SKELETON, bi)
	return {"mesh": _finish(acc), "tets": (acc["cells"] as PackedInt32Array).size() / 4}


## Leaf clumps for the lofted tree: a squashed ball of leaves round the twig ends, deeper in W than
## the wood (the Lookout's leafy tree does the same). `size` scales them, `every` thins the tips.
static func clumps(sk: Resource, opts: Dictionary = {}) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var size: float = float(opts.get("size", 0.32))
	var every: int = maxi(1, int(opts.get("every", 1)))
	var cw: float = float(opts.get("w_scale", 1.1))
	var acc: Dictionary = _new_acc()
	var positions: PackedVector4Array = sk.get("positions")
	var node_branch: PackedInt32Array = sk.get("node_branch")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(opts.get("seed", 11))
	var tips: PackedInt32Array = sk.call("tips")
	var n: int = 0
	for ti in tips.size():
		if ti % every != 0:
			continue
		var i: int = tips[ti]
		var c: Vector4 = positions[i]
		var s: float = size * rng.randf_range(0.8, 1.2)
		var secs: Array = [
			{"center": c - Vector4(0, s * 0.45, 0, 0), "radius": s * 0.8, "v_scale": 1.0, "w_scale": cw},
			{"center": c + Vector4(0, s * 0.1, 0, 0), "radius": s, "v_scale": 1.0, "w_scale": cw},
			{"center": c + Vector4(0, s * 0.6, 0, 0), "radius": s * 0.7, "v_scale": 1.0, "w_scale": cw},
		]
		var m: ArrayTetraMesh4D = Loft.build(secs, 3, 6, true, false, false, 1, false, 1000.0)
		if m != null:
			_append(acc, m, Style.LEAVES, node_branch[i], 1.0, 1.0)
			n += 1
	return {"mesh": _finish(acc), "tets": (acc["cells"] as PackedInt32Array).size() / 4, "count": n, "ms": (Time.get_ticks_usec() - t0) / 1000.0}
