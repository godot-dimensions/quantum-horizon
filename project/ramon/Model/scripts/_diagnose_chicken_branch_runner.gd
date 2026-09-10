extends SceneTree

## Reproduces "Add branch here" on the chicken, which is where the one-legged
## result showed up. Reports, for each attempt, where the new ball landed relative
## to its anchor and whether the chain paired.

var _instance: Node
var _frame: int = 0
var _targets: Array = [
	["Models/Chicken/Body", "Ball4"],
	["Models/Chicken/Leg", "Ball2"],
	["Models/Chicken/NeckHead", "Ball4"],
]


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		for entry in _targets:
			var rig: Node = _instance.get_node(entry[0])
			rig.verbose = false
			rig.get_node(entry[1]).add_branch_here()
		return false

	for entry in _targets:
		var rig: Node = _instance.get_node(entry[0])
		print("--- %s, branched off %s (mirror_x=%s, axis=%d) ---" % [
			entry[0].get_file(), entry[1], rig.mirror_x, rig.mirror_axis])
		for chain in rig._collect_chains():
			var names: Array[String] = []
			for ball in chain:
				names.append(ball.name)
			if chain.size() < 2:
				continue
			# Ask the rig, not the ball: a branch ball's own position is relative to its
			# parent ball, and the rig is what resolves that into rig space.
			var anchor: Vector4 = rig._position_in_rig(chain[0])
			var tip: Vector4 = rig._position_in_rig(chain[chain.size() - 1])
			var offset: Vector4 = tip - anchor
			print("   %-34s  offset from anchor = (%.2f, %.2f, %.2f, %.2f)" % [
				" -> ".join(names), offset.x, offset.y, offset.z, offset.w])
	return true
