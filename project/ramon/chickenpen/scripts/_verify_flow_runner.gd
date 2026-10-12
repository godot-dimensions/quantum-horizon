extends SceneTree

## Phase 08 (items 67-74): does the session have a beginning, a middle and an end?
##
## Plays the whole loop without a human: reads the start state, watches the hints appear in
## order, delivers all twelve chickens, checks the completion behaviour, then restarts and
## checks the scene is genuinely back to the start rather than merely reset-looking.

var _root: Node
var _f: int = 0
var _t0: int = 0
var _game: Node
var _mgr: Node
var _fence: Node
var _locator: Node
var _cues: Node
var _tutor: Node
var _hint: Label
var _seen_hints: Array = []
var _stage: int = 0
var _completed: bool = false
var _noted_first: bool = false


func _initialize() -> void:
	_root = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _process(_d) -> bool:
	_f += 1
	if _f < 60:
		return false
	if _game == null:
		_game = _root.get_node("Systems/Game")
		_mgr = _root.get_node("Chickens")
		_fence = _root.get_node("Pen/Fence")
		_locator = _root.get_node("Systems/Locator")
		_cues = _root.get_node("Systems/Cues")
		_tutor = _root.get_node("Systems/Tutor")
		_hint = _root.get_node("UI/Hint")
		_game.connect("completed", func() -> void: _completed = true)
		_t0 = Time.get_ticks_msec()
		print("--- item 67: the start state ---")
		var player: Node4D = _root.get_node("Player")
		var gate: Vector4 = (_fence as Node4D).global_position
		print("   player starts at %.1v, %.1f units from the pen centre" % [
			player.global_position, player.global_position.distance_to(gate)])
		print("   keeper placeholder: %s   sign: %s" % [
			_root.get_node_or_null("World/KeeperPost/Keeper") != null,
			_root.get_node_or_null("World/Sign") != null])
		print("   objective: %s" % (_root.get_node("UI/Objective") as Label).text)
		print("   progress:  %s" % (_root.get_node("UI/Progress") as Label).text)
		print("   time pressure: %s (item 71 wants none)" % _has_timer())

	var hint: String = _hint.text
	if hint != "" and not _seen_hints.has(hint):
		_seen_hints.append(hint)

	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0

	match _stage:
		0:
			# Let the opening hints play out before touching anything.
			# Long enough for more than one hint: they are shown one at a time for
			# hint_seconds each, so a two-second window can only ever see the first.
			if elapsed < 16.0:
				return false
			print("\n--- item 68: hints, in the order they became true ---")
			for h in _seen_hints:
				print("   %s" % h)
			_stage = 1
		1:
			# Deliver them one at a time, so the confirmation can be checked per return
			# rather than only at the end.
			var remaining: Array = _mgr.call("locator_candidates")
			if remaining.is_empty():
				_stage = 2
				return false
			_deliver(remaining[0])
			if int(_mgr.call("returned_count")) == 1 and not _noted_first:
				_noted_first = true
				print("\n--- item 70: first return ---")
				print("   %s" % (_root.get_node("UI/Progress") as Label).text)
				print("   confirm sound playing: %s" % _playing("Confirm"))
		2:
			print("\n--- item 72: completion ---")
			print("   %s" % (_root.get_node("UI/Objective") as Label).text)
			print("   %s" % (_root.get_node("UI/Progress") as Label).text)
			print("   completed signal fired: %s" % _completed)
			print("   locator still guiding: %s" % _locator.is_physics_processing())
			print("   locator says: %s" % (_root.get_node("UI/Locator") as Label).text)
			print("   chorus playing: %s" % _playing("Chorus"))
			var drawn: int = 0
			for m in (_cues.get("_markers") as Dictionary).values():
				if (m as MeshInstance4D).visible:
					drawn += 1
			print("   glimpse markers still shown: %d" % drawn)
			_stage = 3
		3:
			# Item 73: back to the beginning, without leaving the scene.
			_game.call("restart")
			_tutor.call("reset")
			_stage = 4
		4:
			var agents: Array = _mgr.get("agents")
			var homes: Array = []
			for a in agents:
				homes.append((a.get("home_position") as Vector4))
			print("\n--- item 73: after restart ---")
			print("   %s" % (_root.get_node("UI/Objective") as Label).text)
			print("   %s" % (_root.get_node("UI/Progress") as Label).text)
			print("   chickens: %d, eligible again: %d" % [
				agents.size(), (_mgr.call("locator_candidates") as Array).size()])
			print("   any still marked returned: %s" % _any_returned())
			print("   locator guiding again: %s" % _locator.is_physics_processing())
			print("   first four homes back at authored spots: %s" % [
				homes.slice(0, 4).map(func(v: Vector4) -> String: return "%.1f,%.1f,w%.1f" % [v.x, v.z, v.w])])
			print("   hint after reset: %s" % _hint.text)
			return true
	return false


## Put a chicken in the pen the way a throw would: held first, then placed inside.
func _deliver(agent: Node) -> void:
	var body: Node4D = agent.get_parent() as Node4D
	agent.call("on_caught")
	agent.call("on_released")
	var spot: Vector4 = _fence.call("random_interior_point", RandomNumberGenerator.new())
	body.position = spot - (_mgr as Node4D).global_position


func _any_returned() -> bool:
	for a in (_mgr.get("agents") as Array):
		if bool(a.get("returned")):
			return true
	return false


func _playing(named: String) -> bool:
	var player: AudioStreamPlayer = _cues.get_node_or_null(named) as AudioStreamPlayer
	return player != null and player.playing


## Item 71: make sure nobody quietly added time pressure.
##
## Looks for a RULE, not for arithmetic involving time. An earlier version flagged every
## chicken's _peck_countdown, which is how long until the bird next pecks the ground -
## time pressure on the player is a different thing entirely. So private counters are
## ignored and only exported, settable limits count.
func _has_timer() -> String:
	var found: Array = []
	var words := ["time_limit", "time_remaining", "deadline", "session_seconds", "par_time"]
	for node in _all(_root):
		if node is Timer:
			found.append("Timer at %s" % _root.get_path_to(node))
		if node.get_script() == null:
			continue
		for prop in node.get_property_list():
			var prop_name: String = str(prop["name"])
			if prop_name.begins_with("_"):
				continue
			for word in words:
				if prop_name.to_lower().contains(word):
					found.append("%s.%s" % [_root.get_path_to(node), prop_name])
	return "none found" if found.is_empty() else ", ".join(found)


func _all(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_all(child))
	return out
