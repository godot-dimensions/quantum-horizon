extends Control

## The grass panel: a see-through block of buttons on the HUD, one per look in
## pen_grass_looks.gd; click one (Esc first, to have the mouse) or press O for the next. Under
## them, the ground: the pen's own or painted (the glow and the sandy yard; Shift+O). Made by the Grass
## node (pen_grass_4d.gd, show_panel), so no scene has to carry it.
##
## O, NOT G: G is the project's carry_pig action (Nike); it was G for a night by mistake.
##
## ON THE LEFT, JUST ABOVE THE TO-DO LIST: on a 2560 x 1440 screen the right side is full (the
## controls, the Cinematics and Lookout cards, the dial, the camera picker) and the left has an
## empty stretch between the readouts at the top and the list.
##
## IN THE CAMERA PICKER'S HAND: the same dark glass, the same white chips, the one you are in
## filled. A test tool, and labelled as one.

const LOOKS := preload("res://ramon/chickenpen/grass/pen_grass_looks.gd")

## The Grass node it works.
var grass: Node
## Font size for the buttons; the lines over them are drawn smaller.
var text_size: int = 13
var panel_alpha: float = 0.3
var margin: float = 24.0
## What it sits above, left edges lined up (the to-do list); without one, at the left edge,
## at_height of the way down.
var above: Control
var gap: float = 10.0
var at_height: float = 0.5

var _buttons: Array[Button] = []
var _ground_buttons: Array[Button] = []
var _glow_button: Button
var _grass_button: Button
var _dark_label: Label
var _dark_slider: HSlider
var _wind_label: Label
var _wind_slider: HSlider
var _title: Label
var _hint: Label
var _box: VBoxContainer
var _chip: StyleBoxFlat
var _chip_hover: StyleBoxFlat
var _chip_on: StyleBoxFlat
var _panel: StyleBoxFlat


func _ready() -> void:
	name = "GrassPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = _style(Color(0.04, 0.05, 0.08, panel_alpha), Color(1.0, 1.0, 1.0, 0.07), 9)
	_chip = _style(Color(1.0, 1.0, 1.0, 0.08), Color(1.0, 1.0, 1.0, 0.16), 4)
	_chip_hover = _style(Color(1.0, 1.0, 1.0, 0.15), Color(1.0, 1.0, 1.0, 0.3), 4)
	_chip_on = _style(Color(1.0, 1.0, 1.0, 0.26), Color(1.0, 1.0, 1.0, 0.55), 4)
	var back := PanelContainer.new()
	back.add_theme_stylebox_override("panel", _panel)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(pad)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 5)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(_box)
	_title = _label("Grass", Color(1.0, 1.0, 1.0, 0.58))
	# The grass itself, on or off (Alt+O). Not G: G picks Nike up.
	_grass_button = _button("Grass on   Alt+O")
	_grass_button.pressed.connect(_toggle_grass)
	_hint = _label("Look   O      (Esc for the mouse)", Color(1.0, 1.0, 1.0, 0.38))
	var keys: Array = LOOKS.PRESETS.keys()
	keys.sort()
	for n in keys:
		var b := _button("%d   %s" % [n, LOOKS.PRESETS[n].get("name", "")])
		b.set_meta("look", n)
		b.pressed.connect(_pick.bind(n))
		_buttons.append(b)
	_label("Ground   Shift+O", Color(1.0, 1.0, 1.0, 0.58))
	for painted in [false, true]:
		var b := _button("Paint layer" if painted else "Base color")
		b.set_meta("painted", painted)
		b.pressed.connect(_set_ground.bind(painted))
		_ground_buttons.append(b)
	# The centre glow alone, on or off, the sand staying (Ctrl+O).
	_glow_button = _button("Centre falloff   Ctrl+O")
	_glow_button.pressed.connect(_toggle_glow)
	# Darkness, a test for every look (3 Oct: "a darkness toggle slider so i can test and tell
	# you later which number to pick"): the number is what to tell Claude.
	_dark_label = _label("", Color(1.0, 1.0, 1.0, 0.58))
	# (No focus on the sliders, as the buttons: the arrow keys are the player's.)
	# Darkness against the looks' own (0): right is darker, left lighter. (3 Oct: Ramon picked
	# 0.61 on the first slider, which ran from the shade itself, and asked for it to be the
	# default and to read 0.)
	_dark_slider = _slider(-0.3, 0.3, 0.01)
	var shade_now: float = float(grass.call("_shade")) if grass != null else 0.39
	_dark_slider.value = float(grass.get("shade")) - shade_now if grass != null else 0.0
	_dark_slider.value_changed.connect(_on_dark)
	_on_dark(_dark_slider.value)
	# Wind, all of it at once: calm to a gale, 1 the look's own.
	_wind_label = _label("", Color(1.0, 1.0, 1.0, 0.58))
	_wind_slider = _slider(0.0, 3.0, 0.05)
	_wind_slider.value = float(grass.get("wind_scale")) if grass != null else 1.0
	_wind_slider.value_changed.connect(_on_wind)
	_on_wind(_wind_slider.value)
	if grass != null and grass.has_signal("preset_changed"):
		grass.connect("preset_changed", _on_changed)
	if grass != null and grass.has_signal("ground_changed"):
		grass.connect("ground_changed", _on_ground)
	if grass != null and grass.has_signal("glow_changed"):
		grass.connect("glow_changed", _on_glow)
	if grass != null and grass.has_signal("enabled_changed"):
		grass.connect("enabled_changed", _on_enabled)
	_on_enabled(bool(grass.get("enabled")) if grass != null else false)
	_on_glow(bool(grass.get("ground_glow")) if grass != null else false)
	_on_changed(int(grass.get("preset")) if grass != null else 0)
	_on_ground(bool(grass.get("ground_paint")) if grass != null else false)


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(150.0, 0.0)
	# No focus: Space is jump, and a focused button would take it.
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", text_size)
	_box.add_child(b)
	return b


