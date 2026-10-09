extends SceneTree

## THE FITTING ROOM, PLAYED THROUGH (outfit/PLAN_FITTING_ROOM.md step 44): first on its own, every key
## and a few clicks, the piece on the right checked row by row; then from the farm, through the circle's
## Enter and back, the farm checked for everything the trip has to put back; then the circle's switch
## that makes the room the only way. PASS or FAIL per check; frames=1 saves a picture of each beat to
## smoke_test_output/outfit/room/, and hud4k does it at Ramon's 3840 x 2160 and 145%.
##
## Never touches Ramon's saved outfit (a test file of its own), and only its own key presses get in.
##
##   lab_run.sh windowed outfit_room res://ramon/chickenpen/outfit/_verify_room_runner.gd frames=1

const Outfit := preload("res://ramon/chickenpen/outfit/outfit_4d.gd")
const Trip := preload("res://ramon/chickenpen/outfit/outfit_room_trip_4d.gd")
const ROOM := "res://ramon/chickenpen/outfit/fitting_room.tscn"
const OUT := "res://smoke_test_output/outfit/room/"
const TEST_SAVE := "user://outfit_test_room.cfg"
## The Tab panel's saves go here in a test, never to the room's own file.
const TEST_TUNING := "user://outfit_test_room_tuning.cfg"
const TUNING_FILE := "res://ramon/chickenpen/outfit/fitting_room_tuning.cfg"
const OURS := 77

var _fails: Array[String] = []
var _checks: int = 0
var _frames_on: bool = false
var _hud4k: bool = false
var _t0: int = 0
var _his_before: String = ""
var _farm_done: bool = false
var _his_tuning_before: String = ""


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
		if a == "hud4k":
			_hud4k = true
			DisplayServer.window_set_position(Vector2i(0, 0))
			DisplayServer.window_set_size(Vector2i(3840, 2160))
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 240000:
		print("ROOM FAIL: gave up after 240 s")
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_TUNING))
	_his_tuning_before = _file_stamp(TUNING_FILE)
	Outfit.use_save_path(TEST_SAVE)
	root.add_child(Guard.new())
	await _alone()
	if _hud4k:
		_finish()
		return
	await _from_the_farm()
	_check("the farm leg ran to its end", _farm_done)
	_finish()


func _finish() -> void:
	_check("Ramon's own saved outfit was not touched", _file_stamp("user://pen_outfit.cfg") == _his_before)
	_check("nor the room's own light file", _file_stamp(TUNING_FILE) == _his_tuning_before)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_TUNING))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://outfit_test_journal.cfg"))
	print("\nROOM: %s (%d checks, %d failed)%s" % ["PASS" if _fails.is_empty() else "FAIL", _checks, _fails.size(),
		"" if _fails.is_empty() else "  " + ", ".join(_fails)])
	quit(0 if _fails.is_empty() else 1)


# --- On its own -----------------------------------------------------------------------------------

