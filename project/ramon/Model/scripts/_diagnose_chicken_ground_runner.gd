extends SceneTree
## Where is the chicken's floor, really? The two ways of finding a foot disagree.
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 30: return false
	var c: Node4D = _root.get_node_or_null("Chicken")
	print("Chicken node position: %v" % c.position)
	for leg in ["LegL", "LegR"]:
		var rig: Node = c.get_node_or_null(leg)
		print("-- %s (rig local %v)" % [leg, (rig as Node4D).position])
		for child in rig.get_children():
			if child.has_method("get_loft_section"):
				print("   ball %s local %v global %v" % [child.name, child.position, (child as Node4D).global_position])
			else:
				print("   non-ball child: %s (%s)" % [child.name, child.get_class()])
	var deep: Node = c.get_node_or_null("LegL")
	while deep.get_child_count() > 0: deep = deep.get_child(deep.get_child_count()-1)
	print("deepest-child walk lands on: %s (%s) global %v" % [deep.name, deep.get_class(),
		(deep as Node4D).global_position if deep is Node4D else Vector4.ZERO])
	return true
