extends SceneTree
## Phase 05: does the fence build from numbers, resize without stretching, keep its
## collision in step, and does the return volume follow the same extents?
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _count(fence: Node, kind: String) -> int:
	var n := 0
	for c in fence.get_children():
		if String(c.name).begins_with(kind): n += 1
	return n
func _walls(fence: Node) -> int:
	var body: Node = fence.get_node_or_null("Collision")
	return body.get_child_count() if body else -1
func _process(_d) -> bool:
	_f += 1
	if _f < 40: return false
	var fence: Node = _root.get_node("Pen/Fence")
	for size in [[7.0, 6.0], [14.0, 6.0], [3.0, 3.0]]:
		fence.set("extend_x_positive", size[0])
		fence.set("extend_x_negative", size[0])
		fence.set("extend_z_positive", size[1])
		fence.set("extend_z_negative", size[1])
		var b: Array = fence.call("interior_bounds")
		print("pen %.0f x %.0f -> posts %d, rails %d, collision walls %d, interior %.1f x %.1f" % [
			size[0] * 2, size[1] * 2, _count(fence, "Post"), _count(fence, "Rail"), _walls(fence),
			b[1].x - b[0].x, b[1].z - b[0].z])
	# Post proportions must not change with pen size (item 38).
	var post: MeshInstance4D = null
	for c in fence.get_children():
		if String(c.name).begins_with("Post"): post = c as MeshInstance4D; break
	print("post size stays %v regardless of pen size" % (post.mesh as BoxTetraMesh4D).size)
	# The return volume follows the same numbers.
	var inside: bool = bool(fence.call("contains_point", (fence as Node4D).global_position))
	var outside: bool = bool(fence.call("contains_point", (fence as Node4D).global_position + Vector4(99, 0, 0, 0)))
	print("centre inside: %s | far point inside: %s" % [str(inside), str(outside)])
	return true
