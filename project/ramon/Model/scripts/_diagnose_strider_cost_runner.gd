extends SceneTree
## What one Strider rebuild costs, which decides whether it can be animated by
## rebuilding per frame or needs skinning.
var _i: Node
var _done := false
func _initialize() -> void:
	_i = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(_i)
func _process(_d) -> bool:
	if _done: return true
	_done = true
	var rig: Node = _i.get_node("Creature/Strider/Hide")
	rig.verbose = false
	var runs := 8
	var best := 1 << 30
	for r in range(runs):
		var t := Time.get_ticks_usec()
		rig.build(false)
		best = mini(best, Time.get_ticks_usec() - t)
	var cells: int = rig.mesh.get_simplex_cell_vertex_indices().size() / 4
	print("Strider: %d cells, %d vertices, rebuild %.1f ms -> %s at 60Hz, %s at 30Hz" % [
		cells, rig.mesh.get_vertex_positions().size(), float(best) / 1000.0,
		"fits" if best < 16700 else "TOO SLOW", "fits" if best < 33300 else "TOO SLOW"])
	return true
