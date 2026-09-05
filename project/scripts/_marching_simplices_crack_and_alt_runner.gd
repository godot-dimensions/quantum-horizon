extends Node
## TEMPORARY, THROWAWAY follow-up to _marching_simplices_density_match_runner.gd.
##
## A. Re-runs the exact position-keyed face-adjacency crack test at the
## ACTUAL density-matched grids used in the last screenshots (14^4 sphere,
## 8x6x8x8 terrain) - the earlier 0.0% result was only ever confirmed at
## the original, finer resolution (24^4 / 12x10x12x12), not here.
##
## B. Diagnoses the visible gap in the terrain screenshot's leg: runs DC at
## the SAME 8x6x8x8 resolution (not its original 12x10x12x12) so both
## algorithms are compared at the identical coarse grid, and checks whether
## the gap location is a genuine face-adjacency hole (a crack) or shows up
## in BOTH algorithms at this resolution (an under-resolved thin feature -
## a shared aliasing problem, not an MT-specific defect).
##
## C. Tries a checkerboard-parity alternating triangulation scheme (see
## generate_mt's alternate_scheme param) as a fix for the regular/faceted
## look, and tests it against TWO INDEPENDENT, BOTH-REQUIRED conditions:
## does it visibly reduce the grid-aligned regularity, AND does it still
## pass the 0% unpaired-face crack test. These are reported separately -
## a visual improvement that fails the crack test is a failure, not a win.

const MarchingSimplices4DScript = preload("res://scripts/_marching_simplices_4d_runner.gd")

var _mt: MarchingSimplices4DScript

func _ready() -> void:
	_mt = MarchingSimplices4DScript.new()
	await _run()

func _control_sphere_density(p: Vector4) -> float:
	return p.length() - 5.0

## Position-based (not index-based) - see _marching_simplices_compare_runner.gd
## for why: MT's output isn't deduplicated to one index per unique
## position the way DC's is, so index-equality alone would misreport
## welded-but-differently-indexed vertices as distinct. Position keys work
## uniformly for DC, MT, and MT-alternating output alike.
func _pos_key(p: Vector4) -> String:
	return "%.5f,%.5f,%.5f,%.5f" % [p.x, p.y, p.z, p.w]

func _face_key(positions: PackedVector4Array, a: int, b: int, c: int) -> String:
	var arr := [_pos_key(positions[a]), _pos_key(positions[b]), _pos_key(positions[c])]
	arr.sort()
	return arr[0] + "|" + arr[1] + "|" + arr[2]

## Returns {distinct_faces, count1, count2, count3plus, pct1, hole_positions}
## hole_positions is the centroid of every singly-referenced face, for
## locating a specific reported crack/gap.
func _face_adjacency(result: Dictionary, label: String) -> Dictionary:
	var tet_indices: PackedInt32Array = result.tet_vertex_indices
	var positions: PackedVector4Array = result.unique_vertex_positions
	var tet_count: int = result.tet_count
	var face_map := {}
	for t in range(tet_count):
		var base := t * 4
		var v := [tet_indices[base], tet_indices[base + 1], tet_indices[base + 2], tet_indices[base + 3]]
		var faces := [
			[v[0], v[1], v[2]], [v[0], v[1], v[3]], [v[0], v[2], v[3]], [v[1], v[2], v[3]],
		]
		for f in faces:
			var key := _face_key(positions, f[0], f[1], f[2])
			if not face_map.has(key):
				face_map[key] = {"count": 0, "verts": f}
			face_map[key].count += 1
	var count1 := 0
	var count2 := 0
	var count3plus := 0
	var hole_positions := []
	for key in face_map:
		var entry: Dictionary = face_map[key]
		var c: int = entry.count
		if c == 1:
			count1 += 1
			var verts: Array = entry.verts
			var centroid: Vector4 = (positions[verts[0]] + positions[verts[1]] + positions[verts[2]]) / 3.0
			hole_positions.append(centroid)
		elif c == 2:
			count2 += 1
		else:
			count3plus += 1
	var total: int = face_map.size()
	var pct: float = (100.0 * count1 / float(total)) if total > 0 else 0.0
	print("=== FACE ADJACENCY: %s (tet_count=%d) ===" % [label, tet_count])
	print("distinct_faces=%d referenced_1x(HOLE)=%d(%.2f%%) referenced_2x(OK)=%d referenced_3x_plus(OVERLAP)=%d" % [
		total, count1, pct, count2, count3plus
	])
	return {"count1": count1, "count2": count2, "count3plus": count3plus, "pct1": pct, "hole_positions": hole_positions}

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

func _instance_terrain() -> Dictionary:
	var packed: PackedScene = load("res://sandbox/terrain4d/terrain4d_test.tscn")
	var root: Node = packed.instantiate()
	var terrain: StaticBody4D = root.get_node("World/TerrainRig/Terrain")
	terrain.resolution_horizontal = 2
	terrain.resolution_vertical = 2
	add_child(root)
	for i in range(5):
		await get_tree().process_frame
	return {"root": root, "terrain": terrain}

