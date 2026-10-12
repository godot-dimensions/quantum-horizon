extends SceneTree

## How much geometry each piece of the Lookout adds: mesh nodes and tetrahedra, per piece.
## Headless is fine - this is geometry, not rendering.
##
##   godot... --headless --path project --script res://ramon/chickenpen/lookout/_count_cells_runner.gd

const PIECES := ["World/LookoutSite/Lookout", "World/OwlTree", "World/AnaOwl", "World/Balloon", "World/AnaMarsh", "World/AnaHeron",
	"World/KataWood", "World/Chipmunk0", "World/LookoutSite/Wren"]

var _room: Node
var _t: float = 0.0


func _initialize() -> void:
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_count_test.cfg")
	root.add_child(_room)


func _count(node: Node) -> Vector2i:
	var nodes: int = 0
	var cells: int = 0
	for m in node.find_children("*", "MeshInstance4D", true, false) + ([node] if node is MeshInstance4D else []):
		var mesh: Mesh4D = (m as MeshInstance4D).mesh
		if mesh is TetraMesh4D:
			nodes += 1
			cells += (mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	return Vector2i(nodes, cells)


func _process(d: float) -> bool:
	_t += d
	if _t < 2.0:
		return false
	var total := Vector2i.ZERO
	for path in PIECES:
		var node: Node = _room.get_node_or_null(path)
		if node == null:
			print("      %-18s (none)" % path)
			continue
		var c: Vector2i = _count(node)
		total += c
		print("      %-18s %4d mesh nodes  %7d tetrahedra" % [path.trim_prefix("World/"), c.x, c.y])
	var pen: Vector2i = _count(_room.get_node("World")) - total
	print("      %-18s %4d mesh nodes  %7d tetrahedra" % ["(the pen's World)", pen.x, pen.y])
	print("COUNT DONE")
	return true
