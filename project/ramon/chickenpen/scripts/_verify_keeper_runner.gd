extends SceneTree
var _root: Node
var _f := 0
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 90: return false
	var keeper: Node4D = _root.get_node("World/Keeper")
	var player: Node4D = _root.get_node("Player")
	var label: Label = _root.get_node("UI/Keeper")
	var gap: Vector4 = player.global_position - keeper.global_position
	print("player spawn %.1v, keeper %.1v" % [player.global_position, keeper.global_position])
	print("   apart: %.2f units, %.2f through w" % [
		Vector2(gap.x, gap.z).length(), absf(gap.w)])
	print("   he says: '%s'" % label.text)
	# Walk up to him and ask again.
	player.position = keeper.global_position + Vector4(0.0, 1.3, 1.5, 0.0)
	return false if _f < 140 else _done(label, keeper)
func _done(label: Label, keeper: Node4D) -> bool:
	print("   standing next to him: '%s'" % label.text)
	# And once every chicken is home.
	for a in (_root.get_node("Chickens").get("agents") as Array):
		a.set("returned", true)
	return false if _f < 190 else true
