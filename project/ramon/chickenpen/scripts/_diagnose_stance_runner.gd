extends SceneTree
## Why is the foot never planted? Watch the gait's own state, frame by frame.
var _root: Node
var _f := 0
var _player: CharacterBody4D
var _gait: Node
var _foot: Node4D
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen_proceduralwalker.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 40:
		_player = _root.get_node("Player")
		_gait = _root.get_node("Player/Gait")
		var knee: Node4D = (_root.get_node("Player/Avatar") as Node4D).knee_left
		for c in knee.get_children():
			if c is MeshInstance4D and String(c.name).begins_with("Boot"): _foot = c as Node4D
		return false
	if _f < 40: return false
	_player.linear_velocity.z = 2.2
	if _f % 40 == 0:
		var clock: Node = _gait.get_node_or_null("GaitClock")
		print("f%3d floor %s airborne %.2f | phase %.3f duty %.2f | speed %.2f halted %s | was_stance %s | foot z %.3f plant z %.3f" % [
			_f, str(_player.is_on_floor()), _gait.get("_airborne"),
			float(clock.phase_progress) if clock else -1.0,
			float(clock.duty_factor) if clock else -1.0,
			_gait.get("speed"), str(_gait.get("halted")),
			str((_gait.get("_was_stance") as Array)[0]),
			_foot.global_position.z, (_gait.get("_plant") as Array)[0].z])
	if _f < 320: return false
	return true
