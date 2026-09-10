extends SceneTree
var _done := false
func _initialize() -> void:
	root.add_child((load("res://ramon/Model/model.tscn") as PackedScene).instantiate())
func _process(_d) -> bool:
	if _done: return true
	_done = true
	var rig: Node = root.get_node("Model/Models/Goat/Hide")
	var chains: Array = rig._collect_chains()
	print("goat: %d chains, %d tetrahedra" % [chains.size(), rig.mesh.get_simplex_cell_vertex_indices().size() / 4])
	for chain in chains:
		var names: Array = []
		for b in chain: names.append(b.name)
		var mirrored: bool = false
		var sections: Array = []
		for b in chain:
			var s: Dictionary = b.get_loft_section(); s["center"] = rig._position_in_rig(b); sections.append(s)
		if chain.size() >= 2:
			mirrored = rig._should_mirror(sections, chain != chains[0], rig._axis_value(sections[0]["center"]) if chain != chains[0] else 0.0)
		print("   %s%s" % [" -> ".join(names), "   [MIRRORED into a pair]" if mirrored else ""])
	var ramp: PackedColorArray = rig.mesh.get_meta("loft_ramp", PackedColorArray())
	print("ramp: %d colours for %d coordinates" % [ramp.size(), rig.mesh.get_texture_map_values().size()])
	return true
