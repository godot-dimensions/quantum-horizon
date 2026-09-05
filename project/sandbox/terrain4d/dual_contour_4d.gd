class_name DualContour4D
extends RefCounted
## 4D dual contouring: extracts a tetrahedral hypersurface mesh (the same
## "boundary-only" convention BoxTetraMesh4D/OrthoplexTetraMesh4D use, NOT a
## filled solid) from a scalar density field, generalizing the standard
## 3D algorithm from 8-corner cube cells to 16-corner tesseract cells.
##
## Density convention: negative = solid, positive = air (a standard SDF-like
## sign convention). The surface is the density == 0 level set.
##
## Algorithm, per cell (mirrors the reference 4d_mesh_demo approach, minus
## its sharp-feature multi-vertex-per-cell connectivity graph - this uses
## the simpler, standard one-vertex-per-cell dual contouring):
##   1. Sample density at every grid point once, cache in a flat array
##      (quantized to a byte per point - see DENSITY_QUANT_SCALE).
##   2. For each of the (n-1)^4 cells, if its 16 corners have mixed sign,
##      place one representative "dual vertex" via a regularized
##      least-squares fit (QEF) against the cell's crossing-edge
##      intersection points, using a per-cell-constant gradient normal
##      (central difference across the cell's corners - free, since the
##      16 corner densities are already known; no extra density samples).
##      Only ACTIVE cells get a vertex slot (a compact, already-unique
##      array indexed by a running counter - not one slot per cell in the
##      whole grid, most of which are inactive at any real resolution).
##   3. For each grid EDGE (not cell edge) that crosses the surface, its
##      8 surrounding active cells' dual vertices form a "dual cube" -
##      tetrahedralize that cube into 6 tets (standard main-diagonal
##      decomposition) and emit them as INDICES into the compact vertex
##      array from step 2 - never as duplicated raw positions, so nothing
##      downstream needs to re-discover which positions are the same
##      vertex the way a dedup-by-scanning step would.
##
## The QEF step approximates SVD-clamped pseudoinversion with normal-equation
## least squares regularized (biased) toward the crossing-edge mass point -
## this project has no SVD utility, and a full one isn't needed here since
## the gradient is a single constant vector per cell, not a many-plane fit.

const OTHER_AXES := [[1, 2, 3], [0, 2, 3], [0, 1, 3], [0, 1, 2]]
# Standard 6-tetrahedra decomposition of a cube, all sharing main diagonal 0-7.
# Corner index = ua*4 + ub*2 + uc, i.e. bit pattern (ua, ub, uc) in {0,1}^3.
const TET_CORNERS := [[0, 1, 3, 7], [0, 1, 5, 7], [0, 4, 5, 7], [0, 4, 6, 7], [0, 2, 6, 7], [0, 2, 3, 7]]
# The OTHER main-diagonal decomposition (1-6 instead of 0-7), derived by
# XOR-ing every corner label in TET_CORNERS with 1 - a cube symmetry
# (relabeling vertices via reflection along one axis) that maps a valid
# tetrahedralization to another valid one, and maps diagonal 0-7 to 1-6
# (0^1=1, 7^1=6). A dual cube whose actual point positions make TET_CORNERS
# produce a sliver along the 0-7 diagonal is often well-conditioned along
# the 1-6 diagonal instead (a real, well-known sliver-reduction technique
# in tetrahedral meshing, not a hack) - generate() picks whichever
# decomposition is better-conditioned for each cube's own geometry.
const TET_CORNERS_ALT := [[1, 0, 2, 6], [1, 0, 4, 6], [1, 4, 5, 6], [1, 5, 7, 6], [1, 7, 3, 6], [1, 3, 2, 6]]

