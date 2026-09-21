extends SceneTree

## The items from Phases 03-05 that were built but never actually checked: the startle
## response (21), evade bounds (22, 23), the per-chicken readout (25), the carried pose
## (30), the landing (33), what a returned chicken becomes (35) and whether the pen
## actually fits twelve plus the coop (42).

var _root: Node
var _f: int = 0
var _stage: int = 0
var _t0: int = 0
var _mgr: Node
var _fence: Node
var _catcher: Node
var _player: Node4D
var _wing_angles: Array = []
var _heights: Array = []
var _flight: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _mgr == null:
		_mgr = _root.get_node("Chickens")
		_fence = _root.get_node("Pen/Fence")
		_catcher = _root.get_node("Player/Catcher")
		_player = _root.get_node("Player")
		_t0 = Time.get_ticks_msec()
	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var agents: Array = _mgr.get("agents")
	var bird: Node = agents[0]
	var body: Node4D = bird.get_parent() as Node4D
	var wing: Node4D = body.get_node_or_null("Wing") as Node4D

	match _stage:
		0:
			print("--- item 25: the per-chicken readout ---")
			bird.set("debug_state", true)
			print("   debug_state on for chicken %s; its transitions print below" % bird.get("chicken_id"))
			print("   (every other chicken stays silent, which is the point)")
			print("\n--- item 21: startled ---")
			bird.set("state", 2)
			_stage = 1
			_t0 = Time.get_ticks_msec()
		1:
			if int(bird.get("state")) == 2:
				_wing_angles.append(_lift(wing))
				_heights.append(body.position.y)
				return false
			bird.set("debug_state", false)
			print("   wing lift over the beat: %s" % _span(_wing_angles))
			print("   hop height over the beat: %s" % _span(_heights))
			print("   ended in state %s (2=ALERT 3=EVADE 0=IDLE)" % bird.get("state"))
			_stage = 2
			_t0 = Time.get_ticks_msec()
		2:
			print("\n--- items 22 and 23: evade is bounded ---")
			print("   evade_max_distance %.1f, cooldown %.1f, wander leash %.1f" % [
				bird.get("evade_max_distance"), bird.get("evade_cooldown"), bird.get("wander_radius")])
			_player.position = body.global_position + Vector4(0.0, 0.0, 0.6, 0.0)
			_stage = 3
			_t0 = Time.get_ticks_msec()
		3:
			if elapsed < 12.0:
				_heights.append(body.position.y)
				return false
			var home: Vector4 = bird.get("home_position")
			var strayed: float = Vector2(body.position.x - home.x, body.position.z - home.z).length()
			print("   after 12 s of being chased: %.2f from home (leash %.1f), y stayed %s" % [
				strayed, bird.get("wander_radius"), _span(_heights)])
			print("   still on valid ground: %s" % (absf(body.position.y) < 1.0))
			_stage = 4
		4:
			print("\n--- item 30: the carried pose ---")
			_player.position = body.global_position + Vector4(0.0, 0.0, 0.9, 0.0)
			_catcher.call("_catch", bird)
			_wing_angles.clear()
			_heights.clear()
			_stage = 5
			_t0 = Time.get_ticks_msec()
		5:
			if elapsed < 3.0:
				_wing_angles.append(_lift(wing))
				_heights.append(body.global_position.y)
				return false
			print("   wing over 3 s of carrying: %s" % _span(_wing_angles))
			print("   height over the same: %s" % _span(_heights))
			print("   it is not a still prop: %s" % (_range(_wing_angles) > 0.05))
			_stage = 6
		6:
			print("\n--- item 33: the landing ---")
			_catcher.call("_release", true)
			_flight.clear()
			_stage = 7
			_t0 = Time.get_ticks_msec()
		7:
			if elapsed < 5.0:
				_flight.append(body.global_position.y)
				return false
			var settled: Array = _flight.slice(_flight.size() / 2)
			print("   height through the throw: %s" % _span(_flight))
			print("   settled in the second half: %s (spread %.3f)" % [
				_range(settled) < 0.05, _range(settled)])
			print("   never went below ground: %s" % (_flight.min() > -0.5))
			print("   not still airborne: %s" % (absf(_flight[-1]) < 0.6))
			_stage = 8
		8:
			print("\n--- item 35: what a returned chicken becomes ---")
			var penned: Node = agents[1]
			penned.call("on_caught")
			penned.call("on_released")
			var spot: Vector4 = _fence.call("random_interior_point", RandomNumberGenerator.new())
			var host: Node4D = (penned.get_parent() as Node4D).get_parent() as Node4D
			(penned.get_parent() as Node4D).position = spot - host.global_position
			penned.call("on_landed", true)
			_stage = 9
			_t0 = Time.get_ticks_msec()
		9:
			if elapsed < 0.5:
				return false
			var penned2: Node = agents[1]
			print("   state %s (6=PENNED), catchable again: %s, offered by the locator: %s" % [
				penned2.get("state"), penned2.call("can_be_caught"),
				(_mgr.call("locator_candidates") as Array).has(penned2)])
			print("\n--- item 42: does the pen fit twelve and the coop ---")
			_report_fit(agents)
			return true
	return false


func _report_fit(agents: Array) -> void:
	var b: Array = _fence.call("interior_bounds")
	var area: float = (b[1].x - b[0].x) * (b[1].z - b[0].z)
	var coop: Node4D = _root.get_node("Pen/Coop") as Node4D
	# The coop's footprint, from its own exported size.
	var size: Vector3 = coop.get("body_size")
	var coop_area: float = size.x * (size.z + float(coop.get("ramp_length")))
	var chicken_area: float = 0.47 * 0.52 * 12.0
	print("   interior %.1f x %.1f = %.0f sq units" % [
		b[1].x - b[0].x, b[1].z - b[0].z, area])
	print("   coop plus its ramp takes %.0f, twelve chickens take %.1f" % [coop_area, chicken_area])
	print("   free space per chicken: %.1f sq units (a chicken is 0.24)" % [
		(area - coop_area) / 12.0])


## How far the wing is lifted, as an angle read back off its basis.
func _lift(wing: Node4D) -> float:
	if wing == null:
		return 0.0
	return absf(atan2(wing.basis.x.y, wing.basis.x.x))


func _span(values: Array) -> String:
	if values.is_empty():
		return "no samples"
	return "%.3f to %.3f" % [values.min(), values.max()]


func _range(values: Array) -> float:
	return 0.0 if values.is_empty() else float(values.max()) - float(values.min())
