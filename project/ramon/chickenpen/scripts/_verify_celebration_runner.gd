extends SceneTree

## The twelfth chicken lands. Does the pen actually throw a party, and does it keep it up?
##
## THE TEST PRESSES THE SAME BUTTON A PLAYER WOULD. It does not call _on_completed and
## then check that _on_completed ran. It fills the pen the way the M shortcut does - each
## bird through on_caught and on_released, landed inside the fence - and then waits for
## the return volume, the count and the completion signal to do their own work. If any
## link in that chain breaks, this goes quiet, which is the point.
##
## AND IT CHECKS THAT NOTHING ENDS IT. "They keep going" is the part most likely to rot:
## a later timer, a state change on landing, a walker that reclaims the height. So the
## birds are sampled long after the confetti has settled, and their feet have to still be
## leaving the ground.

var _root: Node
var _f := 0
var _fails: Array = []
var _party: Node
var _game: Node
var _manager: Node
var _stage := 0
var _settle := 0
var _waited := 0
var _lows: Array = []
var _highs: Array = []


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root); current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 5: return false
	match _stage:
		0:
			_party = _root.get_node_or_null("Systems/Celebration")
			_game = _root.get_node_or_null("Systems/Game")
			_manager = _root.get_node_or_null("Chickens")
			print("\n--- before ---")
			if _party == null or _game == null:
				_check("there is a Celebration node", false, "Systems/Celebration")
				_finish(); return true
			_check("nobody is celebrating yet", _partying() == 0,
				"%d of %d birds" % [_partying(), _manager.get("agents").size()])
			_check("and there is no confetti", _party.get_node_or_null("Confetti") == null, "")
			# The shortcut, exactly as the M key calls it.
			_party.call("_fill_the_pen")
		1:
			# WAIT FOR THE CONDITION, NOT FOR A FIXED NUMBER OF FRAMES. This used to sit
			# out three frames and then assert, which is a race it lost about one run in
			# three: pen_return_4d tests every `check_every` frames (3 by default), so
			# three frames of waiting buys somewhere between zero and one check depending
			# on where its tick counter happens to be. It passed on byte-identical files
			# three times running and then failed, which is the signature.
			# Its own counter: _settle belongs to the sampling loop further down, and
			# borrowing it here left that loop starting part-way through its own count.
			_waited += 1
			if not bool(_game.get("_finished")) and _waited < 400:
				return false
		2:
			print("\n--- the twelfth chicken is in ---")
			_check("the game says it is finished", bool(_game.get("_finished")),
				"%d returned" % _manager.call("returned_count"))
			_check("every penned bird is celebrating",
				_partying() == int(_manager.call("returned_count")),
				"%d of %d" % [_partying(), _manager.call("returned_count")])
			var confetti: Node = _party.get_node_or_null("Confetti")
			_check("there is confetti", confetti != null,
				"%d pieces" % (confetti.get_child_count() if confetti != null else 0))
			if confetti != null:
				# The lesson this project keeps re-learning: a prop with no W extent
				# vanishes the moment the slice turns.
				var thin := 0
				var spread_w := 0.0
				for piece in confetti.get_children():
					var m := (piece as MeshInstance4D).mesh as BoxTetraMesh4D
					if m.size.w < 0.01:
						thin += 1
					spread_w = maxf(spread_w, absf((piece as Node4D).position.w))
				_check("no piece is flat through W", thin == 0,
					"%d of %d would vanish on a slice turn" % [thin, confetti.get_child_count()])
				_check("and the burst is spread through W", spread_w > 0.05,
					"reaches %.2f off the slice" % spread_w)
		_:
			# Sample the birds' height long after the burst, to prove nothing stops them.
			_settle += 1
			if _settle == 1:
				print("\n--- and they keep going ---")
			var agents: Array = _manager.get("agents")
			if _lows.is_empty():
				_lows.resize(agents.size()); _lows.fill(99.0)
				_highs.resize(agents.size()); _highs.fill(-99.0)
			for i in agents.size():
				# The agent's PARENT is the creature - the same node chicken_agent_4d
				# calls _creature and writes the hop to. Reading a child of it measures
				# a mesh that never moves, which is what this test did first time and
				# why it reported twelve perfectly still chickens.
				var creature: Node4D = (agents[i] as Node).get_parent() as Node4D
				if creature == null: continue
				_lows[i] = minf(_lows[i], creature.position.y)
				_highs[i] = maxf(_highs[i], creature.position.y)
			if _settle < 260:
				return false
			var bouncing := 0
			var most := 0.0
			for i in _lows.size():
				if not bool((agents[i] as Node).call("is_partying")): continue
				var swing: float = _highs[i] - _lows[i]
				most = maxf(most, swing)
				if swing > 0.05:
					bouncing += 1
			_check("they are still leaving the ground", bouncing == _partying(),
				"%d of %d, biggest hop %.2f, sampled over %d frames"
					% [bouncing, _partying(), most, _settle])
			# Out of step, or twelve chickens read as one animal.
			var same := true
			for i in range(1, _lows.size()):
				if absf(_lows[i] - _lows[0]) > 0.001 or absf(_highs[i] - _highs[0]) > 0.001:
					same = false; break
			_check("and not all in the same instant", not same, "phases differ per bird")
			print("\n--- the M shortcut resets ---")
			_party.call("_reset")
			_check("nobody is celebrating afterwards", _partying() == 0,
				"%d still going" % _partying())
			_check("the game is playable again", not bool(_game.get("_finished")),
				"%d returned" % _manager.call("returned_count"))
			_finish()
			return true
	_stage += 1
	return false


func _partying() -> int:
	var n := 0
	for agent in _manager.get("agents"):
		if agent != null and bool(agent.call("is_partying")):
			n += 1
	return n


func _finish() -> void:
	if _fails.is_empty(): print("\nALL PASS")
	else: print("\n%d FAILED: %s" % [_fails.size(), ", ".join(_fails)])
	quit(1 if _fails.size() > 0 else 0)
