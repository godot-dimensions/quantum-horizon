extends SceneTree
## The only work left per frame that buys nothing: 42 rigs each polling their section
## signature for changes that never happen. Measured directly, since frame time is
## vsync-capped and cannot show it.
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 30: return false
	var rigs: Array = _rigs(_root)
	var runs := 200
	var start := Time.get_ticks_usec()
	for i in range(runs):
		for r in rigs:
			r._section_signature()
	var per_frame := float(Time.get_ticks_usec() - start) / float(runs) / 1000.0
	print("%d rigs, signature poll: %.3f ms per frame (%.1f%% of a 16.7 ms budget)" % [
		rigs.size(), per_frame, 100.0 * per_frame / 16.7])
	return true
func _rigs(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is MeshInstance4D and c.get_script() != null and c.has_method("build"): out.append(c)
		out.append_array(_rigs(c))
	return out