func _run_case(bounds_min: Vector4, bounds_max: Vector4, nx: int, ny: int, nz: int, nw: int, get_density_fn_factory: Callable, image_prefix: String, label: String, also_run_dc: bool) -> void:
	print("=== CASE: %s (grid %dx%dx%dx%d) ===" % [label, nx, ny, nz, nw])
	var inst: Dictionary = await _instance_terrain()
	var root: Node = inst.root
	var terrain: StaticBody4D = inst.terrain
	var density_fn: Callable = get_density_fn_factory.call(terrain)

	# --- A: re-confirm 0% crack rate at the ACTUAL density-matched grid,
	# fixed (single-anchor) scheme - the earlier 0.0% was only measured at
	# the original, finer resolution. ---
	var mt_fixed: Dictionary = _mt.generate_mt(bounds_min, bounds_max, nx, ny, nz, nw, density_fn, false)
	var mt_fixed_faces: Dictionary = _face_adjacency(mt_fixed, label + " [MT fixed-scheme @ this grid]")

	if also_run_dc:
		# --- B: DC at the SAME coarse grid as MT, for a fair "is the gap
		# an MT crack or a shared under-resolution artifact" check. ---
		var dc_result: Dictionary = DualContour4D.generate(bounds_min, bounds_max, nx, ny, nz, nw, density_fn, 0.15)
		_face_adjacency(dc_result, label + " [DC @ SAME coarse grid]")
		var dc_mesh := _build_mesh_from_result(dc_result)
		await _swap_mesh_and_screenshot(terrain, dc_mesh, Color(0.85, 0.25, 0.2, 1.0), image_prefix + "_dc_samegrid.png")

	var mt_fixed_mesh := _build_mesh_from_result(mt_fixed)
	await _swap_mesh_and_screenshot(terrain, mt_fixed_mesh, Color(0.2, 0.55, 0.85, 1.0), image_prefix + "_mt_fixed.png")

	# --- C: alternating (checkerboard-parity) scheme, same grid - report
	# visual regularity and crack rate as SEPARATE, both-required checks. ---
	var mt_alt: Dictionary = _mt.generate_mt(bounds_min, bounds_max, nx, ny, nz, nw, density_fn, true)
	var mt_alt_faces: Dictionary = _face_adjacency(mt_alt, label + " [MT alternating-scheme @ this grid]")
	var mt_alt_mesh := _build_mesh_from_result(mt_alt)
	await _swap_mesh_and_screenshot(terrain, mt_alt_mesh, Color(0.35, 0.75, 0.35, 1.0), image_prefix + "_mt_alternating.png")

	print("--- CRACK-TEST VERDICT: %s ---" % [label])
	print("  MT fixed scheme:       referenced_1x=%.2f%%  %s" % [mt_fixed_faces.pct1, "PASS (0%%)" if mt_fixed_faces.count1 == 0 else "FAIL - cracks present"])
	print("  MT alternating scheme: referenced_1x=%.2f%%  %s" % [mt_alt_faces.pct1, "PASS (0%%)" if mt_alt_faces.count1 == 0 else "FAIL - cracks present"])
	if mt_fixed_faces.count1 == 0 and mt_alt_faces.count1 > 0:
		print("  CONCLUSION: alternating scheme REINTRODUCES cracks the fixed scheme did not have. Visual regularity must be judged from the screenshot, but this fails the required crack-freeness condition regardless of how it looks.")
	elif mt_alt_faces.count1 == 0:
		print("  CONCLUSION: alternating scheme remains crack-free - safe to judge purely on visual regularity from the screenshot.")

	_compose_side_by_side(image_prefix + "_mt_fixed.png", image_prefix + "_mt_alternating.png", image_prefix + "_fixed_vs_alternating_side_by_side.png")

	if mt_fixed_faces.hole_positions.size() > 0:
		print("  first few hole-face centroids (fixed scheme, if any): %s" % [mt_fixed_faces.hole_positions.slice(0, mini(5, mt_fixed_faces.hole_positions.size()))])
	if mt_alt_faces.hole_positions.size() > 0:
		print("  first few hole-face centroids (alternating scheme, if any): %s" % [mt_alt_faces.hole_positions.slice(0, mini(5, mt_alt_faces.hole_positions.size()))])

	root.queue_free()
	await get_tree().process_frame

func _run() -> void:
	await _run_case(
		Vector4(-6, -6, -6, -6), Vector4(6, 6, 6, 6), 14, 14, 14, 14,
		func(_terrain): return Callable(self, "_control_sphere_density"),
		"mc_crackcheck_sphere",
		"control sphere SDF @ density-matched 14^4",
		false  # DC-at-same-grid check is specifically for the terrain leg gap, not needed here
	)

	await _run_case(
		Vector4(-8, -4, -8, -8), Vector4(8, 7, 8, 8), 8, 6, 8, 8,
		func(terrain): return Callable(terrain, "get_density"),
		"mc_crackcheck_terrain",
		"terrain4d_test.tscn density @ density-matched 8x6x8x8",
		true
	)

	print("DONE")
	get_tree().quit()
