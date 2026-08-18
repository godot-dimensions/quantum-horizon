class_name TerrainMeshBackendConnectedDC
extends RefCounted
## SPIKE / RESEARCH BACKEND, v2 - NOT wired into VoxelWorld4D, NOT used by
## any shipped scene, does not touch TerrainMeshBackendMT (the production
## backend) at all.
##
## v1 of this file (from-scratch, not a port) FAILED the crack test badly
## (roughly DOUBLED DC's hole rate, visually confirmed broken/shattered
## output) because its per-edge normal was derived from ONE-SIDED corner
## differences WITHIN a single cell - which is not actually a per-EDGE
## quantity at all: the SAME grid point, approached from two DIFFERENT
## cells that share it, computes a DIFFERENT one-sided difference (using
## whichever neighbor happens to be inside that particular cell), so two
## cells sharing an edge could disagree about that edge's normal and
## therefore about which component it belongs to - breaking the exact
## cross-cell consistency dual contouring depends on for crack-freeness.
##
## v2 fixes this at the root by reading the actual reference source
## (github.com/4Denthusiast/4d_mesh_demo, non-free branch, mesh.js +
## generate.js), rather than guessing at its shape a second time:
##
##   - generate.js computes each edge's crossing position and normal via
##     an INDEPENDENT gradient sample taken AT THE CROSSING POINT itself
##     (gradients(offset(p,axis,pos))) - a pure function of that specific
##     world-space location, not of "which cell is asking." It's stored
##     on a globally memoized per-grid-point object (getPoint(coords)),
##     so it is computed exactly once and every cell that touches that
##     edge reads the identical cached value.
##   - mesh.js's connectFace(axis, axis2, ints, data) is the REAL
##     connectivity decision, and it operates on a 2D FACE of the cell
##     (4 edges, at most, spanning two axes with the other two axes
##     fixed) - not on arbitrary shared-corner edge pairs the way v1
##     guessed. When all 4 of a face's edges cross (the classic
##     marching-cubes "ambiguous face" case), a score built from relative
##     crossing-position offsets and normal-direction agreement picks
##     ONE of the two possible diagonal pairings; otherwise every crossing
##     on that face is just chained in sequence. Material-continuity is
##     the score's tie-breaker in the original (multi-material) code -
##     omitted here (not stubbed as "true", genuinely inapplicable) since
##     this is single-material terrain.
##   - Connected components via DFS over the resulting per-cell graph,
##     one QEF vertex per component - unchanged in spirit from v1, but now
##     operating on a graph built from shared, cross-cell-consistent data.
##
## This IS now a faithful port of connectFace's actual logic (variable
## names/comments below track mesh.js's own axis/axis2/ints/score
## directly), adapted to this project's flat-array/bitmask cell
## representation instead of mesh.js's object-per-corner one. What is
## NOT ported: mesh.js's own tet-fan-per-face rendering step (explicitly
## specific to its own custom WebGL renderer) and its multi-material
## handling (not applicable here) - dual-cube tet assembly below is this
## project's own existing DualContour4D machinery, unchanged.
##
## Solver substitution, reported plainly rather than silently reused: the
## engine's native regularized SPD Cholesky solver
## (solve_spd_4x4_cholesky() in dual_contour_native_4d.cpp) is a private
## C++ free function INSIDE the monolithic Math4D.dual_contour_extract()
## call, not separately bound/exposed to GDScript - exposing it would mean
## an engine rebuild, a materially bigger action than this sandboxed
## spike. Uses DualContour4D._solve_4x4() instead (GDScript Gauss-Jordan,
## same regularized system, correct but not SPD-accelerated).

## Same apron reach as MT/DC.
static func stencil_radius_cells() -> int:
	return 1

## Central-difference gradient at an ARBITRARY world position, independent
## of any cell - the edge-intrinsic normal computation generate.js's own
## gradients(offset(p,axis,pos)) call makes, ported directly: 8 extra
## density_fn evaluations (2 per axis), taken ONCE per unique crossing
## edge and cached (see _get_or_add_edge_crossing) - not free the way
## DualContour4D's single cell-wide corner-difference gradient is, but the
## whole point: a per-cell-relative shortcut is exactly what produced
## disagreeing cross-cell normals in v1.
static func _gradient_at(pos: Vector4, density_fn: Callable, epsilon: Vector4) -> Vector4:
	return Vector4(
		(density_fn.call(pos + Vector4(epsilon.x, 0, 0, 0)) - density_fn.call(pos - Vector4(epsilon.x, 0, 0, 0))) / (2.0 * epsilon.x),
		(density_fn.call(pos + Vector4(0, epsilon.y, 0, 0)) - density_fn.call(pos - Vector4(0, epsilon.y, 0, 0))) / (2.0 * epsilon.y),
		(density_fn.call(pos + Vector4(0, 0, epsilon.z, 0)) - density_fn.call(pos - Vector4(0, 0, epsilon.z, 0))) / (2.0 * epsilon.z),
		(density_fn.call(pos + Vector4(0, 0, 0, epsilon.w)) - density_fn.call(pos - Vector4(0, 0, 0, epsilon.w))) / (2.0 * epsilon.w)
	)

