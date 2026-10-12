extends SceneTree

## THE OUTFIT, PLAYED THROUGH (outfit/PLAN_OUTFIT.md, follow_up/outfit.md): the pen loaded, the
## fitting circle walked up to and stepped into, every key pressed as a player would press it, the
## outfit saved, and then the cinema and the cave opened to see it went along. Prints a PASS or FAIL
## per check; with frames=1 it also saves a picture of every beat to smoke_test_output/outfit/play/.
##
## IT NEVER TOUCHES RAMON'S SAVED OUTFIT: the store is pointed at a test file before anything loads,
## and the check at the end says whether his file was left exactly as it was.
##
## ITS OWN KEYS ONLY. A guard on the root swallows every real key and mouse event (Ramon's typing once
## reached a test window), and lets through only the presses this runner makes, which it marks with a
## device number nobody's keyboard has.
##
##   lab_run.sh windowed outfit_play res://ramon/chickenpen/outfit/_verify_outfit_runner.gd frames=1 [look=art]

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")
const Keeper := preload("res://ramon/chickenpen/outfit/outfit_keeper_4d.gd")
const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const GroundBasis := preload("res://ramon/chickenpen/scripts/ground_basis_4d.gd")
const CIRCLE := "res://ramon/chickenpen/units/outfit/outfit_circle.tscn"
const SITE := Vector4(30.4, 0.0, 43.6, 0.0)
## The circle's front looks east, so the mirror's camera has the house behind you.
const FRONT_YAW := PI / 2.0
const OUT := "res://smoke_test_output/outfit/play/"
const TEST_SAVE := "user://outfit_test.cfg"
const OURS := 77

var _room: Node
var _player: Node4D
var _rig: Node4D
var _circle: Node4D
var _fails: Array[String] = []
var _checks: int = 0
var _frames_on: bool = false
var _t0: int = 0
var _his_before: String = ""
var _hud4k: bool = false


class Guard extends Node:
	func _input(event: InputEvent) -> void:
		if event.device == 77:
			return
		if event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		if a == "frames=1":
			_frames_on = true
		# Ramon's screen (feedback: he plays 3840 x 2160 at 145%, saved in user://pen_settings.cfg, which
		# the pen reads): the HUD judged where he sees it. Stops after the dressing, so the big window is
		# up for as short a time as it can be.
		if a == "hud4k":
			_hud4k = true
			DisplayServer.window_set_position(Vector2i(0, 0))
			DisplayServer.window_set_size(Vector2i(3840, 2160))
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 240000:
		print("OUTFIT FAIL: gave up after 240 s")
		return true
	return false


