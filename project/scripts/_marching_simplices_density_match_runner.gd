extends Node
## TEMPORARY, THROWAWAY follow-up to _marching_simplices_compare_runner.gd.
##
## 1. Audits the per-simplex sign-classification logic DIRECTLY (via
## mt_simplex_stats returned by generate_mt): are fully-inside/fully-outside
## simplices actually skipped with zero emitted tets, or does something
## force all 24 to emit regardless of their own classification? Real
## counts, not a read of the code.
##
## 2. generate_mt() now welds vertices (see _marching_simplices_4d_runner.gd) -
## reports the resulting unique_vertex_count vs. the unwelded tet_count*4,
## as a real memory/efficiency number. Welding cannot change tet_count
## (it only merges duplicate positions), so this is NOT expected to change
## the visual facet density on its own.
##
## 3. If the audit shows classification is already correct (the expected
## outcome - the fix is then "choose a coarser grid", not "fix a bug"):
## calibrates a coarser MT-only resolution whose resulting tet_count
## roughly matches DC's tet_count on the SAME surface, then re-screenshots
## MT at that resolution against the ALREADY-SAVED DC screenshot from the
## earlier comparison run - an apples-to-apples visual-DENSITY comparison,
## not a matched-input-grid one.
##
## 4. Re-times/re-counts DC vs MT once density is brought down, since the
## earlier "MT might also be cheaper, no QEF solve" reasoning was based on
## the inflated, always-24-simplices-per-cell tet count.

const MarchingSimplices4DScript = preload("res://scripts/_marching_simplices_4d_runner.gd")

var _mt: MarchingSimplices4DScript

func _ready() -> void:
	_mt = MarchingSimplices4DScript.new()
	await _run()

func _control_sphere_density(p: Vector4) -> float:
	return p.length() - 5.0

func _print_audit(result: Dictionary, label: String) -> void:
	var stats: Dictionary = result.mt_simplex_stats
	var total: int = stats.total
	print("=== SIGN-CLASSIFICATION AUDIT: %s ===" % [label])
	print("crossing_cells=%d  simplices_visited=%d (24 per crossing cell)  skipped_uniform=%d (%.1f%%)  emit_1tet=%d  emit_3tet=%d  resulting_tet_count=%d" % [
		result.active_cell_count, total, stats.skipped_uniform,
		(100.0 * stats.skipped_uniform / float(total)) if total > 0 else 0.0,
		stats.emit_1tet, stats.emit_3tet, result.tet_count
	])
	var unwelded_would_be: int = result.tet_count * 4
	print("unique_vertex_count (post-weld)=%d  vs unwelded_would_be=%d  (%.2fx fewer)" % [
		result.unique_vertex_count, unwelded_would_be,
		(float(unwelded_would_be) / result.unique_vertex_count) if result.unique_vertex_count > 0 else 0.0
	])

