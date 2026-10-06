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
const SPOT := preload("res://ramon/chickenpen/scripts/pen_hud_spot_4d.gd")
const MainGreen := preload("res://ramon/chickenpen/terrain/main_green_4d.gd")
const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")

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
var _even_button: Button
var _green_box: VBoxContainer
var _look_box: VBoxContainer
var _look_label: Label
var _look_buttons: Array[Button] = []
var _look_node: Node
var _swatch: ColorPickerButton
var _rebake_button: Button
var _green_note: Label
var _picked: Color = Color(0, 0, 0, 0)
var _pick_due: bool = false
var _last_pick: int = 0
var _baking: bool = false
var _grass_button: Button
var _leaves_button: Button
var _flowers_button: Button
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
	# The leaves and fluff in the air, and the flowers, each on or off.
	_leaves_button = _button("Leaves on")
	_leaves_button.pressed.connect(func() -> void: grass.set("bits_enabled", not bool(grass.get("bits_enabled"))))
	_flowers_button = _button("Flowers on")
	_flowers_button.pressed.connect(func() -> void: grass.set("flowers_enabled", not bool(grass.get("flowers_enabled"))))
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
	_main_green_rows()
	_look_rows()
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
	if grass != null and grass.has_signal("bits_changed"):
		grass.connect("bits_changed", _on_switch.bind(_leaves_button, "Leaves"))
		_on_switch(bool(grass.get("bits_enabled")), _leaves_button, "Leaves")
	if grass != null and grass.has_signal("flowers_changed"):
		grass.connect("flowers_changed", _on_switch.bind(_flowers_button, "Flowers"))
		_on_switch(bool(grass.get("flowers_enabled")), _flowers_button, "Flowers")
	_on_enabled(bool(grass.get("enabled")) if grass != null else false)
	_on_glow(bool(grass.get("ground_glow")) if grass != null else false)
	_on_changed(int(grass.get("preset")) if grass != null else 0)
	_on_ground(bool(grass.get("ground_paint")) if grass != null else false)


