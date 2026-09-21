extends SceneTree
## Twelve chickens, one source scene: do they spawn, sit where authored, and differ?
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	var mgr: Node = _root.get_node("Chickens")
	var agents: Array = mgr.get("agents")
	print("spawned %d chickens" % agents.size())
	var w_zero := 0
	var w_off := 0
	var seeds := {}
	var radii := {}
	for a in agents:
		var home: Vector4 = a.get("home_position")
		if absf(home.w) < 0.01: w_zero += 1
		else: w_off += 1
		seeds[a.get("variation_seed")] = true
		radii["%.2f" % float(a.get("wander_radius"))] = true
	print("in the starting slice: %d | offset in W: %d" % [w_zero, w_off])
	print("distinct seeds: %d | distinct wander radii after seeding: %d" % [seeds.size(), radii.size()])
	print("returned so far: %d of %d | locator candidates: %d" % [
		mgr.call("returned_count"), agents.size(), mgr.call("locator_candidates").size()])
	return true
