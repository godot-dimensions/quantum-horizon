extends SceneTree

## LEVEL 3 PLAYED BY THE BOT through the real controls, with frames (smoke_test_output/maze_remake_2/l3/):
## the atrium and crystal; ana at the centre stops dead; the turn (the right-mouse drag, through the
## player's own look()) and V; the sealed vault seen ahead along W; the blue box seen ana from the side;
## seal one behind the amber door; seal two through the weave; the unsealing film; turned at the centre,
## walking along W into the Heart; the finale's film and the end card.
##   run.sh windowed l3 res://ramon/MazeRemake2/scripts/_play_l3_runner.gd

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const Bot := preload("res://ramon/MazeRemake2/scripts/mr2_bot.gd")
const OUT := "res://smoke_test_output/maze_remake_2/l3/"

var _t0: int = 0
var _game: Node
var _bot
var _player: CharacterBody4D


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 280000:
		print("L3 FAIL: gave up after 280 s")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("L3 frame ", name)


func _mode() -> String:
	return String(_game.get("mode"))


## The right-mouse drag: the button held, the mouse moved up in steps, through the player's own look().
func _turn_by_drag(target_tilt: float) -> void:
	_player.set("_turn_held", true)
	for i in 400:
		if float(_player.call("tilt")) >= target_tilt:
			break
		_player.call("look", Vector2(0.0, -6.0))
		await physics_frame
	_player.set("_turn_held", false)
	await _bot.frames(4)


