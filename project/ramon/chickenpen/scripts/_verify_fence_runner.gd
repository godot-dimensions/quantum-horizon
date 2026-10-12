extends SceneTree
## Phase 05: does the fence build from numbers, resize without stretching, keep its
## collision in step, and does the return volume follow the same extents?
##
## Since 6 Oct the fence is Aaron's FenceGenerator4D with pen_fence_compat_4d.gd on it: one
## generated mesh, not a node per post, so "more posts, not fatter ones" is read from the posts'
## part of the mesh (its tetrahedra grow with the pen while post_thickness_meters stays put).

var _root: Node
var _fails: int = 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _post_cells(fence: Node) -> int:
	var mesh: Resource = fence.get("mesh")
	if mesh is MultiSurfaceMesh4D and not (mesh as MultiSurfaceMesh4D).surface_meshes.is_empty():
		return ((mesh as MultiSurfaceMesh4D).surface_meshes[0].call("get_simplex_cell_vertex_indices") as PackedInt32Array).size() / 4
	return -1


func _settle(fence: Node) -> void:
	await _frames(2)
	var guard: int = 0
	while bool(fence.call("is_updating")) and guard < 600:
		await process_frame
		guard += 1


func _run() -> void:
	await _frames(40)
	var fence: Node = _root.get_node("Pen/Fence")
	await _settle(fence)
	var start: Vector3 = fence.get("box_size")
	var thickness: float = float(fence.get("post_thickness_meters"))
	var last_cells: int = 0
	for size in [[3.0, 3.0], [7.0, 6.0], [14.0, 6.0]]:
		fence.set("extend_x_positive", size[0])
		fence.set("extend_z_positive", size[1])
		await _settle(fence)
		var b: Array = fence.call("interior_bounds")
		var east: Node4D = fence.get_node("Collision/WallPosX") as Node4D
		var cells: int = _post_cells(fence)
		print("pen %.0f x %.0f -> post tetrahedra %d, collision walls %d (east wall at x %.2f), interior %.1f x %.1f" % [
			size[0] * 2, size[1] * 2, cells, fence.get_node("Collision").get_child_count(), east.position.x,
			b[1].x - b[0].x, b[1].z - b[0].z])
		_check(absf(east.position.x - size[0]) < 0.01, "the collision follows the extents (%.0f m)" % size[0])
		_check(cells >= last_cells, "a bigger pen has as many posts or more (%d)" % cells)
		last_cells = cells
	# Post proportions do not change with pen size (item 38).
	_check(is_equal_approx(float(fence.get("post_thickness_meters")), thickness), "posts stay %.2f m thick at every size" % thickness)
	# The return volume follows the same numbers.
	var middle: Vector4 = (fence as Node4D).global_position
	var inside: bool = bool(fence.call("contains_point", middle))
	var outside: bool = bool(fence.call("contains_point", middle + Vector4(99, 0, 0, 0)))
	_check(inside and not outside, "the middle is inside, a point 99 m off is not")
	_check(bool(fence.call("is_global_point_inside", middle)), "the generator knows its own footprint (is_global_point_inside)")
	# Back to the pen's own size.
	fence.set("extend_x_positive", start.x * 0.5)
	fence.set("extend_z_positive", start.y * 0.5)
	await _settle(fence)
	print("FENCE %s: %d failed" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)
