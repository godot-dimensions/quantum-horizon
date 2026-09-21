extends SceneTree
## Where is every block, really?
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen_proceduralwalker.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 200: return false
	var avatar: Node4D = _root.get_node("Player/Avatar")
	var player: Node4D = _root.get_node("Player")
	var shape := _root.get_node("Player/CollisionShape4D") as CollisionShape4D
	print("player y %.3f on_floor %s | capsule at local y %.2f radius %.2f full_height %.2f | ground top %.2f" % [
		player.position.y, str((player as CharacterBody4D).is_on_floor()),
		(shape as Node4D).position.y, shape.shape.get("radius"), shape.shape.get("full_height"),
		(_root.get_node("Ground") as Node4D).position.y + 1.0])
	var stack: Array = [avatar]
	var rows: Array = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node4D and n != avatar:
			var g: Vector4 = (n as Node4D).global_position
			rows.append([g.y, "%-12s y %+.3f z %+.3f  %s" % [n.name, g.y, g.z,
				"pivot" if not (n is MeshInstance4D) else ""]])
		for c in n.get_children(): stack.append(c)
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows: print("  " + r[1])
	print("shoulderL basis z-col: %v" % (avatar.shoulder_left as Node4D).basis.z)
	print("hipL basis z-col:      %v" % (avatar.hip_left as Node4D).basis.z)
	return true
