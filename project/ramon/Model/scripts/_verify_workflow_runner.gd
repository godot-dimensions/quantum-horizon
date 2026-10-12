extends SceneTree

## Walks the real authoring workflow on a brand new rig, one button at a time, and
## reports exactly what each press produced. This is the sequence a person actually
## performs to build a limb, so if any step surprises them it should surprise this
## runner too.
##
## After every press it reports each chain, where its balls sit IN RIG SPACE (a
## branch ball's own position is relative to its parent ball, so the raw value is
## not comparable), and whether the chain paired up into a mirrored twin.

var _rig: Node
var _step: int = 0


func _initialize() -> void:
	var world := Node4D.new()
	root.add_child(world)
	_rig = MeshInstance4D.new()
	_rig.set_script(load("res://ramon/Model/scripts/loft_rig_4d.gd"))
	_rig.name = "TestRig"
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
			_report("two presses of 'Add ball' - a plain two-ball chain")
			_rig.get_node("Ball2").add_branch_here()
		4:
			_report("'Add branch here' on Ball2")
			_branch_tip().add_ball_here()
		5:
			_report("'Add ball here' on the new branch ball - extending the limb")
			_branch_tip().add_ball_here()
		6:
			_report("'Add ball here' again - a three-ball limb")
			# THE CASE THAT FAILED: branching off the very END of a limb, where the
			# new ball is the tip's only child and used to be absorbed as a
			# continuation instead of starting a chain of its own.
			_branch_tip().add_branch_here()
		7:
			_report("'Add branch here' on the TIP of that limb")
			return true
	return false


## The deepest ball of the branch, i.e. whatever the last press created.
func _branch_tip() -> Node:
	var node: Node = _rig.get_node("Ball2")
	while true:
		var kids: Array = []
		for child in node.get_children():
			if child.has_method("get_loft_section"):
				kids.append(child)
		if kids.is_empty():
			return node
		node = kids[0]
	return node


func _report(label: String) -> void:
	print("--- %s ---" % label)
	for chain in _rig._collect_chains():
		var parts: Array[String] = []
		for ball in chain:
			var at: Vector4 = _rig._position_in_rig(ball)
			parts.append("%s(%.2f, %.2f, %.2f)" % [ball.name, at.x, at.y, at.z])
		var mirrored: bool = _rig._should_mirror(_sections(chain), chain[0] != _rig.get_node_or_null(String(chain[0].name)), 0.0)
		print("   %s" % " -> ".join(parts))
	print("   mesh: %s" % ("none" if _rig.mesh == null else "%d tetrahedra" % ((_rig.mesh as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4)))


func _sections(chain: Array) -> Array:
	var out: Array = []
	for ball in chain:
		var section: Dictionary = ball.get_loft_section()
		section["center"] = _rig._position_in_rig(ball)
		out.append(section)
	return out
