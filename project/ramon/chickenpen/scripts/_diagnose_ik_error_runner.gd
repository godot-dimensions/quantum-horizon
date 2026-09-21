extends SceneTree
## During stance, does the ankle actually end up ON the plant?
var _root: Node
var _f := 0
var _gait: Node
var _avatar: Node4D
func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen_proceduralwalker.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 40:
		_gait = _root.get_node("Player/Gait")
		_avatar = _root.get_node("Player/Avatar")
		return false
	if _f < 40: return false
	Input.action_press(&"move_back")
	if _f % 10 == 0 and _f < 170:
		var knee: Node4D = _avatar.knee_left
		var shin: float = float(_gait.get("_shin"))
		var ankle: Vector4 = knee.global_position + knee.global_basis * Vector4(0.0, -shin, 0.0, 0.0)
		var plant: Vector4 = (_gait.get("_plant") as Array)[0]
		var stance: bool = (_gait.get("_was_stance") as Array)[0]
		print("f%3d stance %-5s | plant (%.2f,%.2f,%.2f) | ankle (%.2f,%.2f,%.2f) | error %.3f" % [
			_f, str(stance), plant.x, plant.y, plant.z, ankle.x, ankle.y, ankle.z,
			ankle.distance_to(plant)])
	if _f < 170: return false
	Input.action_release(&"move_back")
	return true
