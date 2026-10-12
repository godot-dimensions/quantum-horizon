extends Node
## TEMPORARY, THROWAWAY - quick Marching Tetrahedra ("marching 4-simplices")
## implementation for a side-by-side comparison against the broken Dual
## Contouring output, on the EXACT SAME density fields already used in the
## diagnostic tests (control sphere SDF, reduced-resolution
## terrain4d_test.tscn density). Not production quality - no sliver
## handling, crude per-cell normals. The POINT is topology, not polish:
## does this reproduce the holes/cracks, or not?
##
## Algorithm: each 4D grid cell (a 16-corner tesseract, the SAME
## corner_density[16] gather SingleVertexDualContour4D already does) is split into
## 4! = 24 four-simplices via the standard Kuhn/Freudenthal cube
## triangulation - the SAME construction TET_CORNERS/TET_CORNERS_ALT
## already use for 3!=6 in the 3D case, just carried one dimension further.
## Each 5-corner simplex is classified by how many of its corners are
## "solid" (negative density):
##   0 or 5: no crossing, skip entirely - zero tets emitted (audited via
##     the returned mt_simplex_stats, not just assumed).
##   1 or 4: the minority corner is cut off - the 4 crossing points from it
##     to the other 4 corners form ONE tetrahedron.
##   2 or 3: the corners split into a 2-group and a 3-group; the 2*3=6
##     edges between the two groups all cross the surface, and the 6
##     crossing points form a triangular prism, split into 3 tetrahedra by
##     the standard fixed prism decomposition.
##
## Vertex welding: a crossing point is an exact linear interpolation
## between two GLOBAL grid corners, determined entirely by those two
## corners' global grid indices and densities - not by which simplex or
## cell happened to compute it, and not by which of the two corners a given
## simplex locally treated as the "minority" side. _get_or_add_crossing_vertex
## canonicalizes the lerp order by global index (always lower-index corner
## first) specifically so that two different simplices - even ones that
## locally disagree on which corner is the minority - compute the SAME
## edge in the SAME order and land on a bit-identical result, making exact
## position-keyed caching correct rather than approximate.
##
## The crack-resistance argument this whole thing tests: two neighboring
## cells sharing a grid EDGE both compute the SAME position on that edge
## from the SAME two corner densities - bit-identical by construction,
## unlike DC's independently-QEF-solved dual vertex per cell.

static func _permutations(n: int) -> Array:
	if n == 0:
		return [[]]
	var result := []
	var smaller: Array = _permutations(n - 1)
	for p in smaller:
		for i in range(p.size() + 1):
			var new_p: Array = p.duplicate()
			new_p.insert(i, n - 1)
			result.append(new_p)
	return result

const BIT_FOR_AXIS := [8, 4, 2, 1]  # matches ci = bi*8 + bj*4 + bk*2 + bl (x,y,z,w)

## Kuhn/Freudenthal triangulation generalized to an arbitrary anchor corner:
## the standard construction (anchor=0) always builds monotone paths from
## local corner 0 (0000) to its complement 15 (1111) - i.e. it's always
## anchored to the SAME main diagonal for every cell, which is exactly what
## makes the whole grid's triangulation visually regular/grid-aligned.
## Anchoring at a different corner (e.g. 1 = 0001) builds monotone paths
## toward ITS complement (14 = 1110) instead - a genuinely different (not
## just relabeled) triangulation of the same tesseract, since it picks a
## different one of the cube's 8 antipodal corner pairs as its "spine".
## XOR (not OR) is required here since a bit may already be 1 at the
## anchor - toggling is what "move one step closer to the complement"
## means for an arbitrary anchor, whereas OR only works when anchor=0.
static func _build_simplices(anchor: int = 0) -> Array:
	var simplices := []
	for perm in _permutations(4):
		var corners := [anchor]
		var acc := anchor
		for axis in perm:
			acc = acc ^ BIT_FOR_AXIS[axis]
			corners.append(acc)
		simplices.append(corners)
	return simplices

var _simplices_anchor0: Array = _build_simplices(0)  # 24 entries, 5 corner indices each - the original, always-regular scheme
var _simplices_anchor1: Array = _build_simplices(1)  # alternate spine (corner 1 <-> corner 14) - for checkerboard parity mixing

## Reset per generate_mt() call - maps "lo_gidx_hi_gidx" -> index into the
## call's out_positions, so every simplex/cell that touches a given global
## grid edge shares one output vertex instead of emitting its own copy.
var _edge_vertex_cache: Dictionary = {}

