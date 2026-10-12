extends SceneTree

## Checks the mirroring rule on the chicken:
##
## - An off-centre chain (Leg, Wing) must produce BOTH sides from one rig, so its
##   mesh should be symmetric about X = 0 and hold twice the tetrahedra.
## - A midline chain (Body, NeckHead, Beak, Wattle) must be left alone, the way
##   Spore leaves a part sitting on the centre line single rather than doubling it.

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var chicken: Node = _instance.get_node("Models/Chicken")
	print("%-10s %9s %8s %8s %9s   %s" % ["rig", "tetrahedra", "min x", "max x", "ball |x|", "verdict"])
	for part in chicken.get_children():
		var mesh: ArrayTetraMesh4D = part.mesh
		if mesh == null:
			print("%-10s FAILED: no mesh" % part.name)
			continue
		var min_x: float = INF
		var max_x: float = -INF
		for p in mesh.get_vertex_positions():
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
		# A round body is symmetric in X whether or not it was mirrored, so the mesh
		# bounds cannot tell you. The actual criterion is where the BALLS sit.
		var ball_offset: float = 0.0
		for ball in part.get_children():
			if ball.has_method("get_loft_section"):
				ball_offset = maxf(ball_offset, absf((ball.get_loft_section()["center"] as Vector4).x))
		var verdict: String = "MIRRORED (balls off-centre)" if ball_offset > 0.001 else "single (balls on midline)"
		print("%-10s %9d %8.3f %8.3f %9.3f   %s" % [
			part.name, mesh.get_simplex_cell_vertex_indices().size() / 4,
			min_x, max_x, ball_offset, verdict])
	return true
