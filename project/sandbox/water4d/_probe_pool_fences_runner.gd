extends SceneTree

## Did Aaron's fence generator actually BUILD anything?
##
##   godot --path project --rendering-method forward_plus \
##       --script res://sandbox/water4d/_probe_pool_fences_runner.gd
##
## A FenceGenerator4D that is handed a footprint it cannot use keeps its node, keeps its
## settings and quietly produces an empty mesh. "The node is there" and "there is a fence
## there" are different claims, and only the second one matters - so this counts VERTICES,
## the same lesson the voxel chunks taught: `mesh != null` is not geometry.

const SCENE := "res://sandbox/water4d/pool_room.tscn"

var _frames: int = 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var scene: Node = (load(SCENE) as PackedScene).instantiate()
		root.add_child(scene)
		current_scene = scene
		return false
	if _frames < 8:
		return false

	var total: int = 0
	var empty: Array[String] = []
	print("\n  fences built by FenceGenerator4D:")
	for node in _walk(current_scene):
		var fence := node as FenceGenerator4D
		if fence == null:
			continue
		var verts: int = _vertices(fence)
		total += verts
		print("    %-16s footprint %-22s %6d vertices" % [fence.name, str(fence.box_size), verts])
		if verts == 0:
			empty.append(String(fence.name))

	print("")
	if total == 0:
		print("  FAIL - every fence is empty. The generator ran and produced nothing, so")
		print("         whatever is on screen is the solid boxes, not Aaron's fence.")
	elif not empty.is_empty():
		print("  FAIL - these built nothing: %s" % ", ".join(empty))
	else:
		print("  PASS - every fence produced geometry, %d vertices in all." % total)
	quit(0 if total > 0 and empty.is_empty() else 1)
	return true


## A fence keeps its output on child MeshInstance4Ds, so the count is theirs.
func _vertices(fence: Node) -> int:
	var count: int = 0
	for node in _walk(fence):
		var instance := node as MeshInstance4D
		if instance == null or instance.mesh == null:
			continue
		var mesh: Mesh = instance.mesh.get_proxy_mesh_3d() if instance.mesh.has_method(
				"get_proxy_mesh_3d") else null
		if mesh != null:
			for surface in range(mesh.get_surface_count()):
				var arrays: Array = mesh.surface_get_arrays(surface)
				if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return count


func _walk(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child in node.get_children():
		found.append_array(_walk(child))
	return found
