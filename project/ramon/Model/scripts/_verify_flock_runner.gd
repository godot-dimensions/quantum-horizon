extends SceneTree
## Five birds: do they all walk, do they take different paths, do they stay together,
## and what does the whole flock cost per frame?
var _root: Node
var _f := 0
var _birds: Array = []
var _last := 0
var _ms := 0.0
var _n := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		for n in _root.get_children():
			if n.name.begins_with("Chicken"):
				_birds.append({"node": n, "start": (n as Node4D).position,
					"prev": (n as Node4D).position, "dist": 0.0, "pts": []})
		print("birds found: %d" % _birds.size())
		_last = Time.get_ticks_usec()
		return false
	if _f < 20: return false
	var now := Time.get_ticks_usec()
	_ms += (now - _last) / 1000.0
	_last = now
	_n += 1
	for b in _birds:
		var pos: Vector4 = (b["node"] as Node4D).position
		b["dist"] += pos.distance_to(b["prev"])
		b["prev"] = pos
		b["pts"].append(pos)
	if _n < 1200: return false
	print("frame: %.2f ms with five birds" % (_ms / _n))
	for b in _birds:
		var pos: Vector4 = b["prev"]
		print("  %-9s walked %5.2f units, now %.2f from where it started" % [
			b["node"].name, b["dist"], Vector2(pos.x - b["start"].x, pos.z - b["start"].z).length()])
	# Are they taking different paths, or the same one shifted?
	var worst_pair := 1e9
	var closest := 1e9
	for i in _birds.size():
		for j in range(i + 1, _birds.size()):
			var a: Array = _birds[i]["pts"]
			var c: Array = _birds[j]["pts"]
			var same := 0.0
			for k in a.size():
				var da: Vector4 = a[k] - _birds[i]["start"]
				var dc: Vector4 = c[k] - _birds[j]["start"]
				same += da.distance_to(dc)
				closest = minf(closest, Vector2(a[k].x - c[k].x, a[k].z - c[k].z).length())
			worst_pair = minf(worst_pair, same / a.size())
	print("most similar pair of paths: %.2f units apart on average (0 = identical motion)" % worst_pair)
	print("closest two birds ever got: %.2f units" % closest)
	return true
