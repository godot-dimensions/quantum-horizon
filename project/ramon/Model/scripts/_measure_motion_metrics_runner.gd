extends SceneTree
## Every number a slide about the walking creatures needs, from one run.
## Windowed and vsync off: headless never builds the proxy mesh the cost lives in, and
## vsync quantises the frame to the 60 Hz beat, so a real cost shows up either as nothing
## or as a whole missed frame.
##
## Each phase switches ONE group off and re-measures, so the differences are attributable
## rather than inferred.
var _root: Node
var _f := 0
var _last := 0
var _ms := []
var _n := []
var _chicken_walkers: Array = []
var _brachio_walkers: Array = []
var _trym_solvers: Array = []
var _creatures: Array = []
var _tets := 0
var _chicken_tets := 0
const _PHASE := 350
const _LABELS := ["all running", "chicken walkers off", "brachio walker off",
	"Trym's solvers off", "everything frozen", "creatures hidden"]
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for i in _LABELS.size(): _ms.append(0.0); _n.append(0)
func _hide(n: Node, v: bool) -> void:
	if n is MeshInstance4D: (n as MeshInstance4D).visible = v
	for c in n.get_children(): _hide(c, v)
func _count(n: Node) -> int:
	var t := 0
	var stack: Array = [n]
	while not stack.is_empty():
		var m: Node = stack.pop_back()
		if m is MeshInstance4D and (m as MeshInstance4D).mesh is TetraMesh4D:
			t += ((m as MeshInstance4D).mesh as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
		for c in m.get_children(): stack.append(c)
	return t
func _process(_d) -> bool:
	_f += 1
	if _f == 30:
		for n in _root.get_children():
			if not (n is Node4D) or n.name == "Ground": continue
			var t := _count(n)
			if t == 0: continue
			_creatures.append(n); _tets += t
			if n.name.begins_with("Chicken"):
				_chicken_tets += t
				var w: Node = n.get_node_or_null("Walker")
				if w: _chicken_walkers.append(w)
			elif n.name == "Brachio":
				var w2: Node = n.get_node_or_null("Walker")
				if w2: _brachio_walkers.append(w2)
			print("  %-10s %6d tetrahedra" % [n.name, t])
		for solver in ["IKGaitDriver", "FootGroundSolver", "TailSway", "SpineNeckSolver",
				"IdleLayer", "HeadAttention", "HeadRotationDemo"]:
			var s: Node = _root.get_node_or_null(solver)
			if s: _trym_solvers.append(s)
		print("creatures %d (%d tetrahedra), chickens %d (%d tets), Trym solvers %d" % [
			_creatures.size(), _tets, _chicken_walkers.size(), _chicken_tets, _trym_solvers.size()])
		_last = Time.get_ticks_usec()
		return false
	if _f < 30: return false
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	var slot: int = (_f - 30) / _PHASE
	if slot >= _LABELS.size():
		for i in _LABELS.size():
			print("  %-22s %6.2f ms/frame" % [_LABELS[i], _ms[i] / _n[i]])
		var all: float = _ms[0] / _n[0]
		print("RESULTS")
		print("  frame with everything walking: %.2f ms  (%.0f fps)" % [all, 1000.0 / all])
		print("  five chickens cost:            %.2f ms  (%.2f ms each)" % [all - _ms[1] / _n[1], (all - _ms[1] / _n[1]) / 5.0])
		print("  brachiosaurus costs:           %.2f ms" % (all - _ms[2] / _n[2]))
		print("  Trym's six solvers cost:       %.2f ms" % (all - _ms[3] / _n[3]))
		print("  all animation costs:           %.2f ms" % (all - _ms[4] / _n[4]))
		print("  DRAWING all %d tetrahedra:   %.2f ms" % [_tets, _ms[4] / _n[4] - _ms[5] / _n[5]])
		return true
	if (_f - 30) % _PHASE == 0:
		for w in _chicken_walkers: w.set_physics_process(slot != 1 and slot < 4)
		for w in _brachio_walkers: w.set_physics_process(slot != 2 and slot < 4)
		for s in _trym_solvers: s.set_physics_process(slot != 3 and slot < 4)
		for c in _creatures: _hide(c, slot != 5)
	if (_f - 30) % _PHASE > 40: _ms[slot] += dt; _n[slot] += 1
	return false
