extends RefCounted

## The Voxel Lab: a ray against the engine's own chunk meshes, for specimens our GDScript copy cannot
## follow (Andrew's landscape and caves come from 4D noise in C++). The surface of a 4D solid is made
## of tetrahedra, three-dimensional cells in 4D; a line in 4D meets a 3D cell in a single point, found by
## solving o + t d = v0 + a e1 + b e2 + c e3 for (t, a, b, c), inside when a, b, c >= 0 and
## a + b + c <= 1. That is exactly the surface the cross-section is drawn from, so the aim lands where
## the eye sees it.
##
## A broad phase first: only chunks whose 8-voxel box the ray passes through, nearest first, and in
## them only cells whose bounding ball the ray passes near. A chunk's cells and their balls are worked
## out once per mesh and cached (a cut gives a chunk a new mesh, and a new cache).
##
## raycast(specimen, origin, dir, length) -> {} or {"point", "normal", "material", "t"} in the
## specimen's voxels.
##
## The engine has no voxel raycast for GDScript yet (Zylann's Voxel Tools has VoxelTool.raycast); that
## is on the wishlist for 4Denthusiast (follow_up/voxel_lab.md).
##
## NO class_name (engine_gotchas.md).

const CHUNK := 8.0

static var _cache: Dictionary = {}


static func raycast(specimen: Node, o: Vector4, d: Vector4, length: float) -> Dictionary:
	var dn: Vector4 = d.normalized()
	var candidates: Array = []
	for ch in specimen.call("chunk_nodes"):
		var at: Vector4 = (ch as Node4D).position
		var span: Vector2 = _ray_box(o, dn, at - Vector4.ONE, at + Vector4.ONE * (CHUNK + 1.0))
		if span.x <= span.y and span.y >= 0.0 and span.x <= length:
			candidates.append([span.x, ch])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var best: Dictionary = {}
	for cand in candidates:
		if not best.is_empty() and float(cand[0]) > float(best["t"]):
			break
		var hit: Dictionary = _ray_chunk(cand[1], o, dn, length)
		if not hit.is_empty() and (best.is_empty() or float(hit["t"]) < float(best["t"])):
			best = hit
	return best


static func _ray_chunk(ch: MeshInstance4D, o: Vector4, d: Vector4, length: float) -> Dictionary:
	var data: Dictionary = _data(ch)
	var at: Vector4 = ch.position
	var lo: Vector4 = o - at
	var pos: PackedVector4Array = data["pos"]
	var cells: PackedInt32Array = data["cells"]
	var centres: PackedVector4Array = data["centres"]
	var radii: PackedFloat32Array = data["radii"]
	var mats: PackedInt32Array = data["mats"]
	var best_t: float = length
	var best: Dictionary = {}
	for i in centres.size():
		var c: Vector4 = centres[i] - lo
		var along: float = c.dot(d)
		if along < -radii[i] or along - radii[i] > best_t:
			continue
		if (c - d * along).length_squared() > radii[i] * radii[i]:
			continue
		var v0: Vector4 = pos[cells[i * 4]]
		var e1: Vector4 = pos[cells[i * 4 + 1]] - v0
		var e2: Vector4 = pos[cells[i * 4 + 2]] - v0
		var e3: Vector4 = pos[cells[i * 4 + 3]] - v0
		var m := Projection(d, -e1, -e2, -e3)
		if absf(m.determinant()) < 1e-9:
			continue
		var s: Vector4 = m.inverse() * (v0 - lo)
		if s.x < 0.0 or s.x > best_t or s.y < -1e-4 or s.z < -1e-4 or s.w < -1e-4 or s.y + s.z + s.w > 1.0001:
			continue
		best_t = s.x
		var n: Vector4 = _cell_normal(e1, e2, e3)
		if n.dot(d) > 0.0:
			n = -n
		best = {"t": s.x, "point": o + d * s.x, "normal": n, "material": mats[i]}
	return best


## A chunk mesh's cells, positions (chunk-local), bounding balls and materials, worked out once.
static func _data(ch: MeshInstance4D) -> Dictionary:
	var mesh: Resource = ch.mesh
	var id: int = mesh.get_instance_id()
	if _cache.has(id):
		return _cache[id]
	var tm: TetraMesh4D = mesh as TetraMesh4D
	var pos: PackedVector4Array = tm.get_vertex_positions()
	var cells: PackedInt32Array = tm.get_simplex_cell_vertex_indices()
	var am = tm if tm is ArrayTetraMesh4D else tm.to_array_tetra_mesh()
	var tv: PackedVector3Array = am.call("get_texture_map_values")
	var ti: PackedInt32Array = am.call("get_simplex_cell_texture_map_indices")
	var n: int = cells.size() / 4
	var centres := PackedVector4Array()
	var radii := PackedFloat32Array()
	var mats := PackedInt32Array()
	centres.resize(n)
	radii.resize(n)
	mats.resize(n)
	for i in n:
		var a: Vector4 = pos[cells[i * 4]]
		var b: Vector4 = pos[cells[i * 4 + 1]]
		var c: Vector4 = pos[cells[i * 4 + 2]]
		var e: Vector4 = pos[cells[i * 4 + 3]]
		var mid: Vector4 = (a + b + c + e) * 0.25
		centres[i] = mid
		radii[i] = maxf(maxf(mid.distance_to(a), mid.distance_to(b)), maxf(mid.distance_to(c), mid.distance_to(e)))
		mats[i] = int(round(tv[ti[i * 4]].x * 255.0)) if ti.size() > i * 4 and ti[i * 4] < tv.size() else 0
	var out := {"pos": pos, "cells": cells, "centres": centres, "radii": radii, "mats": mats}
	if _cache.size() > 600:
		_cache.clear()
	_cache[id] = out
	return out


## The unit 4D vector at right angles to three edges of a cell (the 4D cross product).
static func _cell_normal(a: Vector4, b: Vector4, c: Vector4) -> Vector4:
	var n := Vector4(
		-a.y * (b.z * c.w - b.w * c.z) + a.z * (b.y * c.w - b.w * c.y) - a.w * (b.y * c.z - b.z * c.y),
		a.x * (b.z * c.w - b.w * c.z) - a.z * (b.x * c.w - b.w * c.x) + a.w * (b.x * c.z - b.z * c.x),
		-a.x * (b.y * c.w - b.w * c.y) + a.y * (b.x * c.w - b.w * c.x) - a.w * (b.x * c.y - b.y * c.x),
		a.x * (b.y * c.z - b.z * c.y) - a.y * (b.x * c.z - b.z * c.x) + a.z * (b.x * c.y - b.y * c.x))
	return n.normalized() if n.length() > 0.0 else Vector4(0, 0, 1, 0)


static func _ray_box(o: Vector4, d: Vector4, lo: Vector4, hi: Vector4) -> Vector2:
	var t0: float = -INF
	var t1: float = INF
	for axis in 4:
		if absf(d[axis]) < 1e-9:
			if o[axis] < lo[axis] or o[axis] > hi[axis]:
				return Vector2(1, 0)
			continue
		var a: float = (lo[axis] - o[axis]) / d[axis]
		var b: float = (hi[axis] - o[axis]) / d[axis]
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	return Vector2(t0, t1)
