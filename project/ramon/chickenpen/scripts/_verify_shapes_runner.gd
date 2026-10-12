extends SceneTree

## The theatre's 4D shapes (theatre/theatre_shapes_4d.gd): are they closed, how many
## tetrahedra do they cost, how long do they take, and can they be made off the main
## thread the way the theatre makes them?
##
## CLOSED MEANS EVERY TRIANGLE IS SHARED BY EXACTLY TWO TETRAHEDRA. A boundary with a hole
## in it slices into a surface with a hole in it, which in the cross-section renderer is a
## gap you can see through. Faces are matched by position rather than by index, because two
## of the shapes are deliberately not welded along a seam (the Klein bottle meets itself
## mirrored, and the duocylinder's two halves meet along a flat torus) - the seam is closed
## if the points on either side are the same points.
##
## Headless is fine: nothing here draws.

const Shapes := preload("res://ramon/chickenpen/theatre/theatre_shapes_4d.gd")

var _fails: Array = []
var _made: Array = []


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _initialize() -> void:
	var total := 0
	print("\n--- each shape ---")
	for id in ["hyperball", "tesseract", "tiger", "spheritorus", "ditorus", "duocylinder", "klein"]:
		var t0: int = Time.get_ticks_usec()
		var mesh: ArrayTetraMesh4D = _make(id)
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		if mesh == null:
			_check(id, false, "no mesh")
			continue
		var tets: int = mesh.simplex_cell_vertex_indices.size() / 4
		total += tets
		var open: Array = _open_faces(mesh)
		var lo := Vector4.INF
		var hi := -Vector4.INF
		for p in mesh.vertex_positions:
			lo = lo.min(p)
			hi = hi.max(p)
		_check("%s is closed" % id, open[0] == 0,
			"%d tetrahedra in %.0f ms, %d of %d faces unpaired, extent %s"
				% [tets, ms, open[0], open[1], str((hi - lo).snappedf(0.01))])
		var lines: Array = Shapes.shadow_lines(id)
		_check("%s has a shadow to draw" % id, lines.size() > 0, "%d lines" % lines.size())
	_check("the set costs what was budgeted", total < 110000,
		"%d tetrahedra, about %.0f MB of video memory at 1.25 KB each" % [total, float(total) * 1.25 / 1024.0])

	print("\n--- off the main thread ---")
	var task: int = WorkerThreadPool.add_task(func() -> void:
		for id in ["tiger", "klein"]:
			_made.append(_make(id)), false, "shapes test")
	WorkerThreadPool.wait_for_task_completion(task)
	_check("made on a worker thread", _made.size() == 2 and _made[0] != null and _made[1] != null,
		"%d of 2" % _made.size())
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)


func _make(id: String) -> ArrayTetraMesh4D:
	match id:
		"hyperball":
			return Shapes.hyperball()
		"tesseract":
			return Shapes.tesseract()
	return Shapes.zoo_mesh(id)


## [unpaired faces, all faces], matching triangles by the positions of their corners.
func _open_faces(mesh: ArrayTetraMesh4D) -> Array:
	var keys := PackedInt64Array()
	var pos: PackedVector4Array = mesh.vertex_positions
	var id := {}
	var vkey := PackedInt32Array()
	vkey.resize(pos.size())
	for i in pos.size():
		var k := Vector4i((pos[i] * 2000.0).round())
		if not id.has(k):
			id[k] = id.size()
		vkey[i] = id[k]
	var faces := {}
	var cells: PackedInt32Array = mesh.simplex_cell_vertex_indices
	for t in cells.size() / 4:
		var v := [vkey[cells[t * 4]], vkey[cells[t * 4 + 1]], vkey[cells[t * 4 + 2]], vkey[cells[t * 4 + 3]]]
		for skip in 4:
			var f: Array = []
			for k in 4:
				if k != skip:
					f.append(v[k])
			f.sort()
			var key := Vector3i(f[0], f[1], f[2])
			faces[key] = int(faces.get(key, 0)) + 1
	var open := 0
	for key in faces:
		if int(faces[key]) != 2:
			open += 1
	return [open, faces.size()]