func _get_or_add_crossing_vertex(gidx_a: int, pos_a: Vector4, d_a: float, gidx_b: int, pos_b: Vector4, d_b: float, out_positions: PackedVector4Array) -> int:
	var lo_gidx: int
	var hi_gidx: int
	var lo_pos: Vector4
	var hi_pos: Vector4
	var lo_d: float
	var hi_d: float
	if gidx_a <= gidx_b:
		lo_gidx = gidx_a
		lo_pos = pos_a
		lo_d = d_a
		hi_gidx = gidx_b
		hi_pos = pos_b
		hi_d = d_b
	else:
		lo_gidx = gidx_b
		lo_pos = pos_b
		lo_d = d_b
		hi_gidx = gidx_a
		hi_pos = pos_a
		hi_d = d_a
	var key := "%d_%d" % [lo_gidx, hi_gidx]
	if _edge_vertex_cache.has(key):
		return _edge_vertex_cache[key]
	var t: float = lo_d / (lo_d - hi_d)
	var pos: Vector4 = lo_pos.lerp(hi_pos, t)
	var idx: int = out_positions.size()
	out_positions.append(pos)
	_edge_vertex_cache[key] = idx
	return idx

## Returns an Array of tets, each an Array of exactly 4 welded vertex
## indices into out_positions (mutated in place via _get_or_add_crossing_vertex).
## stats is mutated in place to audit the sign classification: every one of
## the 24 simplices per crossing cell increments stats.total, and either
## stats.skipped_uniform (0 tets, fully inside/outside) or
## stats.emit_1tet/stats.emit_3tet (per the case below) - never both.
func _simplex_to_tets(sc: Array, corner_pos: Array, corner_density: Array, corner_gidx: Array, out_positions: PackedVector4Array, stats: Dictionary) -> Array:
	var d := []
	var p := []
	var g := []
	for ci in sc:
		d.append(corner_density[ci])
		p.append(corner_pos[ci])
		g.append(corner_gidx[ci])
	var neg_indices := []
	var pos_indices := []
	for i in range(5):
		if d[i] < 0.0:
			neg_indices.append(i)
		else:
			pos_indices.append(i)
	var k: int = neg_indices.size()
	stats.total += 1
	if k == 0 or k == 5:
		stats.skipped_uniform += 1
		return []
	if k == 1 or k == 4:
		stats.emit_1tet += 1
		var minority: Array = neg_indices if k == 1 else pos_indices
		var majority: Array = pos_indices if k == 1 else neg_indices
		var iso: int = minority[0]
		var idxs := []
		for j in majority:
			idxs.append(_get_or_add_crossing_vertex(g[iso], p[iso], d[iso], g[j], p[j], d[j], out_positions))
		return [idxs]
	stats.emit_3tet += 1
	# k == 2 or k == 3: 2-group vs 3-group, 6 pairwise crossing points,
	# split into 3 tets via the standard triangular-prism decomposition.
	var group_a: Array = neg_indices if neg_indices.size() == 2 else pos_indices
	var group_b: Array = pos_indices if neg_indices.size() == 2 else neg_indices
	var vidx := []  # vidx[i][j] = welded vertex index between group_a[i] and group_b[j]
	for i in range(2):
		var row := []
		for j in range(3):
			var ai: int = group_a[i]
			var bj: int = group_b[j]
			row.append(_get_or_add_crossing_vertex(g[ai], p[ai], d[ai], g[bj], p[bj], d[bj], out_positions))
		vidx.append(row)
	var v00: int = vidx[0][0]
	var v01: int = vidx[0][1]
	var v02: int = vidx[0][2]
	var v10: int = vidx[1][0]
	var v11: int = vidx[1][1]
	var v12: int = vidx[1][2]
	return [
		[v00, v01, v02, v12],
		[v00, v01, v11, v12],
		[v00, v10, v11, v12],
	]

