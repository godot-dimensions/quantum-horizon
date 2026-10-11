extends SceneTree

## Every key and option, run alone (F6-style, no menu): Tab opens the panel (game keys dead while open,
## a slider changes the game live, SAVE writes, RESET puts it back; your own saved file is set aside first
## and restored), Esc closes the panel first and otherwise asks before leaving (N stays), B, F1, G, R on a
## level view (back to the room's W) and on a turned one (level), Backspace, the wheel's nudge, the level
## keys. Frames of the panel and the Esc box in smoke_test_output/maze_remake_2/features/.
##   run.sh windowed features res://ramon/MazeRemake2/scripts/_features_runner.gd

const SCENE := "res://ramon/MazeRemake2/maze_remake_2.tscn"
const Bot := preload("res://ramon/MazeRemake2/scripts/mr2_bot.gd")
const OUT := "res://smoke_test_output/maze_remake_2/features/"
const SAVE := "user://maze_remake_2_tuning.cfg"
const ASIDE := "user://maze_remake_2_tuning.features_aside.cfg"
const VIEW := "user://maze_remake_2.cfg"
const VIEW_ASIDE := "user://maze_remake_2.features_aside.cfg"

var _t0: int = 0
var _game: Node
var _bot
var _had: Dictionary = {}


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_aside()
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 160000:
		print("FEAT FAIL: gave up after 160 s")
		_restore()
		quit(1)
		return true
	return false


func _aside() -> void:
	var dir := DirAccess.open("user://")
	for pair in [[SAVE, ASIDE], [VIEW, VIEW_ASIDE]]:
		_had[pair[0]] = dir.file_exists(String(pair[0]).get_file())
		if _had[pair[0]]:
			dir.rename(String(pair[0]).get_file(), String(pair[1]).get_file())


func _restore() -> void:
	var dir := DirAccess.open("user://")
	for pair in [[SAVE, ASIDE], [VIEW, VIEW_ASIDE]]:
		if dir.file_exists(String(pair[0]).get_file()):
			dir.remove(String(pair[0]).get_file())
		if bool(_had.get(pair[0], false)) and dir.file_exists(String(pair[1]).get_file()):
			dir.rename(String(pair[1]).get_file(), String(pair[0]).get_file())
	print("FEAT your settings files are back as they were")


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("FEAT frame ", name)