func _calibrate_mt_resolution(bounds_min: Vector4, bounds_max: Vector4, base_nx: int, base_ny: int, base_nz: int, base_nw: int, density_fn: Callable, target_tet_count: int, base_mt_tet_count: int, label: String) -> Dictionary:
	print("=== CALIBRATING coarser MT resolution for %s (target tet_count ~ %d, matching DC) ===" % [label, target_tet_count])
	# Cube-root estimate: tet_count scales roughly with resolution^3 for a
	# fixed-size domain (the crossing-cell "shell" is a 3D hypersurface
	# embedded in the 4D grid, same reasoning as DC's own active_cell_count
	# scaling) - a starting guess, refined by actually measuring a couple of
	# neighboring candidates rather than trusting the formula blindly.
	var scale_estimate: float = pow(float(target_tet_count) / float(base_mt_tet_count), 1.0 / 3.0)
	var scale_trials := [scale_estimate, scale_estimate * 1.15, scale_estimate * 0.85]
	var best: Dictionary = {}
	var best_log_error := INF
	for scale_try in scale_trials:
		var nx: int = maxi(4, roundi(base_nx * scale_try))
		var ny: int = maxi(4, roundi(base_ny * scale_try))
		var nz: int = maxi(4, roundi(base_nz * scale_try))
		var nw: int = maxi(4, roundi(base_nw * scale_try))
		var t0 := Time.get_ticks_usec()
		var result: Dictionary = _mt.generate_mt(bounds_min, bounds_max, nx, ny, nz, nw, density_fn)
		var elapsed: float = (Time.get_ticks_usec() - t0) / 1000000.0
		var tet_count: int = result.tet_count
		var log_error: float = abs(log(float(tet_count) / float(target_tet_count)))
		print("  trial nx=%d ny=%d nz=%d nw=%d -> tet_count=%d (target=%d, ratio=%.2fx) wall=%.2fs" % [
			nx, ny, nz, nw, tet_count, target_tet_count, float(tet_count) / float(target_tet_count), elapsed
		])
		if log_error < best_log_error:
			best_log_error = log_error
			best = {"nx": nx, "ny": ny, "nz": nz, "nw": nw, "result": result, "wall_s": elapsed}
	print("  chosen: nx=%d ny=%d nz=%d nw=%d tet_count=%d" % [best.nx, best.ny, best.nz, best.nw, best.result.tet_count])
	return best

func _build_mesh_from_result(result: Dictionary) -> ArrayTetraMesh4D:
	var mesh := ArrayTetraMesh4D.new()
	var indices: PackedInt32Array = mesh.append_vertices(result.unique_vertex_positions, false)
	var tet_indices: PackedInt32Array = result.tet_vertex_indices
	var tet_count: int = result.tet_count
	for t in range(tet_count):
		var base := t * 4
		mesh.append_tetra_cell_indices(
			indices[tet_indices[base + 0]], indices[tet_indices[base + 1]],
			indices[tet_indices[base + 2]], indices[tet_indices[base + 3]]
		)
	mesh.normal_values = result.tet_vertex_normals
	mesh.simplex_cell_normal_indices = PackedInt32Array(range(result.tet_vertex_normals.size()))
	mesh.calculate_boundary_normals()
	return mesh

func _swap_mesh_and_screenshot(terrain: StaticBody4D, mesh: ArrayTetraMesh4D, albedo: Color, image_name: String) -> void:
	var material := TetraMaterial4D.new()
	material.albedo_color = albedo
	terrain.mesh_instance.mesh = mesh
	terrain.mesh_instance.material_override = material
	for i in range(10):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)
	print("SCREENSHOT_SAVED: %s" % [image_name])

func _compose_side_by_side(name_a: String, name_b: String, out_name: String) -> void:
	var a := Image.load_from_file("res://smoke_test_output/" + name_a)
	var b := Image.load_from_file("res://smoke_test_output/" + name_b)
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var gap := 12
	var w: int = a.get_width()
	var h: int = a.get_height()
	var combined := Image.create(w + gap + b.get_width(), maxi(h, b.get_height()), false, Image.FORMAT_RGBA8)
	combined.fill(Color(0.05, 0.05, 0.05, 1.0))
	combined.blit_rect(a, Rect2i(0, 0, w, h), Vector2i(0, 0))
	combined.blit_rect(b, Rect2i(0, 0, b.get_width(), b.get_height()), Vector2i(w + gap, 0))
	combined.save_png("res://smoke_test_output/" + out_name)
	print("COMPOSED_SIDE_BY_SIDE: %s" % [out_name])

