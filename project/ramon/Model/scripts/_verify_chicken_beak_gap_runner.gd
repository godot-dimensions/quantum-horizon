extends SceneTree
## How far above the ground does the beak actually get? Measure against the feet.
var _root: Node
var _f := 0
var _head: Node4D
var _foot_lo := 1e9
var _beak_lo := 1e9
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 5:
		var c: Node4D = _root.get_node_or_null("Chicken")
		var n: Node = c.get_node_or_null("NeckHead")
		while n != null and n.get_child_count() > 0: n = n.get_child(n.get_child_count()-1)
		_head = n as Node4D
		for leg in ["LegL", "LegR"]:
			var l: Node = c.get_node_or_null(leg)
			print("%s present: %s" % [leg, l != null])
		return false
	if _f < 10: return false
	var c2: Node4D = _root.get_node_or_null("Chicken")
	# The FOOT is the lowest ball of the leg, not the last child - the last child is
	# the hip, which is what made the first pass at this measurement meaningless.
	for leg in ["LegL", "LegR"]:
		var rig: Node = c2.get_node_or_null(leg)
		for b in rig.get_children():
			if b.has_method("get_loft_section") and b is Node4D:
				_foot_lo = minf(_foot_lo, (b as Node4D).global_position.y)
	_beak_lo = minf(_beak_lo, _head.global_position.y)
	if _f < 1500: return false
	print("lowest foot ball centre: %.3f" % _foot_lo)
	print("lowest beak ball centre: %.3f" % _beak_lo)
	print("beak vs lowest foot: %+.3f  (0 = beak reaches the ground the feet stand on)" % (_beak_lo - _foot_lo))
	return true
