extends SceneTree

## The menu's CINEMATICS list, end to end: the heading and the keys on the rows, 2 (a
## placeholder) staying put and saying so, 1 opening the pen and playing Flight of the 4D
## Starlings with the pen borrowed (HUD, player and the teal sky fill off, the farm's buses
## muted), Escape skipping it, and the menu coming back with everything the cinematic
## borrowed given back first.
##
## Windowed, small and unfocused; saves res://smoke_test_output/menucine_<n>_<what>.png:
##
##   godot.windows.editor.double.x86_64.console.exe --path project --windowed
##       --resolution 1280x720 --position 40,40 --script res://ramon/Menu/_verify_menu_cinematic_runner.gd

const MENU := "res://ramon/menu_final.tscn"
const PEN := "res://ramon/chickenpen/playable_world.tscn"

var _f: int = 0
var _t: float = 0.0
var _step: int = 0
var _failed: int = 0
var _n: int = 0


func _initialize() -> void:
	root.unfocusable = true
	change_scene_to_file(MENU)


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("   %s %-60s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _save(what: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/menucine_%d_%s.png" % [_n, what])
	_n += 1


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e)


func _labels_with(node: Node, text: String) -> int:
	var n: int = 0
	for l in node.find_children("*", "Label", true, false):
		if (l as Label).text.contains(text):
			n += 1
	return n


func _scene() -> String:
	return current_scene.scene_file_path if current_scene != null else ""


func _process(d: float) -> bool:
	_f += 1
	_t += d
	match _step:
		0:
			if _t > 2.0 and _scene() == MENU:
				var menu: Node = current_scene
				_check("the menu has a CINEMATICS heading with its keys", _labels_with(menu, "CINEMATICS  ·  PRESS 1 OR 2") == 1)
				var films: Array = menu.call("_cinematic_order")
				_check("two cinematics, in order", films.size() == 2, str(films))
				_check("1 is Flight of the 4D Starlings", films.size() == 2 and String((menu.call("_entry", films[0]) as Resource).get("title")) == "Flight of the 4D Starlings")
				_check("and its row shows the key", _labels_with(menu, "FLIGHT OF THE 4D STARLINGS") >= 1)
				_save("menu")
				_key(KEY_2)
				_step = 1
				_t = 0.0
		1:
			if _t > 0.5:
				var menu: Node = current_scene
				_check("2, the placeholder, leaves you in the menu", _scene() == MENU)
				var path: String = (menu.get("_detail_path") as Label).text
				_check("and says it is not made yet", path.contains("placeholder"), path)
				_key(KEY_1)
				_step = 2
				_t = 0.0
		2:
			if _scene() == PEN and _t > 1.0:
				var pen: Node = current_scene
				var cine: Node = pen.get_node("Cinematics")
				_check("1 opens the pen and plays the cinematic", bool(cine.call("is_playing")))
				_check("the request is used up", not root.has_meta(&"pen_cinematic"))
				_step = 3
				_t = 0.0
			elif _t > 20.0:
				_check("1 opens the pen", false, "still in %s" % _scene())
				_step = 9
		3:
			# Into the first shot, then look at what it has borrowed.
			if _t > 7.0:
				var pen: Node = current_scene
				_check("the player is hidden", not (pen.get_node("Player") as Node4D).visible)
				_check("the teal sky fill is off", not (pen.get_node("World/SkyFill") as Node4D).visible)
				_check("the farm's music bus is muted", AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")))
				_check("the HUD's to-do card is hidden", not (pen.get_node("UI/Quests") as CanvasItem).visible)
				_save("first_shot")
				_key(KEY_ESCAPE)
				_step = 4
				_t = 0.0
		4:
			if _scene() == MENU and _t > 1.0:
				_check("Escape skips it and the menu comes back", true, "%.1f s" % _t)
				_check("the farm's buses are unmuted again", not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music"))
					and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Ambience")))
				_check("time runs at normal speed", is_equal_approx(Engine.time_scale, 1.0))
				_save("back")
				_step = 9
			elif _t > 10.0:
				_check("Escape skips it and the menu comes back", false, "still in %s" % _scene())
				_step = 9
		9:
			print("%d FAIL(s)" % _failed)
			quit()
			return true
	return false
