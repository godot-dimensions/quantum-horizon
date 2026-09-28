extends SceneTree

## The trough: what it is made of, who stands at it, and whether the pig turns up.

var _root: Node
var _f := 0
var _fails: Array = []
var _up: Node4D
var _nike: Node4D
var _antics: Node
var _spot: Vector4
var _said_frame := 0
## Physics ticks, counted separately from process frames. See stage 3.
var _ticks := 0
var _jump_by := 0
var _stage := 0
var _start_gap: float = 0.0
var _peaked: float = 0.0


func _initialize() -> void:
	physics_frame.connect(func() -> void: _ticks += 1)
	_root = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(_root)
	current_scene = _root


func _check(label: String, ok: bool, detail: String) -> void:
	print("   %s %-44s %s" % ["PASS" if ok else "FAIL", label, detail])
	if not ok:
		_fails.append(label)


func _process(_d) -> bool:
	_f += 1
	if _f < 30:
		return false
	if _up == null:
		_up = _root.get_node_or_null("Pen/Upgrades") as Node4D
		_nike = _root.get_node_or_null("World/Nike") as Node4D
		_antics = _root.get_node_or_null("World/Nike/Antics")
		if _up == null or _nike == null or _antics == null:
			_check("the pieces are in the scene", false, "Pen/Upgrades / World/Nike")
			return _finish()
		print("\n--- the trough ---")
		_root.get_node("UI/Inventory").call("add_item", "found_gold")
		_check("a nugget buys one", bool(_up.call("buy", "feeder")), "found_gold spent")
		var trough: Node4D = _up.get_node_or_null("Feeder1") as Node4D
		if trough == null:
			_check("and one goes up", false, "no Feeder1")
			return _finish()
		_spot = trough.global_position
		_check("and one goes up", true, "%d pieces, not one brown box"
			% trough.get_child_count())

		# The two colours, and which is which. A trough that came out all one colour would
		# still pass a child count.
		var timber := 0
		var grain := 0
		var wide := 0.0
		var tall := 0.0
		for piece in trough.get_children():
			var mesh: BoxTetraMesh4D = (piece as MeshInstance4D).mesh as BoxTetraMesh4D
			wide = maxf(wide, mesh.size.x)
			tall = maxf(tall, mesh.size.y + absf((piece as Node4D).position.y))
			var col: Color = ((piece as MeshInstance4D).material_override as TetraMaterial4D).albedo_color
			if col.r > 0.8 and col.g > 0.6 and col.b < 0.4:
				grain += 1
			else:
				timber += 1
		_check("timber round the outside", timber >= 5, "%d planks: a floor, two sides, two ends" % timber)
		_check("and yellow feed in the middle", grain >= 3,
			"%d pieces of grain, in the one colour nothing else on the farm is" % grain)
		_check("a tiny bit smaller than it was", wide < 1.9,
			"%.2f long, against 1.90 before" % wide)
		_check("and sitting on the ground, not sunk into it",
			trough.position.y == 0.0 and tall > 0.2,
			"root at y 0, pieces measured up from there")
		return false

	match _stage:
		0:
			print("\n--- who stands at it ---")
			# Birds are told where home is every frame; give it a few to settle.
			_stage = 1
			return false
		1:
			var manager: Node = _root.get_node("Chickens")
			var claimed := 0
			var inside := 0
			for agent in manager.get("agents"):
				if not is_instance_valid(agent):
					continue
				var home: Vector4 = agent.get("home_position")
				var gap := Vector2(home.x - _spot.x, home.z - _spot.z)
				if gap.length() > float(_up.get("draw_radius")):
					continue
				claimed += 1
				# The footprint is 1.6 by 0.6, so half of it is 0.8 by 0.3.
				if absf(gap.x) < 0.8 and absf(gap.y) < 0.3:
					inside += 1
			_check("the birds it drew in stand round the rim", claimed > 0 and inside == 0,
				"%d gathered, %d of them standing in the timber" % [claimed, inside])
			_check("and they mill less than the stand-off",
				float(_up.get("gather_wander")) < float(_up.get("rim_wide")),
				"wander %.2f inside a rim at %.2f, so they do not drift back in"
					% [float(_up.get("gather_wander")), float(_up.get("rim_wide"))])

			print("\n--- and the pig ---")
			_check("Nike hears about dinner",
				_up.is_connected("feeder_raised", Callable(_antics, "go_and_eat")),
				"Pen/Upgrades -> World/Nike/Antics")
			_check("and sets off for it", bool(_antics.get("_going_to_eat"))
				or _near_trough(), "he was told the moment it went up")
			_stage = 2
			_said_frame = _f + 60
			return false
		2:
			# He walks at one speed and the trough is ten metres off, so arriving is a
			# minute and a half of nothing. What is worth asserting is that he is CLOSING
			# on it - he used to set off in whatever direction he happened to be facing
			# and only come round at the end of the leg, which cost him a metre the wrong
			# way before he had started.
			if _f == _said_frame:
				_start_gap = _gap()
			elif _f > _said_frame + 4000:
				_check("and walks towards it, not off at a tangent", _gap() < _start_gap,
					"closed %.2f m - he turns first, then sets off"
						% (_start_gap - _gap()))
				_stage = 3
		3:
			# THE FENCE. He is kinematic, so he walked straight through the rails - true
			# before any of this and very visible once he has a reason to cross them.
			print("
--- over the fence ---")
			var fence: Node4D = _root.get_node("Pen/Fence") as Node4D
			var centre: Vector4 = fence.global_position
			_antics.set("_going_to_eat", false)
			# Stood inside the pen, on the line between the middle and his dinner.
			var toward := Vector2(_spot.x - centre.x, _spot.z - centre.z).normalized()
			_nike.global_position = Vector4(centre.x + toward.x * 1.5, 0.0,
				centre.z + toward.y * 1.5, 0.0)
			_antics.call("go_and_eat", _spot)
			_check("in the pen when dinner turns up", bool(_antics.get("_going_to_eat")),
				"%.1f m from the middle, inside a %.1f by %.1f fence" % [1.5,
					float(fence.get("extend_x_positive")), float(fence.get("extend_z_positive"))])
			_stage = 4
			# THE DEADLINE IS IN PHYSICS TICKS, NOT FRAMES. He walks on the physics clock and
			# slowly - a couple of metres to the rail is twenty-odd seconds - while this loop
			# counts process frames, which headless run faster than physics by a ratio that
			# depends on how busy the machine is. A deadline of 4000 frames was 25-30 seconds
			# of his time on a quiet machine and less under load, so the test failed about
			# one run in four and more often in a batch: a race, not a pig who would not jump.
			# Sixty seconds of his own time is comfortably more than he needs.
			_jump_by = _ticks + 60 * 60
		4:
			if int(_antics.get("state")) == 5:
				_peaked = maxf(_peaked, _nike.global_position.y)
				_stage = 5
			elif _ticks >= _jump_by:
				_check("he jumps it", false, "he never left the ground in 60 s of his own time")
				return _finish()
		5:
			_peaked = maxf(_peaked, _nike.global_position.y)
			if int(_antics.get("state")) != 5:
				var fence: Node4D = _root.get_node("Pen/Fence") as Node4D
				_check("he jumps it", _peaked > float(fence.get("height")),
					"cleared %.2f m over a %.2f m rail" % [_peaked, float(fence.get("height"))])
				var centre: Vector4 = fence.global_position
				var here := Vector2(_nike.global_position.x - centre.x,
					_nike.global_position.z - centre.z)
				_check("and lands on the far side of it",
					absf(here.x) > float(fence.get("extend_x_positive"))
						or absf(here.y) > float(fence.get("extend_z_positive")),
					"outside the rails, not astride them")
				_check("then goes back to walking",
					is_zero_approx(_nike.global_position.y),
					"feet down, gait picked back up mid-stride")
				return _finish()
	return false


func _gap() -> float:
	var away: Vector4 = _nike.global_position - _spot
	return Vector2(away.x, away.z).length()


func _near_trough() -> bool:
	return _gap() <= float(_antics.get("feed_radius"))


func _finish() -> bool:
	print("\n%d FAIL(s)" % _fails.size())
	quit(1 if _fails.size() > 0 else 0)
	return true
