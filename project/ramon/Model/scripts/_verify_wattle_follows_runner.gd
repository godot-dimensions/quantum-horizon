extends SceneTree
## Does the wattle stay glued to the beak through a peck?
var _root: Node
var _f := 0
var _w: Node
var _beak: Node4D
var _wat: Node4D
var _gap_lo := 1e9
var _gap_hi := -1e9
var _wat_lo := 1e9
var _wat_hi := -1e9
var _n := 0
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 5:
		_w = _root.get_node_or_null("Chicken/Walker")
		_beak = _root.get_node_or_null("Chicken/NeckHead/Ball4/BeakBase/BeakMid/BeakTip")
		_wat = _root.get_node_or_null("Chicken/Wattle/Ball2")
		print("beak tip: %s   wattle ball: %s" % [_beak != null, _wat != null])
		return false
	if _f < 5: return false
	_n += 1
	var d: float = _beak.global_position.distance_to(_wat.global_position)
	_gap_lo = minf(_gap_lo, d); _gap_hi = maxf(_gap_hi, d)
	_wat_lo = minf(_wat_lo, _wat.global_position.y); _wat_hi = maxf(_wat_hi, _wat.global_position.y)
	if _n < 1600: return false
	print("beak-to-wattle distance over the run: %.4f .. %.4f (rigid = constant)" % [_gap_lo, _gap_hi])
	print("wattle height: %.3f .. %.3f (it must DROP during a peck, not hover)" % [_wat_lo, _wat_hi])
	return true
