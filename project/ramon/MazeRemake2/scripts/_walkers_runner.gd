extends SceneTree

## THE TALL ONES, played by the bot (smoke_test_output/maze_remake_2/walkers/): level 1's first sighting
## and its film; walking up to one until it notices (red eyes); shifting out of its slice until it gives
## up; standing in its slice until it catches you (the red flash, back to the room's way in, the Tall
## Ones back at their posts); level 2's ambush with the Lens film skipped (Esc), the slab down, home
## to lose them; and level 3's weave, where one stands at home past the second gate.
##   run.sh windowed walkers res://ramon/MazeRemake2/scripts/_walkers_runner.gd

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const Bot := preload("res://ramon/MazeRemake2/scripts/mr2_bot.gd")
const OUT := "res://smoke_test_output/maze_remake_2/walkers/"

var _t0: int = 0
var _game: Node
var _bot


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 200000:
		print("WALK FAIL: gave up after 200 s")
		quit(1)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return false


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("WALK frame ", name)


func _mode() -> String:
	return String(_game.get("mode"))


func _level(n: int) -> bool:
	return int(_game.get("level_index")) == n and _mode() == "play"


func _run() -> void:
	_game = (load(SCENE) as PackedScene).instantiate()
	_game.set("capture_mouse", false)
	root.add_child(_game)
	_bot = Bot.new(self, _game)
	_bot.log_prefix = "WALK"
	(_game.get("light") as Node).call("set_dark", true, false)
	var player: CharacterBody4D = _game.get("player")
	var ok: bool = await _bot.until(func() -> bool: return _level(0), 20.0)
	_bot.check(ok, "level 1 starts")
	await _bot.frames(10)

	# THE FIRST SIGHTING: in the Long Hall at the Tall One's W, looking down the hall.
	var walker: Node = ((_game.get("level") as Node).get("walkers") as Array)[0]
	player.call("place", Vector4(0, 0, -23.2, 3.5), 0.0)
	_bot.face(-1.6, -34.0)
	ok = await _bot.until(func() -> bool: return _mode() == "film", 3.0)
	_bot.check(ok, "seeing a Tall One for the first time plays the film")
	for i in 3:
		await _bot.frames(int(60 * 1.7))
		await _shot("01_sighting_%d" % i)
	ok = await _bot.until(func() -> bool: return _mode() == "play", 12.0)
	_bot.check(ok and bool(_game.get("sighted")), "the film ends, once")
	_bot.check(String(walker.get("state")) == "idle", "after its film it is calm again (%s)" % String(walker.get("state")))

	# NOTICED: walk up the hall at its W.
	ok = await _bot.walk_to(0.0, -28.6, 6.0)
	ok = await _bot.until(func() -> bool: return String(walker.get("state")) in ["notice", "hunt"], 6.0)
	_bot.check(ok, "walking up to it, it notices (%s)" % String(walker.get("state")))
	_bot.face(-1.6, -34.0)
	await _bot.frames(70)
	_bot.check(float(walker.get("red")) > 0.6, "its eyes have gone red (%.2f)" % float(walker.get("red")))
	await _shot("02_red_eyes")
	# LOST: shift out of its slice; it gives up after a few seconds.
	var w: float = await _bot.shift_to(4.3)
	_bot.check(w > 4.2, "shifted out of its slice (W %.2f)" % w)
	await _shot("03_out_of_its_slice")
	ok = await _bot.until(func() -> bool: return String(walker.get("state")) in ["return", "idle"], 6.0)
	_bot.check(ok and int(_game.get("deaths")) == 0, "out of its slice it gives up (%s)" % String(walker.get("state")))
	# CAUGHT: back into its slice and stand still.
	w = await _bot.shift_to(3.4)
	_bot.face(-1.6, -34.0)
	ok = await _bot.until(func() -> bool: return int(_game.get("deaths")) == 1, 25.0)
	_bot.check(ok, "standing in its slice, it walks up and catches you")
	await _bot.frames(12)
	await _shot("04_caught_flash")
	ok = await _bot.until(func() -> bool: return _mode() == "play", 6.0)
	_bot.check(ok and absf(player.global_position.z + 23.2) < 0.5, "back at the Long Hall's way in (z %.2f)" % player.global_position.z)
	var post: Vector4 = walker.get("post")
	var q: Vector4 = (walker as Node4D).global_position
	_bot.check(String(walker.get("state")) == "idle" and Vector2(q.x - post.x, q.z - post.z).length() < 0.4, "the Tall One is back at its post")
	await _bot.frames(30)
	await _shot("05_after_death")

	# LEVEL 2'S AMBUSH, the Lens film skipped.
	await _bot.key(KEY_2)
	ok = await _bot.until(func() -> bool: return _level(1), 14.0)
	_game.set("sighted", true)
	var lvl: Node = _game.get("level")
	player.call("place", Vector4(6.4, 0, -8.0, 2.4), -PI * 0.5)
	await _bot.frames(10)
	Input.action_press(&"move_forward")
	ok = await _bot.until(func() -> bool: return _mode() == "film", 5.0)
	Input.action_release(&"move_forward")
	_bot.check(ok, "the Lens film starts")
	await _bot.frames(60)
	await _bot.key(KEY_ESCAPE)
	ok = await _bot.until(func() -> bool: return _mode() == "play", 4.0)
	_bot.check(ok and bool(_game.get("has_lens")), "Esc skips the film; the Lens is ours")
	var kennel: Array = lvl.get("_kennel_walkers")
	var hunting: int = 0
	for k in kennel:
		if String(k.get("state")) in ["notice", "hunt"]:
			hunting += 1
	_bot.check(hunting == 5, "all five come out (%d hunting)" % hunting)
	_bot.face(12.0, -11.0)
	await _bot.frames(100)
	_bot.check(((lvl.get("_kennel_door") as Array)[0] as Node4D).position.y < -1.0, "a skipped film still sinks the slab")
	await _shot("06_ambush")
	ok = await _bot.until(func() -> bool:
		for k in kennel:
			if (k as Node4D).global_position.x < 11.5:
				return true
		return false, 8.0)
	_bot.check(ok, "they walk out of the kennel into the bay")
	await _shot("06b_out_of_the_kennel")
	w = await _bot.shift_to(0.0)
	ok = await _bot.until(func() -> bool:
		for k in kennel:
			if String(k.get("state")) in ["notice", "hunt"]:
				return false
		return true, 8.0)
	_bot.check(ok and int(_game.get("deaths")) == 1, "at home they lose you (deaths still %d)" % int(_game.get("deaths")))
	await _shot("07_home_safe")

	# LEVEL 3'S WEAVE: past the second gate at home, one stands there.
	await _bot.key(KEY_3)
	ok = await _bot.until(func() -> bool: return _level(2), 14.0)
	_game.set("sighted", true)
	var weave: Node = ((_game.get("level") as Node).get("walkers") as Array)[1]
	player.call("place", Vector4(21.6, 0, 2.0, 0.0), -PI * 0.5)
	await _bot.frames(6)
	await _shot("08_weave_tall_one")
	ok = await _bot.until(func() -> bool: return String(weave.get("state")) in ["notice", "hunt"], 8.0)
	_bot.check(ok, "the weave's Tall One notices you")
	w = await _bot.shift_to(2.4)
	await _bot.frames(60)
	await _shot("09_weave_ana")
	ok = await _bot.until(func() -> bool: return String(weave.get("state")) in ["return", "idle"], 6.0)
	_bot.check(ok and int(_game.get("deaths")) == 1, "shifting ana loses it (deaths %d)" % int(_game.get("deaths")))
	print("WALK DONE fails=%d" % _bot.fails)
	quit(0 if _bot.fails == 0 else 1)
