extends SceneTree
## Checks the split-rig creature: every rig builds, the hierarchy inherits
## transforms, and the head animation drives a node rather than a rebuild.

var _frame := 0
var _root: Node

func _initialize() -> void:
	var packed: PackedScene = load("res://ramon/Model/rigged_creature.tscn")
	if packed == null:
		print("FAIL: scene did not load")
		quit(1)
		return
	_root = packed.instantiate()
	root.add_child(_root)

func _rigs(node: Node, out: Array[Node]) -> void:
	if node.has_method("_collect_chains") and node.has_method("build"):
		out.append(node)
	for child in node.get_children():
		_rigs(child, out)

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	var rigs: Array[Node] = []
	_rigs(_root, rigs)
	var built := 0
	var empty: Array[String] = []
	var tets := 0
	for rig in rigs:
		rig.verbose = false
		rig.build(false)
		var m := rig.mesh as ArrayTetraMesh4D
		if m == null:
			empty.append(String(rig.name))
		else:
			built += 1
			tets += m.get_simplex_cell_vertex_indices().size() / 4
	print("rigs found: %d   built: %d   total tets: %d" % [rigs.size(), built, tets])
	if not empty.is_empty():
		print("EMPTY RIGS: %s" % ", ".join(empty))

	# Transform inheritance: rotating the chest must carry the neck and head.
	var chest: Node4D = _root.get_node("Creature/Barrel/Chest")
	var head: Node4D = _root.get_node("Creature/Barrel/Chest/Neck1/Neck2/Head")
	var before: Vector4 = head.global_position
	chest.basis = Basis4D.from_xy(deg_to_rad(25.0))
	var after: Vector4 = head.global_position
	chest.basis = Projection.IDENTITY
	print("head global moved when chest rotated: %.3f units  %s" % [
		(after - before).length(), "INHERITS" if (after - before).length() > 0.01 else "*** NOT INHERITING ***"])

	# The animation must not dirty any mesh: rotating a rig node leaves the
	# section signature untouched, so no rebuild is scheduled.
	var sig_before: PackedFloat64Array = head._section_signature()
	head.basis = Basis4D.from_zw(deg_to_rad(30.0))
	var sig_after: PackedFloat64Array = head._section_signature()
	head.basis = Projection.IDENTITY
	print("rotating the head changes its section signature: %s  %s" % [
		"yes" if sig_before != sig_after else "no",
		"(no rebuild triggered - the free path)" if sig_before == sig_after else "*** WOULD REBUILD ***"])

	var ok: bool = empty.is_empty() and built == rigs.size() and sig_before == sig_after
	print("RESULT: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
