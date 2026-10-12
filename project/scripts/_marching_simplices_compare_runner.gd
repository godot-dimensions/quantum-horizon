extends Node
## TEMPORARY, THROWAWAY - side-by-side comparison of the broken Dual
## Contouring output against a quick Marching Tetrahedra ("marching
## 4-simplices") implementation, on the EXACT SAME density fields already
## used in the correctness diagnosis: the control sphere SDF and the
## reduced-resolution terrain4d_test.tscn case. Reuses the SAME
## terrain4d_test.tscn scene/camera (proven setup) for both algorithms in
## each case, swapping only the mesh in place between screenshots so the
## viewpoint is guaranteed identical - a direct visual A/B, not theory.

const MarchingSimplices4DScript = preload("res://scripts/_marching_simplices_4d_runner.gd")

var _mt: MarchingSimplices4DScript

func _ready() -> void:
	_mt = MarchingSimplices4DScript.new()
	await _run()

func _control_sphere_density(p: Vector4) -> float:
	return p.length() - 5.0

## Position-based, NOT index-based: DC's output is already vertex-deduped
## (one index per active cell) so index-equality and position-equality
## agree there, but MT's output (deliberately, per its throwaway scope) has
## NO vertex dedup - every tet gets fresh indices even when two tets share
## the exact same crossing-point position. Keying by index would make every
## MT face look "unique" regardless of real topology - a test artifact, not
## a finding. Keying by position (rounded to well above float noise) is
## what actually tests the "shared grid edges compute identical crossing
## points" claim, and works for both algorithms' output uniformly.
func _pos_key(p: Vector4) -> String:
	return "%.5f,%.5f,%.5f,%.5f" % [p.x, p.y, p.z, p.w]

func _face_key(positions: PackedVector4Array, a: int, b: int, c: int) -> String:
	var arr := [_pos_key(positions[a]), _pos_key(positions[b]), _pos_key(positions[c])]
	arr.sort()
	return arr[0] + "|" + arr[1] + "|" + arr[2]

func _face_adjacency_summary(result: Dictionary, label: String) -> void:
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
			face_map[key] = face_map.get(key, 0) + 1
	var count1 := 0
	var count2 := 0
	var count3plus := 0
	for key in face_map:
		var c: int = face_map[key]
		if c == 1:
			count1 += 1
		elif c == 2:
			count2 += 1
		else:
			count3plus += 1
	var total: int = face_map.size()
	var pct: float = (100.0 * count1 / float(total)) if total > 0 else 0.0
	print("=== FACE ADJACENCY: %s (tet_count=%d) ===" % [label, tet_count])
	print("distinct_faces=%d referenced_1x(HOLE)=%d(%.1f%%) referenced_2x(OK)=%d referenced_3x_plus(OVERLAP)=%d" % [
		total, count1, pct, count2, count3plus
	])

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

## get_density_fn_factory: Callable(terrain) -> Callable, so the terrain
## case can reuse the real terrain.get_density (needs the instanced node
## for its @onready noise state) while the sphere case ignores the arg.
func _run_case(bounds_min: Vector4, bounds_max: Vector4, nx: int, ny: int, nz: int, nw: int, get_density_fn_factory: Callable, image_prefix: String, label: String) -> void:
	print("=== CASE: %s (grid %dx%dx%dx%d) ===" % [label, nx, ny, nz, nw])
	var packed: PackedScene = load("res://sandbox/terrain4d/terrain4d_test.tscn")
	var root: Node = packed.instantiate()
	var terrain: StaticBody4D = root.get_node("World/TerrainRig/Terrain")
	terrain.resolution_horizontal = 2  # keep _ready()'s own regenerate() cheap - we overwrite the mesh right after
	terrain.resolution_vertical = 2
	add_child(root)
	for i in range(5):
		await get_tree().process_frame

	var density_fn: Callable = get_density_fn_factory.call(terrain)

	var t0 := Time.get_ticks_usec()
	var dc_result: Dictionary = SingleVertexDualContour4D.generate(bounds_min, bounds_max, nx, ny, nz, nw, density_fn, 0.15)
	print("DC generate() wall time: %.2f s" % [(Time.get_ticks_usec() - t0) / 1000000.0])
	_face_adjacency_summary(dc_result, label + " [Dual Contouring]")

	var t1 := Time.get_ticks_usec()
	var mt_result: Dictionary = _mt.generate_mt(bounds_min, bounds_max, nx, ny, nz, nw, density_fn)
	print("MT generate_mt() wall time: %.2f s" % [(Time.get_ticks_usec() - t1) / 1000000.0])
	_face_adjacency_summary(mt_result, label + " [Marching Tetrahedra]")

	var dc_mesh := _build_mesh_from_result(dc_result)
	await _swap_mesh_and_screenshot(terrain, dc_mesh, Color(0.85, 0.25, 0.2, 1.0), image_prefix + "_dc.png")
	var mt_mesh := _build_mesh_from_result(mt_result)
	await _swap_mesh_and_screenshot(terrain, mt_mesh, Color(0.2, 0.55, 0.85, 1.0), image_prefix + "_mt.png")

	root.queue_free()
	await get_tree().process_frame

	_compose_side_by_side(image_prefix + "_dc.png", image_prefix + "_mt.png", image_prefix + "_side_by_side.png")

func _run() -> void:
	# --- Case 1: control sphere SDF, same grid as the diagnostic's Part C
	# (24^4, bounds -6..6) - exact apples-to-apples against the already-
	# reported ~25.3% DC hole-face rate on this input. ---
	await _run_case(
		Vector4(-6, -6, -6, -6), Vector4(6, 6, 6, 6), 24, 24, 24, 24,
		func(_terrain): return Callable(self, "_control_sphere_density"),
		"mc_compare_sphere",
		"control sphere SDF (24^4)"
	)

	# --- Case 2: real terrain_generator.gd density (volumetric smooth_max,
	# noise + box-closing), reduced to the SAME 12x10x12x12 resolution
	# already screenshotted showing holes/fragments in the DC diagnostic
	# (diagnose_part_a2_small_12x10.png). ---
	await _run_case(
		Vector4(-8, -4, -8, -8), Vector4(8, 7, 8, 8), 12, 10, 12, 12,
		func(terrain): return Callable(terrain, "get_density"),
		"mc_compare_terrain",
		"terrain4d_test.tscn density, reduced resolution (12x10x12x12)"
	)

	print("DONE")
	get_tree().quit()
