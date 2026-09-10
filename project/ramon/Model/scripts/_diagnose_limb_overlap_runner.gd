extends SceneTree
## Are the limb shells buried inside the body shell?
##
## The rig lofts each chain as its OWN closed surface and merges them - joints overlap
## rather than fuse. Standing still that is invisible, because one shell simply sits
## inside another. Once the legs SWING, their surface sweeps in and out through the
## torso's, and the interpenetration shows up as clipping. This measures how deep each
## hip sits inside the body it hangs off.
var _i: Node
var _f := 0
func _initialize() -> void:
	_i = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(_i)
func _process(_d) -> bool:
	_f += 1
	if _f < 5: return false
	var rig: Node = _i.get_node("Creature/Strider/Hide")
	for body in rig.get_children():
		if not body.has_method("get_loft_section"): continue
		var bs: Dictionary = body.get_loft_section()
		var bc: Vector4 = rig._position_in_rig(body)
		for limb in body.get_children():
			if not limb.has_method("get_loft_section"): continue
			var ls: Dictionary = limb.get_loft_section()
			var lc: Vector4 = rig._position_in_rig(limb)
			var d: float = bc.distance_to(lc)
			# Widest half-extent of each section, the worst case for overlap.
			var br: float = float(bs["radius"]) * maxf(1.0, maxf(float(bs.get("v_scale", 1.0)), float(bs["w_scale"])))
			var lr: float = float(ls["radius"]) * maxf(1.0, maxf(float(ls.get("v_scale", 1.0)), float(ls["w_scale"])))
			var overlap: float = (br + lr) - d
			print("   %-9s in %-7s: centres %.2f apart, half-extents %.2f + %.2f -> overlap %+.2f %s" % [
				limb.name, body.name, d, br, lr, overlap,
				"<-- limb buried in body" if overlap > 0.0 else ""])
	return true
