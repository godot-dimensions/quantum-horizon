extends Node
## TEMPORARY diagnostic: same reference-geometry sweep as
## _diagnose_mt_reference_geometry_runner.gd, extended to compare the
## CURRENT triangular-prism split (fan from group_a[0], sharing diagonal
## group_a[0]-group_b[2]) against an ALTERNATE valid decomposition (fan
## from group_a[1]/group_b[0], sharing diagonal group_a[1]-group_b[0] -
## the other standard way to slice a triangular prism into 3 tets).
## Reports: (a) the exact (simplex, group_a) combos flagged degenerate
## under CURRENT - needed to build a targeted per-case lookup table -  and
## whether ALTERNATE clears each one, (b) total degenerate-case counts for
## CURRENT vs ALTERNATE across the whole sweep, for the fallback decision
## if the targeted fix doesn't fully resolve the visible pattern.

const BIT_FOR_AXIS := [8, 4, 2, 1]
const THRESHOLD := 0.01

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

## CURRENT split (matches _simplex_to_tets in terrain4d_mesh_backend_mt.gd):
## fan sharing diagonal group_a[0]-group_b[2].
func _current_min_condition(a0: Vector4, a1: Vector4, b0: Vector4, b1: Vector4, b2: Vector4) -> float:
	var p00 := (a0 + b0) * 0.5
	var p01 := (a0 + b1) * 0.5
	var p02 := (a0 + b2) * 0.5
	var p10 := (a1 + b0) * 0.5
	var p11 := (a1 + b1) * 0.5
	var p12 := (a1 + b2) * 0.5
	var m := INF
	m = minf(m, _condition_of(p00, p01, p02, p12))
	m = minf(m, _condition_of(p00, p01, p11, p12))
	m = minf(m, _condition_of(p00, p10, p11, p12))
	return m

## ALTERNATE split: the other standard way to slice the same prism into 3
## tets - fan sharing diagonal group_a[1]-group_b[0] instead.
func _alternate_min_condition(a0: Vector4, a1: Vector4, b0: Vector4, b1: Vector4, b2: Vector4) -> float:
	var p00 := (a0 + b0) * 0.5
	var p01 := (a0 + b1) * 0.5
	var p02 := (a0 + b2) * 0.5
	var p10 := (a1 + b0) * 0.5
	var p11 := (a1 + b1) * 0.5
	var p12 := (a1 + b2) * 0.5
	var m := INF
	m = minf(m, _condition_of(p00, p01, p02, p10))
	m = minf(m, _condition_of(p01, p02, p10, p11))
	m = minf(m, _condition_of(p02, p10, p11, p12))
	return m

func _ready() -> void:
	var simplices := _build_simplices()
	var all_local := [0, 1, 2, 3, 4]

	var current_degenerate := 0
	var alternate_degenerate := 0
	var flagged_combos := []  # [simplex_idx, group_a_local (sorted Array)]
	var resolved_count := 0
	var still_degenerate_count := 0
	var total := 0

	for s_idx in range(simplices.size()):
		var sc: Array = simplices[s_idx]
		var pos := []
		for ci in sc:
			pos.append(_reference_pos(ci))

		for group_a in _combinations(all_local, 2):
			var group_b: Array = []
			for i in all_local:
				if not (i in group_a):
					group_b.append(i)
			var a0: Vector4 = pos[group_a[0]]
			var a1: Vector4 = pos[group_a[1]]
			var b0: Vector4 = pos[group_b[0]]
			var b1: Vector4 = pos[group_b[1]]
			var b2: Vector4 = pos[group_b[2]]

			total += 1
			var c_cur := _current_min_condition(a0, a1, b0, b1, b2)
			var c_alt := _alternate_min_condition(a0, a1, b0, b1, b2)
			var cur_bad := c_cur < THRESHOLD
			var alt_bad := c_alt < THRESHOLD
			if cur_bad:
				current_degenerate += 1
				flagged_combos.append([s_idx, group_a])
				if alt_bad:
					still_degenerate_count += 1
				else:
					resolved_count += 1
			if alt_bad:
				alternate_degenerate += 1

	print("=== ALTERNATE PRISM-SPLIT DIAGNOSTIC (3-tet prism-split case only, %d total combos) ===" % [total])
	print("CURRENT split degenerate count: %d / %d (%.1f%%)" % [current_degenerate, total, 100.0 * current_degenerate / total])
	print("ALTERNATE split degenerate count: %d / %d (%.1f%%)" % [alternate_degenerate, total, 100.0 * alternate_degenerate / total])
	print("Of the %d combos flagged degenerate under CURRENT:" % [current_degenerate])
	print("  resolved by switching to ALTERNATE: %d" % [resolved_count])
	print("  still degenerate even under ALTERNATE: %d" % [still_degenerate_count])
	print("--- flagged combo list (simplex_idx, group_a_local) - for the targeted lookup table ---")
	for combo in flagged_combos:
		print("  simplex#%d group_a_local=%s" % [combo[0], combo[1]])
	print("--- FALLBACK GUIDANCE (if targeted fix doesn't fully resolve the visible pattern) ---")
	print("Fewer total degenerate cases: %s" % ["ALTERNATE" if alternate_degenerate < current_degenerate else ("CURRENT" if current_degenerate < alternate_degenerate else "TIE")])
	print("DONE")
	get_tree().quit()
