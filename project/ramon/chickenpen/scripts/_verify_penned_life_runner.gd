extends SceneTree

## After it lands in the pen, does the bird get on with its life where it fell?
##
## Two faults were reported as one - "it skates back as it lands". The skate was the drift
## onto the pen's slice running against a HALTED walker: the body travelled through W with
## both feet planted. The other half is that a penned bird then never moved again, because
## the state re-entered itself with the walker halted for ever.
##
## So: it must end up near where it landed and not somewhere else, it must actually cover
## ground afterwards, and it must not move while its feet are still.

var _root: Node
var _f := 0
var _step := 0
var _fails: Array = []
var _landed := Vector4.ZERO
var _agent: Node
var _body: Node4D
var _walker: Node
var _slid: float = 0.0
var _first_second: float = 0.0
var _walked: float = 0.0
var _last := Vector4.ZERO


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-38s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 70: return false
	var mgr: Node = _root.get_node("Chickens")
	var player: Node4D = _root.get_node("Player")

	# WATCHED BEFORE THE STEPS, not after them. Sat at the bottom of _process it never ran
	# at all: the waiting step returns early every frame, so the tracking was only reached
	# on the frames where nothing was being waited for - and it reported a bird that had
	# not moved as a bird that could not move.
	if _body != null and _walker != null:
		var at: Vector4 = _body.global_position
		var moved: float = (at - _last).length()
		if bool(_walker.get("halted")):
			_slid += moved
			# The first second after touchdown is the window the skate was reported in.
			if _step == 1 and _f < 60:
				_first_second += moved
		else:
			_walked += moved
		_last = at

	match _step:
		0:
			player.position = Vector4(30.0, 1.3, 30.0, 0.0)
			_agent = (mgr.get("agents") as Array)[3]
			_body = _agent.get_parent() as Node4D
			# BY NAME, the way the agent itself finds it. Hunting for a `belt_speed`
			# property found nothing - that belongs to the four-legged strider, and a
			# chicken uses chicken_walker.gd - so the whole watch was skipped and a bird
			# that had not moved looked like one that could not.
			_walker = _body.get_node_or_null("Walker")
			# Put it down well off-centre inside the pen, and off the pen's own slice, so
			# both the settle and the walk have somewhere to go.
			_agent.call("on_caught")
			_agent.call("on_released")
			var host: Node4D = (_body.get_parent() as Node4D)
			_body.position = Vector4(2.6, 0.0, -12.4, 1.4) - host.global_position
			_agent.call("on_landed", true)
			_landed = _body.global_position
			_last = _landed
			print("\n   landed at %v" % _landed)
		1:
			# Longer than before: it lands STANDING now, so the first stroll is a few
			# seconds away rather than immediate.
			if _f < 420: return false
			print("   seven seconds later it is at %v" % _body.global_position)
			var strayed: float = Vector2(_body.global_position.x - _landed.x,
				_body.global_position.z - _landed.z).length()
			_check("it stayed where it landed", strayed < 2.5,
				"%.2f from the spot it came down on" % strayed)
			_check("and it actually walked", _walked > 0.25,
				"covered %.2f units on the ground" % _walked)
			_check("it never slid with its feet still", _slid < 0.05,
				"%.3f units travelled while halted" % _slid)
			_check("and nothing moved it as it landed", _first_second < 0.02,
				"%.4f units in the first second after touchdown" % _first_second)
			_check("it is penned and counted", bool(_agent.get("returned")),
				"state %s" % _agent.call("describe"))
			print("\n%d FAIL(s)" % _fails.size())
			quit(1 if _fails.size() > 0 else 0)
			return true
	if _step == 0:
		_step = 1
	return false
