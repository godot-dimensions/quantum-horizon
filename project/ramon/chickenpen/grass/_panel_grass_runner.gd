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
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_panel_test.cfg")
	_grass = _room.get_node("World/Grass")
	root.add_child(_room)
	current_scene = _room


func _process(d: float) -> bool:
	_t += d
	if _step == 0:
		if _t > 90.0:
			print("PANEL FAIL: no grass after 90 s")
			return true
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
		# Ctrl+O: the centre glow off, the ground still painted (the sand stays).
		_press_o(true)
		_step = 3
		_t = 0.0
	elif _step == 3 and _t > 1.0:
		var ground := _room.get_node("World/Ground/GroundMesh") as MeshInstance4D
		print("      after Ctrl+O: glow %s, ground painted %s" % [_grass.get("ground_glow"), ground.mesh is ArrayTetraMesh4D])
		root.get_texture().get_image().save_png("res://smoke_test_output/grass_panel_2_glow_off.png")
		_press_o(true)
		_step = 4
		_t = 0.0
	elif _step == 4 and _t > 1.0:
		print("      after Ctrl+O again: glow %s" % _grass.get("ground_glow"))
		_press_o(false, true)
		_step = 5
		_t = 0.0
	elif _step == 5 and _t > 1.0:
		print("      after Alt+O: grass %s" % ("on" if _grass.get("enabled") else "off"))
		root.get_texture().get_image().save_png("res://smoke_test_output/grass_panel_3_grass_off.png")
		_press_o(false, true)
		_step = 6
		_t = 0.0
	elif _step == 6 and _t > 1.0:
		print("      after Alt+O again: grass %s" % ("on" if _grass.get("enabled") else "off"))
		# The Darkness slider: 0.1 darker than the looks' own, kept across a change of look.
		var slider: HSlider = _room.get_node("UI/GrassPanel").get("_dark_slider")
		slider.value = 0.1
		_press_o()
		_step = 7
		_t = 0.0
	elif _step == 7 and _t > 1.5:
		print("      darkness +0.10 -> shade %.2f (the looks' own %.2f), after a change of look %.2f (look %s)" % [_grass.get("shade_test"), _grass.get("shade"), _grass.call("_shade"), _grass.get("preset")])
		root.get_texture().get_image().save_png("res://smoke_test_output/grass_panel_4_dark.png")
		var wind_slider: HSlider = _room.get_node("UI/GrassPanel").get("_wind_slider")
		wind_slider.value = 2.0
		_step = 8
		_t = 0.0
	elif _step == 8 and _t > 2.0:
		var m: ShaderMaterial = (_grass.get("_bands") as Array)[0].material
		print("      wind x2 -> scale %.2f, shader wind %.2f m/s (look's own %.2f), leaves and bits up %d" % [_grass.get("wind_scale"),
			m.get_shader_parameter("wind_speed"), _grass.get("wind_speed"), int(_grass.call("bits_count"))])
		# The Leaves and Flowers buttons, as a click would press them.
		var panel: Node = _room.get_node("UI/GrassPanel")
		(panel.get("_leaves_button") as Button).pressed.emit()
		(panel.get("_flowers_button") as Button).pressed.emit()
		print("      after Leaves and Flowers: leaves %s, flowers %s, shader flower share %.3f (look's own %.3f)" % [_grass.get("bits_enabled"),
			_grass.get("flowers_enabled"), m.get_shader_parameter("flower_share"), _grass.get("flower_share")])
		print("PANEL DONE")
		if FileAccess.file_exists("user://lookout_journal_panel_test.cfg"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_panel_test.cfg"))
		return true
	return false


func _press_o(ctrl: bool = false, alt: bool = false) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_O
	e.physical_keycode = KEY_O
	e.ctrl_pressed = ctrl
	e.alt_pressed = alt
	e.pressed = true
	Input.parse_input_event(e)
	var up := InputEventKey.new()
	up.keycode = KEY_O
	up.physical_keycode = KEY_O
	up.pressed = false
	Input.parse_input_event(up)
