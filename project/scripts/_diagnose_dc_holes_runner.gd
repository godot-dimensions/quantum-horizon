extends Node
## TEMPORARY - root-cause diagnosis ONLY (no fixes) for the gap/spike
## defect confirmed in terrain4d_test.tscn, which reproduces in the
## UNTOUCHED single-monolithic-grid SingleVertexDualContour4D.generate() path (no
## bricking involved at all).
##
## Part A: renders the native-port correctness suite's small "real
## production heightfield" fixture (6^4 grid) to check whether the same
## kind of defect reproduces at a much smaller scale.
##
## Part B: runs the EXACT terrain_generator.gd density/grid (same
## noise_seed/frequency/amplitude/persistence, same smooth_max box-closing,
## same 21x16x21x21 resolution) through SingleVertexDualContour4D.generate(), then
## builds a face-adjacency histogram over the returned tet_vertex_indices:
## for a closed/watertight tetrahedral hypersurface, every triangular FACE
## of every tet should be shared by EXACTLY 2 tets (the 4D analog of "every
## edge of a closed triangle mesh is shared by exactly 2 triangles"). A
## face referenced by only 1 tet is a direct, exact signature of a hole -
## no camera/screen-space geometry needed to find it. A face referenced by
## 3+ tets is a different bug shape (overlap/duplication).
##
## For each found hole-boundary face, reports its world position and the
## dual-cube ID(s) (tet_source_ids) of the tet(s) that reference it, and
## resamples the surrounding grid corners' density directly - which lets
## the two competing hypotheses (a dual cube skipped because not all 8 of
## its corner cells were active vs. two ADJACENT dual cubes independently
## picking different tet-diagonal decompositions on what should be the
## same shared face) be told apart by direct inspection.

func _box_density(p: Vector4, half_horizontal: float, y_center: float, half_y: float) -> float:
	return maxf(
		maxf(absf(p.x) - half_horizontal, absf(p.y - y_center) - half_y),
		maxf(absf(p.z) - half_horizontal, absf(p.w) - half_horizontal)
	)

static func _smooth_max(a: float, b: float, k: float) -> float:
	if k <= 0.0:
		return maxf(a, b)
	var h := clampf(0.5 - 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) + k * h * (1.0 - h)

# --- Exact terrain_generator.gd defaults ---
const NOISE_SEED := 1
const BOUNDS_HALF_EXTENT_H := 8.0
const BOUNDS_MIN_Y := -4.0
const BOUNDS_MAX_Y := 7.0
const RES_H := 21
const RES_V := 16
const NOISE_FREQUENCY := 0.18
const NOISE_AMPLITUDE := 6.0
const NOISE_PERSISTENCE := 0.55
const GROUND_LEVEL := 0.0
const QEF_REGULARIZATION := 0.15
const BOUNDARY_MARGIN_H := 1.0
const BOUNDARY_MARGIN_V := 1.0
const SEAM_SMOOTHING := 0.6

var _noise: Noise4D

func get_density(p: Vector4) -> float:
	var height_field := p.y - GROUND_LEVEL - NOISE_AMPLITUDE * _noise.fractal_noise(p * NOISE_FREQUENCY, 3, NOISE_PERSISTENCE, 2.0)
	var half_horizontal := BOUNDS_HALF_EXTENT_H - BOUNDARY_MARGIN_H
	var y_center := (BOUNDS_MIN_Y + BOUNDS_MAX_Y) * 0.5
	var half_y := (BOUNDS_MAX_Y - BOUNDS_MIN_Y) * 0.5 - BOUNDARY_MARGIN_V
	var box := _box_density(p, half_horizontal, y_center, half_y)
	return _smooth_max(height_field, box, SEAM_SMOOTHING)

func _ready() -> void:
	_noise = Noise4D.new(NOISE_SEED)
	await _run()

func _ready_fixture_density(p: Vector4) -> float:
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

## Reuses the REAL terrain4d_test.tscn scene (proven camera/World4D setup,
## no guessing at Camera4D/World4D construction from scratch) at a reduced
## resolution - overriding exported properties before add_child(), the
## same safe pattern _measure_live_popin_latency_runner.gd already
## established this session - so this is a genuine visual check through
## the actual working rendering path, not a hand-built one that might be
## wrong in some unrelated way.
func _screenshot_terrain_generator_at_resolution(res_h: int, res_v: int, image_name: String) -> void:
	var packed: PackedScene = load("res://sandbox/terrain4d/terrain4d_test.tscn")
	var root: Node = packed.instantiate()
	var terrain: StaticBody4D = root.get_node("World/TerrainRig/Terrain")
	terrain.resolution_horizontal = res_h
	terrain.resolution_vertical = res_v
	add_child(root)  # _ready() fires here, using the overridden resolution above
	for i in range(10):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)
	var result: Dictionary = terrain.get_last_result()
	_analyze_faces(result, "terrain4d_test.tscn at reduced resolution %dx%dx%dx%d" % [res_h, res_v, res_h, res_h])
	root.queue_free()
	await get_tree().process_frame

