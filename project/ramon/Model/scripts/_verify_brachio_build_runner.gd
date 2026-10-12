extends SceneTree
## Is the brachiosaurus itself built cleanly? The scene throws warnings from several
## rigs at once, so this rebuilds ONLY the brachio with reporting on, between markers.
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 15: return false
	var spine := _root.get_node_or_null("Brachio/Spine") as MeshInstance4D
	spine.set("verbose", true)
	print("===BRACHIO BUILD BEGIN===")
	spine.call("build")
	print("===BRACHIO BUILD END===")
	var m := spine.mesh as TetraMesh4D
	print("brachio: %d tets after the tip ball came off" % (m.get_simplex_cell_vertex_indices().size() / 4))
	return true
