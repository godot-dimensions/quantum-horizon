extends SceneTree

## Phase 10 (items 83-89): the final pass.
##
## Every chicken, not a sample. Item 85 asks for all twelve verified through the whole
## chain, so this walks the flock one bird at a time rather than proving the mechanism once
## and assuming the other eleven are the same - the placements differ, and two of the bugs
## found in this project were in exactly one chicken.

var _root: Node
var _f: int = 0
var _t0: int = 0
var _stage: int = 0
var _mgr: Node
var _fence: Node
var _locator: Node
var _game: Node
var _player: Node4D
var _rows: Array = []
var _index: int = 0
var _second_run: int = 0
var _targets: Dictionary = {}
var _finished_at: String = ""


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
		_locator = _root.get_node("Systems/Locator")
		_game = _root.get_node("Systems/Game")
		_player = _root.get_node("Player")
		_t0 = Time.get_ticks_msec()
	var elapsed: float = float(Time.get_ticks_msec() - _t0) / 1000.0
	var agents: Array = _mgr.get("agents")

	match _stage:
		0:
			if elapsed < 4.0:
				# Let them all wander a little first, so "does it move" is a real question.
				_record_start(agents)
				return false
			print("--- item 85: all twelve, one at a time ---")
			print("   %-3s %-22s %-8s %-7s %-7s %-7s %s" % [
				"id", "spawned at", "moved", "caught", "carried", "in pen", "counted"])
			_stage = 1
		1:
			if _index >= agents.size():
				_stage = 2
				return false
			_check_one(agents[_index])
			_index += 1
		2:
			# Captured HERE, before the locator and fence checks reset the scene - not
			# after, which is why this once reported the first run reaching 0/12.
			_finished_at = "%d/12, objective reads '%s'" % [
				_mgr.call("returned_count"), (_root.get_node("UI/Objective") as Label).text]
			print("\n--- item 86: the locator across every placement ---")
			_check_locator(agents)
			_stage = 3
		3:
			print("\n--- item 87: fence parameters in several directions ---")
			_check_fence()
			_stage = 4
		4:
			print("\n--- item 88: the orientation cue ---")
			_check_mark(agents[0])
			_stage = 5
		5:
			print("\n--- item 89: the full loop, then a restart and part of a second ---")
			print("   first run reached %s" % _finished_at)
			_game.call("restart")
			_stage = 6
			_t0 = Time.get_ticks_msec()
		6:
			if elapsed < 1.0:
				return false
			print("   after restart: %d loose, %s" % [
				(_mgr.call("locator_candidates") as Array).size(),
				(_root.get_node("UI/Progress") as Label).text])
			_stage = 7
		7:
			# Part of a second run: deliver four, the way the first run delivered twelve.
			if _second_run >= 4:
				print("   second run reached %s" % (_root.get_node("UI/Progress") as Label).text)
				print("   locator still working: %s" % (_root.get_node("UI/Locator") as Label).text)
				_stage = 8
				return false
			_deliver(agents[_second_run])
			_second_run += 1
		8:
			return true
	return false


func _record_start(agents: Array) -> void:
	if not _targets.is_empty():
		return
	for agent in agents:
		_targets[agent] = (agent.get_parent() as Node4D).global_position


## One chicken, all the way through: it moved, it can be caught, it stays with the player
## through a W move, it lands in the pen, and it counts once.
func _check_one(agent: Node) -> void:
	var body: Node4D = agent.get_parent() as Node4D
	var spawned: Vector4 = _targets.get(agent, body.global_position)
	# Read BEFORE anything below touches it: landing in the pen rewrites home_position, so
	# printing it at the end of this function reported every chicken as living at w 0.
	var home: Vector4 = agent.get("home_position")
	var moved: float = Vector2(body.global_position.x - spawned.x,
		body.global_position.z - spawned.z).length()

	var catchable: bool = bool(agent.call("can_be_caught"))
	agent.call("on_caught")
	var carried: bool = int(agent.get("state")) == 4

	# Survives W navigation: move it a long way through W while held, as carrying does.
	var host: Node4D = body.get_parent() as Node4D
	var origin: Vector4 = host.global_position if host != null else Vector4.ZERO
	body.position = Vector4(spawned.x, spawned.y, spawned.z, 2.4) - origin
	var held_w: bool = is_equal_approx(body.global_position.w, 2.4)

	agent.call("on_released")
	var before: int = int(_mgr.call("returned_count"))
	var spot: Vector4 = _fence.call("random_interior_point", RandomNumberGenerator.new())
	body.position = spot - origin
	var inside: bool = bool(_fence.call("contains_point", body.global_position))
	agent.call("on_landed", true)
	_mgr.call("note_returned", agent)
	# Twice more, to prove the count is not merely right the first time.
	agent.call("on_landed", true)
	_mgr.call("note_returned", agent)
	var after: int = int(_mgr.call("returned_count"))

	print("   %-3d %-22s %-8s %-7s %-7s %-7s %s" % [
		agent.get("chicken_id"),
		"%.1f,%.1f w%.1f" % [spawned.x, spawned.z, home.w],
		"%.2f" % moved, str(catchable), str(carried), str(inside),
		"+%d" % (after - before)])


