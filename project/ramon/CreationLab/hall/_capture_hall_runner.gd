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
	_check(door != null, "room 1's back door holds the hologram into the hall")
	_check(_g.get_node_or_null("BigRoom") == null, "no room 2 (round 3: one door into the showcase)")
	if door != null:
		_check(absf(door.position.z + float(_g.get("room_back")) + 0.25) < 0.01, "the hologram stands in the wall's thickness")
		_put(0.0, door.position.z + 0.3, 0.0)
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
	# The back door with the showcase's title over it, and the hologram in it.
	_put(1.7, -float(_g.get("room_back")) + 1.6, 0.25, 4.0)
	await _wait(1.0)
	await _shot("room1_showcase_door")
	# Looking back at the entrance, where the corridor's ceiling flickered (item 25).
	_put(0.0, 4.0, PI, 2.0)
	await _wait(1.0)
	await _shot("room1_entrance_wall")
	_check(String(_g.get("hud").get("switch_text")).begins_with("DARK MODE"), "the mode switch says DARK MODE, as the other labs'")


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
	# Nike walks (item 31): how far he goes in twelve seconds.
	var nike: Node4D = null
	for st in built:
		if String(st["data"]["kind"]) == "nike" and not (st["animals"] as Array).is_empty():
			nike = (st["animals"] as Array)[0]
	if nike != null:
		var path: float = 0.0
		var last: Vector4 = nike.global_position
		var t_end: int = Time.get_ticks_msec() + 30000
		while Time.get_ticks_msec() < t_end:
			await process_frame
			path += Vector2(nike.global_position.x - last.x, nike.global_position.z - last.z).length()
			last = nike.global_position
		_check(path > 1.5, "Nike walks (%.1f m in 30 s)" % path)
	# Labels, grass, holograms (items 28, 29, 37).
	var labels: int = 0
	var grass: int = 0
	var holos: int = 0
	for st in built:
		labels += 1 if st.has("label") else 0
		grass += 1 if st.has("grass") else 0
		holos += 1 if (st["node"] as Node).get_node_or_null("Hologram") != null else 0
	_check(labels == 10, "a label at every creature (%d)" % labels)
	_check(grass >= 13, "grass on the natural decks (%d)" % grass)
	_check(holos == 10, "a hologram on every creature pedestal (%d)" % holos)
	# The stations, by area.
	for v in [["centre", 0.0, 3.5, 0.0, -12.0], ["wolf", -5.0, 4.0, 0.75, -12.0], ["azathoth", 5.0, 4.0, -0.75, -12.0],
			["nike_goat", 0.0, 1.0, 0.0, -10.0], ["owl_chipmunk", -1.0, -17.4, PI * 0.5, -14.0], ["crows", 4.0, -17.0, -PI * 0.5, -14.0], ["chickens_heron", 0.0, 11.5, PI, -16.0]]:
		_put(v[1], v[2], v[3], v[4])
		await _wait(1.2)
		await _shot("hall_" + v[0])
	# Through W: a step ana at the chickens, and a turned slice from the entrance.
	_put(-5.0, 13.4, PI, -20.0, 2.4)
	await _wait(1.2)
	await _shot("hall_chickens_ana")
	# The building stays still while the animals turn (item 38): the turn on every pivot, nothing else moved.
	_put(0.0, 3.5, 0.0, -12.0)
	await _wait(0.6)
	var room_before: Array = _poses(["Hall", "Stations", "Paths"])
	_g.set("turn", Vector2(0.9, 0.35))
	await _wait(1.2)
	await _shot("hall_animals_turned")
	var room_after: Array = _poses(["Hall", "Stations", "Paths"])
	var moved: Array = []
	for i in mini(room_before.size(), room_after.size()):
		if room_before[i] != room_after[i]:
			moved.append("%s %s -> %s" % [room_before[i][0], room_before[i][1], room_after[i][1]])
	for m in moved.slice(0, 6):
		print("   moved: ", m)
	_check(room_before.size() == room_after.size() and moved.is_empty(), "walls, pedestals and paths do not move when the animals turn (%d moved)" % moved.size())
	var turned: int = 0
	for n in _g.get_tree().get_nodes_in_group("hall_turn"):
		turned += 1 if (n as Node4D).basis != Projection.IDENTITY else 0
	_check(turned >= 20, "every creature and tree turned (%d pivots)" % turned)
	var rig: Node = _player().get_node_or_null("CameraRig")
	_check(not bool(rig.get("slice_turning")), "the view's own slice does not turn in the hall")
	_g.call("whole_again")
	await _wait(1.2)
	_check(_g.get("turn") == Vector2.ZERO, "R puts them whole again")
	# Tab: the lights, one by one (item 40).
	var ed: Node = _g.get_node_or_null("Dev/LightEditor")
	_check(ed != null, "the hall has the light panel")
	if ed != null:
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.physical_keycode = KEY_TAB
		tab.pressed = true
		ed.call("_input", tab)
		await _wait(0.4)
		_check(bool((ed as Control).visible), "Tab opens it")
		var env: Dictionary = ed.get("env")
		_check(env.has("gain") and env.has("exposure") and env.has("key_elevation"), "it has All spotlights and the room's light")
		var light0: Node = _g.get_node_or_null("CentreSpot")
		var own_before: Variant = (light0.get("energy") as Dictionary).duplicate() if light0 != null else null
		env["gain"] = 2.0
		env["exposure"] = 0.8
		ed.call("_apply_env")
		await _wait(0.4)
		var room5: Node = _g.get_node_or_null("Room")
		var over5: Dictionary = (room5.get("mood_overrides") as Dictionary).get(String(room5.get("mood")), {})
		_check(absf(float(_g.get_script().get_script_constant_map()["Style"].gain.get("spot", 0.0)) - 2.0) < 0.001 and absf(float(over5.get("exposure", 0.0)) - 0.8) < 0.001,
			"All spotlights and Exposure change the room live")
		_check(light0 == null or (light0.get("energy") as Dictionary) == own_before, "each light keeps its own strength")
		ed.call("reset")
		await _wait(0.3)
		await _shot("hall_tab_lights")
		ed.call("_input", tab)
		await _wait(0.3)
		_quiet()
	# Dark mode (item 42): both looks.
	_g.call("toggle_palette")
	await _wait(0.6)
	_check(String(_g.get("hud").get("switch_text")).begins_with("DARK MODE ON"), "dark mode on, and it says so")
	_put(0.0, 15.2, 0.0, -9.0)
	await _wait(0.8)
	await _shot("hall_dark")
	_g.call("toggle_palette")
	await _wait(0.4)
	# Round 4: Azathoth as in the cave, in a turn pivot (items 45, 46).
	var az: Node4D = null
	for st in built:
		if String(st["data"]["kind"]) == "azathoth" and not (st["animals"] as Array).is_empty():
			az = (st["animals"] as Array)[0]
	_check(az != null and az.get_parent().get_script() != null and String(az.get_parent().get_script().resource_path).ends_with("turn_pivot_4d.gd"),
		"Azathoth turns with the others (in a turn pivot)")
	if az != null:
		_check(float(az.get("creature_scale")) >= 2.0 and float(az.get("limb_length")) >= 12.0 and float(az.get("core_height")) >= 6.5,
			"Azathoth at the cave's scale, its long limbs, raised (scale %.1f, limbs %.0f, %.1f m up)" % [float(az.get("creature_scale")), float(az.get("limb_length")), float(az.get("core_height"))])
		_put(0.0, 9.0, -PI * 0.5, 4.0)
		await _wait(1.5)
		await _shot("hall_azathoth_cave")
		_g.set("turn", Vector2(0.8, 0.0))
		await _wait(1.0)
		await _shot("hall_azathoth_turned")
		_g.call("whole_again")
		await _wait(1.0)
	# The labels where Ramon put them (item 47): the heron's west, the chickens' east, Azathoth's west.
	for want in [["Heron", -1.0], ["Chickens", 1.0], ["Azathoth", -1.0]]:
		for st in built:
			if String(st["name"]) == want[0] and st.has("label"):
				var lb: Node4D = st["label"]
				_check(signf(lb.position.x) == float(want[1]), "%s's label on its %s side" % [want[0], "west" if float(want[1]) < 0.0 else "east"])
	# The heron has no croak (item 43); the grass denser and thinner (item 44).
	for st in built:
		if String(st["data"]["kind"]) == "heron" and not (st["animals"] as Array).is_empty():
			_check((st["animals"] as Array)[0].get("croak") == null, "the heron has no croak")
		if String(st["name"]) == "Chickens" and st.has("grass"):
			_check(float(st["grass"].get("spacing_m")) <= 0.04 and float(st["grass"].get("width_scale")) <= 1.0, "the grass denser and thinner")
	# Round 5: Azathoth further back (51); every label outside its pedestal, at the start of the platform (52).
	if az != null:
		_check(az.position.z > 1.0, "Azathoth further back on its deck (%.1f m)" % az.position.z)
	var inside: Array = []
	for st in built:
		if not st.has("label"):
			continue
		var s5: Dictionary = st["data"]
		var lb5: Node4D = st["label"]
		var q5 := Vector2(lb5.position.x, lb5.position.z)
		var sz5: Vector2 = s5["size"]
		var out5: bool = q5.length() > sz5.x if String(s5["shape"]) == "round" else (absf(q5.x) > sz5.x * 0.5 or absf(q5.y) > sz5.y * 0.5)
		if not out5:
			inside.append(String(st["name"]))
	_check(inside.is_empty(), "every label stands at the start of its platform, outside the hologram (inside: %s)" % ", ".join(inside))
	# The close look at every creature, by a click within a metre of its pedestal (items 49, 50).
	var looks: int = 0
	var hidden_you: int = 0
	for st in built:
		var s: Dictionary = st["data"]
		if String(s["kind"]) == "tree":
			continue
		var at: Vector2 = s["at"]
		var dir: Vector2 = (s["front"] as Vector2).normalized()
		var sz: Vector2 = s["size"]
		var edge: float = sz.x if String(s["shape"]) == "round" else absf(dir.x) * sz.x * 0.5 + absf(dir.y) * sz.y * 0.5
		_put(at.x + dir.x * (edge + 0.6), at.y + dir.y * (edge + 0.6), atan2(dir.x, dir.y) + PI, -10.0)
		await _wait(0.4)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		_g.call("_input", click)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		await _wait(0.3)
		if not (_g.get("_look") as Dictionary).is_empty():
			looks += 1
			var av: Node4D = _player().get_node_or_null("Avatar") as Node4D
			if av != null and not av.visible:
				hidden_you += 1
			await _wait(2.6)
			await _shot("hall_look_" + String(st["name"]).to_lower())
			if String(st["name"]) == "Wolf":
				# R in a close look (55): the animals whole again, the close look still on.
				_g.set("turn", Vector2(0.5, 0.0))
				var rk := InputEventKey.new()
				rk.keycode = KEY_R
				rk.physical_keycode = KEY_R
				rk.pressed = true
				_g.call("_unhandled_key_input", rk)
				await _wait(0.6)
				_check(not (_g.get("_look") as Dictionary).is_empty() and (_g.get("turn") as Vector2).length() < 0.2,
					"R in a close look puts them whole again and the close look goes on")
			_g.call("close_look_end")
			await _wait(1.1)
		_quiet()
	_check(looks == 10, "a click by every creature's pedestal starts its close look (%d of 10)" % looks)
	_check(hidden_you == 0, "you stay in the picture in every close look (hidden in %d)" % hidden_you)
	_check((_g.get("_look") as Dictionary).is_empty(), "and each comes back")
	_quiet()
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
	_put(0.0, 21.95, PI, -9.0)
	_check(await _scene(LAB), "the hall's door goes back to the lab")
	_check(await _until(func() -> bool: return not bool(_g.get("loading"))), "the board on the way back finishes")
	await _wait(0.5)
	var p: CharacterBody4D = _player()
	var back: float = -float(_g.get("room_back"))
	_check(p != null and p.global_position.z > back and p.global_position.z < back + 7.0, "you come back in room 1, inside its back door (z %.1f)" % (p.global_position.z if p != null else 0.0))
	await _shot("room1_back_from_hall")


## Every node's place under these, to see they did not move.
func _poses(names: Array) -> Array:
	var out: Array = []
	for nm in names:
		var n: Node = _g.get_node_or_null(nm)
		if n == null:
			continue
		for c in n.find_children("*", "Node4D", true, false):
			# The creatures and their props live on the decks; the building is everything else.
			if "/Deck/" in String(c.get_path()):
				continue
			if c.get_script() == null or not String(c.get_script().resource_path).ends_with("turn_pivot_4d.gd"):
				var inside_pivot: bool = false
				var up: Node = c
				while up != null and up != n:
					# Inside a turn pivot (the exhibits), or a label (it bobs a couple of centimetres, by design).
					if up.get_script() != null and (String(up.get_script().resource_path).ends_with("turn_pivot_4d.gd") 							or String(up.get_script().resource_path).ends_with("hall_float_panel_4d.gd")):
						inside_pivot = true
						break
					up = up.get_parent()
				if not inside_pivot:
					out.append([String(c.get_path()), (c as Node4D).global_position.snapped(Vector4.ONE * 0.001)])
	return out