## Quantization steps per unit of density, for packing the sampled field
## into 2 bytes/point (a manually-packed signed int16) instead of
## PackedFloat64Array's 8 bytes/point - a 4x memory cut on what is, at large
## grid sizes, by far the single largest allocation in this generator.
##
## An earlier version tried 1 byte/point (int8, scale=10 => 0.1 precision,
## range +-12.7) - too coarse: at this generator's actual density gradients
## (roughly 1 unit of density per grid step near the surface), a 0.1
## quantization step is a double-digit-percent error on the exact quantity
## the per-cell gradient estimate and QEF crossing-point interpolation both
## depend on, and that measurably increased the mesh's hole count (visible,
## not just theoretical - confirmed by screenshot). 2 bytes (int16,
## scale=1000 => 0.001 precision, range +-32.767) removes that error
## margin entirely while still halving int8's already-4x-smaller footprint
## relative to float64's 8 bytes - i.e. still a real, meaningful memory win
## for the eventual 200x50x200x200 target, just not the maximum
## theoretically possible one. Values are encoded as a raw signed-int16 bit
## pattern (2 unsigned bytes, two's complement) since GDScript's
## PackedByteArray is unsigned-only.
const DENSITY_QUANT_SCALE := 1000.0
const DENSITY_QUANT_MAX := 32767.0

static func _quantize_density(value: float) -> int:
	return int(roundf(clampf(value * DENSITY_QUANT_SCALE, -DENSITY_QUANT_MAX, DENSITY_QUANT_MAX))) & 0xFFFF

static func _dequantize_density(word_value: int) -> float:
	var signed_value := word_value - 65536 if word_value >= 32768 else word_value
	return float(signed_value) / DENSITY_QUANT_SCALE

static func _write_density(density: PackedByteArray, point_index: int, value: float) -> void:
	var q := _quantize_density(value)
	var byte_index := point_index * 2
	density[byte_index] = q & 0xFF
	density[byte_index + 1] = (q >> 8) & 0xFF

static func _read_density(density: PackedByteArray, point_index: int) -> float:
	var byte_index := point_index * 2
	var q := density[byte_index] | (density[byte_index + 1] << 8)
	return _dequantize_density(q)

## Mirrors ConcaveMeshShape4D's own degeneracy test (normalized 3x3 Gram
## determinant of the tet's 3 edge vectors from vert0) - a sliver tet is
## common where the local surface is nearly flat, since the dual cube's 8
## corners then sit close to coplanar. Returns the raw determinant (not
## just a pass/fail bool) so generate() can compare candidate
## decompositions and pick whichever is best-conditioned, in addition to
## using it as a final skip-if-still-bad safety net.
static func _tet_condition(edge1: Vector4, edge2: Vector4, edge3: Vector4) -> float:
	var len0 := edge1.length()
	var len1 := edge2.length()
	var len2 := edge3.length()
	if len0 < 1e-9 or len1 < 1e-9 or len2 < 1e-9:
		return 0.0
	var n01 := edge1.dot(edge2) / (len0 * len1)
	var n02 := edge1.dot(edge3) / (len0 * len2)
	var n12 := edge2.dot(edge3) / (len1 * len2)
	var c00 := 1.0 - n12 * n12
	var c01 := n02 * n12 - n01
	var c02 := n01 * n12 - n02
	var det := c00 + n01 * c01 + n02 * c02
	return det if is_finite(det) else 0.0

static func _flat_index(coord: Array, counts: Array) -> int:
	return ((coord[0] * counts[1] + coord[1]) * counts[2] + coord[2]) * counts[3] + coord[3]

static func _axis_gradient(corner_density: Array, bitmask: int, step_size: float) -> float:
	var sum_high := 0.0
	var sum_low := 0.0
	for ci in range(16):
		if ci & bitmask:
			sum_high += corner_density[ci]
		else:
			sum_low += corner_density[ci]
	return (sum_high / 8.0 - sum_low / 8.0) / step_size

