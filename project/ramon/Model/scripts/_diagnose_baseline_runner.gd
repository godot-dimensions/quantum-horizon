extends SceneTree
## Nearly 19 ms of the frame belongs to neither creature. What is it?
var _root: Node
var _f := 0
var _last := 0
var _ms := [0.0, 0.0]
var _n := [0, 0]
const _PHASE := 300
func _hide_all(n: Node, v: bool) -> void:
	if n is MeshInstance4D: (n as MeshInstance4D).visible = v
	for c in n.get_children(): _hide_all(c, v)
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		var total := 0
		for c in _root.get_children():
			var cells := 0
			var stack: Array = [c]
			while not stack.is_empty():
				var n: Node = stack.pop_back()
				if n is MeshInstance4D and (n as MeshInstance4D).mesh is TetraMesh4D:
					cells += ((n as MeshInstance4D).mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
				for g in n.get_children(): stack.append(g)
			total += cells
			print("  %-22s %s  %d tets" % [c.name, c.get_class(), cells])
		print("scene total: %d tets" % total)
		print("vsync mode: %d, max fps: %d, screen refresh: %.1f Hz" % [DisplayServer.window_get_vsync_mode(),
			Engine.max_fps, DisplayServer.screen_get_refresh_rate()])
		_last = Time.get_ticks_usec()
		return false
	if _f < 20: return false
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	var slot: int = (_f - 20) / _PHASE
	if slot > 1:
		print("everything visible: %.2f ms/frame" % (_ms[0] / _n[0]))
		print("EVERY mesh hidden:  %.2f ms/frame" % (_ms[1] / _n[1]))
		return true
	if (_f - 20) % _PHASE == 0: _hide_all(_root, slot == 0)
	if (_f - 20) % _PHASE > 30: _ms[slot] += dt; _n[slot] += 1
	return false
