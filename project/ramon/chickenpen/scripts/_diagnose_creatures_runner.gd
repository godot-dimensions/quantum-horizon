extends SceneTree

## Are the cat and the lofted girl actually walking, or standing still / sliding?
##
## Three separate questions, and only the third is "walking":
##   1. Does the body travel across the ground at all?
##   2. Do the feet move RELATIVE to the body - that is, are the legs animating?
##   3. Do the feet hold still in the world while planted?
##
## CAVEAT ON THE SWING FIGURE: it is measured in world Z, so it only means anything while
## the animal happens to be facing along Z - and these wander, so it does not. Body speed
## and foot world speed are sound; treat the swing as an order of magnitude at best.
## A body that travels with still legs is a slide; legs that animate while the body stays
## put is a treadmill.

var _root: Node
var _f := 0
var _t0 := 0
var _rows: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	if _rows.is_empty():
		_rows = [
			["cat", "World/RockPileSpot/Cat", "World/RockPileSpot/Cat/Hide/Chest/FrontHipL/FrontKneeL/FrontFootL"],
			["lofted girl", "World/LoftedGirl", "World/LoftedGirl/Hide/Hips/LegHipL/LegKneeL/LegFootL"],
		]
		for row in _rows:
			var foot: Node4D = _root.get_node_or_null(row[2]) as Node4D
			if foot == null:
				print("%s: FOOT NODE NOT FOUND at %s" % [row[0], row[2]])
			row.append([])   # samples
		_t0 = Time.get_ticks_msec()
		return false

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	for row in _rows:
		var body: Node4D = _root.get_node_or_null(row[1]) as Node4D
		var foot: Node4D = _root.get_node_or_null(row[2]) as Node4D
		if body == null or foot == null:
			continue
		(row[3] as Array).append([elapsed, body.global_position, foot.global_position])
	if elapsed < 9.0:
		return false

	for row in _rows:
		var samples: Array = row[3]
		if samples.size() < 3:
			print("%s: no samples" % row[0]); continue
		var body_moved: float = _flat(samples[-1][1] - samples[0][1])
		# How far the foot swings relative to the body - the legs animating at all.
		var lo := INF
		var hi := -INF
		for s in samples:
			var rel: float = float((s[2] as Vector4).z - (s[1] as Vector4).z)
			lo = minf(lo, rel); hi = maxf(hi, rel)
		# And how slow the foot gets in the WORLD, which is what planting looks like.
		var speeds: Array = []
		for i in range(1, samples.size()):
			var dt: float = float(samples[i][0]) - float(samples[i - 1][0])
			if dt <= 0.0001: continue
			speeds.append(_flat(samples[i][2] - samples[i - 1][2]) / dt)
		speeds.sort()
		print("%s:" % row[0])
		print("   body travelled %.2f units in %.1f s (%.3f units/s)" % [
			body_moved, samples[-1][0], body_moved / maxf(samples[-1][0], 0.001)])
		print("   foot swings %.3f units fore-and-aft relative to the body" % (hi - lo))
		print("   foot world speed slowest/median/fastest: %.3f / %.3f / %.3f" % [
			speeds[0], speeds[speeds.size() / 2], speeds[-1]])
	return true


func _flat(v: Vector4) -> float:
	return Vector2(v.x, v.z).length()
