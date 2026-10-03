extends SceneTree

## The grass panel: it is on the HUD, and O switches the look while playing (the bands rebuilt,
## no errors). A frame of the HUD in each look; prints the look and the blades after each switch.
## Saves res://smoke_test_output/grass_panel_<n>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/grass/_panel_grass_runner.gd

var _room: Node
var _grass: Node
var _t: float = 0.0
var _step: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_panel_test.cfg")
	_grass = _room.get_node("World/Grass")
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	if _step == 0:
		if not bool(_grass.get("mask_ready")) or _t < 5.0:
			return false
		var panel: Node = _room.get_node_or_null("UI/GrassPanel")
		print("      panel: ", panel != null, "  look ", _grass.get("preset"), "  blades ", _grass.call("blade_count"))
		root.get_texture().get_image().save_png("res://smoke_test_output/grass_panel_0.png")
		_press_o()
		_step = 1
		_t = 0.0
	elif _step == 1 and _t > 1.5:
		print("      after O: look ", _grass.get("preset"), "  blades ", _grass.call("blade_count"))
		root.get_texture().get_image().save_png("res://smoke_test_output/grass_panel_1.png")
		_press_o()
		_step = 2
		_t = 0.0
	elif _step == 2 and _t > 1.5:
		print("      after O again: look ", _grass.get("preset"), "  blades ", _grass.call("blade_count"))
		print("PANEL DONE")
		if FileAccess.file_exists("user://lookout_journal_panel_test.cfg"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_panel_test.cfg"))
		return true
	return false


func _press_o() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_O
	e.physical_keycode = KEY_O
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventKey.new()
	up.keycode = KEY_O
	up.physical_keycode = KEY_O
	up.pressed = false
	Input.parse_input_event(up)
