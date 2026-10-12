extends SceneTree
## Does the horse's mesh change at all between frames? Watching a single vertex is
## unreliable - the lowest one turned out to be an unbound part that never moves - so
## this measures the TOTAL displacement of every vertex.
var _root: Node
var _f := 0
var _rig: MeshInstance4D
var _prev := PackedVector4Array()
var _total := 0.0
var _moved := 0
var _frames := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/animation_test.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f < 60: return false
	if _rig == null:
		var stack: Array = [_root]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n.get_script() != null and n.name.findn("walk") >= 0:
				_rig = n.get("_rig") as MeshInstance4D
			for c in n.get_children(): stack.append(c)
		if _rig == null: print("no rig"); return true
	var live := _rig.mesh as ArrayTetraMesh4D
	var now: PackedVector4Array = live.get_vertex_positions()
	if _prev.size() == now.size() and _prev.size() > 0:
		var sum := 0.0
		var count := 0
		for i in now.size():
			var d: float = now[i].distance_to(_prev[i])
			sum += d
			if d > 0.0001: count += 1
		_total += sum; _moved = maxi(_moved, count); _frames += 1
	_prev = now.duplicate()
	if _f < 300: return false
	print("vertices moving in a frame: up to %d of %d" % [_moved, _prev.size()])
	print("total vertex movement: %.4f units per frame on average" % (_total / maxf(_frames, 1)))
	print("verdict: %s" % ("MESH IS DEFORMING" if _total > 0.001 else "MESH IS STATIC"))
	return true
