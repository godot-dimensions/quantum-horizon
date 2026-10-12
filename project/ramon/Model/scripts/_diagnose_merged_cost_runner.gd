extends SceneTree
## What does the merged body+neck cost to ANIMATE, by each of the two routes?
##   skin   - move the mesh's vertices and hand them back (set_vertex_positions)
##   reloft - ask the rig to rebuild the whole chain from its balls (build)
## Interleaved frame by frame against doing nothing, because run-to-run drift here is
## 1-2 ms. Windowed: headless never builds the proxy mesh the cost lives in.
var _root: Node
var _f := 0
var _rig: Node
var _mesh: ArrayTetraMesh4D
var _rest: PackedVector4Array
var _last := 0
var _on := [0.0, 0.0]
var _off := [0.0, 0.0]
var _n := [0, 0]
var _work := [0.0, 0.0]
const _PHASE := 400
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_merged.tscn").instantiate()
	root.add_child(_root); current_scene = _root
	# Vsync quantises the frame to 60 Hz and hides or exaggerates every cost here.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		_rig = _root.get_node("Chicken/Body")
		_mesh = (_rig as MeshInstance4D).mesh as ArrayTetraMesh4D
		_rest = _mesh.get_vertex_positions()
		print("merged mesh: %d verts, %d cells" % [_rest.size(),
			_mesh.get_simplex_cell_vertex_indices().size() / 4])
		_last = Time.get_ticks_usec()
		return false
	if _f < 20: return false
	var now := Time.get_ticks_usec()
	var dt := (now - _last) / 1000.0
	_last = now
	var slot: int = (_f - 20) / _PHASE
	if slot > 0:
		for i in 1:
			var label := "skin  " if i == 0 else "reloft"
			print("%s: %.2f ms/frame  (%.2f doing it vs %.2f not), of which script %.3f ms" % [
				label, _on[i] / maxf(_n[i], 1) - _off[i] / maxf(_n[i], 1),
				_on[i] / maxf(_n[i], 1), _off[i] / maxf(_n[i], 1), _work[i] / maxf(_n[i], 1) / 1000.0])
		return true
	if _f - 20 > slot * _PHASE + 20:
		if ((_f - 1) % 2) == 0: _on[slot] += dt
		else: _off[slot] += dt; _n[slot] += 1
	if _f % 2 == 0:
		var t0 := Time.get_ticks_usec()
		if slot == 0:
			var out := PackedVector4Array(); out.resize(_rest.size())
			var a: float = 0.4 * sin(_f * 0.2)
			for i in _rest.size():
				var v: Vector4 = _rest[i]
				var h: float = clampf((v.y - 1.02) / 0.99, 0.0, 1.0)
				var t: float = a * h
				var y: float = v.y - 1.02
				out[i] = Vector4(v.x, 1.02 + y * cos(t) - v.z * sin(t), y * sin(t) + v.z * cos(t), v.w)
			_mesh.set_vertex_positions(out)
		else:
			_rig.call("build")
		_work[slot] += Time.get_ticks_usec() - t0
	return false
