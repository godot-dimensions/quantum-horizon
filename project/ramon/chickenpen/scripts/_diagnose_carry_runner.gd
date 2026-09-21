extends SceneTree
var _root: Node
var _f := 0
var _player: Node4D
var _catcher: Node
var _anchor: Node4D
var _body: Node4D
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 40:
		_player = _root.get_node("Player")
		_catcher = _root.get_node("Player/Catcher")
		_anchor = _root.get_node("Player/CarryAnchor")
		_body = (_root.get_node("Chickens").get("agents") as Array)[0].get_parent()
		return false
	if _f < 40: return false
	_player.global_position = _body.global_position - Vector4(0, 0, 0.7, 0)
	if _f == 80:
		print("does the catcher tick? _candidate = %s" % str(_catcher.get("_candidate")))
		print("player  global %v" % _player.global_position)
		print("anchor  local %v  global %v" % [_anchor.position, _anchor.global_position])
		print("chicken global %v" % _body.global_position)
		var agents: Array = _root.get_node("Chickens").get("agents")
		_catcher.call("_catch", agents[0])
		return false
	if _f == 120:
		print("after carrying: chicken %v vs anchor %v  gap %.3f" % [
			_body.global_position, _anchor.global_position,
			_body.global_position.distance_to(_anchor.global_position)])
		print("carried is set: %s" % str(_catcher.get("carried") != null))
		return true
	return false
