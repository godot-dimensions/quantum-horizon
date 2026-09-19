extends SceneTree
## The horse scene predates this session's walker changes. Does it still walk?
## Read from the MESH, because the walker no longer moves the balls.
var _root: Node
var _f := 0
var _mesh: ArrayTetraMesh4D
var _lo := 1e9
var _hi := -1e9
var _zlo := 1e9
var _zhi := -1e9
func _initialize() -> void:
	_root = load("res://ramon/Model/animation_test.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 20:
		var stack: Array = [_root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is MeshInstance4D and (n as MeshInstance4D).mesh is ArrayTetraMesh4D:
				var m := (n as MeshInstance4D).mesh as ArrayTetraMesh4D
				if m.get_simplex_cell_vertex_indices().size() / 4 > 500:
					_mesh = m
					print("watching %s (%d cells)" % [n.name, m.get_simplex_cell_vertex_indices().size() / 4])
			for c in n.get_children(): stack.append(c)
		return false
	if _f < 20 or _mesh == null: return _mesh == null and _f > 25
	var low := Vector4(0, 1e9, 0, 0)
	for v in _mesh.get_vertex_positions():
		if v.y < low.y: low = v
	_lo = minf(_lo, low.y); _hi = maxf(_hi, low.y)
	_zlo = minf(_zlo, low.z); _zhi = maxf(_zhi, low.z)
	if _f < 400: return false
	print("lowest point rides %.3f .. %.3f (lift %.3f), swings %.3f in Z" % [_lo, _hi, _hi - _lo, _zhi - _zlo])
	print("verdict: %s" % ("STILL WALKING" if (_hi - _lo) > 0.02 else "NOT MOVING"))
	return true
