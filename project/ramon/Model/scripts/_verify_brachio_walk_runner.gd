extends SceneTree
## Does the brachiosaurus actually move its legs, and what does driving it cost?
var _root: Node
var _f := 0
var _walk: Node
var _mesh: ArrayTetraMesh4D
var _lo := 1e9
var _hi := -1e9
var _zlo := 1e9
var _zhi := -1e9
var _last := 0
var _on := 0.0
var _off := 0.0
var _n := [0, 0]
const _PHASE := 300
var _mid := 0.0
var _nmid := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		_walk = _root.get_node_or_null("Brachio/Walker")
		# The balls no longer move - the mesh is skinned - so this watches the MESH.
		_mesh = (_root.get_node_or_null("Brachio/Spine") as MeshInstance4D).mesh as ArrayTetraMesh4D
		print("walker: %s, legs found: %s, cells: %d" % [_walk != null,
			str(_walk.get("_legs").size()) if _walk and _walk.get("_legs") != null else "?",
			_mesh.get_simplex_cell_vertex_indices().size() / 4])
		_last = Time.get_ticks_usec()
		return false
	if _f < 20: return false
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	# Lowest vertex of the whole animal: that is a foot, and it should rise and swing.
	var lowest := 1e9
	var at_z := 0.0
	for v in _mesh.get_vertex_positions():
		if v.y < lowest: lowest = v.y; at_z = v.z
	_lo = minf(_lo, lowest); _hi = maxf(_hi, lowest)
	_zlo = minf(_zlo, at_z); _zhi = maxf(_zhi, at_z)
	var slot: int = (_f - 20) / _PHASE
	if slot > 2:
		print("front foot lifts %.3f, swings %.3f in Z" % [_hi - _lo, _zhi - _zlo])
		print("walking normally:   %.2f ms/frame" % (_on / _n[0]))
		print("skinning disabled:  %.2f ms/frame  -> skinning costs %.2f" % [_mid / _nmid, _on / _n[0] - _mid / _nmid])
		print("walker off entirely: %.2f ms/frame -> the rest costs %.2f" % [_off / _n[1], _mid / _nmid - _off / _n[1]])
		return true
	if (_f - 20) % _PHASE == 0 and _walk:
		# Phase 1 leaves the walker running but empties its skin list, so _skin() returns
		# immediately. Whatever cost survives that is NOT the skinning.
		if slot == 1: _walk.set("_skin_index", PackedInt32Array())
		if slot == 2: _walk.set_physics_process(false)
	if (_f - 20) % _PHASE > 40:
		if slot == 0: _on += dt; _n[0] += 1
		elif slot == 1: _mid += dt; _nmid += 1
		else: _off += dt; _n[1] += 1
	return false
