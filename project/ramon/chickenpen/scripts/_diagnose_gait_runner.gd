extends SceneTree
## The joints are not visibly moving. Force the character to walk and watch the hips.
var _root: Node
var _f := 0
var _player: CharacterBody4D
var _hip: Node4D
var _lo := 1e9
var _hi := -1e9
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen_proceduralwalker.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		_player = _root.get_node("Player")
		var avatar: Node4D = _root.get_node("Player/Avatar")
		_hip = avatar.get("hip_left")
		print("avatar children: %d, hip_left resolved: %s" % [avatar.get_child_count(), _hip != null])
		print("gait node: %s" % str(_player.get_node_or_null("GaitController") != null))
		return false
	if _f < 20: return false
	# Drive it forward by hand - no input in a headless run.
	_player.linear_velocity.z = 3.0
	if _hip != null:
		var swing: float = _hip.basis.z.y      # how far the hip has rotated in Y-Z
		_lo = minf(_lo, swing); _hi = maxf(_hi, swing)
	if _f % 60 == 0:
		print("frame %3d: speed %.2f, gait phase %.3f, halted %s, hip swing %.3f" % [
			_f, _player.get("speed"), float(_player.get("_gait").phase_progress),
			str(_player.get("halted")), _hip.basis.z.y if _hip else -9])
	if _f < 300: return false
	print("hip swing range over the run: %.3f .. %.3f" % [_lo, _hi])
	print("verdict: %s" % ("JOINTS MOVING" if _hi - _lo > 0.05 else "JOINTS STATIC"))
	return true
