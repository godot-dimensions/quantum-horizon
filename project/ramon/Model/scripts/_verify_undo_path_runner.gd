extends SceneTree

## Isolates why Ctrl+Z does nothing after moving a ball.
##
## The editor's 4D gizmo records undo as `global_position`, so undo works only if
## writing that property is faithful. The simplest possible check: read a node's
## global_position and write the SAME VALUE straight back. That must be a no-op. If
## the node moves, then undo cannot restore anything either - it writes the correct
## old value and the node lands somewhere else.
##
## Tested across the cases that differ: a node under an untransformed parent, one
## under a rotated parent, and one nested inside another ball.

var _instance: Node
var _done: bool = false


func _initialize() -> void:
	_instance = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(_instance)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	print("%-34s %-22s %s" % ["node", "parent", "global_position round trip"])
	for path in [
			"Models/LoftRig/Ball1",                      # parent basis is identity
			"Models/Chicken/Body/Ball1",                 # ditto, nested one level
			"Models/Brachio/Spine/Ball1",                # parent Brachio is yawed 90 degrees
			"Models/Brachio/Spine/Ball3/FrontLeg1",      # yawed parent AND nested in a ball
			"Models/Brachio/Spine/Ball3/FrontLeg1/FrontLeg2"]:
		var node: Node4D = _instance.get_node_or_null(path)
		if node == null:
			continue
		var before: Vector4 = node.global_position
		node.global_position = before
		var after: Vector4 = node.global_position
		var faithful: bool = before.distance_to(after) < 0.0001
		print("%-34s %-22s %s" % [
			String(path).get_file(), node.get_parent().name,
			"ok" if faithful else "BROKEN: %.2f -> %.2f (moved %.2f)" % [
				before.x, after.x, before.distance_to(after)]])
	return true
