extends Node
## TEMPORARY, TIME-BOXED diagnostic: is degeneracy in TerrainMeshBackendMT's
## tets a structural/indexing issue in the 24-simplex Kuhn table itself
## (would show up using NEUTRAL, density-independent midpoint crossing
## positions on a plain reference unit hypercube) or purely a consequence
## of specific, unlucky density-dependent interpolation parameters (t near
## 0 or 1)? Sweeps every simplex x every possible sign-split at the
## midpoint (t=0.5, the least-biased choice) and reports the worst
## _tet_condition() found - independent of any real density field.

const BIT_FOR_AXIS := [8, 4, 2, 1]

func _permutations(n: int) -> Array:
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

func _build_simplices() -> Array:
	var simplices := []
	for perm in _permutations(4):
		var corners := [0]
		var acc := 0
		for axis in perm:
			acc = acc ^ BIT_FOR_AXIS[axis]
			corners.append(acc)
		simplices.append(corners)
	return simplices

func _reference_pos(ci: int) -> Vector4:
	return Vector4(
		float((ci >> 3) & 1), float((ci >> 2) & 1),
		float((ci >> 1) & 1), float(ci & 1)
	)

func _tet_condition(edge1: Vector4, edge2: Vector4, edge3: Vector4) -> float:
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

func _combinations(items: Array, k: int) -> Array:
	if k == 0:
		return [[]]
	if items.size() < k:
		return []
	var result := []
	var first = items[0]
	var rest: Array = items.slice(1)
	for combo in _combinations(rest, k - 1):
		result.append([first] + combo)
	for combo in _combinations(rest, k):
		result.append(combo)
	return result

func _condition_of(p0: Vector4, p1: Vector4, p2: Vector4, p3: Vector4) -> float:
	return _tet_condition(p1 - p0, p2 - p0, p3 - p0)

func _ready() -> void:
	var simplices := _build_simplices()
	var all_local := [0, 1, 2, 3, 4]

	var min_1tet := INF
	var min_1tet_info := ""
	var min_3tet := INF
	var min_3tet_info := ""
	var sum_1tet := 0.0
	var count_1tet := 0
	var sum_3tet := 0.0
	var count_3tet := 0
	var below_threshold_1tet := 0
	var below_threshold_3tet := 0
	const THRESHOLD := 0.01

	for s_idx in range(simplices.size()):
		var sc: Array = simplices[s_idx]
		var pos := []
		for ci in sc:
			pos.append(_reference_pos(ci))

		# k == 1 (or symmetric k == 4, same tet shape by construction: cut
		# off one corner, connect its 4 midpoint-crossing edges) - one case
		# per choice of which local index is the isolated corner.
		for iso in all_local:
			var majority: Array = []
			for i in all_local:
				if i != iso:
					majority.append(i)
			var idxs := []
			for j in majority:
				idxs.append((pos[iso] + pos[j]) * 0.5)
			var c: float = _condition_of(idxs[0], idxs[1], idxs[2], idxs[3])
			sum_1tet += c
			count_1tet += 1
			if c < THRESHOLD:
				below_threshold_1tet += 1
			if c < min_1tet:
				min_1tet = c
				min_1tet_info = "simplex#%d sc=%s iso_local=%d" % [s_idx, sc, iso]

		# k == 2 (or symmetric k == 3) - one case per 2-vs-3 split.
		for group_a in _combinations(all_local, 2):
			var group_b: Array = []
			for i in all_local:
				if not (i in group_a):
					group_b.append(i)
			var p00: Vector4 = (pos[group_a[0]] + pos[group_b[0]]) * 0.5
			var p01: Vector4 = (pos[group_a[0]] + pos[group_b[1]]) * 0.5
			var p02: Vector4 = (pos[group_a[0]] + pos[group_b[2]]) * 0.5
			var p10: Vector4 = (pos[group_a[1]] + pos[group_b[0]]) * 0.5
			var p11: Vector4 = (pos[group_a[1]] + pos[group_b[1]]) * 0.5
			var p12: Vector4 = (pos[group_a[1]] + pos[group_b[2]]) * 0.5
			var tets := [
				[p00, p01, p02, p12],
				[p00, p01, p11, p12],
				[p00, p10, p11, p12],
			]
			for tet in tets:
				var c: float = _condition_of(tet[0], tet[1], tet[2], tet[3])
				sum_3tet += c
				count_3tet += 1
				if c < THRESHOLD:
					below_threshold_3tet += 1
				if c < min_3tet:
					min_3tet = c
					min_3tet_info = "simplex#%d sc=%s group_a_local=%s" % [s_idx, sc, group_a]

	print("=== REFERENCE-GEOMETRY DEGENERACY SWEEP (density-independent, t=0.5 midpoints) ===")
	print("1-tet (corner-cut) case: count=%d avg_condition=%.4f min_condition=%.6f (%s)" % [
		count_1tet, sum_1tet / count_1tet, min_1tet, min_1tet_info
	])
	print("  below_threshold(%.2f): %d / %d" % [THRESHOLD, below_threshold_1tet, count_1tet])
	print("3-tet (prism-split) case: count=%d avg_condition=%.4f min_condition=%.6f (%s)" % [
		count_3tet, sum_3tet / count_3tet, min_3tet, min_3tet_info
	])
	print("  below_threshold(%.2f): %d / %d" % [THRESHOLD, below_threshold_3tet, count_3tet])
	print("CONCLUSION: %s" % [
		"STRUCTURAL - even neutral midpoint crossings on the reference cube produce near-degenerate tets for some simplex/split combination; the 24-simplex table (or the fixed prism decomposition) has an inherent thin-tet problem independent of density data." if (min_1tet < THRESHOLD or min_3tet < THRESHOLD) else
		"NOT STRUCTURAL - every reference-geometry case comfortably clears the degeneracy threshold at neutral midpoint crossings; real degenerate tets are a consequence of specific, unlucky density-dependent interpolation parameters (crossing points landing near a corner), not an indexing/table bug."
	])
	print("DONE")
	get_tree().quit()