func _face_key(a: int, b: int, c: int) -> String:
	var arr := [a, b, c]
	arr.sort()
	return "%d_%d_%d" % [arr[0], arr[1], arr[2]]

func _analyze_faces(result: Dictionary, label: String) -> Array:
	var tet_indices: PackedInt32Array = result.tet_vertex_indices
	var tet_source_ids: PackedInt32Array = result.tet_source_ids
	var positions: PackedVector4Array = result.unique_vertex_positions
	var tet_count: int = result.tet_count
	print("=== FACE ADJACENCY ANALYSIS: %s (tet_count=%d, active_cell_count=%d, crossing_edge_count=%d, skipped_degenerate_tet_count=%d) ===" % [
		label, tet_count, result.active_cell_count, result.crossing_edge_count, result.skipped_degenerate_tet_count
	])

	# face_key -> Array of {tet_index, source_id}
	var face_map := {}
	for t in range(tet_count):
		var base := t * 4
		var v := [tet_indices[base], tet_indices[base + 1], tet_indices[base + 2], tet_indices[base + 3]]
		var faces := [
			[v[0], v[1], v[2]], [v[0], v[1], v[3]], [v[0], v[2], v[3]], [v[1], v[2], v[3]],
		]
		for f in faces:
			var key := _face_key(f[0], f[1], f[2])
			if not face_map.has(key):
				face_map[key] = []
			face_map[key].append({"tet": t, "source_id": tet_source_ids[t], "verts": f})

	var count1 := 0
	var count2 := 0
	var count3plus := 0
	var hole_faces := []
	for key in face_map:
		var refs: Array = face_map[key]
		if refs.size() == 1:
			count1 += 1
			hole_faces.append(refs[0])
		elif refs.size() == 2:
			count2 += 1
		else:
			count3plus += 1

	print("distinct_faces=%d  referenced_1x(HOLE_BOUNDARY)=%d  referenced_2x(properly_shared)=%d  referenced_3x_plus(OVERLAP)=%d" % [
		face_map.size(), count1, count2, count3plus
	])

	if count1 == 0:
		print("no singly-referenced faces found - mesh is a closed/watertight hypersurface by this test")
		return []

	# Cluster hole faces by rough world position (round to 1 decimal) so
	# nearby singly-referenced faces (likely edges of the SAME hole) group
	# together instead of printing hundreds of near-duplicate lines.
	var clusters := {}
	for hf in hole_faces:
		var verts: Array = hf.verts
		var centroid := Vector4.ZERO
		for vi in verts:
			centroid += positions[vi]
		centroid /= 3.0
		var cluster_key := "%.1f_%.1f_%.1f_%.1f" % [centroid.x, centroid.y, centroid.z, centroid.w]
		if not clusters.has(cluster_key):
			clusters[cluster_key] = {"centroid": centroid, "entries": []}
		clusters[cluster_key].entries.append(hf)

	var cluster_list: Array = clusters.values()
	cluster_list.sort_custom(func(a, b): return a.entries.size() > b.entries.size())

	# Classify every cluster (not just the ones printed below) into the two
	# competing mechanisms: a cluster touched by 2+ DISTINCT dual-cube IDs
	# is direct evidence of adjacent cubes disagreeing on a shared face
	# (inconsistent diagonal choice); a cluster touched by exactly 1 ID
	# with MORE unpaired faces than a single cube's genuine corner/edge
	# faces would plausibly produce (>2, since a real corner of the whole
	# shape can legitimately expose 1-2 unmatched faces) points instead at
	# that cube being orphaned - some/all of its neighbors were never built.
	var multi_id_clusters := 0
	var multi_id_faces := 0
	var single_id_many_clusters := 0
	var single_id_many_faces := 0
	var single_id_few_clusters := 0
	var single_id_few_faces := 0
	for cluster in cluster_list:
		var entries: Array = cluster.entries
		var ids := {}
		for e in entries:
			ids[e.source_id] = true
		if ids.size() >= 2:
			multi_id_clusters += 1
			multi_id_faces += entries.size()
		elif entries.size() > 2:
			single_id_many_clusters += 1
			single_id_many_faces += entries.size()
		else:
			single_id_few_clusters += 1
			single_id_few_faces += entries.size()
	print("MECHANISM CLASSIFICATION (%d total hole-boundary faces across %d clusters):" % [count1, cluster_list.size()])
	print("  multi_dual_cube_id_clusters (INCONSISTENT DIAGONAL signature): %d clusters, %d faces (%.1f%% of hole faces)" % [
		multi_id_clusters, multi_id_faces, 100.0 * multi_id_faces / float(count1)
	])
	print("  single_id_many_faces_clusters (ORPHANED/ISOLATED CUBE signature, >2 unpaired faces from one cube): %d clusters, %d faces (%.1f%% of hole faces)" % [
		single_id_many_clusters, single_id_many_faces, 100.0 * single_id_many_faces / float(count1)
	])
	print("  single_id_1to2_faces_clusters (ambiguous/could be either, or a legitimate rare corner): %d clusters, %d faces (%.1f%% of hole faces)" % [
		single_id_few_clusters, single_id_few_faces, 100.0 * single_id_few_faces / float(count1)
	])

	print("hole_boundary_faces_cluster_into_%d_distinct_locations (rounded to 0.1 world units):" % [cluster_list.size()])
	var shown := 0
	for cluster in cluster_list:
		if shown >= 25:
			print("  ... (%d more clusters not shown)" % [cluster_list.size() - shown])
			break
		var entries: Array = cluster.entries
		var source_ids := {}
		for e in entries:
			source_ids[e.source_id] = true
		print("  location=%s  hole_faces_here=%d  distinct_dual_cube_ids_touching=%s" % [
			cluster.centroid, entries.size(), str(source_ids.keys())
		])
		shown += 1

	var centroids := []
	for cluster in cluster_list:
		centroids.append(cluster.centroid)
	return centroids