func _check(what: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("  %s  %s  %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_fails.append(what)


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


## Waits until [param cond] holds or [param limit] seconds pass; says which.
func _until(cond: Callable, limit: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return bool(cond.call())


func _shot(name: String) -> void:
	if not _frames_on:
		return
	await process_frame
	await process_frame
	var path: String = OUT + ("4k_" if _hud4k else "") + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("FRAME %s" % path)


## A key pressed and let go, as from a keyboard, marked as ours so the guard lets it through.
func _press(code: Key) -> void:
	var down := InputEventKey.new()
	down.device = OURS
	down.physical_keycode = code
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_his_before = _file_stamp("user://pen_outfit.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Outfit.use_save_path(TEST_SAVE)
	_check("the store is on the test's own file", Outfit.current_save_path() == TEST_SAVE)

	print("\n--- the store ---")
	_check("a fresh outfit is today's figure", Outfit.is_default())
	Outfit.set_value("shirt", 99)
	_check("a choice past the palette wraps round", Outfit.get_value("shirt") == posmod(99, Outfit.options("shirt").size()))
	var file := ConfigFile.new()
	file.set_value("outfit", "skin", 999)
	file.set_value("outfit", "hair", "purple")
	file.set_value("outfit", "shoes", 3)
	file.save(TEST_SAVE)
	Outfit.read_again()
	_check("a garbled file falls back to the defaults", Outfit.get_value("skin") == 1 and Outfit.get_value("hair") == 0,
		"skin %d hair %d" % [Outfit.get_value("skin"), Outfit.get_value("hair")])
	_check("and keeps what it could read", Outfit.get_value("shoes") == 3)
	Outfit.reset()
	Outfit.save()
	Outfit.read_again()
	_check("saved and read back as the defaults", Outfit.is_default())

	print("\n--- the pen ---")
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout != null:
		lookout.set("journal_path", "user://outfit_test_journal.cfg")
	root.add_child(_room)
	current_scene = _room
	root.add_child(Guard.new())
	await _wait(2.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player = _room.get_node("Player") as Node4D
	_rig = _player.get_node("CameraRig") as Node4D
	_circle = _room.get_node_or_null("World/OutfitCircle") as Node4D
	if _circle == null:
		_circle = (load(CIRCLE) as PackedScene).instantiate() as Node4D
		_room.get_node("World").add_child(_circle)
		_circle.global_position = SITE
		_circle.global_basis = Basis4D.from_zx(FRONT_YAW)
		print("  (circle spawned at %s for the test)" % str(SITE))
	var looks: Vector4 = _circle.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)
	_check("the circle's front looks east, away from the house", looks.is_equal_approx(Vector4(1.0, 0.0, 0.0, 0.0)), str(looks))
	_hud_off()
	var avatar := _player.get_node("Avatar") as Node4D
	await _until(func() -> bool: return root.get_node_or_null(NodePath(String(Keeper.NAME))) != null, 3.0)
	var keeper: Node = root.get_node_or_null(NodePath(String(Keeper.NAME)))
	_check("the keeper is on the root", keeper != null)
	if keeper == null:
		print("OUTFIT: FAIL (no keeper, nothing more to check)")
		quit(1)
		return
	var dressed: bool = await _until(func() -> bool: return keeper.call("wearer_for", avatar) != null, 5.0)
	_check("the pen's player has a wearer", dressed)
	await _wait(0.3)
	_check("dressed as today: tunic", _albedo(avatar, "Tunic").is_equal_approx(Outfit.ORIGINAL_SHIRT), str(_albedo(avatar, "Tunic")))
	_check("dressed as today: face", _albedo(avatar, "Head").is_equal_approx(Outfit.ORIGINAL_SKIN), str(_albedo(avatar, "Head")))
	_check("dressed as today: shorts", _albedo(avatar, "Belt").is_equal_approx(Outfit.ORIGINAL_TROUSERS))
	_check("dressed as today: boots", _albedo(avatar, "BootL").is_equal_approx(Outfit.ORIGINAL_SHOES))
	_check("dressed as today: hair and cap", _albedo(avatar, "Hair").is_equal_approx(Outfit.ORIGINAL_HAIR) and
		_albedo(avatar.get("head"), "Cap").is_equal_approx(Outfit.ORIGINAL_SHIRT))
	var pick_cap: Color = _pickaxe_cap(avatar)
	var npcs_dressed: int = 0
	for w in keeper.get_children():
		var who: Node = w.get("avatar")
		if who != null and who != avatar:
			npcs_dressed += 1
	_check("nobody else is dressed", npcs_dressed == 0, "%d other wearers" % npcs_dressed)

	print("\n--- walking up ---")
	# Along the circle's own front, wherever the circle stands.
	var site: Vector4 = _circle.global_position
	var front: Vector4 = _circle.global_basis * Vector4(0.0, 0.0, 1.0, 0.0)
	front = Vector4(front.x, 0.0, front.z, 0.0).normalized()
	_player.set("input_enabled", false)
	_place_player(site + front * 6.0)
	var look: Vector4 = site - _player.global_position
	SliceAngles.tilt(_rig, 0.0, 0.0, atan2(look.x, look.z) + PI)
	_rig.set("pitch", deg_to_rad(-12.0))
	_rig.call("_apply")
	await _wait(1.5)
	_check("past 3 m, only the capped plate", int(_circle.get("state")) == 0 and not (_circle.get_node("Frame") as Node4D).visible)
	await _shot("01_far")
	# Walk in, a step at a time, as the walk would carry you.
	for i in 30:
		_place_player(site + front * lerpf(6.0, 2.4, float(i) / 29.0))
		await process_frame
		await process_frame
	await _wait(0.45)
	await _shot("02_rising")
	await _wait(1.2)
	_check("within 3 m, the frame folds out", int(_circle.get("state")) == 1)
	_check("and says nothing yet", not (_circle.get("_tag") as Label).visible)
	await _shot("03_ready")
	_player.set("input_enabled", true)
	_place_player(site + front * 1.2)
	await _wait(0.4)
	var tag_text: String = (_circle.get("_tag") as Label).text
	_check("closer still: F  Outfit scanner", (_circle.get("_tag") as Label).visible and tag_text == "F  Outfit scanner", "'%s'" % tag_text)
	_check("and F would start it", bool(_circle.call("usable")))
	await _shot("03b_named")
	# Walking onto it is free now (Ramon, 8 Oct: "to use outfit scanner you press F").
	for i in 20:
		_place_player(site + front * lerpf(1.2, 0.0, float(i) / 19.0))
		await process_frame
	await _wait(0.6)
	_check("walking onto it starts nothing", int(_circle.get("state")) == 1)
	_place_player(site + front * 1.0)
	await _wait(0.2)
	await _press(KEY_F)
	var began: bool = await _until(func() -> bool: return int(_circle.get("state")) == 2, 2.0)
	_check("F starts the scan", began)
	_check("your walking is off", _player.get("input_enabled") == false)
	_check("the camera comes in", bool(_rig.get("_talking")))
	await _wait(0.5)
	await _shot("04_scan_low")
	await _wait(0.5)
	await _shot("05_scan_high")
	var dressing: bool = await _until(func() -> bool: return int(_circle.get("state")) == 3, 4.0)
	_check("the scan ends in the dressing", dressing)
	var strips: Node = _circle.get_node_or_null("Strips")
	var printed: int = 0
	for i in 6:
		if strips != null and float(strips.call("get_print", i)) >= 1.0:
			printed += 1
	_check("all six strips printed", printed == 6, "%d" % printed)
	var readout: Label = _circle.get("_readout")
	_check("the readout gives four sizes", readout != null and readout.text.contains("thick in W"), readout.text if readout != null else "")
	var size: Vector4 = _circle.call("measure_figure")
	_check("and they are the figure's", size.y > 1.3 and size.y < 1.8 and size.w > 0.25 and size.w < 0.6, str(size))
	# The strips stand on your left as you look at yourself: left of you on screen.
	var cam: Camera4D = _player.get_node("CameraRig/Pitch/Camera4D")
	var you_x: float = cam.world_to_viewport(_player.global_position + Vector4(0, 1.0, 0, 0)).x
	var strip_x: float = cam.world_to_viewport((strips as Node4D).global_position + (strips as Node4D).global_basis * Vector4(-1.3, 0.9, 0, 0)).x
	_check("the strips are on the left of you", strip_x < you_x, "%.0f < %.0f" % [strip_x, you_x])
	await _wait(0.6)
	await _shot("06_dressing")
	if _hud4k:
		Outfit.restore({"hat": Outfit.HAT_TOP, "hat_colour": 2, "hair": 3, "skin": 4, "shirt": 7, "legs": 1, "trousers": 1, "shoes": 12})
		strips.set("active_row", 4)
		await _wait(0.8)
		await _shot("07_dressed")
		strips.set("active_row", 6)
		await _wait(0.4)
		await _shot("07b_advanced")
		for label in (_circle.get("_ui") as Control).find_children("*", "Label", true, false):
			if (label as Label).visible:
				print("LABEL %-14s at %s size %s  '%s'" % [label.name, str((label as Label).position.round()), str((label as Label).size.round()), (label as Label).text])
		print("CANVAS %s" % str((_circle.get("_ui") as Control).get_viewport_rect().size))
		await _press(KEY_F)
		await _wait(0.6)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
		print("\nOUTFIT 4K: %s (%d checks, %d failed)" % ["PASS" if _fails.is_empty() else "FAIL", _checks, _fails.size()])
		quit(0)
		return

	print("\n--- the arrow keys ---")
	var stood: Vector4 = _player.global_position
	var tilt_before: float = GroundBasis.tilt(_rig.basis)
	_check("starts on the shirt", int(strips.get("active_row")) == 3)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	_check("right twice: the shirt is the second cloth colour", Outfit.get_value("shirt") == 2)
	await _wait(0.6)
	_check("and the tunic wears it", _albedo(avatar, "Tunic").is_equal_approx(Outfit.colour("shirt")))
	_check("and the sleeves", _albedo(avatar, "UpperArmL").is_equal_approx(Outfit.colour("shirt")))
	await _shot("07_shirt")
	await _press(KEY_DOWN)
	_check("down: the trousers", int(strips.get("active_row")) == 4)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	Outfit.set_value("legs", Outfit.LEGS_LONG)
	await _wait(0.6)
	_check("long trousers (the fitting room's style) wear the colour on the legs", _albedo(avatar, "ThighL").is_equal_approx(Outfit.colour("trousers")) and
		_albedo(avatar, "ShinR").is_equal_approx(Outfit.colour("trousers")))
	await _shot("08_trousers")
	await _press(KEY_DOWN)
	await _press(KEY_LEFT)
	_check("the shoes, one to the left", Outfit.get_value("shoes") == Outfit.options("shoes").size() - 1)
	await _press(KEY_UP)
	await _press(KEY_UP)
	await _press(KEY_UP)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	_check("skin: tone five", Outfit.get_value("skin") == 4)
	await _wait(0.6)
	_check("and the face, ears and hands wear it", _albedo(avatar, "Head").is_equal_approx(Outfit.colour("skin")) and
		_albedo(avatar, "EarA").is_equal_approx(Outfit.colour("skin")) and _albedo(avatar, "HandL").is_equal_approx(Outfit.colour("skin")))
	await _press(KEY_UP)
	await _press(KEY_RIGHT)
	_check("hair: black", Outfit.get_value("hair") == 1)
	await _shot("09_skin_hair")
	await _press(KEY_UP)
	await _press(KEY_UP)
	_check("up at the top stays at the hat", int(strips.get("active_row")) == 0)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	_check("the cap's colour", Outfit.get_value("hat_colour") == 2)
	for i in 6:
		await _press(KEY_DOWN)
	_check("down past the shoes: ADVANCED", int(strips.get("active_row")) == 6)
	await _press(KEY_DOWN)
	_check("and no further", int(strips.get("active_row")) == 6)
	var shirt_now: int = Outfit.get_value("shirt")
	await _press(KEY_LEFT)
	_check("left on ADVANCED changes nothing", Outfit.get_value("shirt") == shirt_now and int(_circle.get("state")) == 3)
	await _wait(0.3)
	await _shot("09b_advanced")
	await _press(KEY_UP)
	_check("up again: the shoes", int(strips.get("active_row")) == 5)
	# The hats are the fitting room's (its own runner presses those keys); here, that each is worn.
	Outfit.set_value("hat", Outfit.HAT_NONE)
	await _wait(0.3)
	_check("no hat: the cap off and the hair on top", avatar.get("wear_cap") == false and _find(avatar, "Crown") != null and _head_has(avatar, "Cap") == false)
	Outfit.set_value("hat", Outfit.HAT_BEANIE)
	await _wait(0.3)
	_check("a beanie on the head", _find(avatar, "Beanie") != null and _find(avatar, "Crown") != null)
	await _shot("10_beanie")
	Outfit.set_value("hat", Outfit.HAT_TOP)
	await _wait(0.3)
	_check("a top hat", _find(avatar, "HatCrown") != null and _find(avatar, "Beanie") == null)
	await _shot("11_top_hat")
	Outfit.set_value("hat", Outfit.HAT_CHICKEN)
	await _wait(0.4)
	_check("the chicken", _find(avatar, "ChickenHead") != null and _find(avatar, "HatCrown") == null)
	await _shot("12_chicken")
	Outfit.set_value("hat", Outfit.HAT_HYPERCUBE)
	await _wait(0.3)
	var cube: Node4D = _find(avatar, "Hypercube") as Node4D
	_check("the hypercube", cube != null)
	var basis_a: Projection = cube.basis if cube != null else Projection()
	await _wait(0.6)
	await _shot("13_hypercube_a")
	_check("and it turns", cube != null and not (cube.basis.x.is_equal_approx(basis_a.x) and cube.basis.w.is_equal_approx(basis_a.w)))
	_check("the pickaxe keeps its own colours", _pickaxe_cap(avatar).is_equal_approx(pick_cap), str(_pickaxe_cap(avatar)))

	print("\n--- nothing else heard the keys ---")
	var moved: float = (_player.global_position - stood).length()
	_check("you stood where you were", moved < 0.05, "%.3f m" % moved)
	_check("the slice did not turn", absf(GroundBasis.tilt(_rig.basis) - tilt_before) < 0.001, "%.4f" % GroundBasis.tilt(_rig.basis))
	var talking: bool = false
	for talker in get_nodes_in_group(&"npc_talk"):
		var talk: Object = talker.get("_talk")
		if talk != null and talk.has_method("is_running") and bool(talk.call("is_running")):
			talking = true
	_check("no conversation started", not talking)

	print("\n--- a rebuild ---")
	# Put a known outfit on for the rest: a top hat, cobalt shirt, long red trousers.
	Outfit.restore({"hat": Outfit.HAT_TOP, "hat_colour": 12, "hair": 3, "skin": 2, "shirt": 7, "legs": 1, "trousers": 1, "shoes": 12})
	await _wait(0.2)
	avatar.call("rebuild")
	await _wait(0.2)
	_check("after the figure rebuilds itself, the outfit is back on", _albedo(avatar, "Tunic").is_equal_approx(Outfit.colour("shirt")) and
		_find(avatar, "HatCrown") != null)
	SliceAngles.tilt(_rig, deg_to_rad(35.0), 0.0)
	await _wait(0.6)
	await _shot("15_turned_slice")
	SliceAngles.tilt(_rig, 0.0, 0.0)
	await _wait(0.3)

	print("\n--- F: done ---")
	var choice: Dictionary = Outfit.snapshot()
	await _press(KEY_F)
	await _wait(0.2)
	await _shot("16_folding")
	var closed: bool = await _until(func() -> bool: return int(_circle.get("state")) == 1, 3.0)
	_check("F folds it away", closed)
	_check("your walking is back", _player.get("input_enabled") == true)
	_check("the camera goes back out", not bool(_rig.get("_talking")))
	var saved := ConfigFile.new()
	_check("the outfit is saved", saved.load(TEST_SAVE) == OK and int(saved.get_value("outfit", "shirt", -1)) == choice["shirt"] and
		int(saved.get_value("outfit", "hat", -1)) == choice["hat"])
	await _wait(1.0)
	await _shot("17_done")
	_check("standing in it after, it does not start again", int(_circle.get("state")) == 1)
	await _wait(2.0)
	await _press(KEY_F)
	var again: bool = await _until(func() -> bool: return int(_circle.get("state")) == 3, 3.0)
	_check("F again: a quicker scan", again)
	await _press(KEY_F)
	await _until(func() -> bool: return int(_circle.get("state")) == 1, 3.0)
	_place_player(site + front * 4.0)
	await _wait(1.6)
	_check("past 3 m again, the frame folds in", int(_circle.get("state")) == 0)

	print("
--- the dev look ---")
	# Blue, the rim still cyan (Ramon, 8 Oct: "in dev mode, the closed panel should have the cyan
	# outline, but everything else blue").
	var look: Node = _room.get_node_or_null("Systems/Look")
	if look != null:
		var was_dev: bool = bool(look.get("dev"))
		look.call("set_dev", true)
		await _wait(0.8)
		var blue: Color = look.get("foundation_colour")
		var plate: Color = _flat_albedo(_circle.get_node("Plate"))
		var rim: Color = _flat_albedo(_circle.get_node("Rim"))
		var post: Color = _flat_albedo(_circle.get_node("Frame/Post0"))
		var crown_edge: Color = _flat_albedo(_circle.get_node("Frame/CrownEdge"))
		_check("dev: the plate and the frame in the Look's blue", plate.is_equal_approx(blue) and post.is_equal_approx(blue) and crown_edge.is_equal_approx(blue),
			"%s %s %s" % [plate, post, crown_edge])
		_check("dev: the rim stays cyan", rim.is_equal_approx(_circle.get("edge_color")), str(rim))
		_place_player(site + front * 6.0)
		await _wait(0.6)
		await _shot("17b_dev_closed")
		look.call("set_dev", false)
		await _wait(0.8)
		_check("art: the plate back to its own colour", _flat_albedo(_circle.get_node("Plate")).is_equal_approx(_circle.get("frame_color")))
		look.call("set_dev", was_dev)
		await _wait(0.4)

	print("\n--- the cinema ---")
	var crossing: Node = _room.get_node_or_null("Crossing")
	if crossing != null:
		crossing.call("go_for_testing")
		var away: bool = await _until(func() -> bool: return bool(crossing.call("is_away")), 10.0)
		await _wait(2.5)
		var theatre: Node = crossing.get("_theatre")
		var their: Node4D = theatre.get_node_or_null("Player/Avatar") as Node4D if theatre != null else null
		_check("the cinema opened", away and their != null)
		if their != null:
			_check("the cinema's player wears it: shirt", _albedo(their, "Tunic").is_equal_approx(Outfit.colour("shirt")))
			_check("the cinema's player wears it: trousers", _albedo(their, "ThighL").is_equal_approx(Outfit.colour("trousers")))
			_check("the cinema's player wears it: the hat", _find(their, "HatCrown") != null and their.get("wear_cap") == false)
			var their_rig: Node4D = theatre.get_node_or_null("Player/CameraRig") as Node4D
			if their_rig != null:
				their_rig.set("pitch", deg_to_rad(-14.0))
				their_rig.call("_apply")
			await _wait(0.5)
			await _shot("18_cinema")
		crossing.call("come_back")
		await _until(func() -> bool: return not bool(crossing.call("is_away")), 10.0)
		await _wait(2.0)
		_check("home again, still dressed", _albedo(avatar, "Tunic").is_equal_approx(Outfit.colour("shirt")) and _find(avatar, "HatCrown") != null)
	else:
		_check("the cinema's crossing is there", false)

	print("\n--- the cave ---")
	var cave: Node = _room.get_node_or_null("CaveCrossing")
	if cave != null:
		cave.call("go_for_testing")
		await _until(func() -> bool: return bool(cave.call("is_away")), 10.0)
		await _wait(3.0)
		_check("in the cave, the same player, still dressed", _albedo(avatar, "Tunic").is_equal_approx(Outfit.colour("shirt")) and
			_find(avatar, "HatCrown") != null)
		_rig.set("pitch", deg_to_rad(-10.0))
		_rig.call("_apply")
		await _wait(0.4)
		await _shot("19_cave")
		cave.call("come_back")
		await _until(func() -> bool: return not bool(cave.call("is_away")), 10.0)
		await _wait(1.0)
	else:
		_check("the cave's crossing is there", false)

	print("\n--- carrying a chicken: the hat keeps low ---")
	var catcher: Node = _player.get_node_or_null("Catcher")
	var bird: Node4D = null
	for c in _room.get_node("Chickens").find_children("*", "Node4D", true, false):
		if c.has_method("on_caught"):
			bird = c
			break
	if catcher != null and bird != null:
		Outfit.set_value("hat", Outfit.HAT_TOP)
		await _wait(0.3)
		var tall: float = ((_find(avatar, "HatCrown") as MeshInstance4D).mesh as BoxTetraMesh4D).size.y
		bird.global_position = _player.global_position + Vector4(0.0, 0.0, -0.8, 0.0)
		await _wait(0.1)
		catcher.call("_catch", bird)
		await _wait(0.4)
		var crown := _find(avatar, "HatCrown") as MeshInstance4D
		var low: float = (crown.mesh as BoxTetraMesh4D).size.y if crown != null else -1.0
		_check("with a chicken overhead the top hat is low", catcher.get("carried") != null and low > 0.0 and low < 0.1,
			"crown %.2f m, was %.2f" % [low, tall])
		Outfit.set_value("hat", Outfit.HAT_CHICKEN)
		await _wait(0.3)
		_check("and the chicken costume is only a comb and a beak", _find(avatar, "ChickenNeck") == null and _find(avatar, "Comb2") != null)
		_player.set("_facing", 0.0)
		SliceAngles.tilt(_rig, 0.0, 0.0, PI)
		_rig.set("pitch", deg_to_rad(-8.0))
		_rig.set("_zoom_target", 2.6)
		_rig.call("_apply")
		await _wait(0.8)
		await _shot("20_carry_low")
		catcher.call("_release", false)
		await _wait(0.5)
		_check("put it down and the costume is back", _find(avatar, "ChickenNeck") != null)
		Outfit.set_value("hat", Outfit.HAT_TOP)
		await _wait(0.3)
		crown = _find(avatar, "HatCrown") as MeshInstance4D
		_check("and the top hat is tall again", crown != null and (crown.mesh as BoxTetraMesh4D).size.y > 0.25)
	else:
		_check("there is a catcher and a chicken to catch", false)

	print("\n--- a laptop trip to the menu and back ---")
	var trip: Node = (load("res://ramon/chickenpen/scripts/pen_laptop_trip_4d.gd") as GDScript).new()
	root.add_child(trip)
	trip.call("go", "res://ramon/menu_final.tscn", _player.get_node("CameraRig/Pitch/Camera4D"))
	var in_menu: bool = await _until(func() -> bool: return current_scene != _room and current_scene != null, 10.0)
	await _wait(2.0)
	_check("the menu opened", in_menu, str(current_scene.name) if current_scene != null else "none")
	_check("the keeper stays on the root through it", root.get_node_or_null(NodePath(String(Keeper.NAME))) != null)
	trip.call("come_back")
	var home: bool = await _until(func() -> bool: return _room.is_inside_tree() and current_scene == _room, 10.0)
	await _wait(1.0)
	_check("back in the pen", home)
	_check("still dressed after the menu", _albedo(avatar, "Tunic").is_equal_approx(Outfit.colour("shirt")) and _find(avatar, "HatCrown") != null)
	Outfit.set_value("shirt", 9)
	await _wait(0.6)
	_check("and a change still reaches the figure", _albedo(avatar, "Tunic").is_equal_approx(Outfit.colour("shirt")))

	print("\n--- next time ---")
	# The shirt changed on the way back from the menu was never saved: what comes back from the file is
	# the outfit F saved, as it would be on the next run.
	Outfit.read_again()
	_check("read back from the file, it is the outfit F saved", Outfit.snapshot() == choice, str(Outfit.snapshot()))
	_check("Ramon's own saved outfit was not touched", _file_stamp("user://pen_outfit.cfg") == _his_before)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://outfit_test_journal.cfg"))
	print("\nOUTFIT: %s (%d checks, %d failed)%s" % ["PASS" if _fails.is_empty() else "FAIL", _checks, _fails.size(),
		"" if _fails.is_empty() else "  " + ", ".join(_fails)])
	quit(0 if _fails.is_empty() else 1)


func _place_player(at: Vector4) -> void:
	_player.global_position = Vector4(at.x, _player.global_position.y, at.z, at.w)
	if _player is CharacterBody4D:
		(_player as CharacterBody4D).linear_velocity = Vector4.ZERO


func _head_has(figure: Node, part: String) -> bool:
	var head: Node = figure.get("head")
	return head != null and head.get_node_or_null(NodePath(part)) != null


func _find(figure: Node, part: String) -> Node:
	return figure.find_child(part, true, false)


func _flat_albedo(node: Node) -> Color:
	var mi := node as MeshInstance4D
	if mi == null or not (mi.material_override is TetraMaterial4D):
		return Color(-1, -1, -1)
	return (mi.material_override as TetraMaterial4D).albedo_color


func _albedo(figure: Node, part: String) -> Color:
	var node := _find(figure, part) as MeshInstance4D
	if node == null or not (node.material_override is TetraMaterial4D):
		return Color(-1, -1, -1)
	return (node.material_override as TetraMaterial4D).albedo_color


## The colour of the end of the pickaxe's haft (its part called Cap), or none if it has no pickaxe.
func _pickaxe_cap(figure: Node) -> Color:
	var pick: Node = figure.find_child("Pickaxe", true, false)
	return _albedo(pick, "Cap") if pick != null else Color(-2, -2, -2)


func _file_stamp(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "absent"
	return "%d:%s" % [FileAccess.get_modified_time(path), FileAccess.get_md5(path)]


## The pen's HUD off for clean frames, all but the circle's own words.
func _hud_off() -> void:
	var ui: Node = _room.get_node_or_null("UI")
	if ui == null:
		return
	for c in ui.get_children():
		if String(c.name) in ["GrassPanel", "PathsPanel"]:
			c.process_mode = Node.PROCESS_MODE_DISABLED
		if c.name == &"OutfitCircleUI":
			continue
		if c is CanvasItem:
			(c as CanvasItem).visible = false
		elif c is CanvasLayer:
			(c as CanvasLayer).visible = false
