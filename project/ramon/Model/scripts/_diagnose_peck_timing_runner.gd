extends SceneTree
## Does a peck last as long as peck_duration says it does?
var _root: Node
var _f := 0
var _w: Node
var _active := false
var _start := 0
var _lens: Array[float] = []
var _gaps: Array[float] = []
var _last_end := 0
var _t0 := 0
func _now() -> int: return Time.get_ticks_msec()
func _initialize() -> void:
	_root = load("res://ramon/Model/rigged_creature_ramon.tscn").instantiate()
	root.add_child(_root); current_scene = _root
func _process(_d) -> bool:
	_f += 1
	if _f == 5:
		_t0 = _now()
		_w = _root.get_node_or_null("Chicken/Walker")
		print("walker found: %s, peck_duration %.2f, interval %.1f..%.1f" % [_w != null,
			_w.peck_duration, _w.peck_interval_min, _w.peck_interval_max])
		return false
	if _f < 5: return false
	if _w == null: return true
	var on: bool = _w._peck_elapsed >= 0.0
	if on and not _active:
		_start = _now()
		if _last_end > 0: _gaps.append((_now() - _last_end) / 1000.0)
	if _active and not on:
		_lens.append((_now() - _start) / 1000.0); _last_end = _now()
	_active = on
	if _f < 1800: return false
	print("ran %d frames, %.1f s of wall clock" % [_f, (_now() - _t0) / 1000.0])
	print("pecks completed: %d, lengths (s): %s" % [_lens.size(), str(_lens.map(func(v): return "%.2f" % v))])
	print("gaps between them (s): %s" % str(_gaps.map(func(v): return "%.2f" % v)))
	return true
