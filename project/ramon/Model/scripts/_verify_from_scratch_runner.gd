extends SceneTree

## Walks the exact path a person takes from an empty MeshInstance4D to a limbed
## model, using only the buttons - no hand-built nodes, no scene tree dragging.

var _rig: Node
var _frame: int = 0


func _initialize() -> void:
	var world := Node4D.new()
	root.add_child(world)
	_rig = MeshInstance4D.new()
	_rig.set_script(load("res://ramon/Model/scripts/loft_rig_4d.gd"))
	_rig.name = "NewRig"
	world.add_child(_rig)


func _process(_delta: float) -> bool:
	_frame += 1
	if _rig.get("verbose") != null:
		_rig.verbose = false

	match _frame:
		1:
			print("empty rig:            mesh=%s" % ("none" if _rig.mesh == null else "built"))
			_rig.add_ball()
		2:
			print("after 1x 'Add ball':  %d ball(s), mesh=%s" % [
				_count(), "none (needs 2)" if _rig.mesh == null else "built"])
			_rig.add_ball()
		3:
			print("after 2x 'Add ball':  %d ball(s), mesh=%s" % [_count(), _describe()])
			_rig.get_node("Ball2").add_ball_here()
		4:
			print("after 'Add ball here': %d ball(s), mesh=%s" % [_count(), _describe()])
			_rig.get_node("Ball2").add_branch_here()
		5:
			print("after 'Add branch here':")
			for chain in _rig._collect_chains():
				var names: Array[String] = []
				var offset: float = 0.0
				for index in range(chain.size()):
					names.append(chain[index].name)
					if index > 0:
						offset = maxf(offset, absf((chain[index].get_loft_section()["center"] as Vector4).x))
				print("   %-32s %s" % [" -> ".join(names), "MIRRORED" if offset > 0.001 else "single"])
			print("   total: %s" % _describe())
			return true
	return false


func _count() -> int:
	var total: int = 0
	for child in _rig.get_children():
		if child.has_method("get_loft_section"):
			total += 1
	return total


func _describe() -> String:
	if _rig.mesh == null:
		return "none"
	return "%d tetrahedra" % ((_rig.mesh as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4)
