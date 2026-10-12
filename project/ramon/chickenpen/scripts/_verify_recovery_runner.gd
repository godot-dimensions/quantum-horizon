extends SceneTree

## Items 76, 77 and 78: break four chickens four different ways, press the buttons too
## fast, then crowd all twelve into the pen and see whether anything explodes.

var _root: Node
var _f: int = 0
var _t0: int = 0
var _mgr: Node
var _fence: Node
var _catcher: Node
var _broken: Array = []
var _stage: int = 0
var _was: Array = []
var _wedge_cleared: bool = false


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
		_catcher = _root.get_node("Player/Catcher")
		_t0 = Time.get_ticks_msec()

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var agents: Array = _mgr.get("agents")

	match _stage:
		0:
			print("--- item 76: four ways to lose a chicken ---")
			var ways := [
				["dropped through the floor", Vector4(0.0, -40.0, 0.0, 0.0)],
				["thrown past the horizon", Vector4(400.0, 0.0, 400.0, 0.0)],
				["position became NaN", Vector4(NAN, NAN, NAN, NAN)],
			]
			for i in ways.size():
				var agent: Node = agents[i]
				var body: Node4D = agent.get_parent() as Node4D
				_broken.append([agent, str(ways[i][0]), body.position])
				body.position = ways[i][1]
			# The fourth: wedged. Pinned well away from home while it is trying to walk, so
			# that "it is back home" is a real observation rather than a description of
			# where it was already standing.
			var stuck: Node = agents[3]
			var wedge: Vector4 = (stuck.get("home_position") as Vector4) + Vector4(9.0, 0.0, 9.0, 0.0)
			_broken.append([stuck, "wedged against something", wedge])
			(stuck.get_parent() as Node4D).position = wedge
			stuck.set("state", 1)
			_stage = 1
		1:
			# Keep the wedged one wedged: still trying to walk, going nowhere. Halting the
			# walker rather than teleporting it back each frame matters - moving it and then
			# putting it back looks exactly like walking to anything watching distance
			# travelled, which is how the first version of this test passed a detector that
			# was not working.
			var stuck: Node = _broken[3][0]
			var stuck_body: Node4D = stuck.get_parent() as Node4D
			var stuck_walker: Node = stuck_body.get_node_or_null("Walker")
			# Once the recovery has moved it, the wedge is behind it - a post it is no
			# longer standing against. Holding it there afterwards would be testing whether
			# the game can escape a trap that follows it around.
			if int(stuck.get("state")) == 7:
				_wedge_cleared = true
			if not _wedge_cleared:
				if stuck_walker != null:
					stuck_walker.set("halted", true)
				if int(stuck.get("state")) != 1:
					stuck.set("state", 1)
				stuck_body.position = _broken[3][2]
			# Long enough for TWO windows: the one already running when it got wedged is
			# still holding the walking it did before, so only the next clean one can trip.
			if elapsed < 24.0:
				return false
			for row in _broken:
				var agent: Node = row[0]
				var body: Node4D = agent.get_parent() as Node4D
				var home: Vector4 = agent.get("home_position")
				# Recovered means "put back home and got on with its life", so the test
				# allows for the wandering it will have done since.
				var leash: float = float(agent.get("wander_radius")) + 1.0
				var back: bool = body.position.distance_to(home) < leash
				print("   #%d %-28s -> %s" % [
					agent.get("chicken_id"), row[1],
					"recovered" if back else "STILL LOST at %.0v" % body.position])
			_stage = 2
		2:
			print("\n--- item 77: the same button, far too fast ---")
			var victim: Node = agents[5]
			var body: Node4D = victim.get_parent() as Node4D
			var before: int = int(_mgr.call("returned_count"))
			for i in 20:
				victim.call("on_caught")
			print("   20 catches in a row: state %s, ever_carried %s" % [
				victim.get("state"), victim.get("ever_carried")])
			for i in 20:
				victim.call("on_released")
			print("   20 releases in a row: state %s" % victim.get("state"))
			# And a return counted twenty times over.
			body.position = (_fence.call("random_interior_point", RandomNumberGenerator.new())
				- (_mgr as Node4D).global_position)
			for i in 20:
				victim.call("on_landed", true)
				_mgr.call("note_returned", victim)
			print("   20 landings in the pen: count went %d -> %d (one chicken)" % [
				before, int(_mgr.call("returned_count"))])
			_stage = 3
			_t0 = Time.get_ticks_msec()
		3:
			print("\n--- item 78: all twelve in the pen at once ---")
			for agent in agents:
				var body: Node4D = agent.get_parent() as Node4D
				agent.call("on_caught")
				agent.call("on_released")
				body.position = (_fence.call("random_interior_point", RandomNumberGenerator.new())
					- (_mgr as Node4D).global_position)
				_was.append(body.global_position)
			_stage = 4
			_t0 = Time.get_ticks_msec()
		4:
			if elapsed < 20.0:
				return false
			var closest: float = INF
			var outside: int = 0
			var max_speed: float = 0.0
			for i in agents.size():
				var a: Node4D = agents[i].get_parent() as Node4D
				if not bool(_fence.call("contains_point", a.global_position)):
					outside += 1
				max_speed = maxf(max_speed, a.global_position.distance_to(_was[i]) / 20.0)
				_was[i] = a.global_position
				for j in range(i + 1, agents.size()):
					var b: Node4D = agents[j].get_parent() as Node4D
					closest = minf(closest, a.global_position.distance_to(b.global_position))
			print("   after 20 s: closest pair %.2f units, %d outside the fence" % [closest, outside])
			print("   fastest drift %.2f units/s over that window (no physics bodies, so no forces)" % max_speed)
			var gate: Vector4 = (_fence as Node4D).global_position + Vector4(0.0, 0.0, 6.0, 0.0)
			var near_gate: int = 0
			for agent in agents:
				var at: Vector4 = (agent.get_parent() as Node4D).global_position
				if Vector2(at.x - gate.x, at.z - gate.z).length() < 1.5:
					near_gate += 1
			print("   chickens within 1.5 units of the 2.4-wide gateway: %d" % near_gate)
			return true
	return false
