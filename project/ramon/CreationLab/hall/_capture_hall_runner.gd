extends SceneTree

## The Creature Lab v2 and its hall, end to end (PLAN_V2 step 69): room 1 (the route, the floating picker, the
## wolf 2, R), through the hologram door into the hall (the board, every station built, the walkers kept on
## their decks, the copies through W, the info card and its click), and back through the hall's door.
## Photographs to res://smoke_test_output/creation_lab/v2/<nn>_<what>.png; prints PASS / FAIL lines and the
## hall's script time.
##
##   CreationLab/scripts/lab_run.sh windowed hall res://ramon/CreationLab/hall/_capture_hall_runner.gd
##   (add -- quick=1 to skip room 1)

const LAB := "res://ramon/CreationLab/creature_lab.tscn"
const OUT := "res://smoke_test_output/creation_lab/v2/"
## Every wait gives up after this many seconds (follow_up: runners fail fast).
const PATIENCE := 75.0

var _g: Node
var _n: int = 0
var _fails: Array = []
var _quick: bool = false


func _initialize() -> void:
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		if a == "quick=1":
			_quick = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## Waits until `cond` holds, at most `limit` seconds; whether it did.
func _until(cond: Callable, limit: float = PATIENCE) -> bool:
	var until: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return false


func _shot(what: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s%02d_%s.png" % [OUT, _n, what])
	print("shot ", what)
	_n += 1


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _player() -> CharacterBody4D:
	return _g.get("player") if _g != null else null


func _put(x: float, z: float, face: float, pitch_deg: float = -9.0, w: float = 0.0) -> void:
	var p: CharacterBody4D = _player()
	p.global_position = Vector4(x, 0.05, z, w)
	p.linear_velocity = Vector4.ZERO
	p.set("_facing", face + PI)
	var rig: Node = p.get_node_or_null("CameraRig")
	rig.set("yaw", face)
	rig.set("pitch", deg_to_rad(pitch_deg))
	rig.call("_apply")


func _quiet() -> void:
	var p: Node = _player()
	if p != null:
		p.set("input_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var u := InputEventKey.new()
	u.keycode = code
	u.physical_keycode = code
	Input.parse_input_event(u)
	await process_frame


func _scene(path: String) -> bool:
	var ok: bool = await _until(func() -> bool: return current_scene != null and current_scene.scene_file_path == path)
	_g = current_scene
	return ok


func _run() -> void:
	change_scene_to_file(LAB)
	_check(await _scene(LAB), "room 1 loads")
	await _wait(0.8)
	await _shot("room1_loading_board")
	_check(await _until(func() -> bool: return not bool(_g.get("loading"))), "room 1's loading board finishes")
	await _wait(0.5)
	_quiet()
	if not _quick:
		await _room_one()
	# Through the hologram door: walk the player into it.
	var door: Node4D = _g.get_node_or_null("HallDoor") as Node4D
	_check(door != null, "room 2 has the hologram door into the hall")
	if door != null:
		_put(0.0, door.position.z + 0.2, 0.0)
	_check(await _scene("res://ramon/CreationLab/hall/creature_hall.tscn"), "walking into the door goes to the hall")
	await _wait(0.8)
	await _shot("hall_loading_board")
	await _hall()
	print("---- %d fails" % _fails.size())
	for f in _fails:
		print("FAIL: ", f)
	quit(1 if not _fails.is_empty() else 0)


func _room_one() -> void:
	_check(_g.get_node_or_null("Paths/Route") != null, "room 1's route is the PathCreator network")
	var picker: Node = _g.get_node_or_null("ExhibitPicker")
	_check(picker != null and picker.get("player") != null, "the floating picker knows the player (it wobbles)")
	_put(0.0, 12.0, 0.0, -11.0)
	await _wait(1.0)
	await _shot("room1_entrance")
	_put(0.0, 5.0, 0.0, -14.0)
	await _wait(1.0)
	await _shot("room1_picker")
	# The wolf: wolf 2 on the plinth (its first time builds and bakes it).
	_g.call("pick", 2)
	await _wait(6.0)
	var sc: Node = _g.get("showcase")
	var s: Script = sc.get("exhibit_script") if sc != null else null
	_check(s != null and s.resource_path.ends_with("v2/rd_wolf2_4d.gd"), "3 puts the fixed wolf on the plinth")
	_put(2.5, 3.6, 0.6, -10.0)
	await _wait(1.0)
	await _shot("room1_wolf2")
	# R: the exhibit back whole.
	sc.call("step_slice", 2)
	await _wait(0.3)
	_g.call("whole_again")
	await _wait(0.3)
	var mid: int = int(sc.get_script().get_script_constant_map().get("SLICES", 9)) / 2
	_check(int(sc.get("slice_index")) == mid, "R puts the exhibit back on its middle slice")
	_g.call("pick", 0)
	await _wait(1.0)
	# The entry room and its door.
	var big: Node4D = _g.get_node_or_null("BigRoom") as Node4D
	if big != null:
		_put(0.0, big.position.z + 2.0, 0.0, -6.0)
		await _wait(1.0)
		await _shot("room2_hall_door")


func _hall() -> void:
	_check(await _until(func() -> bool: return not bool(_g.get("loading"))), "the loading board finishes")
	_quiet()
	var built: Array = _g.get("stations")
	var all: Array = _g.get_script().get_script_constant_map()["STATIONS"]
	_check(built.size() == all.size(), "every station built (%d of %d)" % [built.size(), all.size()])
	var animals: int = 0
	for st in built:
		animals += (st["animals"] as Array).size()
	print("animals: ", animals)
	_check(animals >= 25, "the hall has its animals, copies through W included (%d)" % animals)
	# Where everyone starts, to see they stay on their decks.
	await _wait(0.5)
	_put(0.0, 15.2, 0.0, -9.0)
	await _wait(1.0)
	await _shot("hall_entrance")
	# The script time, with nothing being photographed (follow_up: never measure in a screenshot's frame).
	var proc: float = 0.0
	var phys: float = 0.0
	for i in 120:
		await process_frame
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	print("hall script time: process %.2f ms, physics %.2f ms (mean of 120 frames)" % [proc / 120.0 * 1000.0, phys / 120.0 * 1000.0])
	# Kept on their decks: every roaming animal, sampled for eight seconds.
	var worst: float = -INF
	var who: String = ""
	var until: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < until:
		for st in built:
			var s: Dictionary = st["data"]
			var node: Node4D = st["node"]
			for roam in node.find_children("Roam", "", true, false):
				var w: Node = roam.get_node_or_null(roam.get("walker_path"))
				var a: Node4D = w.get_parent() as Node4D if w != null else null
				if a == null:
					continue
				var c: Vector2 = roam.get("centre")
				var q := Vector2(a.position.x - c.x, a.position.z - c.y)
				var over: float = q.length() - float(roam.get("radius")) if float(roam.get("radius")) > 0.0 \
					else maxf(absf(q.x) - (roam.get("half") as Vector2).x, absf(q.y) - (roam.get("half") as Vector2).y)
				if over > worst:
					worst = over
					who = String(s["name"])
		await process_frame
	_check(worst < 0.0, "every walker stays inside its deck (closest to the edge: %s, %.2f m inside)" % [who, -worst])
	# The stations, by area.
	for v in [["centre", 0.0, 3.5, 0.0, -12.0], ["wolf", -5.0, 4.0, 0.75, -12.0], ["horse", 5.0, 4.0, -0.75, -12.0],
			["nike_goat", 0.0, 1.0, 0.0, -10.0], ["owl_chipmunk", -1.0, -17.4, PI * 0.5, -14.0], ["crows", 4.0, -17.0, -PI * 0.5, -14.0], ["chickens_heron", 0.0, 11.5, PI, -16.0]]:
		_put(v[1], v[2], v[3], v[4])
		await _wait(1.2)
		await _shot("hall_" + v[0])
	# Through W: a step ana at the chickens, and a turned slice from the entrance.
	_put(-5.0, 13.4, PI, -20.0, 2.4)
	await _wait(1.2)
	await _shot("hall_chickens_ana")
	_put(0.0, 15.2, 0.0, -9.0)
	var rig: Node = _player().get_node_or_null("CameraRig")
	rig.set("_slice_xw", 0.55)
	rig.call("_apply")
	await _wait(1.2)
	await _shot("hall_slice_turned")
	rig.set("_slice_xw", 0.0)
	rig.call("_apply")
	# The info card: comes up near the wolf, a click closes it, it stays closed till you have been away.
	var card: Node = _g.get("card")
	_put(-9.5, 4.4, 0.0, -10.0)
	await _wait(0.8)
	_check(card != null and bool(card.call("showing")), "the wolf's card comes up beside its pedestal")
	await _shot("hall_card_wolf")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_g.call("_input", click)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _wait(0.5)
	_check(card != null and not bool(card.call("showing")), "a left click closes it")
	_put(-9.5, 3.9, 0.0, -10.0)
	await _wait(0.5)
	_check(card != null and not bool(card.call("showing")), "it stays closed while you are still there")
	_put(0.0, 2.4, 0.0, -10.0)
	await _wait(0.5)
	_put(-9.5, 4.4, 0.0, -10.0)
	await _wait(0.6)
	_check(card != null and bool(card.call("showing")), "away and back, it comes up again")
	# Back through the hall's door: arriving in room 2 by the hall's door.
	_put(0.0, 21.6, PI, -9.0)
	_check(await _scene(LAB), "the hall's door goes back to the lab")
	_check(await _until(func() -> bool: return not bool(_g.get("loading"))), "the board on the way back finishes")
	await _wait(0.5)
	var big: Node4D = _g.get_node_or_null("BigRoom") as Node4D
	var p: CharacterBody4D = _player()
	_check(big != null and p != null and p.global_position.z < big.position.z, "you come back in room 2, by the hall's door (z %.1f)" % (p.global_position.z if p != null else 0.0))
	await _shot("room2_back_from_hall")
