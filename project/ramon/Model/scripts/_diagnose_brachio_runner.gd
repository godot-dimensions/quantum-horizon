extends SceneTree
## Where does the brachiosaurus's foot sit, how big is its mesh, and which of its ball
## chains would a walker mistake for a leg?
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 15: return false
	var spine := _root.get_node_or_null("Brachio/Spine") as MeshInstance4D
	if spine == null:
		print("no brachio"); return true
	var m := spine.mesh as TetraMesh4D
	print("brachio spine: %d tets" % (m.get_simplex_cell_vertex_indices().size() / 4))
	var lowest := 1e9
	var stack: Array = [spine]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node4D and n.has_method("get_loft_section"):
			lowest = minf(lowest, (n as Node4D).global_position.y)
		for c in n.get_children(): stack.append(c)
	print("lowest ball centre: %.2f (0 = standing on the ground)" % lowest)
	# Chains of three descending balls - what a walker treats as a leg.
	for ball in spine.get_children():
		if not ball.has_method("get_loft_section"): continue
		for hip in ball.get_children():
			if not hip.has_method("get_loft_section"): continue
			var chain: Array = [hip.name]
			var n2: Node = hip
			while true:
				var nxt: Node = null
				for c in n2.get_children():
					if c.has_method("get_loft_section"): nxt = c; break
				if nxt == null: break
				chain.append(nxt.name); n2 = nxt
			print("  branch off %s: %s (drops %.1f)" % [ball.name, str(chain),
				(hip as Node4D).global_position.y - (n2 as Node4D).global_position.y])
	return true
