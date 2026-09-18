extends SceneTree
## Did the neck actually fuse into the body, and what did it cost?
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_merged.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 1:
		var body: MeshInstance4D = _root.get_node("Chicken/Body")
		var m := body.mesh as ArrayTetraMesh4D
		print("MERGED body+neck mesh: %d vertices, %d cells" % [m.get_vertex_positions().size(),
			m.get_simplex_cell_vertex_indices().size() / 4])
		print("separate rigs remaining under Chicken: %s" % str(_root.get_node("Chicken").get_children().map(func(c): return c.name)))
		return false
	var p: CharacterBody4D = _root.get_node("Player")
	var c: Vector4 = _root.get_node("Chicken").position
	var eye := c + Vector4(2.4, 1.15, 0.9, 0.0)
	p.global_position = eye
	p.global_basis = Basis4D.looking_at(c + Vector4(0.0, 0.85, 0.0, 0.0) - eye)
	p.linear_velocity = Vector4.ZERO
	if _f < 40: return false
	var img: Image = root.get_texture().get_image()
	img.save_png("res://smoke_test_output/merged.png")
	print("SAVED merged")
	return true
