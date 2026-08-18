extends Node
## TEMPORARY, THROWAWAY spike verification for TerrainMeshBackendConnectedDC
## (sandbox/terrain4d/terrain4d_mesh_backend_connected_dc.gd) - NOT wired
## into VoxelWorld4D, NOT touching the shipped MT pipeline. Runs the SAME
## position-keyed face-adjacency crack test, at the SAME grids/bounds, as
## the original DC/MT comparison (_marching_simplices_crack_and_alt_runner.gd):
##   - control sphere SDF (p.length()-5.0), bounds [-6,-6,-6,-6]-[6,6,6,6],
##     grid 14x14x14x14
##   - terrain4d_test.tscn's real density, bounds [-8,-4,-8,-8]-[8,7,8,8],
##     grid 8x6x8x8
## Runs DC fresh (not assumed) as the ~25% baseline, and ConnectedDC as the
## test subject, reporting both directly. Then builds an actual mesh from
## ConnectedDC's own output and screenshots it through the SAME production
## Cross-section material/lighting Terrain4D uses - numbers alone weren't
## sufficient evidence for MT and aren't being treated as sufficient here.

func _control_sphere_density(p: Vector4) -> float:
	return p.length() - 5.0

func _pos_key(p: Vector4) -> String:
	return "%.5f,%.5f,%.5f,%.5f" % [p.x, p.y, p.z, p.w]

func _face_key(positions: PackedVector4Array, a: int, b: int, c: int) -> String:
	var arr := [_pos_key(positions[a]), _pos_key(positions[b]), _pos_key(positions[c])]
	arr.sort()
	return arr[0] + "|" + arr[1] + "|" + arr[2]

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
			hole_positions.append((positions[verts[0]] + positions[verts[1]] + positions[verts[2]]) / 3.0)
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
	return {"count1": count1, "pct1": pct, "hole_positions": hole_positions}

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
	mesh.set_simplex_cell_vertex_normals(result.tet_vertex_normals)
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

func _run_case(bounds_min: Vector4, bounds_max: Vector4, nx: int, ny: int, nz: int, nw: int, get_density_fn_factory: Callable, image_prefix: String, label: String) -> void:
	print("=== CASE: %s (grid %dx%dx%dx%d) ===" % [label, nx, ny, nz, nw])
	var inst: Dictionary = await _instance_terrain()
	var root: Node = inst.root
	var terrain: StaticBody4D = inst.terrain
	var density_fn: Callable = get_density_fn_factory.call(terrain)

	var dc_result: Dictionary = DualContour4D.generate(bounds_min, bounds_max, nx, ny, nz, nw, density_fn, 0.15)
	var dc_faces: Dictionary = _face_adjacency(dc_result, label + " [DC baseline]")

	var cdc_result: Dictionary = TerrainMeshBackendConnectedDC.generate(bounds_min, bounds_max, nx, ny, nz, nw, density_fn, 0.15)
	var cdc_faces: Dictionary = _face_adjacency(cdc_result, label + " [ConnectedDC]")
	print("  ConnectedDC-specific: active_cell_count=%d component_count=%d multi_vertex_cell_count=%d (cells that needed >1 vertex)" % [
		cdc_result.active_cell_count, cdc_result.component_count, cdc_result.multi_vertex_cell_count
	])

	var cdc_mesh := _build_mesh_from_result(cdc_result)
	await _swap_mesh_and_screenshot(terrain, cdc_mesh, Color(0.75, 0.35, 0.85, 1.0), image_prefix + "_connected_dc.png")

	print("--- CRACK-TEST VERDICT: %s ---" % [label])
	print("  DC baseline:  referenced_1x=%.2f%%" % [dc_faces.pct1])
	print("  ConnectedDC:  referenced_1x=%.2f%%  %s" % [cdc_faces.pct1, "PASS (0%%)" if cdc_faces.count1 == 0 else "FAIL - cracks present"])
	if cdc_faces.hole_positions.size() > 0:
		print("  first few hole-face centroids (ConnectedDC, if any): %s" % [cdc_faces.hole_positions.slice(0, mini(5, cdc_faces.hole_positions.size()))])

	root.queue_free()
	await get_tree().process_frame

func _run() -> void:
	await _run_case(
		Vector4(-6, -6, -6, -6), Vector4(6, 6, 6, 6), 14, 14, 14, 14,
		func(_terrain): return Callable(self, "_control_sphere_density"),
		"connected_dc_crackcheck_sphere",
		"control sphere SDF @ 14^4"
	)

	await _run_case(
		Vector4(-8, -4, -8, -8), Vector4(8, 7, 8, 8), 8, 6, 8, 8,
		func(terrain): return Callable(terrain, "get_density"),
		"connected_dc_crackcheck_terrain",
		"terrain4d_test.tscn density @ 8x6x8x8"
	)

	print("DONE")
	get_tree().quit()

func _ready() -> void:
	await _run()