func _dump_cell_diagnostics(density_fn: Callable, center: Vector4, step: Vector4, label: String) -> void:
	print("--- CELL DIAGNOSTICS near %s (%s) ---" % [center, label])
	var half := step * 0.5
	var corners := []
	for bi in range(2):
		for bj in range(2):
			for bk in range(2):
				for bl in range(2):
					var offset := Vector4(
						(bi - 0.5) * step.x, (bj - 0.5) * step.y, (bk - 0.5) * step.z, (bl - 0.5) * step.w
					)
					var pos: Vector4 = center + offset
					var d: float = density_fn.call(pos)
					corners.append({"pos": pos, "density": d})
	var any_zero := false
	var any_nan := false
	var min_d := INF
	var max_d := -INF
	for c in corners:
		var d: float = c.density
		if is_nan(d) or not is_finite(d):
			any_nan = true
		if absf(d) < 1e-9:
			any_zero = true
		min_d = minf(min_d, d)
		max_d = maxf(max_d, d)
	print("  16 corner densities: min=%.6f max=%.6f any_exact_zero=%s any_nan_or_inf=%s mixed_sign=%s" % [
		min_d, max_d, any_zero, any_nan, (min_d < 0.0 and max_d > 0.0)
	])
	for c in corners:
		print("    pos=%s density=%.6f" % [c.pos, c.density])

func _control_sphere_density(p: Vector4) -> float:
	return p.length() - 5.0

