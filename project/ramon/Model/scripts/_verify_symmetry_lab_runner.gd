extends SceneTree
## Checks symmetry_lab.tscn loads, lights, grounds and builds its ring creature.

var _frame := 0
var _root: Node

func _initialize() -> void:
	var packed: PackedScene = load("res://ramon/Model/symmetry_lab.tscn")
	if packed == null:
		print("FAIL: scene did not load")
		quit(1)
		return
	_root = packed.instantiate()
	root.add_child(_root)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	var ok := true
	for path in ["Sun", "Environment", "Ground/CollisionShape4D", "Ground/GroundMesh", "Creature", "Player"]:
		var node: Node = _root.get_node_or_null(path)
		print("%-28s %s" % [path, "present" if node != null else "MISSING"])
		if node == null:
			ok = false
	var rig: Node = _root.get_node_or_null("Creature")
	if rig != null:
		rig.build(true)
		var m := rig.mesh as ArrayTetraMesh4D
		if m == null:
			print("creature mesh: NULL")
			ok = false
		else:
			var verts: PackedVector4Array = m.get_vertex_positions()
			var ys := []
			var ws := []
			for v in verts:
				ys.append(v.y)
				ws.append(v.w)
			ys.sort()
			ws.sort()
			print("creature: %d verts, %d tets, %d chains" % [
				verts.size(), m.get_simplex_cell_vertex_indices().size() / 4,
				rig._collect_chains().size()])
			print("bounds:   y %.2f..%.2f   w %.2f..%.2f" % [ys[0], ys[-1], ws[0], ws[-1]])
			var leg: Node = _root.get_node_or_null("Creature/Chest/ForeLegTop")
			print("fore leg: symmetry_type=%d symmetry_count=%d (2 = Cyclic)" % [
				leg.symmetry_type, leg.symmetry_count])
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
