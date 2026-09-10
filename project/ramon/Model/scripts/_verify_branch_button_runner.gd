extends SceneTree

## Checks both buttons do what their names promise, and that a limb built entirely
## with them ends up as a real mirrored branch rather than a stray ball.

var _instance: Node
var _spine: Node
var _frame: int = 0


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	_frame += 1
	if _spine == null:
		_spine = _instance.get_node("Models/Brachio/Spine")
		_spine.verbose = false

	match _frame:
		1:
			print("--- 'Add ball here' on a ball in the RIG's own chain: expect a SIBLING ---")
			var mid: Node = _spine.get_node("Ball4")
			mid.add_ball_here()
		2:
			_report_chain("after continuing the spine")
			print("--- 'Add ball here' on a ball INSIDE a branch: expect a CHILD ---")
			var limb: Node = _spine.get_node("Ball3/FrontLeg1/FrontLeg2/FrontLeg3/FrontLeg4")
			limb.add_ball_here()
		3:
			_report_chain("after extending the front leg")
			print("--- 'Add branch here' on the chest: expect a NEW mirrored limb ---")
			_spine.get_node("Ball3").add_branch_here()
		4:
			_report_chain("after starting a new branch")
			return true
	return false


func _report_chain(label: String) -> void:
	print("  %s" % label)
	for chain in _spine._collect_chains():
		var names: Array[String] = []
		var offset: float = 0.0
		for index in range(chain.size()):
			names.append(chain[index].name)
			if index > 0:
				offset = maxf(offset, absf((chain[index].get_loft_section()["center"] as Vector4).x))
		print("    %-58s %s" % [
			" -> ".join(names), "MIRRORED" if offset > 0.001 else "single"])
