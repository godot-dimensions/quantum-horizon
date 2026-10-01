extends SceneTree

## The pen's Cinematics card, by key, as a player would use it: 1 still selects the belt's
## first slot while you are not in the card, K steps in, 2 says the placeholder is not made
## yet, Escape steps out without freeing the cursor, K then 1 plays Flight of the 4D
## Starlings in the pen, Escape skips it, and the pen comes back as it was - player shown,
## teal sky fill on, the farm's buses unmuted, still in the pen.
##
## Windowed, small, unfocused; saves res://smoke_test_output/pencine_<n>_<what>.png:
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/scripts/_verify_cinematics_card_runner.gd

var _room: Node
var _card: Control
var _belt: Node
var _f: int = 0
var _t: float = 0.0
var _step: int = 0
var _failed: int = 0
var _n: int = 0
var _mouse: int = 0
var _belt_before: int = -1


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("   %s %-58s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _save(what: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/pencine_%d_%s.png" % [_n, what])
	_n += 1


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e)


func _playing() -> bool:
	return bool(_room.get_node("Cinematics").call("is_playing"))


func _process(d: float) -> bool:
	_f += 1
	_t += d
	match _step:
		0:
			if _t > 3.0:
				_card = _room.get_node("UI/Cinematics") as Control
				_belt = _room.get_node("UI/Inventory")
				_check("the HUD has a Cinematics card, showing", _card != null and _card.is_visible_in_tree())
				_check("not entered to begin with", not bool(_card.call("is_open")))
				_save("idle")
				var before: int = int(_belt.get("selected"))
				_key(KEY_1)
				_check("1 outside the card still selects the belt's first slot", int(_belt.get("selected")) == (0 if before != 0 else -1),
					"selected %d -> %d" % [before, int(_belt.get("selected"))])
				_check("and plays nothing", not _playing())
				_key(KEY_1)
				_step = 1
				_t = 0.0
		1:
			if _t > 0.3:
				_mouse = Input.mouse_mode
				var belt_before: int = int(_belt.get("selected"))
				_key(KEY_K)
				_check("K steps into the card", bool(_card.call("is_open")))
				_belt_before = belt_before
				_step = 10
				_t = 0.0
		10:
			# A frame's grace before each picture: the texture read is the last frame drawn.
			if _t > 0.2:
				_save("entered")
				_key(KEY_2)
				_check("2, the placeholder, plays nothing", not _playing())
				_check("and says it is not made yet", float(_card.get("_note")) > 0.0)
				_check("and leaves the belt alone", int(_belt.get("selected")) == _belt_before)
				_step = 11
				_t = 0.0
		11:
			if _t > 0.2:
				_save("placeholder")
				_key(KEY_ESCAPE)
				_check("Escape steps out", not bool(_card.call("is_open")))
				_check("without freeing the cursor or anything else Escape does", Input.mouse_mode == _mouse and _room.is_inside_tree(),
					"mouse mode %d -> %d" % [_mouse, Input.mouse_mode])
				_key(KEY_K)
				_key(KEY_1)
				_check("K then 1 plays Flight of the 4D Starlings", _playing())
				_check("the card is left as it plays", not bool(_card.call("is_open")))
				_step = 2
				_t = 0.0
		2:
			if _t > 7.0:
				_check("the player is hidden for it", not (_room.get_node("Player") as Node4D).visible)
				_check("the teal sky fill is off for it", not (_room.get_node("World/SkyFill") as Node4D).visible)
				_save("playing")
				_key(KEY_ESCAPE)
				_step = 3
				_t = 0.0
		3:
			if not _playing() and _t > 0.5:
				_check("Escape skips it", true, "%.1f s" % _t)
				_check("still in the pen", current_scene == _room and _room.is_inside_tree())
				_check("the player back", (_room.get_node("Player") as Node4D).visible)
				_check("the teal sky fill back on", (_room.get_node("World/SkyFill") as Node4D).visible)
				_check("the farm's buses unmuted", not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music"))
					and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambience")))
				_check("the card showing again", _card.is_visible_in_tree())
				_check("the farm's own camera back", (_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).current)
				_step = 4
				_t = 0.0
			elif _t > 8.0:
				_check("Escape skips it", false, "still playing")
				_step = 9
		4:
			if _t > 1.0:
				_save("after")
				_step = 9
		9:
			print("%d FAIL(s)" % _failed)
			quit()
			return true
	return false
