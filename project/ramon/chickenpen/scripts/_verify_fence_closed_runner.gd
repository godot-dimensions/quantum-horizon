extends SceneTree

## Is the pen actually shut? Both halves of it: the rails you see and the wall you cannot
## walk through are generated in the same pass, so a gap could close in one and not the
## other and only one of those is visible.

var _root: Node
var _f := 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 40: return false
	var fence: Node4D = _root.get_node("Pen/Fence")
	var fails: int = 0

	# Walk along the +Z side - the one the gateway used to be in - at ankle height and
	# see whether a collision box covers every point of it.
	var body: Node = null
	for child in fence.get_children():
		if child is CollisionObject4D:
			body = child
	var boxes: Array = []
	for shape in body.get_children():
		if shape is CollisionShape4D and shape.shape is BoxShape4D:
			boxes.append([shape.position, (shape.shape as BoxShape4D).size])
	print("   %d collision boxes in the fence" % boxes.size())

	# READ FROM THE FENCE. Written down, this walked the near side of a pen that had since
	# been made smaller and reported a gap where there is timber.
	var z_side: float = float(fence.get("extend_z_positive"))
	var x_reach: float = float(fence.get("extend_x_positive"))
	var holes: Array = []
	for i in 81:
		var x: float = -x_reach + float(i) * (x_reach * 2.0 / 80.0)
		var covered: bool = false
		for b in boxes:
			var at: Vector4 = b[0]
			var size: Vector4 = b[1]
			if absf(at.z - z_side) > size.z * 0.5 + 0.01:
				continue
			if absf(x - at.x) <= size.x * 0.5 + 0.001:
				covered = true
				break
		if not covered:
			holes.append(x)
	print("   uncovered points along the near side: %d" % holes.size())
	if holes.size() > 0:
		print("   FAIL there is still a gap around x %.2f to %.2f" % [holes[0], holes[-1]])
		fails += 1
	else:
		print("   PASS the near side is solid from end to end")

	# And the rails, which are what actually reads as a fence.
	var rails: int = 0
	var near_rails: int = 0
	for child in fence.get_children():
		if child is MeshInstance4D:
			rails += 1
			if absf(child.position.z - z_side) < 0.2:
				near_rails += 1
	print("   %d fence meshes, %d of them on the near side" % [rails, near_rails])
	if near_rails == 0:
		print("   FAIL nothing is drawn along the near side")
		fails += 1
	else:
		print("   PASS the near side is drawn")

	print("\n%d FAIL(s)" % fails)
	quit(1 if fails > 0 else 0)
	return true