func _run_full_case(bounds_min: Vector4, bounds_max: Vector4, base_nx: int, base_ny: int, base_nz: int, base_nw: int, get_density_fn_factory: Callable, image_prefix: String, dc_screenshot_name: String, label: String) -> void:
	print("=== CASE: %s ===" % [label])
	var packed: PackedScene = load("res://sandbox/terrain4d/terrain4d_test.tscn")
	var root: Node = packed.instantiate()
	var terrain: StaticBody4D = root.get_node("World/TerrainRig/Terrain")
	terrain.resolution_horizontal = 2
	terrain.resolution_vertical = 2
	add_child(root)
	for i in range(5):
		await get_tree().process_frame
	var density_fn: Callable = get_density_fn_factory.call(terrain)

	# --- DC reference, at the ORIGINAL resolution (matches the earlier comparison) ---
	var t_dc := Time.get_ticks_usec()
	var dc_result: Dictionary = SingleVertexDualContour4D.generate(bounds_min, bounds_max, base_nx, base_ny, base_nz, base_nw, density_fn, 0.15)
	var dc_wall: float = (Time.get_ticks_usec() - t_dc) / 1000000.0
	print("DC @ original resolution (%dx%dx%dx%d): wall=%.2fs tet_count=%d" % [base_nx, base_ny, base_nz, base_nw, dc_wall, dc_result.tet_count])

	# --- MT at ORIGINAL resolution: audit + welding numbers ---
	var t_mt0 := Time.get_ticks_usec()
	var mt_result0: Dictionary = _mt.generate_mt(bounds_min, bounds_max, base_nx, base_ny, base_nz, base_nw, density_fn)
	var mt_wall0: float = (Time.get_ticks_usec() - t_mt0) / 1000000.0
	print("MT @ original resolution (%dx%dx%dx%d): wall=%.2fs tet_count=%d" % [base_nx, base_ny, base_nz, base_nw, mt_wall0, mt_result0.tet_count])
	_print_audit(mt_result0, label + " @ original resolution")

	# --- calibrate coarser MT resolution to roughly match DC's tet_count ---
	var best: Dictionary = _calibrate_mt_resolution(bounds_min, bounds_max, base_nx, base_ny, base_nz, base_nw, density_fn, dc_result.tet_count, mt_result0.tet_count, label)
	var mt_result_matched: Dictionary = best.result
	_print_audit(mt_result_matched, label + " @ density-matched resolution")

	print("--- SUMMARY: %s ---" % [label])
	print("  DC @ %dx%dx%dx%d: tet_count=%d wall=%.2fs" % [base_nx, base_ny, base_nz, base_nw, dc_result.tet_count, dc_wall])
	print("  MT @ %dx%dx%dx%d (same grid as DC): tet_count=%d wall=%.2fs unique_vertices=%d" % [base_nx, base_ny, base_nz, base_nw, mt_result0.tet_count, mt_wall0, mt_result0.unique_vertex_count])
	print("  MT @ %dx%dx%dx%d (density-matched): tet_count=%d wall=%.2fs unique_vertices=%d" % [best.nx, best.ny, best.nz, best.nw, mt_result_matched.tet_count, best.wall_s, mt_result_matched.unique_vertex_count])

	var mt_mesh := _build_mesh_from_result(mt_result_matched)
	await _swap_mesh_and_screenshot(terrain, mt_mesh, Color(0.2, 0.55, 0.85, 1.0), image_prefix + "_mt_matched.png")

	root.queue_free()
	await get_tree().process_frame

	_compose_side_by_side(dc_screenshot_name, image_prefix + "_mt_matched.png", image_prefix + "_density_matched_side_by_side.png")

func _run() -> void:
	await _run_full_case(
		Vector4(-6, -6, -6, -6), Vector4(6, 6, 6, 6), 24, 24, 24, 24,
		func(_terrain): return Callable(self, "_control_sphere_density"),
		"mc_density_match_sphere",
		"mc_compare_sphere_dc.png",
		"control sphere SDF"
	)

	await _run_full_case(
		Vector4(-8, -4, -8, -8), Vector4(8, 7, 8, 8), 12, 10, 12, 12,
		func(terrain): return Callable(terrain, "get_density"),
		"mc_density_match_terrain",
		"mc_compare_terrain_dc.png",
		"terrain4d_test.tscn density, reduced resolution"
	)

	print("DONE")
	get_tree().quit()