func _run() -> void:
	var packed: PackedScene = load(SCENE)
	_game = packed.instantiate()
	_game.set("capture_mouse", false)
	_game.set("popups", false)
	_game.set("start_level", 3)
	root.add_child(_game)
	_bot = Bot.new(self, _game)
	_bot.log_prefix = "L3"
	var light: Node = _game.get("light")
	light.call("set_dark", true, false)
	_game.set("sighted", true)
	_player = _game.get("player")
	var ok: bool = await _bot.until(func() -> bool: return int(_game.get("level_index")) == 2 and _mode() == "play", 25.0)
	_bot.check(ok, "level 3 starts in play")
	_bot.check(bool(_player.get("turn_enabled")), "the turn is enabled in level 3")
	await _bot.frames(30)
	await _shot("01_arrival")
	ok = await _bot.walk_to(0.0, 2.0, 12.0, 0.3)
	_bot.check(ok, "walked to the centre")
	_bot.face_yaw(0.0)
	await _bot.frames(6)
	var w: float = await _bot.shift_to(3.0, 4.0)
	_bot.check(w > 1.6 and w < 1.9, "ana at the centre stops at about 1.75 (W %.2f)" % w)
	await _shot("02_blocked_at_centre")
	# The turn by a drag to 70 per cent, then V.
	await _turn_by_drag(PI * 0.5 * 0.72)
	await _shot("03_turn_70")
	var target: Dictionary = _game.get("target")
	_bot.check(String(target.get("kind", "")) == "turn" and bool(target.get("offered", false)), "V offers to finish the turn")
	await _bot.key(KEY_V)
	await _bot.frames(50)
	_bot.check(absf(float(_player.call("tilt")) - PI * 0.5) < 0.01, "V finished the turn exactly (%.3f)" % float(_player.call("tilt")))
	_bot.check(_player.global_position.w < -0.5, "V on the turn stepped us back along W (%.2f)" % _player.global_position.w)
	await _shot("04_turned_sealed_vault")
	# Walk forward along W: the seal stops you.
	Input.action_press(&"move_forward")
	await _bot.frames(90)
	Input.action_release(&"move_forward")
	await _bot.frames(6)
	_bot.check(_player.global_position.w < 2.0, "the sealed doorway stops you (W %.2f)" % _player.global_position.w)
	await _bot.key(KEY_R)
	await _bot.frames(40)
	_bot.check(float(_player.call("tilt")) < 0.01, "R levelled the view")
	# The box seen ana from the side.
	ok = await _bot.walk_to(8.0, 2.0, 8.0)
	_bot.check(ok, "walked out of the ring")
	w = await _bot.shift_to(3.0)
	_bot.face(0.0, 2.0)
	await _bot.frames(6)
	await _shot("05_box_seen_ana")
	w = await _bot.shift_to(0.0)
	# Seal one: the amber door, kata.
	ok = await _bot.walk_to(-12.4, 2.0, 10.0)
	_bot.face(-15.0, 2.0)
	w = await _bot.shift_to(-1.0)
	target = _game.get("target")
	if bool(target.get("offered", false)):
		await _bot.key(KEY_V)
		await _bot.frames(40)
	await _shot("06_amber_door")
	# Below the atrium's kata Tall One (W -1.9): through the door at W -2.5, where it cannot see you.
	w = await _bot.shift_to(-2.5)
	ok = await _bot.walk_to(-16.6, 2.0, 8.0, 0.35)
	await _bot.frames(20)
	await _shot("07_seal_kata")
	var seals: Dictionary = (_game.get("level") as Node).get("seals")
	_bot.check(bool(seals.get("kata", false)), "lit the kata seal")
	# Back out and through the weave.
	ok = await _bot.walk_to(-12.0, 2.0, 8.0)
	w = await _bot.shift_to(0.0)
	ok = await _bot.walk_to(-2.0, 10.0, 10.0)
	ok = await _bot.walk_to(14.6, 2.0, 14.0)
	_bot.check(ok, "at the weave's mouth")
	_bot.face(30.0, 2.0)
	await _shot("08_weave_home")
	w = await _bot.shift_to(2.4)
	await _shot("09_weave_ana")
	ok = await _bot.walk_to(19.0, 2.0, 6.0, 0.3)
	_bot.check(ok, "through gate one ana")
	w = await _bot.shift_to(0.0)
	await _shot("10_weave_gate2_home")
	ok = await _bot.walk_to(21.6, 2.0, 6.0, 0.25)
	_bot.check(ok, "through gate two at home")
	_bot.face(30.0, 2.0)
	await _shot("10b_weave_tall_one")
	w = await _bot.shift_to(2.4)
	ok = await _bot.walk_to(27.6, 2.0, 6.0, 0.35)
	_bot.check(ok, "through gate three ana")
	await _bot.frames(20)
	_bot.check(bool(seals.get("ana", false)), "lit the ana seal")
	_bot.check(int(_game.get("deaths")) == 0, "no Tall One caught us on the way (deaths %d)" % int(_game.get("deaths")))
	ok = await _bot.until(func() -> bool: return _mode() == "film", 6.0)
	_bot.check(ok, "the unsealing film plays")
	for i in 3:
		await _bot.frames(int(60 * 2.6))
		await _shot("11_unseal_film_%d" % i)
	ok = await _bot.until(func() -> bool: return _mode() == "play", 12.0)
	_bot.check(bool((_game.get("level") as Node).get("unsealed")), "the vault is unsealed")
	# Into the Heart: centre, turn, walk along W.
	_player.call("place", Vector4(0, 0, 2.0, 0.0), 0.0)
	await _bot.frames(10)
	await _turn_by_drag(PI * 0.5 * 0.75)
	await _bot.key(KEY_V)
	await _bot.frames(50)
	await _shot("12_turned_open_vault")
	Input.action_press(&"move_forward")
	ok = await _bot.until(func() -> bool: return _player.global_position.w > 3.0 or _mode() != "play", 10.0)
	Input.action_release(&"move_forward")
	_bot.check(ok, "walked along W through the doorway (W %.2f)" % _player.global_position.w)
	await _shot("13_inside_heart")
	ok = await _bot.until(func() -> bool: return _mode() == "film", 8.0)
	_bot.check(ok, "the finale's film plays")
	for i in 3:
		await _bot.frames(int(60 * 2.4))
		await _shot("14_finale_%d" % i)
	ok = await _bot.until(func() -> bool: return _mode() == "end", 14.0)
	_bot.check(ok, "the end card")
	await _bot.frames(20)
	await _shot("15_end_card")

	# Bright: the atrium, and turned at the centre.
	await _bot.key(KEY_ENTER)
	ok = await _bot.until(func() -> bool: return int(_game.get("level_index")) == 0 and _mode() == "play", 14.0)
	_bot.check(ok, "Enter on the end card plays again from level 1")
	await _bot.key(KEY_3)
	ok = await _bot.until(func() -> bool: return int(_game.get("level_index")) == 2 and _mode() == "play", 14.0)
	light.call("set_dark", false, false)
	_player.call("place", Vector4(0, 0, 12.0, 0.0), 0.0)
	await _bot.frames(10)
	await _shot("16_bright_atrium")
	_player.call("place", Vector4(0, 0, 2.0, 0.0), 0.0)
	await _bot.frames(6)
	await _turn_by_drag(PI * 0.5 * 0.75)
	await _bot.key(KEY_V)
	await _bot.frames(50)
	await _shot("17_bright_turned")
	light.call("set_dark", true, false)
	print("L3 DONE fails=%d" % _bot.fails)
	quit(0 if _bot.fails == 0 else 1)
