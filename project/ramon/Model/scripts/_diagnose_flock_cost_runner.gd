extends SceneTree
## Five birds cost 76 ms/frame. How much of that is DRAWING them and how much is
## ANIMATING them? Interleaved is not possible here, so each phase is long and the
## walkers are switched off wholesale.
var _root: Node
var _f := 0
var _last := 0
var _ms := [0.0, 0.0, 0.0]
var _n := [0, 0, 0]
var _walkers: Array = []
var _birds: Array = []
const _PHASE := 400
func _hide(n: Node, v: bool) -> void:
	if n is MeshInstance4D: (n as MeshInstance4D).visible = v
	for c in n.get_children(): _hide(c, v)
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		for n in _root.get_children():
			if n.name.begins_with("Chicken"):
				_birds.append(n)
				var w: Node = n.get_node_or_null("Walker")
				if w: _walkers.append(w)
		print("birds %d, walkers %d" % [_birds.size(), _walkers.size()])
		if OS.get_cmdline_user_args().has("norebuild"):
			for b in _birds:
				for leg in ["LegL", "LegR"]:
					var r: Node = b.get_node_or_null(leg)
					if r: r.set("live_rebuild", false)
			print("leg rigs set to NOT re-loft")
		_last = Time.get_ticks_usec()
		return false
	if _f < 20: return false
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	var slot: int = (_f - 20) / _PHASE
	if slot > 2:
		print("all five walking:        %.2f ms/frame" % (_ms[0] / _n[0]))
		print("walkers off, still drawn: %.2f ms/frame -> animating costs %.2f" % [_ms[1] / _n[1], _ms[0]/_n[0] - _ms[1]/_n[1]])
		print("birds hidden entirely:    %.2f ms/frame -> drawing costs %.2f" % [_ms[2] / _n[2], _ms[1]/_n[1] - _ms[2]/_n[2]])
		return true
	if (_f - 20) % _PHASE == 0:
		for w in _walkers: w.set_physics_process(slot == 0)
		for b in _birds: _hide(b, slot != 2)
	if (_f - 20) % _PHASE > 40: _ms[slot] += dt; _n[slot] += 1
	return false
