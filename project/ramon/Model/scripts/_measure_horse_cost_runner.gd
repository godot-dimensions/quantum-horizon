extends SceneTree
## What does the horse cost per frame, and how much of it is its walker?
## Windowed, vsync off - headless never builds the proxy mesh the cost lives in.
var _root: Node
var _f := 0
var _last := 0
var _ms := [0.0, 0.0]
var _n := [0, 0]
var _walkers: Array = []
const _PHASE := 400
func _initialize() -> void:
	_root = load("res://ramon/Model/animation_test.tscn").instantiate()
	root.add_child(_root); current_scene = _root
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
func _process(_d) -> bool:
	_f += 1
	if _f == 30:
		var stack: Array = [_root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n.get_script() != null and n.has_method("_physics_process") and n.name.findn("walk") >= 0:
				_walkers.append(n)
			for c in n.get_children(): stack.append(c)
		print("walkers found: %d" % _walkers.size())
		_last = Time.get_ticks_usec()
		return false
	if _f < 30: return false
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	var slot: int = (_f - 30) / _PHASE
	if slot > 1:
		print("horse walking: %.2f ms/frame (%.0f fps)" % [_ms[0] / _n[0], 1000.0 / (_ms[0] / _n[0])])
		print("walker off:    %.2f ms/frame -> animating the horse costs %.2f ms" % [
			_ms[1] / _n[1], _ms[0] / _n[0] - _ms[1] / _n[1]])
		return true
	if (_f - 30) % _PHASE == 0:
		for w in _walkers: w.set_physics_process(slot == 0)
	if (_f - 30) % _PHASE > 40: _ms[slot] += dt; _n[slot] += 1
	return false
