extends SceneTree
## Is the IK being asked for something it cannot reach? Print the target it is handed,
## against the leg's actual reach, while the character walks.
var _root: Node
var _f := 0
var _player: CharacterBody4D
var _gait: Node
var _avatar: Node4D
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen_proceduralwalker.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 40:
		_player = _root.get_node("Player")
		_gait = _root.get_node("Player/Gait")
		_avatar = _root.get_node("Player/Avatar")
		return false
	if _f < 40: return false
	Input.action_press(&"move_back")
	if _f % 12 == 0 and _f < 200:
		var hip: Node4D = _avatar.hip_left
		var plant: Vector4 = (_gait.get("_plant") as Array)[0]
		var local: Vector4 = _avatar.global_basis.inverse() * (plant - hip.global_position)
		var want: float = Vector2(local.z, local.y).length()
		var reach: float = float(_gait.get("_thigh")) + float(_gait.get("_shin"))
		var clock: Node = _gait.get_node("GaitClock")
		print("f%3d phase %.2f stance %s | target z %+.3f y %+.3f | want %.3f reach %.3f %s | stride %.2f period %.2f" % [
			_f, fposmod(float(clock.phase_progress), 1.0), str((_gait.get("_was_stance") as Array)[0]),
			local.z, local.y, want, reach, "CLAMPED" if want > reach else "ok",
			float(_gait.get("stride_length")), float(clock.period_sec)])
	if _f < 200: return false
	Input.action_release(&"move_back")
	return true
