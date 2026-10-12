extends SceneTree

## Reports how the TestLimb decomposes: which chains it splits into, where each
## ball resolves in rig space, and which chains paired into mirrored twins. A ball
## with two children should end its chain and start one per child, so the fork
## should show up as its own pair.

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var rig: Node = _instance.get_node("Models/TestLimb")
	rig.verbose = false
	rig.build(false)

	for chain in rig._collect_chains():
		var parts: Array[String] = []
		var sections: Array = []
		for ball in chain:
			var at: Vector4 = rig._position_in_rig(ball)
			parts.append("%s(%.2f, %.2f)" % [ball.name, at.x, at.y])
			var section: Dictionary = ball.get_loft_section()
			section["center"] = at
			sections.append(section)
		var is_branch: bool = chain[0].get_parent() != rig or chain.size() > 0 and chain[0].get_parent() == rig and false
		is_branch = chain[0].get_parent() == rig and chain.size() > 1 and chain[1].get_parent() == chain[0]
		var plane: float = (sections[0]["center"] as Vector4).x if is_branch else 0.0
		print("   %-52s %s" % [
			" -> ".join(parts),
			"MIRRORED" if rig._should_mirror(sections, is_branch, plane) else "single"])

	var mesh: ArrayTetraMesh4D = rig.mesh
	print("   mesh: %d tetrahedra" % (mesh.get_simplex_cell_vertex_indices().size() / 4))
	return true
