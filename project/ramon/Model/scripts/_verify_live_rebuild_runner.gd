extends SceneTree

## Exercises the three things asked for, one per frame, without touching build()
## directly - everything here must happen because the rig noticed a change by
## itself, which is the whole point of live rebuilding.

var _instance: Node
var _rig: Node
var _frame: int = 0


func _initialize() -> void:
	var packed: PackedScene = load("res://ramon/Model/model.tscn")
	_instance = packed.instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	_frame += 1
	if _rig == null:
		_rig = _instance.get_node("Models/LoftRig")
		_rig.verbose = false

	match _frame:
		1:
			_report("baseline")
			print("--- moving Ball2 in W and growing its radius (no build() call) ---")
			var ball: Node = _rig.get_node("Ball2")
			ball.position = Vector4(0.0, 1.8, 0.0, 2.5)
			ball.radius = 2.4
		2:
			_report("after live rebuild")
			print("--- pressing 'Add ball here' on Ball2 (no build() call) ---")
			_rig.get_node("Ball2").add_ball_here()
		3:
			_report("after adding a ball")
			print("children now: %s" % [_child_names()])
			return true
	return false


func _child_names() -> Array[String]:
	var names: Array[String] = []
	for child in _rig.get_children():
		names.append(child.name)
	return names


func _report(label: String) -> void:
	var mesh: ArrayTetraMesh4D = _rig.mesh
	if mesh == null:
		print("%-24s NO MESH" % label)
		return
	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var max_x: float = 0.0
	var min_w: float = positions[0].w
	var max_w: float = positions[0].w
	for p in positions:
		max_x = maxf(max_x, absf(p.x))
		min_w = minf(min_w, p.w)
		max_w = maxf(max_w, p.w)
	print("%-24s vertices=%4d tetrahedra=%5d  max|x|=%.2f  w range=[%.2f, %.2f]" % [
		label, positions.size(), mesh.get_simplex_cell_vertex_indices().size() / 4, max_x, min_w, max_w
	])
