extends SceneTree

## Do the chicken's feet leave the ground, or does it moonwalk?
##
## Two separate questions, and only the second one is what "moonwalking" means:
##   1. Does the foot RISE at all during the stride?
##   2. While the foot is DOWN, does it stay put in the world while the body moves over it?
## A foot that lifts but also slides is still moonwalking. A foot that never lifts but stays
## planted is a shuffle. The failure people recognise is the foot sliding backwards under a
## body that is travelling, so this measures the foot's ground speed against the body's.

var _root: Node
var _f: int = 0
var _t0: int = 0
var _mgr: Node
var _bird: Node4D
var _samples: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 90:
		return false
	if _bird == null:
		_mgr = _root.get_node("Chickens")
		# A bird that is actually walking, not one standing still.
		for agent in (_mgr.get("agents") as Array):
			var body: Node4D = agent.get_parent() as Node4D
			if body.get_node_or_null("LegL/FootL") != null:
				_bird = body
				agent.set("state", 1)
				break
		_t0 = Time.get_ticks_msec()
		return false

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var foot: Node4D = _bird.get_node("LegL/FootL")
	if elapsed < 6.0:
		_samples.append([elapsed, foot.global_position, _bird.global_position])
		return false

	print("raw: time, foot(x,y,z), body(x,z), foot-relative-to-body z")
	var step: int = maxi(_samples.size() / 24, 1)
	for i in range(0, _samples.size(), step):
		var fp: Vector4 = _samples[i][1]
		var bp: Vector4 = _samples[i][2]
		print("   %4.2f  foot %6.3f %6.4f %6.3f   body %6.3f %6.3f   rel z %6.3f" % [
			_samples[i][0], fp.x, fp.y, fp.z, bp.x, bp.z, fp.z - bp.z])

	# Where does the foot sit, vertically, across the stride?
	var lows: Array = []
	var highs: Array = []
	for s in _samples:
		lows.append((s[1] as Vector4).y)
	var floor_y: float = lows.min()
	var ceiling: float = lows.max()
	print("chicken foot height over 6 s: %.4f to %.4f  (lift %.4f)" % [
		floor_y, ceiling, ceiling - floor_y])

	# PLANTING MEASURED DIRECTLY, not inferred from height.
	#
	# Filtering stance by "the foot is low" needs a clean vertical arc to threshold on, and
	# this one is small and noisy, so it kept catching swing frames - where a foot SHOULD
	# be moving faster than the body - and reporting them as slip. What actually defines a
	# planted foot is that it holds still in the WORLD, so measure that: for what fraction
	# of the cycle is the foot nearly stationary, and how slow does it get at its slowest?
	# A good walk holds still for about the duty factor, roughly 60% of the time.
	var speeds: Array = []
	var body_speeds: Array = []
	for i in range(1, _samples.size()):
		var dt: float = float(_samples[i][0]) - float(_samples[i - 1][0])
		if dt <= 0.0001:
			continue
		var f0: Vector4 = _samples[i - 1][1]
		var f1: Vector4 = _samples[i][1]
		var b0: Vector4 = _samples[i - 1][2]
		var b1: Vector4 = _samples[i][2]
		speeds.append(Vector2(f1.x - f0.x, f1.z - f0.z).length() / dt)
		body_speeds.append(Vector2(b1.x - b0.x, b1.z - b0.z).length() / dt)
	var body_avg: float = _avg(body_speeds)
	var still: int = 0
	for v in speeds:
		if float(v) < body_avg * 0.25:
			still += 1
	var sorted_speeds: Array = speeds.duplicate()
	sorted_speeds.sort()
	print("body averages %.3f units/s" % body_avg)
	print("foot is nearly stationary in %.0f%% of frames (a walk plants for about 60%%)" % [
		100.0 * float(still) / float(speeds.size())])
	print("foot speed, slowest to fastest: %.3f / %.3f / %.3f / %.3f units/s" % [
		sorted_speeds[0], sorted_speeds[sorted_speeds.size() / 4],
		sorted_speeds[sorted_speeds.size() / 2], sorted_speeds[-1]])
	print("   (the slowest quarter should sit near zero if the foot is truly planted)")
	return true

func _avg(values: Array) -> float:
	var total: float = 0.0
	for v in values:
		total += float(v)
	return total / float(values.size())
