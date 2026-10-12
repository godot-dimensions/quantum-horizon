extends SceneTree
## Which editing path is safe on the rigged creature's deep hierarchy?
## The viewport gizmo writes global_position; the Inspector writes local position.
## Round-tripping a value must be a no-op, or undo cannot restore it either.

var _frame := 0
var _root: Node

func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature.tscn").instantiate()
	root.add_child(_root)

func _depth(node: Node) -> int:
	var d := 0
	var n: Node = node
	while n != null and n != _root:
		d += 1
		n = n.get_parent()
	return d

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 3:
		return false
	var paths := [
		"Creature/Barrel/B2",
		"Creature/Barrel/Chest/Neck1/Neck2/Head/B2",
		"Creature/Barrel/Rump/Tail1/Tail2/Tail3/Tail4/B2",
		"Creature/Barrel/Chest/ForeLA Upper/B2".replace(" ", ""),
	]
	print("node                                              depth  global round trip      local round trip")
	for p in paths:
		var n: Node4D = _root.get_node_or_null(p) as Node4D
		if n == null:
			continue
		# global_position: read it, write the same value back.
		var g0: Vector4 = n.global_position
		n.global_position = g0
		var g1: Vector4 = n.global_position
		var gdrift: float = (g1 - g0).length()
		n.global_position = g0  # leave it be (may itself be lossy; local restored below)
		# local position: the Inspector's field.
		var l0: Vector4 = n.position
		n.position = l0
		var l1: Vector4 = n.position
		var ldrift: float = (l1 - l0).length()
		print("%-48s %5d  %-21s  %s" % [
			p.get_file() if false else p, _depth(n),
			"OK" if gdrift < 0.0001 else "BROKEN: off by %.2f" % gdrift,
			"OK" if ldrift < 0.0001 else "BROKEN: off by %.2f" % ldrift])
	quit(0)
	return true
