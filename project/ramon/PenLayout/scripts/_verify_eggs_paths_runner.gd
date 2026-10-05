extends SceneTree

## Pen layout A (6 Oct 2026, PenLayout/PLAN_A.md steps 32 and 59): the two bags of azoth and the
## paths' three switches.
##   the bags   each stands inside the field (46 m in x, z and W), clear of the hill, and walking
##              up to it at its W puts two azoth on the belt
##   the paths  the network built (routes, sand, marks); F6 hides and shows the marks, F7 the sand,
##              F5 turns reveal on (only what you have been near shows) and off again; each is
##              remembered in user://pen_settings.cfg
##
##   CreationLab/scripts/lab_run.sh windowed pl_eggs res://ramon/PenLayout/scripts/_verify_eggs_paths_runner.gd

var _room: Node
var _player: CharacterBody4D
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _check(ok: bool, what: String, detail: String = "") -> void:
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e)
		await process_frame


## How many of the network's boxes of each kind are showing: [marks, sand].
func _showing(net: Node) -> Array:
	var marks: int = 0
	var sand: int = 0
	for c in net.get_children():
		if c is MeshInstance4D and (c as MeshInstance4D).visible:
			var n: String = String(c.name)
			if n.begins_with("Sand") or n.begins_with("Pad"):
				sand += 1
			else:
				marks += 1
	return [marks, sand]


func _run() -> void:
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	_player = _room.get_node("Player") as CharacterBody4D
	_player.set("input_enabled", false)
	await _frames(40)
	print("THE BAGS")
	var belt: Node = _room.get_node("UI/Inventory")
	for name in ["AzothBag1", "AzothBag2"]:
		var bag := _room.get_node_or_null("World/Pickups/" + name) as Node4D
		_check(bag != null, "%s is in the field" % name)
		if bag == null:
			continue
		var p: Vector4 = bag.global_position
		_check(Vector3(p.x, p.z, p.w).length() < 46.0, "%s is inside the field's 46 m" % name, "%.1f m out" % Vector3(p.x, p.z, p.w).length())
		var before: int = int(belt.call("count_of", "found_azoth"))
		for i in 30:
			_player.global_position = Vector4(p.x, 1.2, p.z + 0.6, p.w)
			_player.linear_velocity = Vector4.ZERO
			await physics_frame
		var after: int = int(belt.call("count_of", "found_azoth"))
		_check(after - before == 2 and not bag.visible, "walking up to %s at W %.1f puts two azoth on the belt" % [name, p.w], "%d -> %d" % [before, after])
	print("THE PATHS")
	var net: Node = _room.get_node("World/Paths")
	var paths: Node = _room.get_node("Systems/Paths")
	var graph: Resource = net.get("graph")
	_check(graph != null and (graph.get("edges") as Array).size() > 30, "the network has its routes", "%d edges" % ((graph.get("edges") as Array).size() if graph != null else 0))
	for n in net.call("notes"):
		print("    note: %s" % n)
	net.set("show_marks", true)
	net.set("show_sand", true)
	net.set("reveal", false)
	await _frames(5)
	var both: Array = _showing(net)
	_check(both[0] > 40 and both[1] > 40, "icons and sand both showing", "marks %d, sand %d" % both)
	await _key(paths.get("key_icons"))
	await _frames(3)
	var no_marks: Array = _showing(net)
	_check(no_marks[0] == 0 and no_marks[1] == both[1], "F6: the icons go, the sand stays", "marks %d, sand %d" % no_marks)
	await _key(paths.get("key_sand"))
	await _frames(3)
	var none: Array = _showing(net)
	_check(none[0] == 0 and none[1] == 0, "F7: the sand goes too", "marks %d, sand %d" % none)
	await _key(paths.get("key_icons"))
	await _key(paths.get("key_sand"))
	await _frames(3)
	var back: Array = _showing(net)
	_check(back == both, "F6 and F7 again: both back", "marks %d, sand %d" % back)
	# Reveal: from a clean slate, nothing found far from everything (the player taken there first,
	# or what was near the last bag is found); standing at the start finds what is near it.
	for i in 10:
		_player.global_position = Vector4(0.0, 1.2, -40.0, -8.0)
		await physics_frame
	net.call("reset_reveal")
	await _key(paths.get("key_reveal"))
	_check(bool(net.get("reveal")), "F5: reveal on")
	for i in 20:
		_player.global_position = Vector4(0.0, 1.2, -40.0, -8.0)
		await physics_frame
	var far_found: int = 0
	for i in (graph.get("edges") as Array).size():
		var f: Vector2 = net.call("found_of", i)
		if f.x <= f.y:
			far_found += 1
	_check(far_found == 0, "far from every route, nothing is found", "%d edges found" % far_found)
	for i in 30:
		_player.global_position = Vector4(4.0, 1.2, 37.0, 0.0)
		await physics_frame
	var found: int = 0
	for i in (graph.get("edges") as Array).size():
		var f: Vector2 = net.call("found_of", i)
		if f.x <= f.y:
			found += 1
	_check(found >= 3 and found < (graph.get("edges") as Array).size(), "at the start, the routes near it are found and the rest are not", "%d of %d" % [found, (graph.get("edges") as Array).size()])
	await _key(paths.get("key_reveal"))
	_check(not bool(net.get("reveal")), "F5 again: every route shown")
	var cfg := ConfigFile.new()
	cfg.load("user://pen_settings.cfg")
	_check(cfg.get_value("paths", "reveal", null) == false and cfg.get_value("paths", "icons", null) == true and cfg.get_value("paths", "sand", null) == true,
		"the switches are remembered", "%s %s %s" % [cfg.get_value("paths", "reveal", "?"), cfg.get_value("paths", "icons", "?"), cfg.get_value("paths", "sand", "?")])
	print("EGGS AND PATHS: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)
