extends SceneTree

## How many MeshInstance4D nodes the pen draws, and how many tetrahedra they hold: the
## projection's CPU cost goes with the first (3 Oct). Gives up after 40 s.
##
##   godot... --path project --windowed --resolution 960x540 --position 40,40
##       --script res://ramon/chickenpen/lookout/_count_meshes_runner.gd

var _room: Node
var _t: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	if _t < 10.0:
		return false
	var nodes: int = 0
	var cells: int = 0
	var by_top: Dictionary = {}
	for n in _room.find_children("*", "MeshInstance4D", true, false):
		var m := n as MeshInstance4D
		if m == null or not m.is_visible_in_tree() or m.mesh == null:
			continue
		nodes += 1
		var c: int = 0
		if m.mesh is TetraMesh4D:
			c = (m.mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
		cells += c
		# Grouped by the node under World (or the room) it belongs to.
		var p: Node = m
		while p.get_parent() != null and p.get_parent() != _room and String(p.get_parent().name) != "World":
			p = p.get_parent()
		var key: String = String(p.name)
		var row: Array = by_top.get(key, [0, 0])
		by_top[key] = [int(row[0]) + 1, int(row[1]) + c]
	print("      visible MeshInstance4D nodes: %d, tetrahedra %d" % [nodes, cells])
	var keys: Array = by_top.keys()
	keys.sort_custom(func(a, b): return int(by_top[a][0]) > int(by_top[b][0]))
	for k in keys.slice(0, 14):
		print("        %-22s %5d nodes %8d tetrahedra" % [k, by_top[k][0], by_top[k][1]])
	print("COUNT DONE")
	return true
