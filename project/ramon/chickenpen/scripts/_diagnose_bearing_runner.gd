extends SceneTree
const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 50: return false
	var player: Node4D = _root.get_node("Player")
	var mgr: Node = _root.get_node("Chickens")
	var bird: Node = null
	for a in (mgr.get("agents") as Array):
		if absf((a.get("home_position") as Vector4).w) > 0.5: bird = a; break
	var body: Node4D = bird.get_parent()
	player.position = Vector4(body.global_position.x, 0.0, body.global_position.z - 2.0, 0.0)
	print("player at %v   bird at %v" % [player.global_position, body.global_position])
	var b: Dictionary = BearingUtility4D.compute(player, body.global_position)
	for k in b.keys():
		print("   %-16s %s" % [k, str(b[k])])
	return true
