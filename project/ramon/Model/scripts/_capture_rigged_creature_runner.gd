extends SceneTree
## Frame cost with the head animation running, plus a shot at each plane's peak.

var _frame := 0
var _root: Node
var _player: CharacterBody4D
var _samples: Array[float] = []
var _shots := [[95, "xz"], [275, "xy"], [455, "xw"], [635, "zw"]]
var _next := 0

func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_player = _root.get_node("Player")
		return false
	var eye := Vector4(5.2, 3.0, 5.2, 0.0)
	_player.global_position = eye
	_player.global_basis = Basis4D.looking_at(Vector4(-1.2, 2.4, 0.0, 0.0) - eye)
	_player.linear_velocity = Vector4.ZERO
	if _frame > 40:
		_samples.append(delta)
	if _next < _shots.size() and _frame == int(_shots[_next][0]):
		var img: Image = root.get_texture().get_image()
		if img != null:
			img.save_png("user://rigged_%s.png" % _shots[_next][1])
			print("captured %s" % _shots[_next][1])
		_next += 1
	if _frame >= 700:
		var total := 0.0
		var worst := 0.0
		for s in _samples:
			total += s
			worst = maxf(worst, s)
		var mean: float = total / float(_samples.size())
		print("with head animation running: mean %.2f ms (%.1f fps), worst %.2f ms" % [
			mean * 1000.0, 1.0 / mean, worst * 1000.0])
		quit(0)
		return true
	return false
