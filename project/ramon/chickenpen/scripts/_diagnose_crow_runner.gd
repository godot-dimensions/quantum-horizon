extends SceneTree
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	var crow: Node4D = _root.get_node("World/Crow")
	print("\n   children of the crow:")
	for c in crow.get_children():
		print("      %s (%s)" % [c.name, c.get_class()])
	for wing in ["WingL", "WingR"]:
		var w: Node = crow.get_node_or_null(wing)
		if w == null:
			print("   %s: MISSING" % wing)
			continue
		print("   %s holds: %s" % [wing, w.get_children().map(func(n): return n.name)])
	print("\n   mood %d, mood_left %.2f, processing %s"
		% [crow.get("_mood"), crow.get("_mood_left"), crow.is_processing()])
	quit(0)
	return true
