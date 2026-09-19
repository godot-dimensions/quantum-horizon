extends SceneTree
## Seating was measured at REST. This measures it while it WALKS: the trunk bobs, the
## legs are posed by IK, and the mesh only re-poses every few frames, so the height it
## actually sits at is not the height it was seated at.
var _root: Node
var _f := 0
var _mesh: ArrayTetraMesh4D
var _node: Node4D
var _ground := 0.0
var _min := 1e9
var _max := -1e9
var _sum := 0.0
var _n := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 30:
		_node = _root.get_node("Brachio/Spine") as Node4D
		_mesh = (_node as MeshInstance4D).mesh as ArrayTetraMesh4D
		_ground = (_root.get_node("Ground") as Node4D).position.y + 1.0
		return false
	if _f < 30: return false
	var b: Projection = _node.global_basis
	var off: Vector4 = _node.global_position
	var low := 1e9
	for v in _mesh.get_vertex_positions():
		low = minf(low, (b * v).y + off.y)
	_min = minf(_min, low); _max = maxf(_max, low); _sum += low; _n += 1
	if _f < 700: return false
	print("ground top %.3f" % _ground)
	print("lowest point while walking: min %+.3f, mean %+.3f, max %+.3f" % [_min, _sum / _n, _max])
	print("it hovers %.3f on average; move Brachio y by %+.3f to plant it" % [_sum / _n - _ground, _ground - _min])
	return true