func _label(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", text_size - 2)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(l)
	return l


func _style(fill: Color, border: Color, corner: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(corner)
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 3.0
	s.content_margin_bottom = 3.0
	return s


func _process(_delta: float) -> void:
	var view: Vector2 = get_viewport_rect().size
	var back: Control = get_child(0) as Control
	size = back.get_combined_minimum_size()
	back.size = size
	if above != null and above.is_visible_in_tree():
		var r: Rect2 = above.get_global_rect()
		position = Vector2(r.position.x, r.position.y - size.y - gap)
	else:
		position = Vector2(margin, view.y * at_height - size.y)


func _pick(n: int) -> void:
	if grass != null and grass.has_method("apply_preset"):
		grass.call("apply_preset", n)


func _set_ground(painted: bool) -> void:
	if grass != null:
		grass.set("ground_paint", painted)


func _slider(lo: float, hi: float, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(150.0, 18.0)
	s.focus_mode = Control.FOCUS_NONE
	s.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.add_child(s)
	return s


func _on_wind(scale: float) -> void:
	_wind_label.text = "Wind   x%.2f" % scale
	if grass != null and absf(scale - float(grass.get("wind_scale"))) > 0.001:
		grass.set("wind_scale", scale)


func _on_dark(darkness: float) -> void:
	_dark_label.text = "Darkness   %+.2f" % darkness
	if grass == null:
		return
	var want: float = maxf(float(grass.get("shade")) - darkness, 0.05)
	if absf(want - float(grass.call("_shade"))) > 0.001:
		grass.set("shade_test", -1.0 if absf(darkness) < 0.001 else want)


func _toggle_grass() -> void:
	if grass != null:
		grass.set("enabled", not bool(grass.get("enabled")))


func _on_enabled(on: bool) -> void:
	if _grass_button != null:
		_grass_button.text = "Grass on   Alt+O" if on else "Grass off   Alt+O"
		_paint(_grass_button, on)


func _toggle_glow() -> void:
	if grass != null:
		grass.set("ground_glow", not bool(grass.get("ground_glow")))


func _on_glow(on: bool) -> void:
	if _glow_button != null:
		_paint(_glow_button, on)


func _on_changed(on: int) -> void:
	for b in _buttons:
		_paint(b, int(b.get_meta("look")) == on)


func _on_ground(painted: bool) -> void:
	for b in _ground_buttons:
		_paint(b, bool(b.get_meta("painted")) == painted)


func _paint(b: Button, mine: bool) -> void:
	b.add_theme_stylebox_override("normal", _chip_on if mine else _chip)
	b.add_theme_stylebox_override("hover", _chip_on if mine else _chip_hover)
	b.add_theme_stylebox_override("pressed", _chip_on)
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95 if mine else 0.55))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 0.95))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_O):
		return
	if (event as InputEventKey).alt_pressed:
		_toggle_grass()
		get_viewport().set_input_as_handled()
	elif (event as InputEventKey).ctrl_pressed:
		_toggle_glow()
		get_viewport().set_input_as_handled()
	elif (event as InputEventKey).shift_pressed:
		_set_ground(not bool(grass.get("ground_paint")))
		get_viewport().set_input_as_handled()
	else:
		var keys: Array = LOOKS.PRESETS.keys()
		keys.sort()
		var at: int = keys.find(int(grass.get("preset")))
		_pick(int(keys[(at + 1) % keys.size()]))
		get_viewport().set_input_as_handled()
