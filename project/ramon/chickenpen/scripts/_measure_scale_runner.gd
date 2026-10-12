extends SceneTree

## How big is everything, really? Eyeballing a screenshot cannot tell a big chicken from a
## near one.

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	var mgr: Node = _root.get_node("Chickens")
	var body: Node4D = (mgr.get("agents")[0] as Node).get_parent() as Node4D
	print("player capsule: %.2f tall" % 1.35)
	print("chicken node scale: %s" % [mgr.get("chicken_scale")])
	_extent("chicken", body)
	_extent("keeper", _root.get_node("World/KeeperPost/Keeper"))
	# The sign was removed from the scene; get_node would error on it.
	var sign: Node = _root.get_node_or_null("World/Sign")
	if sign != null:
		_extent("sign", sign)
	var post: Node = _root.get_node_or_null("World/Scenery/Post5")
	if post != null:
		_extent("one scenery post", post)
	_extent("coop", _root.get_node("Pen/Coop"))
	var fence: Node = _root.get_node("Pen/Fence")
	var b: Array = fence.call("interior_bounds")
	print("pen interior: %.1f x %.1f units (w +/- %.1f)" % [
		b[1].x - b[0].x, b[1].z - b[0].z, b[1].w])
	return true


## World-space size of a node's visible meshes, by walking its children.
func _extent(label: String, node: Node) -> void:
	var lo := Vector4(INF, INF, INF, INF)
	var hi := Vector4(-INF, -INF, -INF, -INF)
	var found := 0
	for child in _all(node):
		var mesh_node: MeshInstance4D = child as MeshInstance4D
		if mesh_node == null or not (mesh_node.mesh is TetraMesh4D):
			continue
		var verts: PackedVector4Array = (mesh_node.mesh as TetraMesh4D).get_simplex_cell_positions()
		if verts.is_empty():
			continue
		found += 1
		for v in verts:
			var w: Vector4 = mesh_node.global_basis * v + mesh_node.global_position
			lo = Vector4(minf(lo.x, w.x), minf(lo.y, w.y), minf(lo.z, w.z), minf(lo.w, w.w))
			hi = Vector4(maxf(hi.x, w.x), maxf(hi.y, w.y), maxf(hi.z, w.z), maxf(hi.w, w.w))
	if found == 0:
		print("%-18s no meshes found" % label)
		return
	print("%-18s %.2f wide  %.2f tall  %.2f deep  %.2f through w   (%d meshes)" % [
		label, hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, hi.w - lo.w, found])


func _all(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_all(child))
	return out
