extends SceneTree

## Walking into the cave, the way a player does (Ramon, 6 Oct: "when you enter the cave it gets dark
## and you dont get teleported to the cave"). _verify_cave_runner.gd puts the player straight into
## the hill's trigger, so a trigger narrower than the tunnel passed it. Here the player walks in on
## the move-forward key from in front of the mouth, along lanes across the tunnel's width and its W:
## the middle, near each wall, and near each W edge (the edge nearest the farm's slice is how you
## find the way in from the field). Every lane where the screen goes fully black has to end in the
## cave.
##
##   lab_run.sh windowed cave_walk res://ramon/chickenpen/scripts/_verify_cave_walk_in_runner.gd

const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")

## (x, W) across the tunnel, in the hill's frame, from its middle.
const LANES := [Vector2(0.0, 0.0), Vector2(-3.0, 0.0), Vector2(3.0, 0.0), Vector2(0.0, -3.0), Vector2(0.0, 3.0), Vector2(-2.8, -2.8)]

var _room: Node
var _fails: int = 0
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 240000:
		print("CAVE WALK: gave up")
		Input.action_release(&"move_forward")
		return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room
	await _frames(40)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player := _room.get_node("Player") as CharacterBody4D
	var rig := player.get_node("CameraRig") as Node4D
	var hill := _room.get_node("World/Cave/CaveHill") as Node4D
	var fade: Node = _room.get_node("Systems/CaveFade")
	var crossing: Node = _room.get_node("CaveCrossing")
	var old_half: float = CaveHill.ARCH_HALF_WIDTH * 0.7
	var way: Array = CaveHill.new().way_in()
	print("   the way in: half %s (it was %.2f across x and W)" % [way[1], old_half])
	for lane: Vector2 in LANES:
		# In front of the mouth, facing into the hill (north, its -z), walking.
		player.global_position = CaveHill.to_world(hill, CaveHill.MOUTH + Vector4(lane.x, 1.2, 4.0, lane.y))
		player.set("linear_velocity", Vector4.ZERO)
		SliceAngles.tilt(rig, 0.0, 0.0, 0.0)
		await _frames(3)
		Input.action_press(&"move_forward")
		var deepest: float = -99.0
		var darkest: float = 0.0
		var at_deepest := Vector4.ZERO
		var went: bool = false
		var start: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 9000:
			await physics_frame
			if bool(crossing.call("is_away")):
				went = true
				break
			var p: Vector4 = CaveHill.to_local(hill, player.global_position)
			var into: float = CaveHill.MOUTH.z + 0.5 - p.z
			if into > deepest:
				deepest = into
				at_deepest = p - CaveHill.MOUTH
			darkest = maxf(darkest, float(fade.call("_into_the_hill")))
		Input.action_release(&"move_forward")
		var old_box: bool = absf(at_deepest.x) <= old_half and absf(at_deepest.w) <= old_half
		var label: String = "lane x %+.1f W %+.1f (global W %.1f)" % [lane.x, lane.y, hill.global_position.w + lane.y]
		print("   %s: reached %.1f m in at x %+.2f W %+.2f, darkest %.2f, %s; the old box %s" % [label, deepest, at_deepest.x, at_deepest.w,
			darkest, "taken into the cave" if went else "NOT taken", "would have" if old_box else "would NOT have"])
		_check(went or darkest < 0.99, "%s: black means you go (black %.2f, went %s)" % [label, darkest, went])
		if went:
			await _frames(30)
			crossing.call("come_back")
			await _frames(60)
			_check(not bool(crossing.call("is_away")), "%s: and back out again" % label)
	print("CAVE WALK: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0)