## Solves the 4x4 system A*x = b via Gauss-Jordan elimination with partial
## pivoting. `rows` is an array of 4 Vector4, one per matrix row.
##
## SPIKE INSTRUMENTATION (temporary - see Terrain4DProfile): wraps this
## function's own body as "qef_solve_only", isolated from the rest of
## generate_phase2_qef (corner gather, gradient, crossing-point collection,
## ATA/ATB accumulation) - added to answer "how much of the QEF phase is
## the solve itself vs. everything around it." Remove the two
## Terrain4DProfile lines (and this paragraph) once the spike's numbers are
## captured, same as every other SPIKE INSTRUMENTATION block in this file.
static func _solve_4x4(rows: Array, b: Vector4) -> Vector4:
	var _profile_t0 := Time.get_ticks_usec()
	var result := _solve_4x4_impl(rows, b)
	Terrain4DProfile.add("qef_solve_only", Time.get_ticks_usec() - _profile_t0)
	return result

static func _solve_4x4_impl(rows: Array, b: Vector4) -> Vector4:
	var m: Array = []
	for r in range(4):
		m.append([rows[r].x, rows[r].y, rows[r].z, rows[r].w, b[r]])
	for col in range(4):
		var pivot_row := col
		var max_val := absf(m[col][col])
		for r in range(col + 1, 4):
			if absf(m[r][col]) > max_val:
				max_val = absf(m[r][col])
				pivot_row = r
		if pivot_row != col:
			var tmp = m[col]
			m[col] = m[pivot_row]
			m[pivot_row] = tmp
		var pivot_val = m[col][col]
		if absf(pivot_val) < 1e-12:
			continue
		for r in range(4):
			if r == col:
				continue
			var factor = m[r][col] / pivot_val
			for c in range(col, 5):
				m[r][c] -= factor * m[col][c]
	var result := Vector4()
	for r in range(4):
		var piv = m[r][r]
		result[r] = (m[r][4] / piv) if absf(piv) > 1e-12 else 0.0
	return result

