extends SceneTree

## LEVEL 2 PLAYED BY THE BOT through the real keys, with frames (smoke_test_output/maze_remake_2/l2/):
## the start bay, the hub at home and kata, the pit's amber bridge to the landing, the shift on the
## landing, the teal bridge, the Lens and its film, the lift; then the side rooms (the computer room
## kata, the archive at home, the gallery ana), a fall from a bridge, and dark frames.
##   run.sh windowed l2 res://ramon/MazeRemake2/scripts/_play_l2_runner.gd

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const Bot := preload("res://ramon/MazeRemake2/scripts/mr2_bot.gd")
const OUT := "res://smoke_test_output/maze_remake_2/l2/"

var _t0: int = 0
var _game: Node
var _bot


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 240000:
		print("L2 FAIL: gave up after 240 s")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("L2 frame ", name)


func _gizmo_shots(name: String) -> void:
	var hud: Node = _game.get("hud")
	var keep: int = int(hud.get("gizmo_index"))
	for i in 3:
		hud.call("set_gizmo", i)
		await _shot("%s_%s" % [name, ["a_ruler", "b_dial", "c_lens"][i]])
	hud.call("set_gizmo", keep)


func _level(n: int) -> bool:
	return int(_game.get("level_index")) == n and String(_game.get("mode")) == "play"


func _run() -> void:
	var packed: PackedScene = load(SCENE)
	_game = packed.instantiate()
	_game.set("capture_mouse", false)
	_game.set("start_level", 2)
	root.add_child(_game)
	_bot = Bot.new(self, _game)
	_bot.log_prefix = "L2"
	var light: Node = _game.get("light")
	light.call("set_dark", false, false)
	var player: CharacterBody4D = _game.get("player")
	var ok: bool = await _bot.until(func() -> bool: return _level(1), 20.0)
	_bot.check(ok, "level 2 starts in play")
	await _bot.frames(20)
	ok = await _bot.walk_to(0.0, 8.0, 8.0)
	_bot.face(0.0, 0.0)
	await _shot("01_start_bay")
	ok = await _bot.walk_to(0.0, 1.8, 8.0)
	_bot.check(ok, "walked into the hub")
	_bot.face(0.0, -6.0)
	await _bot.frames(6)
	await _gizmo_shots("02_hub_home_north")
	var w: float = await _bot.shift_to(-2.4)
	_bot.check(w < -2.0, "shifted kata in the hub (W %.2f)" % w)
	await _shot("03_hub_kata_north")
	_bot.face(-6.0, 0.0)
	await _bot.frames(4)
	await _shot("04_hub_kata_west")
	ok = await _bot.walk_to(0.0, -4.5, 8.0)
	_bot.check(ok, "through the north doorway kata onto the ledge")
	_bot.face(0.0, -9.0)
	await _bot.frames(6)
	await _gizmo_shots("05_pit_kata")
	ok = await _bot.walk_to(0.0, -8.4, 6.0, 0.3)
	_bot.check(ok and player.global_position.y > -0.5, "crossed the amber bridge to the landing")
	_bot.face(4.0, -8.0)
	await _bot.frames(4)
	await _shot("06_landing_kata")
	w = await _bot.shift_to(2.4, 8.0)
	_bot.check(w > 2.0 and player.global_position.y > -0.5, "shifted ana on the landing and stayed on it (W %.2f)" % w)
	await _gizmo_shots("07_landing_ana")
	ok = await _bot.walk_to(3.6, -8.0, 6.0, 0.3)
	_bot.check(ok and player.global_position.y > -0.5, "crossed the teal bridge")
	ok = await _bot.walk_to(6.2, -8.0, 6.0)
	_bot.check(ok, "through the passage into the north-east bay")
	_bot.face(8.0, -8.0)
	await _shot("08_lens_bay")
	Input.action_press(&"move_forward")
	ok = await _bot.until(func() -> bool: return String(_game.get("mode")) == "film", 6.0)
	Input.action_release(&"move_forward")
	_bot.check(ok, "the Lens starts its film")
	for i in 5:
		await _bot.frames(int(60 * 2.0))
		await _shot("09_film_%d" % i)
		if String(_game.get("mode")) != "film":
			break
	ok = await _bot.until(func() -> bool: return String(_game.get("mode")) == "play", 15.0)
	_bot.check(ok and bool(_game.get("has_lens")), "the film ends and the turn is ours")
	await _bot.frames(30)
	await _shot("10_after_lens_card")
	ok = await _bot.walk_to(8.0, -14.2, 8.0)
	ok = await _bot.until(func() -> bool: return _level(2), 14.0)
	_bot.check(ok, "the lift took us to level 3")

	# Side rooms, from a fresh level 2.
	await _bot.key(KEY_2)
	ok = await _bot.until(func() -> bool: return _level(1), 14.0)
	player.call("place", Vector4(0, 0, 1.0, 0.0), PI * 0.5)
	await _bot.frames(10)
	w = await _bot.shift_to(-2.4)
	ok = await _bot.walk_to(-7.0, 0.0, 8.0)
	_bot.check(ok, "into the west bay kata: the computer room")
	_bot.face(-11.0, 0.0)
	await _bot.frames(6)
	await _shot("11_computer_room")
	ok = await _bot.walk_to(-8.2, 1.5, 5.0, 0.4)
	await _bot.frames(10)
	_bot.check(int(_game.get("_relics_found")) >= 1, "took the log's key")
	w = await _bot.shift_to(0.0)
	_bot.face(-11.0, 1.0)
	await _bot.frames(6)
	await _shot("12_archive_home")
	player.call("place", Vector4(0, 0, 0.5, 2.4), -PI * 0.5)
	await _bot.frames(10)
	await _shot("13_hub_ana_east")
	ok = await _bot.walk_to(8.0, 0.0, 8.0)
	_bot.check(ok, "into the gallery ana")
	ok = await _bot.walk_to(8.0, 7.6, 8.0, 0.4)
	await _bot.frames(10)
	_bot.check(int(_game.get("_relics_found")) >= 2, "took the gallery glint")

	# A fall: on the amber bridge, shift home; the bridge goes, down you go, back on the ledge.
	player.call("place", Vector4(0, 0, -6.2, -2.4), 0.0)
	await _bot.frames(10)
	w = await _bot.shift_to(0.0, 4.0)
	ok = await _bot.until(func() -> bool: return player.global_position.z > -5.0 and player.global_position.y > -0.2 and String(_game.get("mode")) == "play", 10.0)
	_bot.check(ok, "fell off the vanishing bridge and came back on the ledge")
	await _shot("14_after_fall")

	# Dark in the hub and over the pit.
	light.call("set_dark", true, false)
	player.call("place", Vector4(0, 0, 2.5, 0.0), 0.0)
	await _bot.frames(8)
	await _shot("15_dark_hub")
	player.call("place", Vector4(0, 0, -4.5, -2.4), 0.0)
	await _bot.frames(8)
	await _shot("16_dark_pit")
	light.call("set_dark", false, false)
	print("L2 DONE fails=%d" % _bot.fails)
	quit(0 if _bot.fails == 0 else 1)
