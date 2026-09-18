extends SceneTree
## Does the walk cycle actually move feet, plant them, and stay free?

var _frame := 0
var _root: Node
var _player: CharacterBody4D
var _walker: Node
var _tracked: Array[Node4D] = []
var _paths: Array[Vector4] = []
var _samples: Array[float] = []
var _shots := [[120, "walk_a"], [175, "walk_b"], [230, "walk_c"]]
var _next := 0

func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root

func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_player = _root.get_node("Player")
		_walker = _root.get_node("IKGaitDriver")
		for tag in ["ForeLA", "ForeRA", "HindLA", "HindRA"]:
			var station: String = "Chest" if tag.begins_with("Fore") else "Rump"
			var n: Node4D = _root.get_node_or_null("Creature/Barrel/%s/%sIK/Upper/Mid/Lower/B2" % [station, tag]) as Node4D
			if n != null:
				_tracked.append(n)
		print("tracking %d feet; walker found %s" % [_tracked.size(), "yes" if _walker != null else "NO"])
		return false
	var eye := Vector4(5.4, 2.8, 5.4, 0.0)
	_player.global_position = eye
	_player.global_basis = Basis4D.looking_at(Vector4(-0.6, 2.2, 0.0, 0.0) - eye)
	_player.linear_velocity = Vector4.ZERO
	if _frame > 40:
		_samples.append(delta)
		for n in _tracked:
			_paths.append(n.global_position)
	if _next < _shots.size() and _frame == int(_shots[_next][0]):
		var img: Image = root.get_texture().get_image()
		if img != null:
			img.save_png("user://%s.png" % _shots[_next][1])
			print("captured %s" % _shots[_next][1])
		_next += 1
	if _frame >= 300:
		var total := 0.0
		var worst := 0.0
		for s in _samples:
			total += s
			worst = maxf(worst, s)
		var mean: float = total / float(_samples.size())
		# Foot travel: a walking leg must sweep a real distance, not jitter.
		var lo := Vector4(INF, INF, INF, INF)
		var hi := Vector4(-INF, -INF, -INF, -INF)
		for p in _paths:
			lo = Vector4(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z), minf(lo.w, p.w))
			hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
		print("foot travel: x %.2f  y %.2f  z %.2f  w %.2f" % [
			hi.x - lo.x, hi.y - lo.y, hi.z - lo.z, hi.w - lo.w])
		print("frame: mean %.2f ms (%.1f fps), worst %.2f ms" % [
			mean * 1000.0, 1.0 / mean, worst * 1000.0])
		quit(0)
		return true
	return false