func _wheel(up: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await process_frame


func _run() -> void:
	_game = (load(SCENE) as PackedScene).instantiate()
	_game.set("capture_mouse", false)
	root.add_child(_game)
	# As F6 or the menu would have it: the Annex is the current scene (the menu's box asks only away from the menu).
	current_scene = _game
	_bot = Bot.new(self, _game)
	_bot.log_prefix = "FEAT"
	var player: CharacterBody4D = _game.get("player")
	# Level 1 opens with its controls card (the popup explainer); Space carries on.
	var ok: bool = await _bot.until(func() -> bool: return String(_game.get("mode")) == "popup", 20.0)
	var popup: Node = (_game.get("hud") as Node).get("popup")
	_bot.check(ok and bool(popup.call("is_open")), "level 1 opens with its controls card")
	await _bot.frames(30)
	await _shot("00_controls_card")
	Input.action_press(&"move_ana")
	await _bot.frames(20)
	Input.action_release(&"move_ana")
	_bot.check(absf(player.global_position.w) < 0.01, "you are held still while the card shows")
	await _bot.key(KEY_SPACE)
	ok = await _bot.until(func() -> bool: return String(_game.get("mode")) == "play", 3.0)
	_bot.check(ok and not bool(popup.call("is_open")), "Space closes the card")
	var music: AudioStreamPlayer = (_game.get("sound") as Node).get("_music")
	_bot.check(music != null and music.playing and (music.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"the cave's track plays under it all, looped")
	await _bot.frames(20)
	# Tab: the panel.
	await _bot.key(KEY_TAB)
	var tuning: Node = _game.get("tuning")
	_bot.check(bool(tuning.call("is_open")), "Tab opens the panel")
	var w0: float = player.global_position.w
	Input.action_press(&"move_ana")
	await _bot.frames(30)
	Input.action_release(&"move_ana")
	_bot.check(absf(player.global_position.w - w0) < 0.01, "no W while the panel is open")
	var sliders: Dictionary = tuning.get("_sliders")
	(sliders["wspeed"] as HSlider).value = 2.4
	_bot.check(absf(float(player.get("w_speed")) - 2.4) < 0.001, "a slider changes the game live")
	await _shot("01_tab_panel")
	tuning.call("save")
	_bot.check(FileAccess.file_exists(SAVE), "SAVE writes the tuning file")
	tuning.call("reset")
	_bot.check(absf(float(player.get("w_speed")) - 1.6) < 0.001, "RESET puts the default back")
	# Esc closes the panel first.
	await _bot.key(KEY_ESCAPE)
	await _bot.frames(4)
	_bot.check(not bool(tuning.call("is_open")), "Esc closes the panel first")
	# Esc again, nothing open: it only frees the cursor (12 Oct: the labs' rule); it never asks or leaves.
	await _bot.key(KEY_ESCAPE)
	await _bot.frames(6)
	var guard: Node = root.get_node_or_null(^"AnnexEscape")
	var way_home: Node = root.get_node_or_null(^"WayHome")
	_bot.check(guard != null and not bool(guard.call("is_open")) and way_home != null and not bool(way_home.call("is_asking")) and String(_game.get("mode")) == "play",
		"Esc with nothing open asks nothing and stays")
	# M: the menu's shared box, the same one every lab uses.
	await _bot.key(KEY_M)
	await _bot.frames(6)
	_bot.check(way_home != null and bool(way_home.call("is_asking")), "M asks the menu's shared question")
	await _shot("02_menu_box")
	await _bot.key(KEY_ESCAPE)
	await _bot.frames(6)
	_bot.check(way_home != null and not bool(way_home.call("is_asking")) and is_instance_valid(_game) and String(_game.get("mode")) == "play", "Esc answers no and the Annex goes on")
	# B, F1, G.
	var dark0: bool = bool((_game.get("light") as Node).get("dark"))
	await _bot.key(KEY_B)
	_bot.check(bool((_game.get("light") as Node).get("dark")) != dark0, "B switches dark and bright")
	await _shot("03_after_b")
	await _bot.key(KEY_B)
	await _bot.key(KEY_F1)
	_bot.check(not bool((_game.get("hud") as Node).get("hud_visible")), "F1 hides the HUD")
	await _bot.key(KEY_F1)
	var g0: int = int((_game.get("hud") as Node).get("gizmo_index"))
	await _bot.key(KEY_G)
	_bot.check(int((_game.get("hud") as Node).get("gizmo_index")) == (g0 + 1) % 4, "G cycles the gizmo")
	await _bot.key(KEY_G)
	await _bot.key(KEY_G)
	await _bot.key(KEY_G)
	_bot.check(int((_game.get("hud") as Node).get("gizmo_index")) == g0, "four Gs come back round to the first")
	# The wheel nudges W.
	w0 = player.global_position.w
	for i in 2:
		await _wheel(true)
	await _bot.frames(60)
	_bot.check(player.global_position.w > w0 + 0.5, "two wheel notches nudge you ana (%.2f to %.2f)" % [w0, player.global_position.w])
	# R on a level view: back to this room's W.
	await _bot.key(KEY_R)
	await _bot.frames(50)
	_bot.check(absf(player.global_position.w - 0.0) < 0.02, "R takes you back to the room's own W (%.2f)" % player.global_position.w)
	# Backspace: back to the room's way in.
	player.call("place", Vector4(0, 0, -4, 0), 0.0)
	await _bot.frames(5)
	await _bot.key(KEY_BACKSPACE)
	ok = await _bot.until(func() -> bool: return String(_game.get("mode")) == "play" and player.global_position.z > 5.0, 5.0)
	_bot.check(ok, "Backspace puts you at the room's way in")
	# Level keys, and R on a turned view in level 3.
	await _bot.key(KEY_3)
	ok = await _bot.until(func() -> bool: return int(_game.get("level_index")) == 2 and String(_game.get("mode")) == "popup", 14.0)
	_bot.check(ok, "3 loads level 3, with its controls card")
	await _bot.frames(30)
	await _shot("00b_controls_card_level3")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	ok = await _bot.until(func() -> bool: return String(_game.get("mode")) == "play", 3.0)
	_bot.check(ok, "a click closes the card too")
	player.set("_turn_held", true)
	for i in 30:
		player.call("look", Vector2(0, -6))
	player.set("_turn_held", false)
	await _bot.frames(4)
	_bot.check(float(player.call("tilt")) > 0.3, "a right-drag turns the view (tilt %.2f)" % float(player.call("tilt")))
	await _bot.key(KEY_R)
	await _bot.frames(50)
	_bot.check(float(player.call("tilt")) < 0.01, "R levels a turned view")
	await _bot.key(KEY_1)
	ok = await _bot.until(func() -> bool: return int(_game.get("level_index")) == 0 and String(_game.get("mode")) == "play", 14.0)
	_bot.check(ok, "1 loads level 1")
	_restore()
	print("FEAT DONE fails=%d" % _bot.fails)
	quit(0 if _bot.fails == 0 else 1)
