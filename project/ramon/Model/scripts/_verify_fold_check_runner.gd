extends SceneTree

## The fold check must be silent on healthy models and loud on a bend that is too
## sharp for the section thickness. A check that cries wolf is worse than none.

const _Builder = preload("res://ramon/Model/scripts/loft_builder_4d.gd")

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	print("--- synthetic: a chain bent past what its thickness allows ---")
	for case in [[0.44, 0.28, 0.0], [0.44, 0.28, 2.0], [1.5, 4.0, 8.0]]:
		var sections: Array = []
		for index in range(5):
			var offset: float = case[2] * case[1] if index == 2 else 0.0
			sections.append({
				"center": Vector4(offset, float(index) * case[1], 0.0, 0.0),
				"radius": case[0], "v_scale": 1.0, "w_scale": 1.0})
		print("radius %.2f, spacing %.2f, pull %.1fx spacing:" % case)
		_Builder.build(sections, 6, 12, true, true, true)

	print("--- the real models, which must all stay silent ---")
	for path in ["Models/Brachio/Spine", "Models/Chicken/Body", "Models/Chicken/NeckHead",
			"Models/Chicken/Leg", "Models/Chicken/Wing", "Models/LoftRig"]:
		var rig: Node = _instance.get_node_or_null(path)
		if rig == null:
			continue
		rig.verbose = false
		rig.build(false)
		print("  %-26s rebuilt, %d tetrahedra" % [
			path, (rig.mesh as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4])
	return true