## THE LOOK (6 Oct, the dev look: look/pen_look_4d.gd): Dev or Art, at the top of the panel, shown
## with the grass off too. The key is the Look node's own (F8).
func _look_rows() -> void:
	_look_box = VBoxContainer.new()
	_look_box.add_theme_constant_override("separation", 5)
	_look_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look_box.set_meta(&"always", true)
	_box.add_child(_look_box)
	_box.move_child(_look_box, 0)
	_look_label = _label("Look", Color(1.0, 1.0, 1.0, 0.58), _look_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look_box.add_child(row)
	for dev in [true, false]:
		var b := _button("Dev" if dev else "Art", row)
		b.custom_minimum_size = Vector2(72.0, 0.0)
		b.set_meta("dev", dev)
		b.pressed.connect(_pick_look.bind(dev))
		_look_buttons.append(b)


func _pick_look(dev: bool) -> void:
	if _look_node != null and is_instance_valid(_look_node):
		_look_node.call("set_dev", dev)


## The Look comes up after this panel; found, and followed, when it is there.
func _find_look() -> void:
	if _look_node != null and is_instance_valid(_look_node):
		return
	var look: Node = Look.current
	if look == null or not is_instance_valid(look):
		_look_box.visible = false
		return
	_look_node = look
	_look_box.visible = true
	_look_label.text = "Look   " + OS.get_keycode_string(look.get("key"))
	look.connect("look_changed", _on_look)
	_on_look(bool(look.get("dev")))


func _on_look(dev: bool) -> void:
	for b in _look_buttons:
		_paint(b, bool(b.get_meta("dev")) == dev)


## MAIN GREEN (6 Oct, Ramon: "make a color picker in the UI, so i can change all green together, and
## with a rebake button under it"): the swatch opens a picker, and the field and the Watchstone's turf
## follow as you drag; Rebake greens bakes the rest in it and saves it (terrain/main_green_4d.gd).
## Under them the switch back to the greens from before (Ctrl+Shift+O) and the first main green.
## Shown with the grass off too, unlike the rows above.
func _main_green_rows() -> void:
	_green_box = VBoxContainer.new()
	_green_box.add_theme_constant_override("separation", 5)
	_green_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_green_box.set_meta(&"always", true)
	_box.add_child(_green_box)
	_label("Main green", Color(1.0, 1.0, 1.0, 0.58), _green_box)
	_swatch = ColorPickerButton.new()
	_swatch.edit_alpha = false
	_swatch.color = MainGreen.shown()
	_swatch.custom_minimum_size = Vector2(150.0, 24.0)
	_swatch.focus_mode = Control.FOCUS_NONE
	_swatch.mouse_filter = Control.MOUSE_FILTER_STOP
	_swatch.add_theme_stylebox_override("normal", _chip)
	_swatch.add_theme_stylebox_override("hover", _chip_hover)
	_swatch.add_theme_stylebox_override("pressed", _chip_on)
	_swatch.color_changed.connect(_on_swatch)
	_swatch.popup_closed.connect(_on_swatch_closed)
	_green_box.add_child(_swatch)
	_rebake_button = _button("Rebake greens", _green_box)
	_rebake_button.pressed.connect(_rebake)
	# One green over the whole field, or the falloff to a darker edge (6 Oct; Ctrl+Shift+O).
	_even_button = _button("Even green   Ctrl+Shift+O", _green_box)
	_even_button.pressed.connect(_toggle_even)
	var first := _button("First main green", _green_box)
	first.pressed.connect(_first_green)
	_green_note = _label("", Color(1.0, 1.0, 1.0, 0.45), _green_box)
	_note_green()


func _on_swatch(c: Color) -> void:
	_picked = c
	_pick_due = true


## Closed: the last colour onto the field now, not after the wait.
func _on_swatch_closed() -> void:
	_last_pick = 0


func _first_green() -> void:
	_swatch.color = MainGreen.default_colour()
	_on_swatch(_swatch.color)
	_last_pick = 0


## The picker's colour onto the field, at most every 0.12 s while it is dragged (a repaint is ~30 ms).
func _pick_now() -> void:
	if not _pick_due or Time.get_ticks_msec() - _last_pick < 120 or grass == null:
		return
	_pick_due = false
	_last_pick = Time.get_ticks_msec()
	grass.call("pick_main_green", _picked)
	_note_green()


func _rebake() -> void:
	if grass == null or _baking:
		return
	_baking = true
	if _pick_due:
		_last_pick = 0
		_pick_now()
	_green_note.text = "Baking, about 15 s ..."
	await get_tree().process_frame
	await get_tree().process_frame
	var started: int = Time.get_ticks_msec()
	grass.call("rebake_greens")
	_baking = false
	_note_green()
	_green_note.text = "Baked and saved, %.0f s" % ((Time.get_ticks_msec() - started) / 1000.0)


func _note_green() -> void:
	if _green_note == null:
		return
	var picked: bool = MainGreen.preview.a > 0.0
	_green_note.text = "Picked: Rebake greens to keep it" if picked else "Saved  #%s" % MainGreen.colour().to_html(false)
	if _rebake_button != null:
		_paint(_rebake_button, picked)


func _button(text: String, parent: Control = null) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(150.0, 0.0)
	# No focus: Space is jump, and a focused button would take it.
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", text_size)
	(parent if parent != null else _box).add_child(b)
	return b


func _label(text: String, colour: Color, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", text_size - 2)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _box).add_child(l)
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
	# Only on the farm (3 Oct: "the grass and its menu should only correspond to the pen scene"):
	# away in the cave the farm is asleep and the grass hidden, and so is this. (The theatre's
	# crossing hides the HUD itself, and puts it back.)
	var on_farm: bool = grass != null and is_instance_valid(grass) and grass.is_visible_in_tree()
	if visible != on_farm:
		visible = on_farm
	if not on_farm:
		return
	_pick_now()
	if _look_box != null:
		_find_look()
	var view: Vector2 = get_viewport_rect().size
	var back: Control = get_child(0) as Control
	size = back.get_combined_minimum_size()
	back.size = size
	# FIRST FREE SPOT (pen_hud_spot_4d.gd, 3 Oct): above the to-do list, left edges level, as it
	# was; grown tall, that ran up into the murmuration card - then beside the list, bottoms
	# level, or beside the murmuration card, tops level. The camera picker and the Lookout card
	# keep to the right and are not counted.
	var places: Array = []
	if above != null and above.is_visible_in_tree():
		var r: Rect2 = SPOT.rect_of(above)
		places.append(Vector2(r.position.x, r.position.y - size.y - gap))
		places.append(Vector2(r.end.x + gap, r.end.y - size.y))
	var stats := get_parent().get_node_or_null(^"FlockStats") as Control
	var column_right: float = margin
	if above != null and above.is_visible_in_tree():
		column_right = maxf(column_right, SPOT.rect_of(above).end.x)
	if stats != null and stats.is_visible_in_tree():
		var s: Rect2 = SPOT.rect_of(stats)
		places.append(Vector2(s.end.x + gap, s.position.y))
		column_right = maxf(column_right, s.end.x)
	# Right of the whole left column, just under the info card at the top (1920 x 1080: the
	# column is full from the top of the screen to the belt).
	var info := get_parent().get_node_or_null(^"InfoCard") as Control
	var under_info: float = SPOT.rect_of(info).end.y + gap if info != null and info.is_visible_in_tree() else margin
	places.append(Vector2(column_right + gap, under_info))
	places.append(Vector2(margin, view.y * at_height - size.y))
	var ignore: Array = []
	for other in [^"CameraPicker", ^"Journal"]:
		var n: Node = get_parent().get_node_or_null(other)
		if n != null:
			ignore.append(n)
	position = SPOT.first(places, size, SPOT.taken(get_parent(), self, ignore), view)


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


func _on_switch(on: bool, button: Button, what: String) -> void:
	button.text = "%s %s" % [what, "on" if on else "off"]
	_paint(button, on)


func _toggle_grass() -> void:
	if grass != null:
		grass.set("enabled", not bool(grass.get("enabled")))


func _on_enabled(on: bool) -> void:
	if _grass_button != null:
		_grass_button.text = "Grass on   Alt+O" if on else "Grass off   Alt+O"
		_paint(_grass_button, on)
	# Off (the pen's default since 6 Oct, "so we can design clearly"): the panel folds down to
	# the one switch, and opens again with the grass.
	if _box != null:
		for row in _box.get_children():
			if row != _title and row != _grass_button and not row.has_meta(&"always") and row is CanvasItem:
				(row as CanvasItem).visible = on


func _toggle_glow() -> void:
	if grass != null:
		grass.set("ground_glow", not bool(grass.get("ground_glow")))


func _on_glow(on: bool) -> void:
	if _glow_button != null:
		_paint(_glow_button, on)
	if _even_button != null and grass != null:
		_paint(_even_button, bool(grass.get("even_green")))


func _toggle_even() -> void:
	if grass != null:
		grass.set("even_green", not bool(grass.get("even_green")))


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
	# Only on the farm, as the panel itself.
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_O):
		return
	if (event as InputEventKey).alt_pressed:
		_toggle_grass()
		get_viewport().set_input_as_handled()
	elif (event as InputEventKey).ctrl_pressed and (event as InputEventKey).shift_pressed:
		_toggle_even()
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