## Shared, deterministic, cached-by-edge-identity crossing computation -
## the actual missing piece from v1. Canonicalizes by GLOBAL grid-point
## flat index (same principle TerrainMeshBackendMT._get_or_add_crossing_vertex
## already uses for its own welded-vertex cache), so any cell that reaches
## this edge - regardless of which of its own local corners it approaches
## from - resolves to the exact same cached {t, world_pos, normal} object.
## Returns the cache entry Dictionary.
static func _get_or_add_edge_crossing(gidx_a: int, pos_a: Vector4, d_a: float, gidx_b: int, pos_b: Vector4, d_b: float, density_fn: Callable, epsilon: Vector4, edge_cache: Dictionary) -> Dictionary:
	var lo_gidx: int
	var hi_gidx: int
	var lo_pos: Vector4
	var hi_pos: Vector4
	var lo_d: float
	var hi_d: float
	if gidx_a <= gidx_b:
		lo_gidx = gidx_a; lo_pos = pos_a; lo_d = d_a
		hi_gidx = gidx_b; hi_pos = pos_b; hi_d = d_b
	else:
		lo_gidx = gidx_b; lo_pos = pos_b; lo_d = d_b
		hi_gidx = gidx_a; hi_pos = pos_a; hi_d = d_a
	var key := "%d_%d" % [lo_gidx, hi_gidx]
	if edge_cache.has(key):
		return edge_cache[key]
	var t: float = lo_d / (lo_d - hi_d)
	var world_pos: Vector4 = lo_pos.lerp(hi_pos, t)
	var normal: Vector4 = _gradient_at(world_pos, density_fn, epsilon)
	normal = Vector4(0.0, 1.0, 0.0, 0.0) if normal.is_zero_approx() else normal.normalized()
	var entry := {"t": t, "world_pos": world_pos, "normal": normal}
	edge_cache[key] = entry
	return entry

## Direct port of mesh.js's connectFace(axis, axis2, ints, data) - see this
## file's header for the mapping. `ints` is a 4-element Array (entries may
## be null), each a Dictionary {slot: int, entry: Dictionary} where `entry`
## is the SHARED edge-crossing cache object (.t, .normal) and `slot` is
## this cell's own index into the 64-slot `intersections` array (used to
## record graph edges by index rather than by JS object reference).
## `connections` (adjacency lists, one per slot) is mutated in place.
## Material-continuity check omitted (see file header - trivially true,
## single-material terrain, not stubbed as a no-op condition but genuinely
## removed since there is nothing for it to check).
static func _connect_face(axis: int, axis2: int, ints: Array, connections: Array) -> void:
	if ints[0] != null and ints[1] != null and ints[2] != null and ints[3] != null:
		var e0: Dictionary = ints[0].entry
		var e1: Dictionary = ints[1].entry
		var e2: Dictionary = ints[2].entry
		var e3: Dictionary = ints[3].entry
		var n0: Vector4 = e0.normal
		var n1: Vector4 = e1.normal
		var n2: Vector4 = e2.normal
		var n3: Vector4 = e3.normal
		var score: float = 0.0
		# ints[0]/ints[1] are edges ALONG axis2 (so .t IS their axis2
		# coordinate within the face); ints[2]/ints[3] are edges ALONG
		# axis - mirrors mesh.js's pos[axis2]/pos[axis] exactly, just
		# using the edge's own scalar fractional-crossing value directly
		# instead of first expanding it into a local 4-vector, since every
		# other component of that vector is identical across all 4 face
		# edges by construction and cancels out of every difference the
		# score formula takes.
		score += e1.t - e0.t + e3.t - e2.t
		score += n0[axis] * signf(n0[axis2])
		score += n1[axis] * signf(n1[axis2])
		score += n2[axis2] * signf(n2[axis])
		score += n3[axis2] * signf(n3[axis])
		var i2: Dictionary = ints[2]
		var i3: Dictionary = ints[3]
		if score <= 0.0:
			var tmp: Dictionary = i2
			i2 = i3
			i3 = tmp
		var s0: int = ints[0].slot
		var s1: int = ints[1].slot
		var s2: int = i2.slot
		var s3: int = i3.slot
		connections[s0].append(s2)
		connections[s2].append(s0)
		connections[s1].append(s3)
		connections[s3].append(s1)
		return
	# Fewer than 4 crossings on this face - no diagonal ambiguity, just
	# chain whichever intersections exist in array order (mesh.js's own
	# fallback, ported directly).
	var prev = null
	for it in ints:
		if it != null and prev != null:
			connections[it.slot].append(prev.slot)
			connections[prev.slot].append(it.slot)
		if it != null:
			prev = it

