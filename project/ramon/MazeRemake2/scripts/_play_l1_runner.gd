extends SceneTree

## LEVEL 1 PLAYED BY THE BOT through the real keys, with frames (smoke_test_output/maze_remake_2/l1/):
## the arrival, the walk to the door, E held until it is part open, V, through, the garden hall, the
## glint at W 3, the second door, the lift; and the amber niche. At the three gizmo moments every design
## is photographed (the trial of PLAN.md section 9). Round 2: in the dark look; the Long Hall, the first
## sighting's film, past the Tall One by shifting out of its slice, the third door, the lift.
##   run.sh windowed l1 res://ramon/MazeRemake2/scripts/_play_l1_runner.gd

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const Bot := preload("res://ramon/MazeRemake2/scripts/mr2_bot.gd")
const OUT := "res://smoke_test_output/maze_remake_2/l1/"

var _t0: int = 0
var _game: Node
var _bot


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 170000:
		print("L1 FAIL: gave up after 170 s")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("L1 frame ", name)


func _gizmo_shots(name: String) -> void:
	var hud: Node = _game.get("hud")
	var keep: int = int(hud.get("gizmo_index"))
	for i in 4:
		hud.call("set_gizmo", i)
		await _shot("%s_%s" % [name, ["a_map", "b_ruler", "c_dial", "d_lens"][i]])
	hud.call("set_gizmo", keep)


func _run() -> void:
	var packed: PackedScene = load(SCENE)
	_game = packed.instantiate()
	_game.set("capture_mouse", false)
	_game.set("popups", false)
	root.add_child(_game)
	_bot = Bot.new(self, _game)
	_bot.log_prefix = "L1"
	var light: Node = _game.get("light")
	light.call("set_dark", true, false)
	var ok: bool = await _bot.until(func() -> bool: return String(_game.get("mode")) == "play", 20.0)
	_bot.check(ok, "the game starts in play")
	var player: CharacterBody4D = _game.get("player")
	await _bot.frames(30)
	await _gizmo_shots("01_arrival")
	# Walk to the corridor's middle.
	ok = await _bot.walk_to(0.0, -5.0, 8.0)
	_bot.check(ok, "walked down the corridor")
	_bot.face(0.0, -9.0)
	await _bot.frames(6)
	await _shot("02_door_closed")
	# E until the door is about two-thirds open.
	var w: float = await _bot.shift_to(1.05)
	print("L1 W after E: ", w)
	await _gizmo_shots("03_part_open")
	var target: Dictionary = _game.get("target")
	_bot.check(String(target.get("kind", "")) == "door", "the door is the target (%s)" % String(target.get("name", "-")))
	_bot.check(bool(target.get("offered", false)), "V is offered at %.0f%% open" % (float(target.get("open", 0.0)) * 100.0))
	await _bot.key(KEY_V)
	await _bot.frames(40)
	_bot.check(absf(player.global_position.w - 1.7) < 0.01, "V aligned to the door's W (%.3f)" % player.global_position.w)
	await _gizmo_shots("04_aligned")
	ok = await _bot.walk_to(0.0, -11.5, 6.0)
	_bot.check(ok, "walked through the first door into the garden hall")
	_bot.face(-2.5, -16.0)
	await _bot.frames(6)
	await _shot("05_garden")
	# The glint at W 3, near the east wall.
	ok = await _bot.walk_to(2.6, -15.0, 6.0)
	_bot.face(4.0, -15.0)
	w = await _bot.shift_to(2.6)
	await _shot("06_glint_appearing")
	w = await _bot.shift_to(3.0)
	ok = await _bot.walk_to(3.9, -15.0, 5.0, 0.4)
	await _bot.frames(10)
	_bot.check(int(_game.get("_relics_found")) >= 1, "took the glint")
	# The second door.
	ok = await _bot.walk_to(0.0, -19.5, 6.0)
	_bot.face(0.0, -22.0)
	w = await _bot.shift_to(3.4)
	await _shot("07_second_door")
	# Into the Long Hall: the first Tall One, and its film.
	ok = await _bot.walk_to(0.0, -24.6, 6.0)
	_bot.face(0.0, -34.0)
	ok = await _bot.until(func() -> bool: return String(_game.get("mode")) == "film", 4.0)
	_bot.check(ok, "the first sighting plays its film")
	for i in 3:
		await _bot.frames(int(60 * 1.6))
		await _shot("07b_sighting_film_%d" % i)
	ok = await _bot.until(func() -> bool: return String(_game.get("mode")) == "play", 12.0)
	_bot.check(ok and bool(_game.get("sighted")), "the film ends, back in play")
	await _gizmo_shots("07c_long_hall")
	# Out of its slice (and to the third door's W), then past it.
	w = await _bot.shift_to(4.2)
	_bot.check(w > 4.0, "shifted out of the Tall One's slice (W %.2f)" % w)
	await _shot("07d_long_hall_far_ana")
	ok = await _bot.walk_to(0.0, -36.4, 10.0)
	_bot.check(ok and int(_game.get("deaths")) == 0, "walked past the Tall One unharmed")
	_bot.face(0.0, -40.0)
	target = _game.get("target")
	if bool(target.get("offered", false)):
		await _bot.key(KEY_V)
		await _bot.frames(40)
	await _shot("07e_third_door")
	ok = await _bot.walk_to(0.0, -40.3, 6.0)
	_bot.check(ok or int(_game.get("level_index")) == 1 or String(_game.get("mode")) != "play", "walked into the lift")
	ok = await _bot.until(func() -> bool: return int(_game.get("level_index")) == 1 and String(_game.get("mode")) == "play", 12.0)
	_bot.check(ok, "the lift took us to level 2")

	# The niche: back to level 1, kata through the amber door.
	await _bot.key(KEY_1)
	ok = await _bot.until(func() -> bool: return int(_game.get("level_index")) == 0 and String(_game.get("mode")) == "play", 12.0)
	await _bot.frames(10)
	ok = await _bot.walk_to(-2.2, 3.5, 6.0)
	_bot.face(-4.0, 3.5)
	w = await _bot.shift_to(-1.0)
	await _shot("08_amber_part_open")
	target = _game.get("target")
	if bool(target.get("offered", false)):
		await _bot.key(KEY_V)
		await _bot.frames(40)
	_bot.check(player.global_position.w < -1.3, "kata enough for the niche (W %.2f)" % player.global_position.w)
	ok = await _bot.walk_to(-4.1, 3.5, 6.0, 0.4)
	ok = await _bot.walk_to(-4.3, 2.55, 6.0, 0.4)
	_bot.face(-6.0, 3.5)
	await _bot.frames(6)
	await _shot("09_niche")
	_bot.check(int(_game.get("_relics_found")) >= 1, "took the amber glint")

	# BRIGHT, in the corridor and the garden hall.
	light.call("set_dark", false, false)
	player.call("place", Vector4(0, 0, -3, 0.9), 0.0)
	await _bot.frames(6)
	await _shot("10_bright_corridor")
	player.call("place", Vector4(0, 0, -10.6, 1.7), 0.0)
	await _bot.frames(6)
	await _shot("11_bright_garden")
	light.call("set_dark", true, false)
	print("L1 DONE fails=%d" % _bot.fails)
	quit(0 if _bot.fails == 0 else 1)