func _run() -> void:
	# --- Part C (control): a plain, perfectly smooth sphere SDF - no
	# smooth_max seam, no box-closing kink, no noise at all - on a grid
	# comfortably larger than the sphere so essentially every crossing
	# edge is a true grid-interior case with a full ring of neighbors.
	# This calibrates what count==1 rate the SAME algorithm produces on a
	# textbook-clean, unambiguous input, before judging whether
	# terrain_generator.gd's own rate (measured above/below) is normal or
	# elevated.
	print("=== PART C (CONTROL): plain sphere SDF, no smooth_max/noise, 24^4 grid ===")
	var t0c := Time.get_ticks_usec()
	var result_c: Dictionary = SingleVertexDualContour4D.generate(Vector4(-6, -6, -6, -6), Vector4(6, 6, 6, 6), 24, 24, 24, 24, Callable(self, "_control_sphere_density"), 0.15)
	print("generate() wall time: %.2f s" % [(Time.get_ticks_usec() - t0c) / 1000000.0])
	_analyze_faces(result_c, "PART C control sphere SDF (24^4)")


	# --- Part A: the exact native-port correctness suite fixture (data-only
	# face-adjacency check - this alone conclusively answers "does a hole
	# exist here", no screenshot needed to detect it). ---
	print("=== PART A: native-port correctness suite's small (6^4) real-production-heightfield fixture ===")
	var step_a := 0.75
	var bounds_min_a := Vector4.ZERO
	var bounds_max_a := Vector4(5.0 * step_a, 5.0 * step_a, 5.0 * step_a, 5.0 * step_a)
	var result_a: Dictionary = SingleVertexDualContour4D.generate(bounds_min_a, bounds_max_a, 6, 6, 6, 6, Callable(self, "_ready_fixture_density"), 0.15, Vector4(step_a, step_a, step_a, step_a))
	var hole_centroids_a: Array = _analyze_faces(result_a, "PART A small fixture (6^4), same as verify suite CASE 2")
	for i in range(mini(2, hole_centroids_a.size())):
		_dump_cell_diagnostics(Callable(self, "_ready_fixture_density"), hole_centroids_a[i], Vector4(step_a, step_a, step_a, step_a), "PART A CASE 2 hole cluster #%d" % [i])

	var bounds_min_a3 := Vector4(3.0 * step_a, -2.0 * step_a, 7.0 * step_a, -4.0 * step_a)
	var bounds_max_a3 := bounds_min_a3 + Vector4(5.0 * step_a, 5.0 * step_a, 5.0 * step_a, 5.0 * step_a)
	var result_a3: Dictionary = SingleVertexDualContour4D.generate(bounds_min_a3, bounds_max_a3, 6, 6, 6, 6, Callable(self, "_ready_fixture_density"), 0.15, Vector4(step_a, step_a, step_a, step_a))
	var hole_centroids_a3: Array = _analyze_faces(result_a3, "PART A offset fixture (6^4), same as verify suite CASE 3")
	for i in range(mini(2, hole_centroids_a3.size())):
		_dump_cell_diagnostics(Callable(self, "_ready_fixture_density"), hole_centroids_a3[i], Vector4(step_a, step_a, step_a, step_a), "PART A CASE 3 hole cluster #%d" % [i])

	# --- Part A2: a genuine VISUAL small-scale repro, using the real
	# terrain4d_test.tscn scene/camera (proven setup, not hand-built) at a
	# drastically reduced resolution but the SAME density function/shape
	# (volumetric smooth_max, not a heightfield) as the actual reported bug -
	# a more direct "smaller reproduction" of the SPECIFIC observed defect
	# than the verify suite's differently-shaped fixture above. ---
	print("=== PART A2: real terrain4d_test.tscn scene at reduced resolution (visual + face-adjacency) ===")
	await _screenshot_terrain_generator_at_resolution(8, 6, "diagnose_part_a2_tiny_8x6.png")
	await _screenshot_terrain_generator_at_resolution(12, 10, "diagnose_part_a2_small_12x10.png")

	# --- Part B: exact terrain_generator.gd repro (already visually
	# confirmed at this exact resolution via terrain4d_test.tscn's own
	# screenshot in the bisection step - no need to re-screenshot here,
	# just run the face-adjacency test against the SAME real parameters). ---
	print("=== PART B: exact terrain_generator.gd density/grid (21x16x21x21) ===")
	var bounds_min_b := Vector4(-BOUNDS_HALF_EXTENT_H, BOUNDS_MIN_Y, -BOUNDS_HALF_EXTENT_H, -BOUNDS_HALF_EXTENT_H)
	var bounds_max_b := Vector4(BOUNDS_HALF_EXTENT_H, BOUNDS_MAX_Y, BOUNDS_HALF_EXTENT_H, BOUNDS_HALF_EXTENT_H)
	var step_b := Vector4(
		(bounds_max_b.x - bounds_min_b.x) / float(RES_H - 1),
		(bounds_max_b.y - bounds_min_b.y) / float(RES_V - 1),
		(bounds_max_b.z - bounds_min_b.z) / float(RES_H - 1),
		(bounds_max_b.w - bounds_min_b.w) / float(RES_H - 1)
	)
	print("step_b=%s" % [step_b])
	var t0 := Time.get_ticks_usec()
	var result_b: Dictionary = SingleVertexDualContour4D.generate(bounds_min_b, bounds_max_b, RES_H, RES_V, RES_H, RES_H, Callable(self, "get_density"), QEF_REGULARIZATION)
	print("generate() wall time: %.2f s" % [(Time.get_ticks_usec() - t0) / 1000000.0])
	var hole_centroids: Array = _analyze_faces(result_b, "PART B terrain_generator.gd exact repro")

	# Dump cell diagnostics at the biggest hole clusters found, resampling
	# the REAL density function directly at those world positions - this is
	# what actually answers "any exact zeros / NaN / degenerate result?" at
	# the specific offending location(s), not a guess from a screenshot.
	var dump_count: int = mini(3, hole_centroids.size())
	for i in range(dump_count):
		_dump_cell_diagnostics(Callable(self, "get_density"), hole_centroids[i], step_b, "PART B hole cluster #%d" % [i])

	print("DONE")
	get_tree().quit()
