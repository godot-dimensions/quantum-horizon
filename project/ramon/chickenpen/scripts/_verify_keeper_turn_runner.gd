extends SceneTree

## Does the keeper turn to face whoever walks up to him?

var _root: Node
var _f := 0
var _keeper: Node4D
var _player: Node4D
var _before: float = 0.0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	if _keeper == null:
		_keeper = _root.get_node("World/Keeper")
		_player = _root.get_node("Player")
		_before = atan2(_keeper.basis.z.x, _keeper.basis.z.z)
		# Walk up from the OTHER side, so facing him means turning right round.
		var at: Vector4 = _keeper.global_position
		_player.position = Vector4(at.x - 2.0, 1.3, at.z - 1.6, 0.0)
		return false
	if _f < 190: return false
	var after: float = atan2(_keeper.basis.z.x, _keeper.basis.z.z)
	var gap: Vector4 = _player.global_position - _keeper.global_position
	var want: float = atan2(gap.x, gap.z)
	print("keeper faced %.2f rad, now faces %.2f, player is at %.2f" % [_before, after, want])
	print("turned to within %.2f rad of the player" % absf(wrapf(after - want, -PI, PI)))
	return true
