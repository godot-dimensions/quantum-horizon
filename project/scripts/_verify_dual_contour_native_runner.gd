extends Node
## TEMPORARY - verifies DualContour4D.generate_native() (native QEF-solve/
## gradient/tet-assembly port, see engine/modules/4d/math/
## dual_contour_native_4d.h/.cpp) against generate() (the existing,
## trusted GDScript implementation) on IDENTICAL input, before trusting
## any benchmark number from the native path - same bar the FastNoise2
## axis-remap check cleared, not a lower one just because this is the
## more important path.
##
## Two cases: a small hand-designed SDF (few active cells, easy to reason
## about) and a real production-shaped brick (native OpenSimplexNoise
## heightfield, same density source/step/grid size the live pipeline
## actually uses).

const EPSILON := 1e-4

func _sphere_density(p: Vector4) -> float:
	return p.length() - 2.0

func _heightfield_density(p: Vector4) -> float:
	var total := 0.0
	var amplitude := 1.0
	var frequency := 0.06
	var max_value := 0.0
	for i in range(3):
		total += Math4D.noise_4d(1, p.x * frequency, 0.0, p.z * frequency, p.w * frequency) * amplitude
		max_value += amplitude
		amplitude *= 0.55
		frequency *= 2.0
	var height := 6.0 * (total / max_value)
	return p.y - height

func _vec4_close(a: Vector4, b: Vector4, eps: float) -> bool:
	return absf(a.x - b.x) < eps and absf(a.y - b.y) < eps and absf(a.z - b.z) < eps and absf(a.w - b.w) < eps

func _compare(label: String, gd: Dictionary, native: Dictionary) -> bool:
	var all_ok := true
	print("--- %s ---" % [label])

	var ok_active: bool = (gd.active_cell_count == native.active_cell_count)
	print("active_cell_count: gdscript=%d native=%d match=%s" % [gd.active_cell_count, native.active_cell_count, ok_active])
	all_ok = all_ok and ok_active

	var ok_tet: bool = (gd.tet_count == native.tet_count)
	print("tet_count: gdscript=%d native=%d match=%s" % [gd.tet_count, native.tet_count, ok_tet])
	all_ok = all_ok and ok_tet

	var ok_crossing: bool = (gd.crossing_edge_count == native.crossing_edge_count)
	print("crossing_edge_count: gdscript=%d native=%d match=%s" % [gd.crossing_edge_count, native.crossing_edge_count, ok_crossing])
	all_ok = all_ok and ok_crossing

	var ok_skipped: bool = (gd.skipped_degenerate_tet_count == native.skipped_degenerate_tet_count)
	print("skipped_degenerate_tet_count: gdscript=%d native=%d match=%s" % [gd.skipped_degenerate_tet_count, native.skipped_degenerate_tet_count, ok_skipped])
	all_ok = all_ok and ok_skipped

	var gd_positions: PackedVector4Array = gd.unique_vertex_positions
	var native_positions: PackedVector4Array = native.unique_vertex_positions
	var ok_vertex_count := gd_positions.size() == native_positions.size()
	print("unique_vertex_count: gdscript=%d native=%d match=%s" % [gd_positions.size(), native_positions.size(), ok_vertex_count])
	all_ok = all_ok and ok_vertex_count

	var ok_positions := true
	var max_position_diff := 0.0
	if ok_vertex_count:
		for i in range(gd_positions.size()):
			var diff: Vector4 = gd_positions[i] - native_positions[i]
			var d := maxf(maxf(absf(diff.x), absf(diff.y)), maxf(absf(diff.z), absf(diff.w)))
			max_position_diff = maxf(max_position_diff, d)
			if not _vec4_close(gd_positions[i], native_positions[i], EPSILON):
				ok_positions = false
	print("vertex_positions_match(eps=%.6f): %s (max_component_diff=%.8f)" % [EPSILON, ok_positions, max_position_diff])
	all_ok = all_ok and ok_positions

	var gd_indices: PackedInt32Array = gd.tet_vertex_indices
	var native_indices: PackedInt32Array = native.tet_vertex_indices
	var ok_indices := gd_indices == native_indices
	print("tet_vertex_indices_exact_match: %s (gdscript_len=%d native_len=%d)" % [ok_indices, gd_indices.size(), native_indices.size()])
	all_ok = all_ok and ok_indices

	var gd_source_ids: PackedInt32Array = gd.tet_source_ids
	var native_source_ids: PackedInt32Array = native.tet_source_ids
	var ok_source_ids := gd_source_ids == native_source_ids
	print("tet_source_ids_exact_match: %s" % [ok_source_ids])
	all_ok = all_ok and ok_source_ids

	var gd_normals: PackedVector4Array = gd.tet_vertex_normals
	var native_normals: PackedVector4Array = native.tet_vertex_normals
	var ok_normal_count := gd_normals.size() == native_normals.size()
	var ok_normals := ok_normal_count
	var max_normal_diff := 0.0
	if ok_normal_count:
		for i in range(gd_normals.size()):
			var diff: Vector4 = gd_normals[i] - native_normals[i]
			var d := maxf(maxf(absf(diff.x), absf(diff.y)), maxf(absf(diff.z), absf(diff.w)))
			max_normal_diff = maxf(max_normal_diff, d)
			if not _vec4_close(gd_normals[i], native_normals[i], EPSILON):
				ok_normals = false
	print("tet_vertex_normals_match(eps=%.6f): %s (max_component_diff=%.8f)" % [EPSILON, ok_normals, max_normal_diff])
	all_ok = all_ok and ok_normals

	print("%s: ALL_OK=%s" % [label, all_ok])
	return all_ok

