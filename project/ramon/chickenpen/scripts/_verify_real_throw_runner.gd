extends SceneTree

## Throw a chicken into the pen the way the game does, and watch every frame of it.
##
## THIS IS THE PATH THE OTHER TESTS MISSED. They called on_landed() themselves, which is
## half of a real delivery. In play the CATCHER lands it first - on_landed(false), which
## means "stopped flying", not "arrived" - and the pen's volume only notices a frame or
## several later. In between the bird is loose, inside the fence, with its home still set
## to where it was authored out in the field, and containment acts on that.

var _root: Node
var _f := 0
var _fails: Array = []
var _agent: Node
var _body: Node4D
var _catcher: Node
var _landed_at := Vector4.ZERO
var _worst_jump: float = 0.0
var _worst_w: float = 0.0
var _last := Vector4.ZERO
var _tracking := false
var _left_pen := false
var _fence: Node


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-40s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 80: return false
	if _agent == null:
		_catcher = _root.get_node("Player/Catcher")
		_fence = _root.get_node("Pen/Fence")
		# Bird 9, authored well out in the field AND off the default slice - the two
		# things that make the stale home visible.
		_agent = (_root.get_node("Chickens").get("agents") as Array)[8]
		_body = _agent.get_parent() as Node4D
		print("\n   its authored home is %v" % _agent.get("home_position"))
		# Carried, then thrown into the pen from just outside it.
		_agent.call("on_caught")
		var host: Node4D = _body.get_parent() as Node4D
		_body.position = Vector4(0.0, 1.4, -6.0, 0.0) - host.global_position
		_agent.call("on_released")
		_catcher.get("_flying").append({
			"agent": _agent, "body": _body,
			"velocity": Vector4(0.0, 1.2, -4.2, 0.0)})
		return false

	# A FIXED FRAME, WELL AFTER THE THROW. Two cleverer triggers got this wrong in
	# opposite directions - one started the watch before the flight and counted the arc
	# as skating, the other never fired at all and reported a bird that was never watched
	# as one that never moved. A frame count cannot misfire.
	# ON THE GROUND. Not a frame count - headless frames are worth a couple of
	# milliseconds each, so a number picked to be "well after the throw" was still in the
	# middle of the arc - and not a state or a queue, both of which misfired in opposite
	# directions. Touching the floor is the thing actually being waited for.
	if not _tracking and _body.global_position.y <= 0.01:
		# Stopped flying: from here on nothing but its own legs should move it.
		_tracking = true
		_landed_at = _body.global_position
		_last = _landed_at
		print("   it came down at %v" % _landed_at)
	if _tracking:
		var at: Vector4 = _body.global_position
		_worst_jump = maxf(_worst_jump, Vector2(at.x - _last.x, at.z - _last.z).length())
		_worst_w = maxf(_worst_w, absf(at.w - _last.w))
		_last = at
		if not bool(_fence.call("contains_point", at)):
			_left_pen = true

	if _tracking and _f % 30 == 0:
		print("      %4d  %-11s  at %.2f,%.2f,%.2f  home %.2f,%.2f,%.2f"
			% [_f, _agent.call("describe"),
				_body.global_position.x, _body.global_position.y, _body.global_position.z,
				(_agent.get("home_position") as Vector4).x,
				(_agent.get("home_position") as Vector4).y,
				(_agent.get("home_position") as Vector4).z])
	if _f < 1400: return false
	print("   it ended at %v, state %s" % [_body.global_position, _agent.call("describe")])
	_check("it did not jump through W on landing", _worst_w < 0.05,
		"biggest single-frame W move was %.3f" % _worst_w)
	_check("nor skate across the ground", _worst_jump < 0.05,
		"biggest single-frame ground move was %.3f" % _worst_jump)
	_check("it stayed in the pen", not _left_pen,
		"never crossed the fence" if not _left_pen else "it got out at least once")
	_check("and it was counted", bool(_agent.get("returned")),
		"%s" % _agent.call("describe"))
	var drift: float = Vector2(_body.global_position.x - _landed_at.x,
		_body.global_position.z - _landed_at.z).length()
	# A COOP VISIT IS NOT DRIFT. A penned bird is meant to go and use the henhouse, which
	# moves it several units on purpose - so the test asks whether it was MOVED, not
	# whether it is still standing on the exact spot.
	var used_coop: bool = int(_agent.get("state")) >= 8
	_check("it stayed near where it came down", drift < 2.0 or used_coop,
		"%.2f from the landing spot%s" % [drift, " (it is using the coop)" if used_coop else ""])
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
