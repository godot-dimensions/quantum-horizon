extends SceneTree
## The legs are skinned now, so the BALLS no longer move and any check that reads them
## is blind. This reads the mesh itself: does the foot end of the leg actually lift and
## swing, and does the knee end bend?
var _root: Node
var _f := 0
var _legs: Array = []
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		for leg in ["LegL", "LegR"]:
			var n := _root.get_node_or_null("Chicken/%s" % leg) as MeshInstance4D
			_legs.append({"name": leg, "mesh": n.mesh as ArrayTetraMesh4D,
				"lo": 1e9, "hi": -1e9, "zlo": 1e9, "zhi": -1e9, "ball_moved": 0.0,
				"ball0": ((n.get_child(0)) as Node4D).position})
		return false
	if _f < 20: return false
	for l in _legs:
		var v: PackedVector4Array = (l["mesh"] as ArrayTetraMesh4D).get_vertex_positions()
		var lo := 1e9
		var at_z := 0.0
		for p in v:
			if p.y < lo: lo = p.y; at_z = p.z
		l["lo"] = minf(l["lo"], lo); l["hi"] = maxf(l["hi"], lo)
		l["zlo"] = minf(l["zlo"], at_z); l["zhi"] = maxf(l["zhi"], at_z)
	if _f < 400: return false
	for l in _legs:
		print("%s: lowest vertex rides %.3f .. %.3f (lift %.3f), swings %.3f in Z" % [
			l["name"], l["lo"], l["hi"], l["hi"] - l["lo"], l["zhi"] - l["zlo"]])
	return true
