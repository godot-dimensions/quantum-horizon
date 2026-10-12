extends SceneTree

## What the landmarks are made of (WTools/PLAN.md steps 12, 25, 32): for the range (its yard as it was, the
## 3D-ish one, enclosed_in_w off), the Watchstone and the camp, every MeshInstance4D: tetrahedra, bounds in
## the unit's frame, and how many connected pieces it holds (pieces: tetrahedra joined through shared
## corners), so an optimiser knows whether it can treat a node as a part or must split it.
##
##   lab_run.sh windowed wt_units res://ramon/WTools/tests/_probe_units_runner.gd

const UNITS := [
	["range", "res://ramon/chickenpen/units/rune_range/rune_range.tscn", {"enclosed_in_w": false}],
	["watchstone", "res://ramon/chickenpen/units/watchstone/watchstone.tscn", {}],
	["camp", "res://ramon/chickenpen/units/camp/camp.tscn", {}],
]


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	for u in UNITS:
		var unit: Node = (load(u[1]) as PackedScene).instantiate()
		for k in u[2]:
			unit.set(k, u[2][k])
		root.add_child(unit)
		await _frames(20)
		var u4 := unit as Node4D
		var inv: Projection = u4.global_basis.inverse()
		var total: int = 0
		var lines := PackedStringArray()
		for node in unit.find_children("*", "MeshInstance4D", true, false):
			var mi := node as MeshInstance4D
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var tm := mi.mesh as TetraMesh4D
			if tm == null:
				continue
			var cells: PackedInt32Array = tm.get_simplex_cell_vertex_indices()
			var tets: int = cells.size() / 4
			total += tets
			var pieces: int = _pieces(cells, tm.get_vertex_positions().size())
			var r: PackedVector4Array = mi.get_rect_bounds_local()
			var lo := Vector4(INF, INF, INF, INF)
			var hi := -lo
			for i in 16:
				var corner: Vector4 = r[0] + Vector4(r[1].x * (i & 1), r[1].y * ((i >> 1) & 1), r[1].z * ((i >> 2) & 1), r[1].w * ((i >> 3) & 1))
				var p: Vector4 = inv * (mi.global_position + mi.global_basis * corner - u4.global_position)
				lo = lo.min(p)
				hi = hi.max(p)
			var size: Vector4 = hi - lo
			lines.append("   %-40s %6d tets %4d pieces  size %.1f x %.1f x %.1f, W %.1f" % [String(unit.get_path_to(mi)).left(40), tets, pieces, size.x, size.y, size.z, size.w])
		print("UNIT %s: %d meshes, %d tetrahedra" % [u[0], lines.size(), total])
		for l in lines:
			print(l)
		root.remove_child(unit)
		unit.free()
		await _frames(3)
	print("UNITS DONE")
	quit(0)


## Connected pieces: tetrahedra joined through shared vertices (union-find over the corners).
func _pieces(cells: PackedInt32Array, verts: int) -> int:
	var parent := PackedInt32Array()
	parent.resize(verts)
	for i in verts:
		parent[i] = i
	var k: int = 0
	while k + 3 < cells.size():
		var a: int = _find(parent, cells[k])
		for j in range(1, 4):
			var b: int = _find(parent, cells[k + j])
			if a != b:
				parent[b] = a
		k += 4
	var roots: Dictionary = {}
	k = 0
	while k < cells.size():
		roots[_find(parent, cells[k])] = true
		k += 4
	return roots.size()


func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i
