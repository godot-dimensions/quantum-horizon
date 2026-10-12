extends SceneTree
## Is the head low ONLY while a peck is actually running?
var _root: Node
var _f := 0
var _w: Node
var _head: Node4D
var _act := 0
var _low := 0
var _low_while_idle := 0
var _idle_hi := -1e9
var _n := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 5:
		_w = _root.get_node_or_null("Chicken/Walker")
		var n: Node = _root.get_node_or_null("Chicken/NeckHead")
		while n.get_child_count() > 0: n = n.get_child(n.get_child_count()-1)
		_head = n as Node4D
		return false
	if _f < 5: return false
	_n += 1
	var on: bool = _w._peck_elapsed >= 0.0
	var y: float = _head.global_position.y
	if on: _act += 1
	if y < 0.8:
		_low += 1
		if not on: _low_while_idle += 1
	if not on: _idle_hi = maxf(_idle_hi, -y)
	if _n < 1600: return false
	print("frames: %d  peck active: %d (%.0f%%)  head below 0.8: %d (%.0f%%)" % [_n, _act,
		100.0*_act/_n, _low, 100.0*_low/_n])
	print("frames with head LOW while no peck is running: %d" % _low_while_idle)
	print("lowest the head ever gets between pecks: %.3f (rest is ~2.01)" % -_idle_hi)
	return true
