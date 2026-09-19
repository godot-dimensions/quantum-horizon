extends SceneTree
## Seat the brachiosaurus by its GEOMETRY, not by its foot ball's radius: the loft's end
## cap tapers, so the mesh never reaches as low as the ball does.
var _root: Node
var _f := 0
var _lowest := 1e9
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 30: return false
	var ground := (_root.get_node_or_null("Ground") as Node4D).position.y + 1.0
	print("ground top: %.3f" % ground)
	for top in _root.get_children():
		if not (top is Node4D) or top.name == "Ground": continue
		var low := 1e9
		var stack: Array = [top]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance4D and (n as MeshInstance4D).mesh is ArrayTetraMesh4D and (n as MeshInstance4D).visible:
				var off: float = (n as Node4D).global_position.y
				for v in ((n as MeshInstance4D).mesh as ArrayTetraMesh4D).get_vertex_positions():
					low = minf(low, v.y + off)
			for c in n.get_children(): stack.append(c)
		if low < 1e8:
			print("  %-10s lowest %+.3f -> %s by %.3f" % [top.name, low,
				"SUNK" if low < ground else "floats", absf(low - ground)])
	return true
