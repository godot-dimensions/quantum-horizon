extends SceneTree
## Does the agent drive the chicken without breaking the walk, and does it flee?
var _root: Node
var _f := 0
var _chicken: Node4D
var _agent: Node
var _player: Node4D
var _states := {}
var _start := Vector4.ZERO
func _initialize() -> void:
	var holder := Node4D.new()
	root.add_child(holder); current_scene = holder
	holder.add_child(DirectionalLight4D.new())
	_chicken = load("res://ramon/chickenpen/chicken.tscn").instantiate()
	holder.add_child(_chicken)
	_player = Node4D.new()
	_player.position = Vector4(6, 0, 0, 0)
	holder.add_child(_player)
	_root = holder
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		_agent = _chicken.get_node("Agent")
		_agent.call("bind_player", _player)
		_start = _chicken.position
		print("agent found, id %d, home %v" % [_agent.get("chicken_id"), _agent.get("home_position")])
		return false
	if _f < 20: return false
	# Walk the player in after a while, and see whether the bird reacts.
	if _f > 260:
		_player.position = _player.position.lerp(_chicken.global_position, 0.05)
	var name: String = _agent.call("describe")
	var key: String = name.split(" ")[1]
	_states[key] = int(_states.get(key, 0)) + 1
	if _f < 620: return false
	print("wandered %.2f units from home" % _chicken.position.distance_to(_start))
	print("states seen: %s" % str(_states))
	print("verdict: %s" % ("REACTS" if _states.has("ALERT") or _states.has("EVADE") else "NEVER REACTED"))
	return true
