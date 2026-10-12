extends SceneTree

## Checks branching and the scale test on the brachiosaurus.
##
## One rig should produce four chains - spine, tail, and two mirrored leg pairs -
## with the midline rule keeping spine and tail single while the legs double.
## Also reports both animals' real heights, since the whole point of the test is
## that a 50 cm chicken and a 10 m sauropod come out of the same authoring tool.

const _UNITS_PER_METRE: float = 4.0 # The chicken is ~2 units and stands in for 50 cm.

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var spine: Node = _instance.get_node("Models/Brachio/Spine")
	print("brachio rig '%s': %d balls in the tree" % [spine.name, _count_balls(spine)])
	for chain in spine._collect_chains():
		var names: Array[String] = []
		var offset: float = 0.0
		for ball in chain:
			names.append(ball.name)
			offset = maxf(offset, absf((ball.get_loft_section()["center"] as Vector4).x))
		print("  chain: %-38s %s" % [
			" -> ".join(names), "MIRRORED" if offset > 0.001 else "single (midline)"])

	_report("Brachio", _instance.get_node("Models/Brachio"))
	_report("Chicken", _instance.get_node("Models/Chicken"))
	return true


func _count_balls(node: Node) -> int:
	var total: int = 0
	for child in node.get_children():
		if child.has_method("get_loft_section"):
			total += 1 + _count_balls(child)
	return total


## Height and length of everything under a model root, in metres.
func _report(label: String, root_node: Node) -> void:
	var low := Vector4(INF, INF, INF, INF)
	var high := Vector4(-INF, -INF, -INF, -INF)
	var cells: int = 0
	for part in root_node.get_children():
		var mesh: ArrayTetraMesh4D = part.mesh
		if mesh == null:
			continue
		cells += mesh.get_simplex_cell_vertex_indices().size() / 4
		for p in mesh.get_vertex_positions():
			low = Vector4(minf(low.x, p.x), minf(low.y, p.y), minf(low.z, p.z), minf(low.w, p.w))
			high = Vector4(maxf(high.x, p.x), maxf(high.y, p.y), maxf(high.z, p.z), maxf(high.w, p.w))
	print("%-8s height %6.2f m   length %6.2f m   width %5.2f m   %d tetrahedra" % [
		label, (high.y - low.y) / _UNITS_PER_METRE, (high.z - low.z) / _UNITS_PER_METRE,
		(high.x - low.x) / _UNITS_PER_METRE, cells])