## Runs dual contouring over an axis-aligned 4D grid spanning
## [bounds_min, bounds_max], with the given point counts per axis
## (nx, ny, nz, nw - at least 2 each), sampling `density_fn` (Callable
## taking a Vector4, returning a float) once per grid point.
##
## Returns a Dictionary:
##   unique_vertex_positions: PackedVector4Array, one entry per active cell
##     (already unique by construction - no dedup pass needed downstream).
##   tet_vertex_indices: PackedInt32Array, 4 per tet, indexing into
##     unique_vertex_positions - feed straight into
##     ArrayTetraMesh4D.append_vertices(positions, false) (false = skip its
##     own O(n) linear-scan dedup, since these are already unique) then
##     append_tetra_cell_indices() using the returned index mapping.
##   tet_vertex_normals: PackedVector4Array, 4 per tet (cell-instance order,
##     matching ArrayTetraMesh4D.normal_values with sequential simplex_cell_normal_indices's
##     expected layout - normals are NOT deduped the same way, since that
##     API wants one per cell-vertex-instance regardless).
##   tet_source_ids, tet_count, active_cell_count, grid_point_count,
##   crossing_edge_count, skipped_degenerate_tet_count: as before.
## `world_step`, if non-zero, is used verbatim instead of being re-derived
## from bounds/counts - callers that generate multiple independent grids
## meant to share exact boundary points (e.g. adjacent voxel bricks) must
## pass the SAME world_step to every call, since two divisions that are
## mathematically equal aren't guaranteed to be bit-identical, and a
## brick's shared boundary depends on bit-identical grid-point positions
## with zero cross-brick communication. Omitted (left at the default
## Vector4.ZERO sentinel), generate() derives step internally exactly as
## before - existing single-monolithic-grid callers are unaffected.
static func generate(bounds_min: Vector4, bounds_max: Vector4, nx: int, ny: int, nz: int, nw: int, density_fn: Callable, qef_regularization: float = 0.15, world_step: Vector4 = Vector4.ZERO) -> Dictionary:
	var counts := [nx, ny, nz, nw]
	var step := world_step if world_step != Vector4.ZERO else Vector4(
		(bounds_max.x - bounds_min.x) / float(nx - 1),
		(bounds_max.y - bounds_min.y) / float(ny - 1),
		(bounds_max.z - bounds_min.z) / float(nz - 1),
		(bounds_max.w - bounds_min.w) / float(nw - 1)
	)
	var step_arr := [step.x, step.y, step.z, step.w]

	# Index arithmetic is inlined directly (nx*ny*nz*nw etc.) rather than
	# going through _flat_index([i,j,k,l], counts) in these hot loops -
	# constructing a throwaway 4-element Array on every single lookup
	# (millions of times, especially in the per-cell 16-corner gather below)
	# was the single largest cost in profiling this generator; the flat-
	# index helper is still used for the few call sites outside these
	# tight loops, where the readability is worth the extra allocation.
	# SPIKE INSTRUMENTATION (temporary - see Terrain4DProfile): times each
	# of this function's 3 phases separately - "density evaluation"
	# (phase 1, which for a BRICK regen call is a cheap stored-array
	# lookup, not live noise - live noise is only ever called during
	# VoxelWorld4D's own collapse-check/apron-sampling, instrumented
	# separately there), "QEF" (phase 2: per-cell gradient+QEF solve),
	# and "tet assembly" (phase 3: grid-edge walk + dual-cube
	# tetrahedralization). Remove the Terrain4DProfile lines (and this
	# paragraph) once the spike's numbers are captured.
	var _profile_t0 := Time.get_ticks_usec()
	var density := PackedByteArray()
	density.resize(nx * ny * nz * nw * 2)
	for i in range(nx):
		for j in range(ny):
			for k in range(nz):
				var base_ijk := ((i * ny + j) * nz + k) * nw
				for l in range(nw):
					var pos := bounds_min + Vector4(i * step.x, j * step.y, k * step.z, l * step.w)
					_write_density(density, base_ijk + l, density_fn.call(pos))
	var _phase1_usec := Time.get_ticks_usec() - _profile_t0
	Terrain4DProfile.add("generate_phase1_density", _phase1_usec)
	_profile_t0 = Time.get_ticks_usec()

	var nx1 := nx - 1
	var ny1 := ny - 1
	var nz1 := nz - 1
	var nw1 := nw - 1
	var counts_cell := [nx1, ny1, nz1, nw1]
	var total_cells: int = nx1 * ny1 * nz1 * nw1
	var cell_active := PackedByteArray()
	cell_active.resize(total_cells)
	# Sparse-to-compact index: only ACTIVE cells get a slot in
	# compact_vertices/compact_normals (via cell_compact_index), rather than
	# every cell in the grid having a slot regardless of activity - at real
	# resolutions only a small fraction of cells are ever active (the ones
	# actually touching the surface), so this avoids allocating two
	# PackedVector4Arrays sized to the FULL cell grid.
	var cell_compact_index := PackedInt32Array()
	cell_compact_index.resize(total_cells)
	var compact_vertices := PackedVector4Array()
	var compact_normals := PackedVector4Array()
	var active_cell_count := 0

	for i in range(nx1):
		for j in range(ny1):
			for k in range(nz1):
				for l in range(nw1):
					var corner_density: Array[float] = []
					corner_density.resize(16)
					var corner_pos: Array[Vector4] = []
					corner_pos.resize(16)
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
									corner_density[ci] = _read_density(density, base_gigjgk + gl)
									corner_pos[ci] = bounds_min + Vector4(gi * step.x, gj * step.y, gk * step.z, gl * step.w)
					var min_d: float = corner_density[0]
					var max_d: float = corner_density[0]
					for d in corner_density:
						min_d = minf(min_d, d)
						max_d = maxf(max_d, d)
					if min_d >= 0.0 or max_d <= 0.0:
						continue

					var grad := Vector4(
						_axis_gradient(corner_density, 8, step_arr[0]),
						_axis_gradient(corner_density, 4, step_arr[1]),
						_axis_gradient(corner_density, 2, step_arr[2]),
						_axis_gradient(corner_density, 1, step_arr[3])
					)
					var n := grad.normalized()
					if n.is_zero_approx():
						n = Vector4(0.0, 1.0, 0.0, 0.0)

					var crossing_positions: Array[Vector4] = []
					for ci in range(16):
						for axis in range(4):
							var bitmask := 1 << (3 - axis)
							var nb := ci ^ bitmask
							if nb > ci:
								var da: float = corner_density[ci]
								var db: float = corner_density[nb]
								if (da < 0.0) != (db < 0.0):
									var t: float = da / (da - db)
									crossing_positions.append(corner_pos[ci].lerp(corner_pos[nb], t))
					if crossing_positions.is_empty():
						continue

					var mass := Vector4()
					for p in crossing_positions:
						mass += p
					mass /= float(crossing_positions.size())

					var ata0 := Vector4()
					var ata1 := Vector4()
					var ata2 := Vector4()
					var ata3 := Vector4()
					var atb := Vector4()
					for p in crossing_positions:
						var dp: float = n.dot(p)
						ata0 += Vector4(n.x * n.x, n.x * n.y, n.x * n.z, n.x * n.w)
						ata1 += Vector4(n.y * n.x, n.y * n.y, n.y * n.z, n.y * n.w)
						ata2 += Vector4(n.z * n.x, n.z * n.y, n.z * n.z, n.z * n.w)
						ata3 += Vector4(n.w * n.x, n.w * n.y, n.w * n.z, n.w * n.w)
						atb += n * dp
					ata0.x += qef_regularization
					ata1.y += qef_regularization
					ata2.z += qef_regularization
					ata3.w += qef_regularization
					atb += mass * qef_regularization

					var solved := _solve_4x4([ata0, ata1, ata2, ata3], atb)
					if not solved.is_finite():
						solved = mass
					var lo: Vector4 = corner_pos[0]
					var hi: Vector4 = corner_pos[15]
					# Inset the clamp slightly so a solve that gets pushed all
					# the way to a cell's boundary can never land EXACTLY on
					# it - two adjacent cells share that boundary, and an
					# exact-coincidence there would produce a zero-volume
					# tetrahedron once both cells' dual vertices end up as
					# corners of the same dual cube.
					var inset := Vector4(step_arr[0], step_arr[1], step_arr[2], step_arr[3]) * 0.02
					solved.x = clampf(solved.x, lo.x + inset.x, hi.x - inset.x)
					solved.y = clampf(solved.y, lo.y + inset.y, hi.y - inset.y)
					solved.z = clampf(solved.z, lo.z + inset.z, hi.z - inset.z)
					solved.w = clampf(solved.w, lo.w + inset.w, hi.w - inset.w)

					var cidx := ((i * ny1 + j) * nz1 + k) * nw1 + l
					cell_active[cidx] = 1
					var compact_index := compact_vertices.size()
					compact_vertices.append(solved)
					compact_normals.append(n)
					cell_compact_index[cidx] = compact_index
					active_cell_count += 1
	var _phase2_usec := Time.get_ticks_usec() - _profile_t0
	Terrain4DProfile.add("generate_phase2_qef", _phase2_usec)
	_profile_t0 = Time.get_ticks_usec()

	var out_indices := PackedInt32Array()
	var out_normals := PackedVector4Array()
	var out_source_ids := PackedInt32Array()
	var tet_count := 0
	var skipped_degenerate_tet_count := 0
	var crossing_edge_count := 0
	var next_dual_cube_id := 0

	# Flat-index strides per axis (how much the flat index changes when that
	# axis's coordinate increments by 1) - lets the neighbor-along-axis
	# lookup below be a single addition instead of duplicating the
	# coordinate array and recomputing the index from scratch.
	var strides := [ny * nz * nw, nz * nw, nw, 1]
	# Same idea, but for the CELL grid (one smaller per axis) - used below to
	# reach a neighboring cell's flat index without duplicating/rebuilding a
	# whole coordinate array per corner.
	var cell_strides := [ny1 * nz1 * nw1, nz1 * nw1, nw1, 1]

	for i in range(nx):
		for j in range(ny):
			for k in range(nz):
				var base_ijk2 := ((i * ny + j) * nz + k) * nw
				var base_cell_ijk := ((i * ny1 + j) * nz1 + k) * nw1
				for l in range(nw):
					var g := [i, j, k, l]
					var base_index := base_ijk2 + l
					# Only valid when l stays within the cell grid, but it's
					# only ever read below after the same bound has already
					# been confirmed via the `ok` check, so an out-of-range
					# base_cell_index here is harmless - it's never used.
					var base_cell_index := base_cell_ijk + l
					for axis in range(4):
						if g[axis] > counts[axis] - 2:
							continue
						var others: Array = OTHER_AXES[axis]
						var ok := true
						for oa in others:
							if g[oa] < 1 or g[oa] > counts[oa] - 2:
								ok = false
								break
						if not ok:
							continue
						var d1: float = _read_density(density, base_index)
						var d2: float = _read_density(density, base_index + strides[axis])
						if (d1 < 0.0) == (d2 < 0.0):
							continue
						crossing_edge_count += 1

						var corner_positions8: Array[Vector4] = []
						corner_positions8.resize(8)
						var corner_normals8: Array[Vector4] = []
						corner_normals8.resize(8)
						var corner_indices8: Array[int] = []
						corner_indices8.resize(8)
						var all_found := true
						var stride_a: int = cell_strides[others[0]]
						var stride_b: int = cell_strides[others[1]]
						var stride_c: int = cell_strides[others[2]]
						for local_index in range(8):
							var ua := (local_index >> 2) & 1
							var ub := (local_index >> 1) & 1
							var uc := local_index & 1
							var cidx := base_cell_index + (ua - 1) * stride_a + (ub - 1) * stride_b + (uc - 1) * stride_c
							if cell_active[cidx] == 0:
								all_found = false
								break
							var compact_idx: int = cell_compact_index[cidx]
							corner_positions8[local_index] = compact_vertices[compact_idx]
							corner_normals8[local_index] = compact_normals[compact_idx]
							corner_indices8[local_index] = compact_idx
						if not all_found:
							continue

						# Pick whichever of the two main-diagonal decompositions
						# is better-conditioned for THIS cube's actual point
						# positions (see TET_CORNERS_ALT comment) - minimizes
						# how often a sliver forces a skipped, hole-leaving tet.
						# Lazy: most cubes are nowhere near degenerate, so only
						# bother scoring the alternate decomposition when the
						# main one is already looking marginal - this keeps
						# the common case at the original single-decomposition
						# cost instead of unconditionally doubling every cube's
						# conditioning work.
						var min_condition_main := INF
						for tet in TET_CORNERS:
							var p0m: Vector4 = corner_positions8[tet[0]]
							min_condition_main = minf(min_condition_main, _tet_condition(
								corner_positions8[tet[1]] - p0m, corner_positions8[tet[2]] - p0m, corner_positions8[tet[3]] - p0m
							))
						var chosen_decomposition: Array = TET_CORNERS
						if min_condition_main < 0.3:
							var min_condition_alt := INF
							for tet in TET_CORNERS_ALT:
								var p0a: Vector4 = corner_positions8[tet[0]]
								min_condition_alt = minf(min_condition_alt, _tet_condition(
									corner_positions8[tet[1]] - p0a, corner_positions8[tet[2]] - p0a, corner_positions8[tet[3]] - p0a
								))
							if min_condition_alt > min_condition_main:
								chosen_decomposition = TET_CORNERS_ALT

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
							if _tet_condition(edge1, edge2, edge3) <= 0.01:
								# Still degenerate even in the better of the two
								# decompositions - skip rather than emit a cell
								# that breaks collision-shape construction.
								# Leaves a tiny gap at worst.
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
	var _phase3_usec := Time.get_ticks_usec() - _profile_t0
	Terrain4DProfile.add("generate_phase3_tet", _phase3_usec)

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
		# Local (thread-safe, per-call) phase timings - NOT the shared
		# Terrain4DProfile static accumulator above, which races when
		# multiple WorkerThreadPool regen jobs call this concurrently (each
		# for a different brick). Callers that need a correct aggregate
		# under concurrent regen (see _measure_edit_latency_runner.gd)
		# should sum these per-job return values on the single thread that
		# collects results, not read Terrain4DProfile.snapshot() after the
		# fact.
		"phase1_usec": _phase1_usec,
		"phase2_usec": _phase2_usec,
		"phase3_usec": _phase3_usec,
	}