func _alone() -> void:
	print("\n--- the room on its own ---")
	Outfit.reset()
	var room: Node = (load(ROOM) as PackedScene).instantiate()
	room.set("tuning_path", TEST_TUNING)
	root.add_child(room)
	current_scene = room
	await _wait(1.5)
	_check("the lab's pedestals: both, with their holograms", room.get_node_or_null("FigurePedestal/Hologram") != null and
		room.get_node_or_null("GarmentPedestal/Hologram") != null and room.get_node_or_null("FigurePedestal/PedestalDeck") != null)
	var camera: Camera4D = room.get("_camera")
	_check("its camera is the one in use", camera != null and camera.current)
	var figure: Node4D = room.get("_figure")
	var piece: Node4D = room.get("_garment")
	_check("you stand on the left, dressed as today", figure != null and _albedo(figure, "Tunic").is_equal_approx(Outfit.ORIGINAL_SHIRT))
	_check("the piece shows the shirt only", _shown(piece) == ["Tunic", "UpperArmL", "UpperArmR"], str(_shown(piece)))
	await _shot("01_shirt")
	await _press(KEY_1)
	await _wait(0.3)
	_check("1: the hat, the cap only", _shown(piece) == ["Cap"], str(_shown(piece)))
	await _shot("02_hat_cap")
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	await _wait(0.3)
	_check("down three: the top hat", Outfit.hat() == Outfit.HAT_TOP and _shown(piece).has("HatCrown") and not _shown(piece).has("Head"), str(_shown(piece)))
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	await _wait(0.6)
	_check("right twice: the hat's colour, on you and on the piece", Outfit.get_value("hat_colour") == 2 and
		_albedo(figure, "HatCrown").is_equal_approx(Outfit.colour("hat_colour")) and _albedo(piece, "HatCrown").is_equal_approx(Outfit.colour("hat_colour")))
	await _shot("03_top_hat")
	await _press(KEY_DOWN)
	await _wait(0.4)
	_check("down: the chicken", _shown(piece).has("ChickenHead"))
	await _shot("04_chicken")
	await _press(KEY_DOWN)
	await _wait(0.4)
	_check("down: the hypercube", _shown(piece) == ["Hypercube"], str(_shown(piece)))
	await _shot("05_hypercube")
	await _press(KEY_2)
	await _wait(0.3)
	_check("2: the hair", not _shown(piece).is_empty() and _shown(piece).all(func(n: String) -> bool: return n in ["Hair", "Crown", "Tie", "Tail1", "Tail2", "Tail3"]), str(_shown(piece)))
	await _press(KEY_RIGHT)
	await _wait(0.5)
	await _shot("06_hair")
	await _press(KEY_3)
	await _wait(0.3)
	_check("3: the skin, a head with its ears and eyes", _shown(piece).has("Head") and _shown(piece).has("EarA") and _shown(piece).has("EyeL"), str(_shown(piece)))
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	await _wait(0.5)
	await _shot("07_skin")
	await _press(KEY_5)
	await _wait(0.3)
	_check("5: shorts, the waistband only", _shown(piece) == ["Belt"], str(_shown(piece)))
	await _press(KEY_DOWN)
	await _wait(0.3)
	_check("down: long trousers, the legs too", _shown(piece).size() == 5 and _shown(piece).has("ShinR"), str(_shown(piece)))
	# A click on a swatch, as the mouse does.
	var grid: GridContainer = room.get("_swatch_grid")
	var swatches: Array = grid.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	(swatches[7] as Button).pressed.emit()
	await _wait(0.6)
	_check("a click on a swatch: cobalt trousers", Outfit.get_value("trousers") == 7 and _albedo(figure, "ThighL").is_equal_approx(Outfit.colour("trousers")))
	await _shot("08_trousers")
	await _press(KEY_6)
	await _wait(0.3)
	_check("6: the boots", _shown(piece) == ["BootL", "BootR"], str(_shown(piece)))
	await _press(KEY_LEFT)
	await _wait(0.5)
	await _shot("09_shoes")
	await _press(KEY_4)
	var spin: Node4D = room.get("_garment_spin")
	await _press(KEY_T)
	await _wait(1.6)
	_check("T: the piece turns through W", absf(spin.basis.x.w) + absf(spin.basis.w.x) > 0.05, str(spin.basis.x))
	await _shot("10_through_w")
	await _press(KEY_T)
	var before: Dictionary = Outfit.snapshot()
	await _press(KEY_X)
	_check("X: a surprise", Outfit.snapshot() != before)
	await _wait(0.5)
	await _shot("11_surprise")
	await _press(KEY_Z)
	_check("Z: back to what you came in wearing", Outfit.is_default(), str(Outfit.snapshot()))
	var turn_before: Projection = (room.get("_figure_turntable") as Node4D).basis
	var q := InputEventKey.new()
	q.device = OURS
	q.physical_keycode = KEY_E
	q.keycode = KEY_E
	q.pressed = true
	Input.parse_input_event(q)
	await _wait(0.6)
	var q_up := q.duplicate() as InputEventKey
	q_up.pressed = false
	Input.parse_input_event(q_up)
	await _wait(0.1)
	_check("E turns you round", not (room.get("_figure_turntable") as Node4D).basis.z.is_equal_approx(turn_before.z))
	await _shot("12_turned")
	# The lab's own B: its dark look, which the kit pieces follow.
	await _press(KEY_B)
	await _wait(1.2)
	await _shot("12b_dark")
	await _press(KEY_B)
	await _wait(1.0)

	# THE LIGHT'S PANEL (Tab), saving to the test's own file.
	var tuner: Control = room.get("_tuner")
	var panel: Control = room.get("_panel")
	await _press(KEY_TAB)
	await _wait(0.3)
	_check("Tab: the light's panel in the outfit panel's place", tuner.visible and not panel.visible and
		tuner.position.is_equal_approx(panel.position), "%s vs %s" % [tuner.get_rect(), panel.get_rect()])
	var light: Node = room.get_node("FigureLight")
	var sliders: Dictionary = tuner.get("_sliders")
	var cone_before: float = float(light.get("angle"))
	(sliders["cone"] as HSlider).value = cone_before + 12.0
	(sliders["height"] as HSlider).value = 4.2
	(sliders["exposure"] as HSlider).value = 1.3
	await _wait(0.4)
	_check("a slider moves the spot: cone, both lights", absf(float(light.get("angle")) - (cone_before + 12.0)) < 0.2 and
		absf(float(room.get_node("GarmentLight").get("angle")) - (cone_before + 12.0)) < 0.2, "%.2f" % float(light.get("angle")))
	_check("and its height", absf((light as Node4D).position.y - 4.2) < 0.01)
	_check("and the room's exposure", absf(float((room.call("light_for", room.call("current_mood")) as Dictionary)["exposure"]) - 1.3) < 0.01)
	await _shot("12c_light_panel")
	tuner.call("save_default")
	var tuned := ConfigFile.new()
	_check("Save as default: written (the test's file)", tuned.load(TEST_TUNING) == OK and absf(float(tuned.get_value("spot_you", "height", 0.0)) - 4.2) < 0.01 and
		tuned.has_section("light_bright"))
	await _press(KEY_TAB)
	await _wait(0.2)
	_check("Tab again: the outfit panel back", panel.visible and not tuner.visible)

	# THE WHEEL, on the shirt: a colour of your own, on you and the piece, saved with the rest.
	await _press(KEY_4)
	var wheel: ColorPicker = room.get("_wheel")
	var own := Color(0.25, 0.85, 0.55)
	_check("the wheel is beside the swatches", wheel != null and wheel.is_visible_in_tree() and
		wheel.get_global_rect().position.x > (room.get("_swatch_grid") as Control).get_global_rect().end.x - 1.0,
		"%s / %s" % [wheel.get_global_rect(), (room.get("_swatch_grid") as Control).get_global_rect()])
	_check("and takes no keyboard focus", wheel.find_children("*", "Control", true, false).all(func(c: Node) -> bool: return (c as Control).focus_mode == Control.FOCUS_NONE))
	wheel.color_changed.emit(own)
	await _wait(0.6)
	_check("the wheel: the shirt is your own colour", Outfit.is_custom("shirt") and Outfit.colour("shirt").is_equal_approx(own))
	_check("and you wear it, and the piece", _albedo(figure, "Tunic").is_equal_approx(own) and _albedo(piece, "Tunic").is_equal_approx(own))
	await _press(KEY_RIGHT)
	_check("right steps off it onto the first swatch", Outfit.get_value("shirt") == 0)
	wheel.color_changed.emit(own)
	await _press(KEY_LEFT)
	_check("left steps off it onto the last", Outfit.get_value("shirt") == Outfit.options("shirt").size() - 1)
	wheel.color_changed.emit(own)
	await _wait(0.4)
	await _shot("12d_wheel")
	await _press(KEY_ENTER)
	await _wait(0.2)
	var with_own := ConfigFile.new()
	_check("your own colour is saved", with_own.load(TEST_SAVE) == OK and int(with_own.get_value("outfit", "shirt", 0)) == Outfit.CUSTOM and
		(with_own.get_value("outfit", "shirt_custom", Color.BLACK) as Color).is_equal_approx(own))
	Outfit.read_again()
	_check("and read back", Outfit.is_custom("shirt") and Outfit.colour("shirt").is_equal_approx(own))
	Outfit.set_value("shirt", 0)
	# How long a frame takes in here (vsync off for this, so the number means something).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _wait(0.5)
	var times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	times.sort()
	print("PERF room frame median %.2f ms, worst %.2f ms" % [times[times.size() / 2], times[times.size() - 1]])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Outfit.set_value("shirt", 5)
	await _press(KEY_ENTER)
	await _wait(0.3)
	var saved := ConfigFile.new()
	_check("Enter on its own: saved", saved.load(TEST_SAVE) == OK and int(saved.get_value("outfit", "shirt", -1)) == 5)
	_check("and it says so", (room.get("_toast") as Label).visible)
	await _shot("13_saved_alone")
	if _hud4k:
		for label in (room.get("_ui") as Control).find_children("*", "Label", true, false):
			if (label as Label).visible and (label as Label).text != "":
				print("LABEL %-14s at %s size %s  '%s'" % [label.name, str((label as Label).position.round()), str((label as Label).size.round()), (label as Label).text.left(60)])
		print("CANVAS %s, PANEL %s" % [str((room.get("_ui") as Control).get_viewport_rect().size), str((room.get("_panel") as Control).get_rect())])
	root.remove_child(room)
	room.queue_free()
	await _wait(0.3)


