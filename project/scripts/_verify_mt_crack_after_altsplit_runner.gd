extends Node
## TEMPORARY - re-confirms TerrainMeshBackendMT (the PRODUCTION backend,
## not the old throwaway _marching_simplices_4d_runner.gd) is still
## crack-free (0% unpaired faces) after switching the k=2/3 triangular-
## prism split to the alternate diagonal. Swapping which valid
## decomposition is used is exactly the kind of change that silently broke
## crack-freeness elsewhere in this investigation (the checkerboard-parity
## experiment), so this is re-verified directly rather than assumed safe
## just because the reference-geometry sweep improved.

func _sphere_density(p: Vector4) -> float:
	return p.length() - 6.0

func _pos_key(p: Vector4) -> String:
	return "%.5f,%.5f,%.5f,%.5f" % [p.x, p.y, p.z, p.w]

func _face_key(positions: PackedVector4Array, a: int, b: int, c: int) -> String:
	var arr := [_pos_key(positions[a]), _pos_key(positions[b]), _pos_key(positions[c])]
	arr.sort()
	return arr[0] + "|" + arr[1] + "|" + arr[2]

func _face_adjacency(result: Dictionary, label: String) -> void:
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
	print("distinct_faces=%d referenced_1x(HOLE)=%d(%.2f%%) referenced_2x(OK)=%d referenced_3x_plus(OVERLAP)=%d" % [
		total, count1, pct, count2, count3plus
	])

func _ready() -> void:
	# Same production brick size this backend actually runs at
	# (VoxelBrick4D.ACTUAL_POINTS_PER_AXIS = 6), plus a larger standalone
	# grid matching the earlier sphere-SDF crack test for direct
	# comparison against the pre-change ~0.0% result.
	var brick_result: Dictionary = TerrainMeshBackendMT.generate_brick_mesh(
		Vector4(-3, -3, -3, -3), Vector4(0.75, 0.75, 0.75, 0.75), 6, Callable(self, "_sphere_density")
	)
	_face_adjacency(brick_result, "production brick size (6^4)")

	var large_result: Dictionary = TerrainMeshBackendMT.generate_brick_mesh(
		Vector4(-6, -6, -6, -6), Vector4(12.0 / 23.0, 12.0 / 23.0, 12.0 / 23.0, 12.0 / 23.0), 24, Callable(self, "_sphere_density")
	)
	_face_adjacency(large_result, "sphere SDF (24^4, matches earlier crack-test scale)")

	print("DONE")
	get_tree().quit()
