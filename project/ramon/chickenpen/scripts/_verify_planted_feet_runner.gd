extends SceneTree
## "Proper walking, not sliding", measured the way that actually settles it.
##
## An earlier version of this compared the foot's movement against the body's and called
## anything that moved "skating". That was wrong twice over: it watched the BOOT, which
## hangs below the ankle and so orbits as the shin turns, and it counted swing frames,
## where a foot is supposed to be moving. What matters is narrower - while a foot is in
## STANCE, does it stay on the spot it was planted?
var _root: Node
var _f := 0
var _gait: Node
var _avatar: Node4D
var _stance_frames := 0
var _worst := 0.0
var _total := 0.0
var _plants := 0
var _last_plant := Vector4.ZERO
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
	if _f > 70:
		var knee: Node4D = _avatar.knee_left
		var shin: float = float(_gait.get("_shin"))
		var ankle: Vector4 = knee.global_position + knee.global_basis * Vector4(0.0, -shin, 0.0, 0.0)
		var plant: Vector4 = (_gait.get("_plant") as Array)[0]
		if (_gait.get("_was_stance") as Array)[0]:
			var err: float = ankle.distance_to(plant)
			_stance_frames += 1
			_total += err
			_worst = maxf(_worst, err)
			if plant.distance_to(_last_plant) > 0.001:
				_plants += 1
				_last_plant = plant
	if _f < 400: return false
	Input.action_release(&"move_back")
	print("stance frames sampled: %d over %d steps" % [_stance_frames, _plants])
	print("ankle-to-plant error: mean %.4f, worst %.4f units" % [_total / maxf(_stance_frames, 1), _worst])
	print("verdict: %s" % ("FEET PLANT" if _worst < 0.02 else "FEET SLIP by %.3f" % _worst))
	return true