func _check_locator(agents: Array) -> void:
	# Every chicken is returned by now, so the locator should have nothing to say.
	print("   with all twelve home: %s" % (_root.get_node("UI/Locator") as Label).text)
	print("   candidates offered: %d" % (_mgr.call("locator_candidates") as Array).size())
	# Put them back and check each one can be found from the start position.
	_game.call("restart")
	var found: int = 0
	var off_slice: int = 0
	for agent in agents:
		var body: Node4D = agent.get_parent() as Node4D
		var home: Vector4 = agent.get("home_position")
		if absf(home.w) > 0.3:
			off_slice += 1
		# Stand beside it on slice zero and ask what the locator says.
		_player.position = Vector4(body.position.x, 1.3, body.position.z + 2.0, 0.0)
		_locator.set("target", agent)
		var text: String = _locator.call("_describe", agent)
		var names_a_key: bool = text.contains("press ") or text.contains("LOCKED")
		if names_a_key:
			found += 1
	print("   %d of %d describable from beside them, %d of them off-slice" % [
		found, agents.size(), off_slice])
	print("   returned chickens excluded: %s" % _excludes_returned(agents))


func _excludes_returned(agents: Array) -> bool:
	var agent: Node = agents[0]
	agent.set("returned", true)
	var offered: bool = (_mgr.call("locator_candidates") as Array).has(agent)
	agent.set("returned", false)
	return not offered


func _check_fence() -> void:
	for size in [[4.0, 4.0], [12.0, 5.0], [7.0, 14.0], [7.0, 6.0]]:
		_fence.set("extend_x_positive", size[0])
		_fence.set("extend_x_negative", size[0])
		_fence.set("extend_z_positive", size[1])
		_fence.set("extend_z_negative", size[1])
		var posts: int = 0
		var rails: int = 0
		var walls: int = 0
		for child in (_fence as Node).get_children():
			if child.name.begins_with("Post_"):
				posts += 1
			elif child.name.begins_with("Rail_"):
				rails += 1
		var collision: Node = (_fence as Node).get_node_or_null("Collision")
		if collision != null:
			walls = collision.get_child_count()
		var b: Array = _fence.call("interior_bounds")
		# Does the return volume agree with the new geometry?
		var corner: Vector4 = (_fence as Node4D).global_position + b[1] - Vector4(0.1, 0.0, 0.1, 0.0)
		var outside: Vector4 = (_fence as Node4D).global_position + b[1] + Vector4(2.0, 0.0, 2.0, 0.0)
		print("   %.0f x %.0f:  %3d posts  %3d rails  %2d collision walls   interior %.1f x %.1f   corner inside: %s, beyond: %s" % [
			size[0] * 2.0, size[1] * 2.0, posts, rails, walls,
			b[1].x - b[0].x, b[1].z - b[0].z,
			_fence.call("contains_point", corner), _fence.call("contains_point", outside)])


## Item 88: the red mark is on the RIGHT wing, and stays there.
func _check_mark(agent: Node) -> void:
	var body: Node4D = agent.get_parent() as Node4D
	var wing: Node4D = body.get_node_or_null("Wing") as Node4D
	if wing == null:
		print("   no Wing node - the cue is missing entirely")
		return
	var mark: Node4D = null
	for child in wing.get_children():
		if child.name.to_lower().contains("mark"):
			mark = child as Node4D
	if mark == null:
		print("   Wing has no mark child")
		return
	print("   mark '%s' parented to Wing at local %.2v" % [mark.name, mark.position])
	print("   sits on the %s side in the chicken's own frame (negative x)" % [
		"right" if mark.position.x < 0.0 else "LEFT - wrong side"])
	var material: Material4D = (mark as MeshInstance4D).material_override if mark is MeshInstance4D else null
	if material is TetraMaterial4D:
		print("   colour %s, distinct from the white body" % [(material as TetraMaterial4D).albedo_color])
	# It must travel with the wing rather than being left behind, which is what a parented
	# node guarantees and a position copied in code does not.
	var before: Vector4 = mark.global_position
	var lift: float = 0.7
	wing.position += Vector4(0.0, lift, 0.0, 0.0)
	var moved: float = mark.global_position.distance_to(before)
	wing.position -= Vector4(0.0, lift, 0.0, 0.0)
	# The chicken is scaled to a quarter, so a 0.7 lift in its own frame is 0.175 in the
	# world. Comparing the local nudge against a world distance made a correct result look
	# like a failure.
	var scale: float = float((_mgr.get("chicken_scale")))
	var expected: float = lift * scale
	print("   follows the wing when it moves: %s (moved %.3f, expected %.3f at %.2f scale)" % [
		absf(moved - expected) < 0.01, moved, expected, scale])


func _deliver(agent: Node) -> void:
	var body: Node4D = agent.get_parent() as Node4D
	var host: Node4D = body.get_parent() as Node4D
	agent.call("on_caught")
	agent.call("on_released")
	var spot: Vector4 = _fence.call("random_interior_point", RandomNumberGenerator.new())
	body.position = spot - (host.global_position if host != null else Vector4.ZERO)
	agent.call("on_landed", true)
	_mgr.call("note_returned", agent)
