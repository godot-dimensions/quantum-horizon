extends SceneTree

## Where does the rock's own geometry sit against the ground?
##
## The block builds its field around the middle of its grid, so the node's origin is the
## CENTRE of the rock and not its base - drop it in at y = 0 and half of it is buried.
## This reports the lowest solid voxel so the lift is a number rather than a nudge.

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var rock: Node4D = _root.get_node("World/MiningRock")
	var voxels: Node = rock.get_node("Voxels")
	var lo: float = 1e9
	var hi: float = -1e9
	var half: float = 0.0
	for shape in voxels.get_children():
		if shape is CollisionShape4D and not shape.is_queued_for_deletion():
			var at: Vector4 = (shape as CollisionShape4D).global_position
			var box: BoxShape4D = (shape as CollisionShape4D).shape as BoxShape4D
			if box != null:
				half = box.size.y * 0.5
			lo = minf(lo, at.y - half)
			hi = maxf(hi, at.y + half)
	print("\n   node sits at y %.2f" % rock.global_position.y)
	print("   rock runs from y %+.2f to %+.2f" % [lo, hi])
	print("   buried by %.2f m; lift the node by that to stand it on the ground" % maxf(-lo, 0.0))
	quit(0)
	return true