func _ready() -> void:
	var overall_ok := true

	# Case 1: small hand-designed SDF, few cells, easy to reason about.
	var bounds_min1 := Vector4(-3.0, -3.0, -3.0, -3.0)
	var bounds_max1 := Vector4(3.0, 3.0, 3.0, 3.0)
	var gd1 := DualContour4D.generate(bounds_min1, bounds_max1, 6, 6, 6, 6, Callable(self, "_sphere_density"), 0.15)
	var native1 := DualContour4D.generate_native(bounds_min1, bounds_max1, 6, 6, 6, 6, Callable(self, "_sphere_density"), 0.15)
	overall_ok = _compare("CASE 1: small SDF sphere, 6^4 grid", gd1, native1) and overall_ok

	# Case 2: real production-shaped brick - same step/grid size/density
	# source as the live pipeline (native OpenSimplexNoise heightfield,
	# ACTUAL_POINTS_PER_AXIS=6, step=0.75).
	var step := 0.75
	var bounds_min2 := Vector4.ZERO
	var bounds_max2 := Vector4(5.0 * step, 5.0 * step, 5.0 * step, 5.0 * step)
	var gd2 := DualContour4D.generate(bounds_min2, bounds_max2, 6, 6, 6, 6, Callable(self, "_heightfield_density"), 0.15, Vector4(step, step, step, step))
	var native2 := DualContour4D.generate_native(bounds_min2, bounds_max2, 6, 6, 6, 6, Callable(self, "_heightfield_density"), 0.15, Vector4(step, step, step, step))
	overall_ok = _compare("CASE 2: real production heightfield brick, 6^4 grid", gd2, native2) and overall_ok

	# Case 3: a second brick offset by a non-trivial amount, to exercise
	# different corner-gather/gradient/QEF/tet-decomposition branches than
	# case 2 landed on (a different slice of the same noise field almost
	# certainly has different active-cell geometry and a different
	# main-vs-alt tet decomposition mix).
	var bounds_min3 := Vector4(3.0 * step, -2.0 * step, 7.0 * step, -4.0 * step)
	var bounds_max3 := bounds_min3 + Vector4(5.0 * step, 5.0 * step, 5.0 * step, 5.0 * step)
	var gd3 := DualContour4D.generate(bounds_min3, bounds_max3, 6, 6, 6, 6, Callable(self, "_heightfield_density"), 0.15, Vector4(step, step, step, step))
	var native3 := DualContour4D.generate_native(bounds_min3, bounds_max3, 6, 6, 6, 6, Callable(self, "_heightfield_density"), 0.15, Vector4(step, step, step, step))
	overall_ok = _compare("CASE 3: real production heightfield brick, offset location", gd3, native3) and overall_ok

	print("OVERALL_ALL_CASES_OK: %s" % [overall_ok])
	print("DONE")
	get_tree().quit()
