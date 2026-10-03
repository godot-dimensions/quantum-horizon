extends SceneTree

## Is the cat actually ON the crate, and does it clear off after scratching you?

var _root: Node
var _f := 0
var _t0 := 0
var _cat: Node4D
var _crate: Node4D
var _grab: Node
var _player: Node4D
var _stage := 0
var _from := Vector4.ZERO


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _lowest() -> float:
	var low := INF
	for c in _all(_cat):
		var m: MeshInstance4D = c as MeshInstance4D
		if m == null or not (m.mesh is TetraMesh4D):
			continue
		for v in (m.mesh as TetraMesh4D).get_simplex_cell_positions():
			low = minf(low, (m.global_basis * v + m.global_position).y)
	return low


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	if _cat == null:
		_cat = _root.get_node("World/Cat")
		_crate = _root.get_node("World/RockPile")
		_grab = _root.get_node("Systems/CatGrab")
		_player = _root.get_node("Player")
		_player.position = Vector4(30.0, 1.3, 30.0, 0.0)
		_t0 = Time.get_ticks_msec()
	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0

	match _stage:
		0:
			if elapsed < 1.0: return false
			var top: float = _crate.global_position.y + float(_crate.get("top"))
			print("crate surface is at y %.2f" % top)
			print("cat origin  y %.2f, its lowest point y %.2f" % [_cat.global_position.y, _lowest()])
			print("gap between cat and crate: %.3f  (negative = standing in it)" % (_lowest() - top))
			_stage = 1; _t0 = Time.get_ticks_msec()
		1:
			# Walk up, grab, and let it scratch.
			var at: Vector4 = _cat.global_position
			_player.position = Vector4(at.x + 0.8, 1.3, at.z + 0.8, at.w)
			if elapsed < 0.6: return false
			_grab.call("_grab")
			_stage = 2; _t0 = Time.get_ticks_msec()
		2:
			if elapsed < 3.6: return false
			_from = _cat.global_position
			print("\nscratched - cat mood %d (4 = FLEE)" % _cat.get("_mood"))
			_stage = 3; _t0 = Time.get_ticks_msec()
		3:
			if elapsed < 5.0: return false
			print("it covered %.2f units in %.1f s getting away" % [
				Vector2(_cat.global_position.x - _from.x, _cat.global_position.z - _from.z).length(),
				elapsed])
			return true
	return false