# --- From the farm ---------------------------------------------------------------------------------

func _from_the_farm() -> void:
	print("\n--- from the farm, through the circle ---")
	Outfit.reset()
	Outfit.save()
	var pen: Node = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	var lookout: Node = pen.get_node_or_null("Systems/Lookout")
	if lookout != null:
		lookout.set("journal_path", "user://outfit_test_journal.cfg")
	root.add_child(pen)
	current_scene = pen
	await _wait(2.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player := pen.get_node("Player") as CharacterBody4D
	var circle := pen.get_node("World/OutfitCircle") as Node4D
	var camera := player.get_node("CameraRig/Pitch/Camera4D") as Camera4D
	var env_before: Node = Trip._environment_in_use(pen)
	var ui_visible: bool = bool(pen.get_node("UI").get("visible"))
	player.global_position = Vector4(circle.global_position.x + 2.5, player.global_position.y, circle.global_position.z, 0.0)
	await _wait(1.6)
	player.global_position = Vector4(circle.global_position.x, player.global_position.y, circle.global_position.z, 0.0)
	await _wait(0.3)
	await _press(KEY_F)
	var dressing: bool = await _until(func() -> bool: return int(circle.get("state")) == 3, 5.0)
	_check("in the circle, dressing", dressing)
	await _press(KEY_ENTER)
	_check("Enter on a colour strip does not leave", current_scene == pen)
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	_check("down to ADVANCED", int((circle.get_node("Strips")).get("active_row")) == 6)
	await _shot("19_advanced_stop")
	var t_go: int = Time.get_ticks_msec()
	await _press(KEY_ENTER)
	var in_room: bool = await _until(func() -> bool: return current_scene != null and current_scene.name == &"FittingRoom", 5.0)
	var trip_now: Node = root.get_node_or_null(NodePath(String(Trip.NAME)))
	if trip_now != null:
		await _until(func() -> bool: return not bool(trip_now.call("is_busy")), 3.0)
	print("PERF Enter to the room, flash and all: %d ms" % (Time.get_ticks_msec() - t_go))
	await _wait(0.8)
	_check("Enter: the fitting room", in_room)
	_check("the farm is parked, not freed", is_instance_valid(pen) and not pen.is_inside_tree())
	var room: Node = current_scene
	var figure: Node4D = room.get("_figure")
	_check("you are the farm's figure (eyes and all)", figure != null and bool(figure.get("eyes")) and absf(float(figure.get("shorts_length")) - 0.16) < 0.001)
	await _shot("20_from_farm")
	await _press(KEY_4)
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	# A colour of your own from the wheel, to see the farm wear one.
	(room.get("_wheel") as ColorPicker).color_changed.emit(Color(0.9, 0.3, 0.75))
	await _wait(0.2)
	var chosen: Color = Outfit.colour("shirt")
	var t_home: int = Time.get_ticks_msec()
	await _press(KEY_ENTER)
	var home: bool = await _until(func() -> bool: return current_scene == pen and pen.is_inside_tree(), 5.0)
	await _until(func() -> bool: return root.get_node_or_null(NodePath(String(Trip.NAME))) == null, 3.0)
	print("PERF Done to the farm, flash and all: %d ms" % (Time.get_ticks_msec() - t_home))
	await _wait(1.2)
	_check("Done: back on the farm", home)
	var avatar: Node = player.get_node("Avatar")
	_check("wearing what you chose", _albedo(avatar, "Tunic").is_equal_approx(chosen))
	_check("the farm's camera is the one in use", camera.current)
	var env_now: Node = Trip._environment_in_use(pen)
	_check("the farm's sky and light are back", env_now == env_before and env_now != null and bool(env_now.get("current")))
	_check("your walking is back", player.get("input_enabled") == true)
	_check("the HUD is as it was", bool(pen.get_node("UI").get("visible")) == ui_visible)
	_check("the circle says it is saved", String(circle.get("_said")).begins_with("Saved"))
	_check("the trip has gone", root.get_node_or_null(NodePath(String(Trip.NAME))) == null)
	await _shot("21_home")

	print("\n--- again, and Esc ---")
	player.global_position = Vector4(circle.global_position.x + 2.5, player.global_position.y, circle.global_position.z, 0.0)
	await _wait(0.8)
	player.global_position = Vector4(circle.global_position.x, player.global_position.y, circle.global_position.z, 0.0)
	await _wait(0.3)
	await _press(KEY_F)
	await _until(func() -> bool: return int(circle.get("state")) == 3, 5.0)
	await _wait(0.8)
	await _shot("21b_own_colour_strip")
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	await _press(KEY_RIGHT)
	var by_right: bool = await _until(func() -> bool: return current_scene != null and current_scene.name == &"FittingRoom", 5.0)
	_check("right on ADVANCED goes too", by_right)
	await _wait(0.6)
	var kept: Dictionary = Outfit.snapshot()
	await _press(KEY_2)
	await _press(KEY_RIGHT)
	var changed: Dictionary = Outfit.snapshot()
	await _press(KEY_ESCAPE)
	await _until(func() -> bool: return current_scene == pen and pen.is_inside_tree(), 5.0)
	await _wait(1.0)
	# Esc keeps it (Ramon, 8 Oct: "when i pressed esc in advanced, nothing was saved. that was a bummer").
	_check("Esc: home, with what you changed kept", Outfit.snapshot() == changed and changed != kept)
	var after_esc := ConfigFile.new()
	_check("and saved", after_esc.load(TEST_SAVE) == OK and int(after_esc.get_value("outfit", "hair", -9)) == int(changed["hair"]))
	_check("and the circle says so", String(circle.get("_said")).begins_with("Saved"))

	print("\n--- the circle's switch: the room as the only way ---")
	circle.set("opens_room", true)
	player.global_position = Vector4(circle.global_position.x + 2.5, player.global_position.y, circle.global_position.z, 0.0)
	await _wait(0.8)
	player.global_position = Vector4(circle.global_position.x, player.global_position.y, circle.global_position.z, 0.0)
	await _wait(0.3)
	await _press(KEY_F)
	var straight: bool = await _until(func() -> bool: return current_scene != null and current_scene.name == &"FittingRoom", 8.0)
	_check("with opens_room on, the scan ends in the room", straight)
	await _wait(0.6)
	await _press(KEY_ENTER)
	await _until(func() -> bool: return current_scene == pen and pen.is_inside_tree(), 5.0)
	await _wait(0.8)
	circle.set("opens_room", false)
	_check("and home again", current_scene == pen)
	_farm_done = true


# --- Helpers --------------------------------------------------------------------------------------

## The names of the piece's parts that still have their mesh, sorted.
func _shown(piece: Node) -> Array:
	var out: Array = []
	for node in piece.find_children("*", "MeshInstance4D", true, false):
		if (node as MeshInstance4D).mesh != null:
			out.append(String(node.name))
	out.sort()
	return out


func _albedo(figure: Node, part: String) -> Color:
	var node := figure.find_child(part, true, false) as MeshInstance4D
	if node == null or not (node.material_override is TetraMaterial4D):
		return Color(-1, -1, -1)
	return (node.material_override as TetraMaterial4D).albedo_color


func _file_stamp(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "absent"
	return "%d:%s" % [FileAccess.get_modified_time(path), FileAccess.get_md5(path)]
