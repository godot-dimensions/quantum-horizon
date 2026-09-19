extends SceneTree
## The editor shows the rig at its AUTHORED resolution; the walker drops it to animation
## resolution at runtime. Those are different meshes and they do not end at the same
## height, so seating against one can leave it floating in the other.
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 30: return false
	var spine := _root.get_node_or_null("Brachio/Spine") as MeshInstance4D
	var brachio := _root.get_node_or_null("Brachio") as Node4D
	var ground := (_root.get_node_or_null("Ground") as Node4D).position.y + 1.0
	var base: float = brachio.position.y + spine.position.y
	for pair in [[int(spine.get("profile_sides")), int(spine.get("profile_rings")), "animation"],
			[12, 6, "authored (what the editor draws)"]]:
		spine.set("profile_sides", pair[0])
		spine.set("profile_rings", pair[1])
		spine.call("build")
		var low := 1e9
		for v in (spine.mesh as ArrayTetraMesh4D).get_vertex_positions():
			low = minf(low, v.y + base)
		print("%-34s sides %2d rings %d: lowest %+.3f, gap to ground %+.3f" % [
			pair[2], pair[0], pair[1], low, low - ground])
	return true
