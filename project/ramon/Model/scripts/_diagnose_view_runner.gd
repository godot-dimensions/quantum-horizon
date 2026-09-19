extends SceneTree
## Why does the floor look foggy, and how deep is everything standing in the mud?
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 15: return false
	var cam: Camera4D = null
	var stack: Array = [_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Camera4D: cam = n
		for c in n.get_children(): stack.append(c)
	if cam:
		print("camera depth_fade_mode=%d start=%.1f | w_fade_mode=%d distance=%.1f slope=%.1f | edge_falloff=%.2f plane_sharpness=%.2f" % [
			cam.depth_fade_mode, cam.depth_fade_start, cam.w_fade_mode, cam.w_fade_distance,
			cam.w_fade_slope, cam.edge_falloff, cam.plane_sharpness])
	var ground := _root.get_node_or_null("Ground") as Node4D
	print("ground node y=%.2f, mesh half-height 1.0 -> top surface at %.2f" % [ground.position.y, ground.position.y + 1.0])
	for path in ["Brachio/Spine/Ball1/BackLeg1/BackLeg2/BackLeg3/BackLeg4",
			"Brachio/Spine/Ball3/FrontLeg1/FrontLeg2/FrontLeg3/FrontLeg4",
			"Chicken/LegL/Ball1"]:
		var b := _root.get_node_or_null(path) as Node4D
		if b == null: continue
		print("  %-28s centre y %.3f, radius %.3f -> lowest surface %.3f" % [
			b.name, b.global_position.y, b.get("radius"), b.global_position.y - float(b.get("radius"))])
	return true
