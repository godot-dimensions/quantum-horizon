extends SceneTree

## Checks the two new controls:
##
## 1. "Add branch here" throws the limb the way new_branch_direction says, so a
##    branch along +Y stays on the mirror plane and therefore stays SINGLE, while
##    one along the mirror axis pairs up.
## 2. "Detach mirror" turns a generated twin into real balls: the chain count goes
##    up, the tetrahedron count stays the same, and both sides become editable.

var _rig: Node
var _step: int = 0


func _initialize() -> void:
	var world := Node4D.new()
	root.add_child(world)
	_rig = MeshInstance4D.new()
	_rig.set_script(load("res://ramon/Model/scripts/loft_rig_4d.gd"))
	_rig.name = "DetachRig"
	world.add_child(_rig)


func _process(_delta: float) -> bool:
	_step += 1
	if _rig.get("verbose") != null:
		_rig.verbose = false

	match _step:
		1:
			_rig.add_ball()
		2:
			_rig.add_ball()
		3:
			_rig.get_node("Ball2").add_branch_here()
		4:
			_report("branch along the mirror axis (default)")
			_rig.new_branch_direction = 3 # +Y
			_rig.get_node("Ball1").add_branch_here()
		5:
			_report("a second branch, thrown along +Y")
			var arm: Node = _rig.get_node("Ball2").get_child(0)
			arm.detach_mirror()
		6:
			_report("after 'Detach mirror' on the first branch")
			# A fork made by adding a SECOND child, with no starts_branch flag on it:
			# it heads a chain purely because its parent now has two children, and it
			# must be detachable exactly like a flagged one.
			var arm: Node = _rig.get_node("Ball2").get_child(0)
			arm.add_ball_here()
			arm.add_ball_here()
		7:
			var fork: Node = _rig.get_node("Ball2").get_child(0).get_child(1)
			print("--- fork '%s' has starts_branch=%s ---" % [fork.name, fork.starts_branch])
			fork.detach_mirror()
		8:
			_report("after detaching that unflagged fork")
			return true
	return false


func _report(label: String) -> void:
	print("--- %s ---" % label)
	for chain in _rig._collect_chains():
		var parts: Array[String] = []
		var sections: Array = []
		for ball in chain:
			var at: Vector4 = _rig._position_in_rig(ball)
			parts.append("%s(%.2f, %.2f)" % [ball.name, at.x, at.y])
			var section: Dictionary = ball.get_loft_section()
			section["center"] = at
			sections.append(section)
		var is_branch: bool = chain.size() > 1 and chain[1].get_parent() == chain[0]
		var plane: float = (sections[0]["center"] as Vector4).x if is_branch else 0.0
		var paired: bool = _rig._should_mirror(sections, is_branch, plane)
		if is_branch and not bool(chain[1].mirror_branch):
			paired = false
		print("   %-46s %s" % [" -> ".join(parts), "MIRRORED" if paired else "single"])
	print("   mesh: %d tetrahedra" % ((_rig.mesh as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4))