## PROTOTYPE/SPIKE - native counterpart to generate() above. Phase 1
## (density sampling) is an EXACT duplicate of generate()'s own phase 1 -
## deliberately not factored into a shared helper, since everything after
## this point diverges completely (GDScript phase2/3 loops above vs one
## native call below) and threading a shared helper's output back into two
## different downstream shapes would cost more readability than the ~15
## duplicated lines save.
##
## From "density already sampled" onward, delegates to
## Math4D.dual_contour_extract() (engine/modules/4d/math/
## dual_contour_native_4d.h/.cpp) - a from-scratch C++ port of phases 2
## and 3 (corner-gather/gradient/QEF-solve, then tet decomposition), using
## a proper SPD-specialized Cholesky solve instead of general Gauss-Jordan
## with pivoting for the QEF system (confirmed symmetric positive-definite
## by construction - A^T*A is always PSD, plus a strictly positive
## regularization*I makes it strictly SPD - so the pivot search/row-swap
## machinery the old solver always pays for was pure waste on this input).
## See _verify_dual_contour_native_runner.gd for the correctness check
## this was cleared against BEFORE any benchmark number from this path was
## trusted - same bar the FastNoise2 axis-remap check cleared, not a lower
## one just because this is the important path.
##
## Thread-safety: Math4D.dual_contour_extract() is a pure function of its
## arguments (no shared mutable state, no cache to invalidate) - safe to
## call concurrently from multiple WorkerThreadPool jobs by construction,
## the same as this file's own generate() already is.
static func generate_native(bounds_min: Vector4, bounds_max: Vector4, nx: int, ny: int, nz: int, nw: int, density_fn: Callable, qef_regularization: float = 0.15, world_step: Vector4 = Vector4.ZERO) -> Dictionary:
	var step := world_step if world_step != Vector4.ZERO else Vector4(
		(bounds_max.x - bounds_min.x) / float(nx - 1),
		(bounds_max.y - bounds_min.y) / float(ny - 1),
		(bounds_max.z - bounds_min.z) / float(nz - 1),
		(bounds_max.w - bounds_min.w) / float(nw - 1)
	)

	var _profile_t0 := Time.get_ticks_usec()
	var density := PackedByteArray()
	density.resize(nx * ny * nz * nw * 2)
	for i in range(nx):
		for j in range(ny):
			for k in range(nz):
				var base_ijk := ((i * ny + j) * nz + k) * nw
				for l in range(nw):
					var pos := bounds_min + Vector4(i * step.x, j * step.y, k * step.z, l * step.w)
					_write_density(density, base_ijk + l, density_fn.call(pos))
	var _phase1_usec := Time.get_ticks_usec() - _profile_t0
	Terrain4DProfile.add("generate_phase1_density", _phase1_usec)

	_profile_t0 = Time.get_ticks_usec()
	var result: Dictionary = Math4D.dual_contour_extract(density, nx, ny, nz, nw, bounds_min, step, qef_regularization)
	var _phase23_usec := Time.get_ticks_usec() - _profile_t0
	# The native call does phases 2 AND 3 in one shot - there's no
	# GDScript-visible boundary between them to time separately the way
	# Terrain4DProfile's generate_phase2_qef/generate_phase3_tet stages do
	# for the GDScript path, so this reports the combined cost under its
	# own stage name rather than mislabeling it as just one of the two.
	Terrain4DProfile.add("generate_phase23_native", _phase23_usec)

	result["grid_point_count"] = nx * ny * nz * nw
	result["phase1_usec"] = _phase1_usec
	result["phase2_usec"] = _phase23_usec
	result["phase3_usec"] = 0
	return result
