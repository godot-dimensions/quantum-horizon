extends SceneTree

## Finds the degenerate tetrahedra that break the closest-point cache.
##
## The engine gives up on the whole cache at the FIRST bad tetrahedron
## (tetra_mesh_4d.cpp:49), so its error names one index and hides the rest. A
## tetrahedron is degenerate when its three edges from vertex 0 are linearly
## dependent - the four points lie in a plane, so it has no volume and its Gram
## matrix cannot be inverted. Raycasts and editor picking need that cache, so a
## single bad cell makes a whole model unclickable.
##
## The engine's test is SCALE-INVARIANT: it normalizes the three edges before taking
## the determinant (geometry_4d.cpp:15-28), so what fails is a SLIVER - a tetrahedron
## that is flat in shape - not merely a small one. That ratio is reproduced exactly
## here, because an absolute volume threshold finds nothing on a 10-metre model whose
## slivers still have large volumes.

const _REPORT_LIMIT: int = 2

var _done: bool = false


func _initialize() -> void:
	root.add_child((load("res://ramon/Model/model.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	for node in root.get_node("Model/Models").get_children():
		for rig in node.get_children():
			if rig is MeshInstance4D and rig.mesh != null:
				_check("%s/%s" % [node.name, rig.name], rig.mesh)
	return true


func _check(label: String, mesh: ArrayTetraMesh4D) -> void:
	var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var count: int = cells.size() / 4
	var bad: Array = []
	var worst: float = INF
	for cell in range(count):
		var a: Vector4 = positions[cells[cell * 4]]
		var b: Vector4 = positions[cells[cell * 4 + 1]]
		var c: Vector4 = positions[cells[cell * 4 + 2]]
		var d: Vector4 = positions[cells[cell * 4 + 3]]
		var quality: float = _quality(a, b, c, d)
		worst = minf(worst, quality)
		# CMP_EPSILON, the engine's own cutoff.
		if quality <= 0.00001:
			bad.append([cell, a, b, c, d])

	var head: String = (label + " ").rpad(24, ".")
	if bad.is_empty():
		print("%s %d tets, all sound (worst shape %f)" % [head, count, worst])
		return
	print("%s %d tets, %d DEGENERATE by the engine's test (worst shape %f)" % [
		head, count, bad.size(), worst])
	for entry in bad.slice(0, _REPORT_LIMIT):
		var a: Vector4 = entry[1]
		var cell: int = entry[0]
		print("   tet %d, vertex indices %d %d %d %d" % [
			cell, cells[cell * 4], cells[cell * 4 + 1], cells[cell * 4 + 2], cells[cell * 4 + 3]])
		for slot in range(4):
			var v: Vector4 = positions[cells[cell * 4 + slot]]
			print("      (%f, %f, %f, %f)" % [v.x, v.y, v.z, v.w])
	if bad.size() > _REPORT_LIMIT:
		print("   ... and %d more" % (bad.size() - _REPORT_LIMIT))


## The engine's degeneracy number: the determinant of the Gram matrix of the three
## edges AFTER normalizing them. Equals (6 * volume / product of edge lengths) squared,
## so it is 1 for a perfectly regular corner and 0 for a flat one, whatever the size.
func _quality(a: Vector4, b: Vector4, c: Vector4, d: Vector4) -> float:
	var e1: Vector4 = b - a
	var e2: Vector4 = c - a
	var e3: Vector4 = d - a
	var l1: float = e1.length()
	var l2: float = e2.length()
	var l3: float = e3.length()
	if l1 <= 0.0 or l2 <= 0.0 or l3 <= 0.0:
		return 0.0
	var n01: float = e1.dot(e2) / (l1 * l2)
	var n02: float = e1.dot(e3) / (l1 * l3)
	var n12: float = e2.dot(e3) / (l2 * l3)
	return (1.0 - n12 * n12) + n01 * (n02 * n12 - n01) + n02 * (n01 * n12 - n02)


## Whether any two of the four corners sit on top of each other - the difference
## between a tetrahedron that is merely flat and one that has collapsed outright.
func _duplicates(entry: Array) -> String:
	var corners: Array = [entry[1], entry[2], entry[3], entry[4]]
	var pairs: Array = []
	for i in range(4):
		for j in range(i + 1, 4):
			if (corners[i] as Vector4).distance_to(corners[j]) < 1e-9:
				pairs.append("%d=%d" % [i, j])
	return "none (flat, not collapsed)" if pairs.is_empty() else ", ".join(pairs)