## Same overall shape/signature as SingleVertexDualContour4D.generate(), but the
## returned dict only has what this comparison needs, plus mt_simplex_stats
## (the sign-classification audit) and unique_vertex_count (post-welding).
## alternate_scheme=false (default) reproduces the original, single-anchor
## behavior exactly - every existing caller that doesn't pass this stays
## byte-for-byte unchanged. When true, picks between the two anchor
## triangulations per CELL based on grid-coordinate parity
## ((i+j+k+l)%2) - a checkerboard alternation, aimed at breaking up the
## single-scheme's visually regular/grid-aligned facet pattern. NOT assumed
## crack-free just because each individual scheme is - two neighboring
## cells with opposite parity use DIFFERENT triangulations of their shared
## face, and unlike the single-scheme case, there is no proof here that
## both sides agree on that face's triangulation. Must be verified via the
## same face-adjacency crack test as everything else, not trusted visually.
func generate_mt(bounds_min: Vector4, bounds_max: Vector4, nx: int, ny: int, nz: int, nw: int, density_fn: Callable, alternate_scheme: bool = false) -> Dictionary:
	var step := Vector4(
		(bounds_max.x - bounds_min.x) / float(nx - 1),
		(bounds_max.y - bounds_min.y) / float(ny - 1),
		(bounds_max.z - bounds_min.z) / float(nz - 1),
		(bounds_max.w - bounds_min.w) / float(nw - 1)
	)
	var nx1 := nx - 1
	var ny1 := ny - 1
	var nz1 := nz - 1
	var nw1 := nw - 1

	_edge_vertex_cache = {}
	var out_positions := PackedVector4Array()
	var out_indices := PackedInt32Array()
	var out_normals := PackedVector4Array()
	var tet_count := 0
	var crossing_cell_count := 0
	var stats := {"total": 0, "skipped_uniform": 0, "emit_1tet": 0, "emit_3tet": 0}

	for i in range(nx1):
		for j in range(ny1):
			for k in range(nz1):
				for l in range(nw1):
					var corner_density: Array = []
					corner_density.resize(16)
					var corner_pos: Array = []
					corner_pos.resize(16)
					var corner_gidx: Array = []
					corner_gidx.resize(16)
					for bi in range(2):
						var gi: int = i + bi
						for bj in range(2):
							var gj: int = j + bj
							for bk in range(2):
								var gk: int = k + bk
								for bl in range(2):
									var gl: int = l + bl
									var ci: int = bi * 8 + bj * 4 + bk * 2 + bl
									var pos := bounds_min + Vector4(gi * step.x, gj * step.y, gk * step.z, gl * step.w)
									corner_pos[ci] = pos
									corner_density[ci] = density_fn.call(pos)
									corner_gidx[ci] = ((gi * ny + gj) * nz + gk) * nw + gl
					var min_d: float = corner_density[0]
					var max_d: float = corner_density[0]
					for d in corner_density:
						min_d = minf(min_d, d)
						max_d = maxf(max_d, d)
					if min_d >= 0.0 or max_d <= 0.0:
						continue  # uniform cell, same early-out DC uses
					crossing_cell_count += 1

					var simplices_for_this_cell: Array = _simplices_anchor0
					if alternate_scheme and (i + j + k + l) % 2 == 1:
						simplices_for_this_cell = _simplices_anchor1

					# One crude per-cell "normal" (central-difference gradient,
					# same style as SingleVertexDualContour4D._axis_gradient) shared by
					# every vertex emitted from this cell - good enough for a
					# throwaway visual, not meant to be exact. Independent of
					# welding: the engine currently ignores per-vertex normals
					# for Cross-section shading anyway (confirmed in
					# tetra_mesh_4d.cpp), so this only needs to exist, not be
					# analytically correct at each welded vertex.
					var grad := Vector4(
						(_sum_where(corner_density, 8) - _sum_where(corner_density, 8, true)) / (8.0 * step.x),
						(_sum_where(corner_density, 4) - _sum_where(corner_density, 4, true)) / (8.0 * step.y),
						(_sum_where(corner_density, 2) - _sum_where(corner_density, 2, true)) / (8.0 * step.z),
						(_sum_where(corner_density, 1) - _sum_where(corner_density, 1, true)) / (8.0 * step.w)
					)
					var n: Vector4 = grad.normalized()
					if n.is_zero_approx():
						n = Vector4(0.0, 1.0, 0.0, 0.0)

					for sc in simplices_for_this_cell:
						var tets: Array = _simplex_to_tets(sc, corner_pos, corner_density, corner_gidx, out_positions, stats)
						for idxs in tets:
							out_indices.append(idxs[0])
							out_indices.append(idxs[1])
							out_indices.append(idxs[2])
							out_indices.append(idxs[3])
							out_normals.append(n)
							out_normals.append(n)
							out_normals.append(n)
							out_normals.append(n)
							tet_count += 1

	return {
		"unique_vertex_positions": out_positions,
		"tet_vertex_indices": out_indices,
		"tet_vertex_normals": out_normals,
		"tet_source_ids": _dummy_source_ids(tet_count),
		"tet_count": tet_count,
		"active_cell_count": crossing_cell_count,
		"crossing_edge_count": 0,
		"skipped_degenerate_tet_count": 0,
		"unique_vertex_count": out_positions.size(),
		"mt_simplex_stats": stats,
	}

func _dummy_source_ids(n: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	ids.resize(n)
	for i in range(n):
		ids[i] = i
	return ids

func _sum_where(corner_density: Array, bitmask: int, invert: bool = false) -> float:
	var total := 0.0
	for ci in range(16):
		var has_bit: bool = (ci & bitmask) != 0
		if has_bit != invert:
			total += corner_density[ci]
	return total
