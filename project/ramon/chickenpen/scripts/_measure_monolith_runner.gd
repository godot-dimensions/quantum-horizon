extends SceneTree

## What the monolith in the cave actually costs, so the miner quotes measured numbers and
## not invented ones (the professor's rule, professor_script.gd header).
##
## Loads the cave on its own - no pen, no crossing - since this only needs the block, and
## reports: grid points, tetrahedra, surface colliders, and how long one blow takes, as
## the mean of several blows at different surface points. Headless is fine: the remesh is
## script time, and the proxy rebuild it triggers is measured separately by the windowed
## frame runner.

var _cave: Node
var _f := 0


func _initialize() -> void:
	_cave = load("res://ramon/chickenpen/cave/cave.tscn").instantiate()
	root.add_child(_cave)


func _process(_d: float) -> bool:
	_f += 1
	if _f < 5:
		return false
	var block: Node4D = _cave.get_node("Monolith")
	var ground: MeshInstance4D = block.get_node("Ground")
	var voxels: Node = block.get_node("Voxels")
	var n: int = int(block.get("grid_size"))
	var tets: int = (ground.mesh as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	print("   grid %d^4 = %d points, cell %.2f m" % [n, n * n * n * n, float(block.get("cell_size"))])
	print("   %d tetrahedra, %d surface colliders" % [tets, voxels.get_child_count()])
	var times: PackedFloat64Array = []
	for i in 5:
		# Fresh each time: a blow frees the colliders it rebuilds, and a freed one does
		# nothing when struck - which measured as a 0 ms blow.
		var shapes: Array = voxels.get_children().filter(func(c): return not c.is_queued_for_deletion())
		var shape: CollisionShape4D = shapes[(i * 37) % shapes.size()] as CollisionShape4D
		var t0: int = Time.get_ticks_usec()
		block.call("mine_at_shape", shape)
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)
	var total := 0.0
	for t in times:
		total += t
	print("   one blow: %.0f ms mean over %d  (%s)" % [total / times.size(), times.size(), ", ".join(Array(times).map(func(t): return "%.0f" % t))])
	tets = (ground.mesh as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	print("   after five blows: %d tetrahedra, %d colliders" % [tets, voxels.get_child_count()])
	quit()
	return true
