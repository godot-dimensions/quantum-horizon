extends SceneTree

## Reports what Ramon's new rig is actually producing, and how thin it is relative
## to how far apart its balls sit - the ratio that decides whether a loft reads as a
## solid body or as a thread.

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var rig: Node = _instance.get_node_or_null("MeshInstance4D")
	if rig == null:
		print("rig not found")
		return true

	var balls: Array = []
	for child in rig.get_children():
		if child.has_method("get_loft_section"):
			balls.append(child)
	print("rig has %d balls, mesh=%s" % [
		balls.size(),
		"NONE" if rig.mesh == null else "%d tetrahedra" % ((rig.mesh as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4)])

	for index in range(balls.size() - 1):
		var a: Vector4 = balls[index].position
		var b: Vector4 = balls[index + 1].position
		var gap: float = a.distance_to(b)
		print("  %s -> %s: gap %.2f, radius %.2f  ->  thickness/gap = %.2f" % [
			balls[index].name, balls[index + 1].name, gap, balls[index].radius, balls[index].radius / gap])

	if rig.mesh != null:
		var low := Vector4(INF, INF, INF, INF)
		var high := Vector4(-INF, -INF, -INF, -INF)
		for p in (rig.mesh as ArrayTetraMesh4D).get_vertex_positions():
			low = Vector4(minf(low.x, p.x), minf(low.y, p.y), minf(low.z, p.z), minf(low.w, p.w))
			high = Vector4(maxf(high.x, p.x), maxf(high.y, p.y), maxf(high.z, p.z), maxf(high.w, p.w))
		print("  model is %.1f tall and %.1f wide - a %.0f:1 ratio" % [
			high.y - low.y, high.x - low.x, (high.y - low.y) / maxf(high.x - low.x, 0.001)])
	return true