## The general (bounds_min, bounds_max, nx, ny, nz, nw) entry point - see
## v1's own header for why this shape (mirrors DualContour4D.generate()
## exactly, including independent per-axis point counts needed to run the
## historical non-cubic crack-test grids).
static func generate(bounds_min: Vector4, bounds_max: Vector4, nx: int, ny: int, nz: int, nw: int, density_fn: Callable, qef_regularization: float = 0.15, world_step: Vector4 = Vector4.ZERO) -> Dictionary:
	var step := world_step if world_step != Vector4.ZERO else Vector4(
		(bounds_max.x - bounds_min.x) / float(nx - 1),
		(bounds_max.y - bounds_min.y) / float(ny - 1),
		(bounds_max.z - bounds_min.z) / float(nz - 1),
		(bounds_max.w - bounds_min.w) / float(nw - 1)
	)
	var step_arr := [step.x, step.y, step.z, step.w]
	# Gradient sample half-width for _gradient_at - a small fraction of
	# the local step size, same spirit as any finite-difference epsilon
	# choice: small enough to approximate the true local gradient, large
	# enough to stay well clear of density quantization/float noise.
	var epsilon := step * 0.01

	var density := PackedByteArray()
	density.resize(nx * ny * nz * nw * 2)
	for i in range(nx):
		for j in range(ny):
			for k in range(nz):
				var base_ijk := ((i * ny + j) * nz + k) * nw
				for l in range(nw):
					var pos := bounds_min + Vector4(i * step.x, j * step.y, k * step.z, l * step.w)
					DualContour4D._write_density(density, base_ijk + l, density_fn.call(pos))

	var nx1 := nx - 1
	var ny1 := ny - 1
	var nz1 := nz - 1
	var nw1 := nw - 1
	var total_cells: int = nx1 * ny1 * nz1 * nw1
	var cell_active := PackedByteArray()
	cell_active.resize(total_cells)
	var cell_edge_vertex: Array = []
	cell_edge_vertex.resize(total_cells)
	var compact_vertices := PackedVector4Array()
	var compact_normals := PackedVector4Array()
	var active_cell_count := 0
	var component_count := 0
	var multi_vertex_cell_count := 0
	# Shared crossing cache, keyed by global edge identity - lives for the
	# WHOLE generate() call, not per-cell, so every cell reaches the exact
	# same cached entry for any edge it shares with a neighbor.
	var edge_cache := {}

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
						var gi := i + bi
						for bj in range(2):
							var gj := j + bj
							for bk in range(2):
								var gk := k + bk
								var base_gigjgk := ((gi * ny + gj) * nz + gk) * nw
								for bl in range(2):
									var gl := l + bl
									var ci := bi * 8 + bj * 4 + bk * 2 + bl
									corner_density[ci] = DualContour4D._read_density(density, base_gigjgk + gl)
									corner_pos[ci] = bounds_min + Vector4(gi * step.x, gj * step.y, gk * step.z, gl * step.w)
									corner_gidx[ci] = base_gigjgk + gl
					var min_d: float = corner_density[0]
					var max_d: float = corner_density[0]
					for d in corner_density:
						min_d = minf(min_d, d)
						max_d = maxf(max_d, d)
					if min_d >= 0.0 or max_d <= 0.0:
						continue

					# --- Build the 64-slot intersections array (axis +
					# 4*ci, exactly mesh.js's own indexing) - non-null only
					# where ci is the LOWER corner along `axis` (bit 0)
					# AND that specific edge actually crosses. Each
					# populated slot wraps a REFERENCE to the shared cache
					# entry (never an independently-recomputed copy). ---
					var intersections: Array = []
					intersections.resize(64)
					var connections: Array = []
					for s in range(64):
						intersections[s] = null
						connections.append([])
					for ci in range(16):
						for axis in range(4):
							var bitmask := 1 << (3 - axis)
							if ci & bitmask:
								continue  # ci must be the lower corner along axis
							var nb := ci ^ bitmask
							var da: float = corner_density[ci]
							var db: float = corner_density[nb]
							if (da < 0.0) == (db < 0.0):
								continue
							var entry: Dictionary = _get_or_add_edge_crossing(
								corner_gidx[ci], corner_pos[ci], da,
								corner_gidx[nb], corner_pos[nb], db,
								density_fn, epsilon, edge_cache
							)
							var slot := axis + 4 * ci
							intersections[slot] = {"slot": slot, "ci": ci, "axis": axis, "entry": entry}

					# --- Face loop: for every (axis, axis2) pair and every
					# anchor corner that is the "low-low" corner for both,
					# gather this face's 4 edges and call connectFace -
					# exactly mesh.js's own double loop (corner x axis x
					# axis2<axis), using this project's `1<<(3-axis)` bit
					# weights in place of mesh.js's `8>>axis`. ---
					for ci in range(16):
						for axis in range(4):
							var bit_axis := 1 << (3 - axis)
							if ci & bit_axis:
								continue
							for axis2 in range(axis):
								var bit_axis2 := 1 << (3 - axis2)
								if ci & bit_axis2:
									continue
								var ints := [
									intersections[axis2 + 4 * ci],
									intersections[axis2 + 4 * (ci + bit_axis)],
									intersections[axis + 4 * ci],
									intersections[axis + 4 * (ci + bit_axis2)],
								]
								_connect_face(axis, axis2, ints, connections)

					# --- DFS connected components over the 64-slot graph. ---
					var visited: Array = []
					visited.resize(64)
					var components: Array = []
					for s in range(64):
						if intersections[s] == null or visited[s]:
							continue
						var stack := [s]
						visited[s] = true
						var comp := []
						while not stack.is_empty():
							var cur: int = stack.pop_back()
							comp.append(cur)
							for nb2 in connections[cur]:
								if not visited[nb2]:
									visited[nb2] = true
									stack.append(nb2)
						components.append(comp)
					if components.is_empty():
						continue
					component_count += components.size()
					if components.size() > 1:
						multi_vertex_cell_count += 1

					# --- One QEF vertex per component - same accumulation
					# DualContour4D itself uses, generalized to sum over
					# the component's own (shared, cached) per-edge
					# normals/positions. ---
					var cidx := ((i * ny1 + j) * nz1 + k) * nw1 + l
					var edge_vertex := {}
					for comp in components:
						var mass := Vector4()
						for s in comp:
							mass += (intersections[s].entry as Dictionary).world_pos
						mass /= float(comp.size())

						var ata0 := Vector4()
						var ata1 := Vector4()
						var ata2 := Vector4()
						var ata3 := Vector4()
						var atb := Vector4()
						for s in comp:
							var e: Dictionary = intersections[s].entry
							var nrm: Vector4 = e.normal
							var p: Vector4 = e.world_pos
							var dp: float = nrm.dot(p)
							ata0 += Vector4(nrm.x * nrm.x, nrm.x * nrm.y, nrm.x * nrm.z, nrm.x * nrm.w)
							ata1 += Vector4(nrm.y * nrm.x, nrm.y * nrm.y, nrm.y * nrm.z, nrm.y * nrm.w)
							ata2 += Vector4(nrm.z * nrm.x, nrm.z * nrm.y, nrm.z * nrm.z, nrm.z * nrm.w)
							ata3 += Vector4(nrm.w * nrm.x, nrm.w * nrm.y, nrm.w * nrm.z, nrm.w * nrm.w)
							atb += nrm * dp
						ata0.x += qef_regularization
						ata1.y += qef_regularization
						ata2.z += qef_regularization
						ata3.w += qef_regularization
						atb += mass * qef_regularization

						var solved: Vector4 = DualContour4D._solve_4x4([ata0, ata1, ata2, ata3], atb)
						if not solved.is_finite():
							solved = mass
						var lo: Vector4 = corner_pos[0]
						var hi: Vector4 = corner_pos[15]
						var inset := Vector4(step_arr[0], step_arr[1], step_arr[2], step_arr[3]) * 0.02
						solved.x = clampf(solved.x, lo.x + inset.x, hi.x - inset.x)
						solved.y = clampf(solved.y, lo.y + inset.y, hi.y - inset.y)
						solved.z = clampf(solved.z, lo.z + inset.z, hi.z - inset.z)
						solved.w = clampf(solved.w, lo.w + inset.w, hi.w - inset.w)

						var avg_normal := Vector4()
						for s in comp:
							avg_normal += (intersections[s].entry as Dictionary).normal
						avg_normal = Vector4(0.0, 1.0, 0.0, 0.0) if avg_normal.is_zero_approx() else avg_normal.normalized()

						var compact_index := compact_vertices.size()
						compact_vertices.append(solved)
						compact_normals.append(avg_normal)
						for s in comp:
							var it: Dictionary = intersections[s]
							edge_vertex[_local_edge_key(it.ci, it.axis)] = compact_index

					cell_active[cidx] = 1
					cell_edge_vertex[cidx] = edge_vertex
					active_cell_count += 1

	# --- Dual-cube tet assembly - DualContour4D's own phase 3, unchanged,
	# except the per-surrounding-cell vertex lookup resolves via the
	# edge's own local key into that cell's edge_vertex Dictionary. ---
	var out_indices := PackedInt32Array()
	var out_normals := PackedVector4Array()
	var out_source_ids := PackedInt32Array()
	var tet_count := 0
	var skipped_degenerate_tet_count := 0
	var crossing_edge_count := 0
	var next_dual_cube_id := 0

	var counts := [nx, ny, nz, nw]
	var strides := [ny * nz * nw, nz * nw, nw, 1]
	var cell_strides := [ny1 * nz1 * nw1, nz1 * nw1, nw1, 1]

	for i in range(nx):
		for j in range(ny):
			for k in range(nz):
				var base_ijk2 := ((i * ny + j) * nz + k) * nw
				var base_cell_ijk := ((i * ny1 + j) * nz1 + k) * nw1
				for l in range(nw):
					var g := [i, j, k, l]
					var base_index := base_ijk2 + l
					var base_cell_index := base_cell_ijk + l
					for axis in range(4):
						if g[axis] > counts[axis] - 2:
							continue
						var others: Array = DualContour4D.OTHER_AXES[axis]
						var ok := true
						for oa in others:
							if g[oa] < 1 or g[oa] > counts[oa] - 2:
								ok = false
								break
						if not ok:
							continue
						var d1: float = DualContour4D._read_density(density, base_index)
						var d2: float = DualContour4D._read_density(density, base_index + strides[axis])
						if (d1 < 0.0) == (d2 < 0.0):
							continue
						crossing_edge_count += 1

						var corner_positions8: Array = []
						corner_positions8.resize(8)
						var corner_normals8: Array = []
						corner_normals8.resize(8)
						var corner_indices8: Array = []
						corner_indices8.resize(8)
						var all_found := true
						var stride_a: int = cell_strides[others[0]]
						var stride_b: int = cell_strides[others[1]]
						var stride_c: int = cell_strides[others[2]]
						for local_index in range(8):
							var ua := (local_index >> 2) & 1
							var ub := (local_index >> 1) & 1
							var uc := local_index & 1
							var cidx2 := base_cell_index + (ua - 1) * stride_a + (ub - 1) * stride_b + (uc - 1) * stride_c
							if cell_active[cidx2] == 0:
								all_found = false
								break
							var local_bits := [0, 0, 0, 0]
							local_bits[axis] = 0
							local_bits[others[0]] = 1 - ua
							local_bits[others[1]] = 1 - ub
							local_bits[others[2]] = 1 - uc
							var ci_local_low: int = local_bits[0] * 8 + local_bits[1] * 4 + local_bits[2] * 2 + local_bits[3]
							var local_key: int = _local_edge_key(ci_local_low, axis)
							var edge_vertex2: Dictionary = cell_edge_vertex[cidx2]
							if not edge_vertex2.has(local_key):
								all_found = false
								break
							var compact_idx: int = edge_vertex2[local_key]
							corner_positions8[local_index] = compact_vertices[compact_idx]
							corner_normals8[local_index] = compact_normals[compact_idx]
							corner_indices8[local_index] = compact_idx
						if not all_found:
							continue

						var min_condition_main := INF
						for tet in DualContour4D.TET_CORNERS:
							var p0m: Vector4 = corner_positions8[tet[0]]
							min_condition_main = minf(min_condition_main, DualContour4D._tet_condition(
								corner_positions8[tet[1]] - p0m, corner_positions8[tet[2]] - p0m, corner_positions8[tet[3]] - p0m
							))
						var chosen_decomposition: Array = DualContour4D.TET_CORNERS
						if min_condition_main < 0.3:
							var min_condition_alt := INF
							for tet in DualContour4D.TET_CORNERS_ALT:
								var p0a: Vector4 = corner_positions8[tet[0]]
								min_condition_alt = minf(min_condition_alt, DualContour4D._tet_condition(
									corner_positions8[tet[1]] - p0a, corner_positions8[tet[2]] - p0a, corner_positions8[tet[3]] - p0a
								))
							if min_condition_alt > min_condition_main:
								chosen_decomposition = DualContour4D.TET_CORNERS_ALT

						var dual_cube_id := next_dual_cube_id
						next_dual_cube_id += 1

						for tet in chosen_decomposition:
							var p0: Vector4 = corner_positions8[tet[0]]
							var p1: Vector4 = corner_positions8[tet[1]]
							var p2: Vector4 = corner_positions8[tet[2]]
							var p3: Vector4 = corner_positions8[tet[3]]
							var n0: Vector4 = corner_normals8[tet[0]]
							var n1: Vector4 = corner_normals8[tet[1]]
							var n2: Vector4 = corner_normals8[tet[2]]
							var n3: Vector4 = corner_normals8[tet[3]]
							var i0: int = corner_indices8[tet[0]]
							var i1: int = corner_indices8[tet[1]]
							var i2: int = corner_indices8[tet[2]]
							var i3: int = corner_indices8[tet[3]]
							var edge1 := p1 - p0
							var edge2 := p2 - p0
							var edge3 := p3 - p0
							if DualContour4D._tet_condition(edge1, edge2, edge3) <= 0.01:
								skipped_degenerate_tet_count += 1
								continue
							var perp := Vector4D.perpendicular(edge1, edge2, edge3)
							var ref_normal := n0 + n1 + n2 + n3
							ref_normal = Vector4(0.0, 1.0, 0.0, 0.0) if ref_normal.is_zero_approx() else ref_normal.normalized()
							if perp.dot(ref_normal) < 0.0:
								var tmp_n := n2
								n2 = n3
								n3 = tmp_n
								var tmp_i := i2
								i2 = i3
								i3 = tmp_i
							out_indices.append(i0)
							out_indices.append(i1)
							out_indices.append(i2)
							out_indices.append(i3)
							out_normals.append(n0)
							out_normals.append(n1)
							out_normals.append(n2)
							out_normals.append(n3)
							out_source_ids.append(dual_cube_id)
							tet_count += 1

	return {
		"unique_vertex_positions": compact_vertices,
		"tet_vertex_indices": out_indices,
		"tet_vertex_normals": out_normals,
		"tet_source_ids": out_source_ids,
		"tet_count": tet_count,
		"active_cell_count": active_cell_count,
		"grid_point_count": nx * ny * nz * nw,
		"crossing_edge_count": crossing_edge_count,
		"skipped_degenerate_tet_count": skipped_degenerate_tet_count,
		"component_count": component_count,
		"multi_vertex_cell_count": multi_vertex_cell_count,
		"unique_edge_crossings_cached": edge_cache.size(),
	}

## Encodes (lower_corner_index 0-15, axis 0-3) into one int - see v1's own
## comment (unchanged): computed identically whether enumerating a cell's
## own crossing edges (phase 2) or re-deriving "which local edge does a
## surrounding cell see" from grid-edge offset arithmetic (phase 3),
## agreeing by construction since both derive the SAME "lower corner along
## this axis, in this cell's own local addressing" for the same edge.
static func _local_edge_key(lower_corner: int, axis: int) -> int:
	return lower_corner * 4 + axis

## Cubic-grid wrapper matching TerrainMeshBackendMT's
## generate_brick_mesh(bounds_min, world_step, points_per_axis, density_fn)
## interface shape - see v1's own comment (unchanged).
static func generate_brick_mesh(bounds_min: Vector4, world_step: Vector4, points_per_axis: int, density_fn: Callable) -> Dictionary:
	var bounds_max := bounds_min + world_step * float(points_per_axis - 1)
	return generate(bounds_min, bounds_max, points_per_axis, points_per_axis, points_per_axis, points_per_axis, density_fn, 0.15, world_step)
