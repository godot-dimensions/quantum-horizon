extends SceneTree
## Something makes the floor change after load. List every large surface in the scene at
## the first frame and again later, and report anything that differs.
var _root: Node
var _f := 0
var _first := {}
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _snapshot() -> Dictionary:
	var out := {}
	var stack: Array = [_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance4D:
			var mi := n as MeshInstance4D
			var m: Mesh4D = mi.mesh
			if m != null:
				var cells := 0
				if m is TetraMesh4D:
					cells = (m as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
				# Only things big enough to be a floor.
				var aabb := 0.0
				if m is TetraMesh4D:
					for v in (m as TetraMesh4D).get_vertex_positions():
						aabb = maxf(aabb, maxf(absf(v.x), absf(v.z)))
				if aabb > 20.0:
					out[String(_root.get_path_to(n))] = "%s cells=%d halfspan=%.0f visible=%s albedo=%s" % [
						m.get_class(), cells, aabb, mi.visible,
						str(mi.material_override.albedo_color) if mi.material_override else "none"]
		for c in n.get_children(): stack.append(c)
	return out
func _process(_d) -> bool:
	_f += 1
	if _f == 2:
		_first = _snapshot()
		print("--- frame 2: %d large surfaces ---" % _first.size())
		for k in _first: print("  %s : %s" % [k, _first[k]])
		return false
	if _f < 240: return false
	var later := _snapshot()
	print("--- frame 240: %d large surfaces ---" % later.size())
	for k in later: print("  %s : %s" % [k, later[k]])
	for k in later:
		if not _first.has(k): print("APPEARED: %s" % k)
		elif later[k] != _first[k]: print("CHANGED: %s\n    was %s\n    now %s" % [k, _first[k], later[k]])
	for k in _first:
		if not later.has(k): print("VANISHED: %s" % k)
	return true
