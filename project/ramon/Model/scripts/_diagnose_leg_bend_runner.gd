extends SceneTree
## Is the leg actually bending, or only appearing to? Measures how far each joint sits
## off the straight line from hip to hoof - zero means a rigid column.
var _i: Node
var _f := 0
func _initialize() -> void:
	_i = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(_i)
func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	var rig: Node = _i.get_node("Creature/Strider/Hide")
	for ball in rig.get_children():
		if not ball.has_method("get_loft_section"): continue
		for hip in ball.get_children():
			if not hip.has_method("get_loft_section"): continue
			var chain: Array = [hip]
			var n: Node = hip
			while true:
				var nx: Node = null
				for c in n.get_children():
					if c.has_method("get_loft_section"): nx = c; break
				if nx == null: break
				chain.append(nx); n = nx
			if chain.size() < 4: continue
			var a: Vector4 = rig._position_in_rig(chain[0])
			var t: Vector4 = rig._position_in_rig(chain[chain.size() - 1])
			var line: Vector4 = t - a
			if line.length() < 0.001: continue
			var dir: Vector4 = line.normalized()
			var offs: Array = []
			for k in range(1, chain.size() - 1):
				var q: Vector4 = rig._position_in_rig(chain[k]) - a
				var perp: Vector4 = q - dir * q.dot(dir)
				offs.append("%s off-line %.2f (of which W %.2f)" % [chain[k].name, perp.length(), absf(perp.w)])
			print("%s: hip->hoof %.2f, %s" % [chain[0].name, line.length(), " | ".join(offs)])
	return true
