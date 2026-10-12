extends SceneTree
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	for name in ["PocketWatch", "GoldenEgg"]:
		var n: Node4D = _root.get_node_or_null("World/Pickups/%s" % name)
		if n == null:
			print("%s: MISSING" % name); continue
		var lo := Vector4(INF, INF, INF, INF)
		var hi := Vector4(-INF, -INF, -INF, -INF)
		var meshes := 0
		for c in n.get_children():
			var m: MeshInstance4D = c as MeshInstance4D
			if m == null or not (m.mesh is TetraMesh4D): continue
			meshes += 1
			for v in (m.mesh as TetraMesh4D).get_simplex_cell_positions():
				var w: Vector4 = m.global_basis * v + m.global_position
				lo = Vector4(minf(lo.x,w.x), minf(lo.y,w.y), minf(lo.z,w.z), minf(lo.w,w.w))
				hi = Vector4(maxf(hi.x,w.x), maxf(hi.y,w.y), maxf(hi.z,w.z), maxf(hi.w,w.w))
		print("%s: %d meshes, at %.2v" % [name, meshes, n.global_position])
		if meshes > 0:
			print("   spans %.2f x %.2f x %.2f, w %.2f..%.2f" % [
				hi.x-lo.x, hi.y-lo.y, hi.z-lo.z, lo.w, hi.w])
	return true
