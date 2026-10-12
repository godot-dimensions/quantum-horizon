extends SceneTree
## Does the bird actually lower its beak to the ground, and stop walking while it does?
var _root: Node
var _f := 0
var _head: Node4D
var _chick: Node4D
var _hy: Array[float] = []
var _mv: Array[float] = []
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 5:
		_chick = _root.get_node_or_null("Chicken")
		# The head is the deepest ball down the neck chain.
		var n: Node = _chick.get_node_or_null("NeckHead")
		while n != null and n.get_child_count() > 0:
			n = n.get_child(n.get_child_count() - 1)
		_head = n as Node4D
		print("head node: %s" % (_head.name if _head else "NOT FOUND"))
		return false
	if _f < 10: return false
	if _head == null: return true
	_hy.append(_head.global_position.y)
	_mv.append(_chick.position.x)
	if _f < 1500: return false
	var lo := 1e9; var hi := -1e9
	for y in _hy: lo = minf(lo, y); hi = maxf(hi, y)
	# A peck is a stretch where the head sits in the bottom third of its range.
	var thresh := lo + (hi - lo) * 0.33
	var pecks := 0; var down := false; var down_frames := 0
	var moved_down := 0.0; var moved_up := 0.0
	for i in range(1, _hy.size()):
		var step: float = absf(_mv[i] - _mv[i-1])
		if _hy[i] < thresh:
			if not down: pecks += 1
			down = true; down_frames += 1; moved_down += step
		else:
			down = false; moved_up += step
	print("head height over %.1f s: %.3f .. %.3f (range %.3f)" % [_hy.size()/60.0, lo, hi, hi-lo])
	print("dips into the bottom third: %d, lasting %.1f s total" % [pecks, down_frames/60.0])
	print("ground travel while head is DOWN: %.4f units/frame" % (moved_down / maxf(down_frames, 1)))
	print("ground travel while head is UP:   %.4f units/frame" % (moved_up / maxf(_hy.size()-down_frames, 1)))
	return true
