extends SceneTree

## Item 64 (pen side) and item 43: a delivered chicken settles onto the pen's slice and is
## counted exactly once, however many times it crosses the line.

var _root: Node
var _f: int = 0
var _mgr: Node
var _fence: Node
var _agent: Node
var _body: Node4D
var _counts: Array = []
var _samples: Array = []
var _t0: int = 0


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _mgr == null:
		_mgr = _root.get_node("Chickens")
		_fence = _root.get_node("Pen/Fence")
		# The first bird that lives off the starting slice - the interesting case.
		for a in (_mgr.get("agents") as Array):
			if absf((a.get("home_position") as Vector4).w) > 0.5:
				_agent = a
				break
		_body = _agent.get_parent() as Node4D
		# Deliver it the way a throw would: held, then put down inside the fence, at the W
		# the player happened to be standing on rather than the pen's own.
		_agent.call("on_caught")
		_agent.call("on_released")
		var drop: Vector4 = _fence.call("random_interior_point", RandomNumberGenerator.new())
		drop.w = 1.4
		_body.position = drop - (_mgr as Node4D).global_position
		_t0 = Time.get_ticks_msec()
		print("chicken #%d dropped inside the pen at w %.2f" % [_agent.get("chicken_id"), _body.position.w])
		return false

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	if _f % 12 == 0:
		_samples.append([elapsed, _body.global_position.w])
		_counts.append(int(_mgr.call("returned_count")))

	# Wall-clock, not frames. In headless _process runs far faster than physics, so counting
	# process frames and dividing by 60 reports a duration the run never took.
	if elapsed < 3.0:
		return false

	print("w against real time: %s" % ", ".join(_samples.map(func(v): return "%.1fs=%.2f" % [v[0], v[1]])))
	print("settled at w %.3f after %.1f s (pen slice %.2f, settle time %.1f s)" % [
		_samples[-1][1], _samples[-1][0], _agent.get("pen_slice_w"), 1.6])
	print("still inside the fence: %s" % _fence.call("contains_point", _body.global_position))
	print("returned_count over the same window: %s" % [_counts])
	print("counted exactly once: %s" % ("yes" if _counts.max() == _counts.min() and _counts.max() == 1 else "NO - %s" % [_counts]))
	return true
