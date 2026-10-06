extends SceneTree

## The tower's tetrahedra, part by part (6 Oct 2026, the tower pass): the Lookout tower alone, on its
## old frame and on the fence frame, each child mesh counted, so a trim goes where the cells are.
##
##   CreationLab/scripts/lab_run.sh headless pl_tower_cells res://ramon/PenLayout/scripts/_study_tower_cells_runner.gd

const Tower := preload("res://ramon/chickenpen/lookout/lookout_tower_4d.gd")


func _initialize() -> void:
	_run.call_deferred()


func _cells(node: Node) -> int:
	var n: int = 0
	var meshes: Array = node.find_children("*", "MeshInstance4D", true, false)
	if node is MeshInstance4D:
		meshes.append(node)
	for mi in meshes:
		var mesh: Resource = (mi as MeshInstance4D).mesh
		if mesh != null and mesh.has_method("get_simplex_cell_vertex_indices"):
			n += (mesh.call("get_simplex_cell_vertex_indices") as PackedInt32Array).size() / 4
	return n


func _report(label: String, tower: Node) -> void:
	var total: int = 0
	var parts: Array = []
	for child in tower.get_children():
		var c: int = _cells(child)
		if c > 0:
			parts.append("%s %d" % [child.name, c])
			total += c
	print("CELLS %-10s %6d  | %s" % [label, total, ", ".join(parts)])


func _run() -> void:
	var tower := Node4D.new()
	tower.set_script(Tower)
	root.add_child(tower)
	await process_frame
	_report("old", tower)
	tower.set("fence_frame", true)
	await process_frame
	_report("fence", tower)
	print("TOWER CELLS DONE")
	quit(0)
