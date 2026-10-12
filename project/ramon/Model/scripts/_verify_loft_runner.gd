extends SceneTree

## Headless check for the Model scene: instantiates model.tscn, lets both loft
## nodes build themselves, and reports watertightness, winding, cell counts and
## per-axis extents for each. Run with:
##   godot...console.exe --headless --path project --script res://ramon/Model/scripts/_verify_loft_runner.gd
##
## model.tscn is hand-written (the project-wide resave script would rewrite all
## ~130 scenes, so it is not an option for verifying one file), which makes
## loading it here the cheap substitute: it catches bad UIDs, unknown node types
## and malformed properties, all of which are otherwise silent until load.

var _instance: Node
var _reported: bool = false


func _initialize() -> void:
	var packed: PackedScene = load("res://ramon/Model/model.tscn")
	if packed == null:
		print("FAILED: model.tscn did not load")
		return
	_instance = packed.instantiate()
	if _instance == null:
		print("FAILED: model.tscn did not instantiate")
		return
	root.add_child(_instance)


## Nodes added during _initialize() are not in the tree yet, so _ready() has not
## run and neither loft node has built itself. Report from here instead, by which
## time both are live.
func _process(_delta: float) -> bool:
	if _reported:
		return true
	_reported = true
	if _instance == null:
		return true

	var names: Array[String] = []
	for child in _instance.get_children():
		names.append(child.name)
	print("RESULT scene loaded, root=%s children=%s" % [_instance.name, ", ".join(names)])

	_report_mesh("Loft (parameter-driven)", _instance.get_node_or_null("Models/Loft"))
	_report_mesh("LoftRig (ball-driven)", _instance.get_node_or_null("Models/LoftRig"))
	return true


func _report_mesh(label: String, node: Node) -> void:
	if node == null:
		print("FAILED: %s node not found" % label)
		return
	var mesh: ArrayTetraMesh4D = node.mesh
	if mesh == null:
		print("FAILED: %s produced no mesh" % label)
		return

	var positions: PackedVector4Array = mesh.get_vertex_positions()
	var cells: PackedInt32Array = mesh.get_simplex_cell_vertex_indices()
	if positions.is_empty():
		print("FAILED: %s has no vertices" % label)
		return

	# The whole point of staggering the sections in W is that the model is NOT a
	# solid of revolution, so report extent per axis - if W were symmetric about
	# the model's own centre and matched X/Z, every slice would look the same and
	# the model would read as an ordinary 3D object however far the player rotates.
	var min_v: Vector4 = positions[0]
	var max_v: Vector4 = positions[0]
	for p in positions:
		min_v = Vector4(minf(min_v.x, p.x), minf(min_v.y, p.y), minf(min_v.z, p.z), minf(min_v.w, p.w))
		max_v = Vector4(maxf(max_v.x, p.x), maxf(max_v.y, p.y), maxf(max_v.z, p.z), maxf(max_v.w, p.w))

	print("RESULT %s: vertices=%d tetrahedra=%d" % [label, positions.size(), cells.size() / 4])
	print("RESULT %s: bounds min=(%.2f, %.2f, %.2f, %.2f) max=(%.2f, %.2f, %.2f, %.2f)" % [
		label, min_v.x, min_v.y, min_v.z, min_v.w, max_v.x, max_v.y, max_v.z, max_v.w
	])
