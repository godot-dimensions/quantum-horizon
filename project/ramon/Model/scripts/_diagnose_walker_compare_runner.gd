extends SceneTree
## Compares what each walker asks of a leg. The two-bone version walks; the FABRIK
## version curls the legs up under the body. The question is whether the solver is at
## fault or the target it is given, and that is answerable by measurement.
var _i: Node
var _f := 0
func _initialize() -> void:
	_i = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(_i)
func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	var rig: Node = _i.get_node("Creature/Strider/Hide")
	var walker: Node = _i.get_node("Creature/Strider/Walker")
	print("walker script: %s" % walker.get_script().resource_path.get_file())
	# Shadow skeletons only exist in the FABRIK version.
	var shadows := 0
	for child in walker.get_children():
		if not str(child.name).begins_with("Shadow_"): continue
		shadows += 1
		var target: Node4D = child.get_node_or_null("Target")
		var lengths: Array = child.link_lengths
		var total: float = 0.0
		for l in lengths: total += float(l)
		var anchor: Vector4 = child.global_position
		var goal: Vector4 = target.global_position
		print("   %s: anchor %s" % [child.name, _v(anchor)])
		print("      chain length %.2f, target at %s, anchor->target %.2f (%.0f%% of chain)" % [
			total, _v(goal), anchor.distance_to(goal), 100.0 * anchor.distance_to(goal) / total])
	if shadows == 0:
		print("   no shadow skeletons - this is the two-bone walker")
	# Whichever walker is in play, where do the balls actually end up?
	for ball in rig.get_children():
		if not ball.has_method("get_loft_section"): continue
		for hip in ball.get_children():
			if not hip.has_method("get_loft_section"): continue
			if not str(hip.name).ends_with("Hip"): continue
			var chain: Array = [hip]
			var n: Node = hip
			while true:
				var nx: Node = null
				for c in n.get_children():
					if c.has_method("get_loft_section"): nx = c; break
				if nx == null: break
				chain.append(nx); n = nx
			var tip: Vector4 = rig._position_in_rig(chain[chain.size() - 1])
			print("   %s: hoof ends at y = %.2f  (ground is 0)" % [hip.name, tip.y])
	return true
func _v(v: Vector4) -> String:
	return "(%.2f, %.2f, %.2f, %.2f)" % [v.x, v.y, v.z, v.w]
