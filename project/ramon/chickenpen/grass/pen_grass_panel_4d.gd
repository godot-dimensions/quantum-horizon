extends Control

## The grass panel: a see-through block of buttons on the HUD, one per look in
## pen_grass_looks.gd; click one (Esc first, to have the mouse) or press O for the next. Under
## them, the ground: the pen's own or painted (the sandy yard; Shift+O). Made by the Grass node
## (pen_grass_4d.gd, show_panel), so no scene has to carry it.
##
## 7 OCT (Ramon's notes after layout B): the Centre falloff button and Ctrl+O are gone with the glow
## ("we dont need it anymore"); the Paths rows have their own window (scripts/pen_paths_panel_4d.gd);
## and Save at the foot keeps the look, darkness, wind, leaves, flowers, ground and even green
## (pen_grass_4d.gd save_settings), which until then were lost at every restart.
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
var _even_button: Button
var _green_box: VBoxContainer
var _look_box: VBoxContainer
var _look_label: Label
var _look_buttons: Array[Button] = []
var _look_node: Node
## How big the panel is drawn, of its own size (Ramon, 7 Oct: "make the look panel 60% of the size"); the paths
## window on top of it takes the same (scripts/pen_paths_panel_4d.gd).
@export_range(0.3, 1.5, 0.05) var panel_scale: float = 1.0
## THE GRASS FOLDED AWAY (Ramon, 7 Oct: "path and look brackets are of a different formatting than other
## windows"). At 60% (panel_scale, his earlier ask) its text and corners were smaller than every other card's;
## at the cards' own size it is kept small instead by folding the grass's rows behind one switch, the look and
## Save settings always showing.
@export var start_folded: bool = true
## The dev look's two colours (Ramon, 7 Oct: "two options in the dev panel that makes me controll the orange and
## the blue in the scene"): swatches under Dev / Art, set live, kept by Save settings, shown in the dev look only
## ("is it possible we show the color squares menu only in the dev look?").
var _colours_box: VBoxContainer
var _blue_swatch: ColorPickerButton
var _orange_swatch: ColorPickerButton
var _save_button: Button
var _save_note: Label
var _save_check: float = 0.0
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
var _fold_button: Button
var _folded: bool = true
var _save_box: VBoxContainer
var _hills_note: Label


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
	_save_rows()
	# The fold: one switch where the "Grass" heading was, right under the look.
	_folded = start_folded
	_title.visible = false
	_fold_button = _button("Show grass")
	_box.move_child(_fold_button, _box.get_children().find(_look_box) + 1)
	_fold_button.pressed.connect(_toggle_fold)
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
	# Small, one under the other, a little cube and its name beside it (Ramon, 7 Oct: "make the swatches to click
	# smaller so its less invasive in the hud. like little cubes, with descripts next to it. and under each other").
	var colours := VBoxContainer.new()
	colours.add_theme_constant_override("separation", 3)
	colours.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_look_box.add_child(colours)
	_colours_box = colours
	_blue_swatch = _colour_swatch("Foundation colour", colours)
	_orange_swatch = _colour_swatch("Landmark colour", colours)


## A little cube for one of the dev look's colours, its name beside it: its picker sets both colours on the look
## as it is dragged.
func _colour_swatch(text: String, parent: Control) -> ColorPickerButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var swatch := ColorPickerButton.new()
	swatch.edit_alpha = false
	swatch.custom_minimum_size = Vector2(14.0, 14.0)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.focus_mode = Control.FOCUS_NONE
	swatch.mouse_filter = Control.MOUSE_FILTER_STOP
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	edge.border_color = Color(1.0, 1.0, 1.0, 0.35)
	edge.set_border_width_all(1)
	edge.set_content_margin_all(0)
	for state in ["normal", "hover", "pressed"]:
		swatch.add_theme_stylebox_override(state, edge)
	swatch.color_changed.connect(func(_c: Color) -> void: _on_colours())
	row.add_child(swatch)
	_label(text, Color(1.0, 1.0, 1.0, 0.45), row)
	return swatch


func _on_colours() -> void:
	if _look_node != null and is_instance_valid(_look_node) and _look_node.has_method("set_colours"):
		_look_node.call("set_colours", _blue_swatch.color, _orange_swatch.color)
		_note_saved()


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
	if _blue_swatch != null:
		_blue_swatch.color = look.get("foundation_colour")
		_orange_swatch.color = look.get("landmark_colour")


func _on_look(dev: bool) -> void:
	for b in _look_buttons:
		_paint(b, bool(b.get_meta("dev")) == dev)
	if _colours_box != null:
		_colours_box.visible = dev


## SAVE (Ramon, 7 Oct: "the greenery controls, and the rebaking options. does that get saved? or not. if
## not make a save button"): Rebake greens always saved the main green; this keeps the rest. Lit while
## the panel shows something other than what is saved. Shown with the grass off too.
func _save_rows() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_meta(&"always", true)
	_box.add_child(box)
	_save_box = box
	_save_button = _button("Save settings", box)
	_save_button.pressed.connect(_save)
	_save_note = _label("", Color(1.0, 1.0, 1.0, 0.45), box)
	_note_saved()
	# The grass on the hills stands on baked heights (grass/grass_heights_4d.gd): said here when they
	# are missing or the hills have moved since.
	var hills: String = String(grass.get("heights_note")) if grass != null and grass.get("heights_note") != null else ""
	if hills != "":
		var note := _label(hills + "  (grass/_bake_grass_heights_runner.gd)", Color(1.0, 0.82, 0.55, 0.7), box)
		# Wrapped to the panel's width: on one line it made the panel twice as wide (7 Oct).
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(190.0, 0.0)
		_hills_note = note


func _save() -> void:
	if grass == null or not grass.has_method("save_settings"):
		return
	var err: int = int(grass.call("save_settings"))
	# The dev look's blue and orange with it (look/look_saved.cfg).
	if err == OK and _look_node != null and is_instance_valid(_look_node) and _look_node.has_method("save_colours"):
		err = int(_look_node.call("save_colours"))
	_note_saved()
	if err != OK:
		_save_note.text = "Not saved: %s" % error_string(err)


func _note_saved() -> void:
	if _save_button == null or grass == null or not grass.has_method("matches_saved"):
		return
	var same: bool = bool(grass.call("matches_saved"))
	if _look_node != null and is_instance_valid(_look_node) and _look_node.has_method("colours_match_saved"):
		same = same and bool(_look_node.call("colours_match_saved"))
	_paint(_save_button, not same)
	if not bool(grass.call("has_saved")):
		_save_note.text = "Nothing saved yet"
	else:
		_save_note.text = "Saved, the pen opens so" if same else "Changed: Save keeps it"


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


var _off_farm: bool = false


func _process(delta: float) -> void:
	# Only on the farm (3 Oct: "the grass and its menu should only correspond to the pen scene"):
	# away in the cave the farm is asleep and the grass hidden, and so is this. (The theatre's
	# crossing hides the HUD itself, and puts it back.)
	var on_farm: bool = grass != null and is_instance_valid(grass) and grass.is_visible_in_tree()
	# Only its own hiding undone: what another hid it for stays hidden (7 Oct: with the Lookout's camera up, which
	# borrows the whole HUD, lookout_station_4d.gd _borrow, this put itself back over the viewfinder every frame).
	if not on_farm:
		if visible:
			visible = false
			_off_farm = true
		return
	if _off_farm:
		_off_farm = false
		visible = true
	if not visible:
		return
	_pick_now()
	if _look_box != null:
		_find_look()
	_save_check -= delta
	if _save_check <= 0.0:
		_save_check = 0.5
		_note_saved()
	var view: Vector2 = get_viewport_rect().size
	var back: Control = get_child(0) as Control
	size = back.get_combined_minimum_size()
	back.size = size
	# Its size (panel_scale): the cards' own since 7 Oct, kept small by the fold (start_folded).
	scale = Vector2.ONE * panel_scale
	var own: Vector2 = size * panel_scale
	# FIRST FREE SPOT (pen_hud_spot_4d.gd, 3 Oct): above the to-do list, left edges level, as it
	# was; grown tall, that ran up into the murmuration card - then beside the list, bottoms
	# level, or beside the murmuration card, tops level. The camera picker and the Lookout card
	# keep to the right and are not counted.
	# THE PATHS WINDOW STACKED ON TOP (Ramon, 7 Oct: "the paths window can stack neatly above the other. not sure why
	# its next to one other"): this panel finds room for the two together, the paths window's height and a gap above
	# its own, and sits at the bottom of it; the paths window takes the top (scripts/pen_paths_panel_4d.gd).
	var stack := get_parent().get_node_or_null(^"PathsPanel") as Control
	var top_h: float = stack.size.y * stack.scale.y + gap if stack != null and stack.is_visible_in_tree() else 0.0
	var block := Vector2(maxf(own.x, stack.size.x * stack.scale.x if top_h > 0.0 else 0.0), own.y + top_h)
	var places: Array = []
	# UNDER THE MURMURATION CARD, UNDER THE PATHS WINDOW (Ramon, 7 Oct: "place them under the murmuration box", then
	# "look needs to go under paths ui"): the paths window at the card's left edge (scripts/pen_paths_panel_4d.gd),
	# this under it, left edges level; with the card away (F3), the same under the info card. Taken first; the old
	# places below are the fallbacks.
	var stats_now := get_parent().get_node_or_null(^"FlockStats") as Control
	var info_now := get_parent().get_node_or_null(^"InfoCard") as Control
	var beside := Vector2.ZERO
	if stats_now != null and stats_now.is_visible_in_tree():
		var sr: Rect2 = SPOT.rect_of(stats_now)
		beside = Vector2(sr.position.x, sr.end.y + gap + top_h)
	elif info_now != null and info_now.is_visible_in_tree():
		var ir: Rect2 = SPOT.drawn_of(info_now)
		beside = Vector2(maxf(ir.position.x, 4.0), ir.end.y + gap + top_h)
	var places_beside: Array = [beside] if beside != Vector2.ZERO else []
	# The to-do list is only this column's when it sits bottom left (since 7 Oct it sits at the top, beside the
	# info card: pen_quests_4d.gd beside_info).
	var in_column: bool = above != null and above.is_visible_in_tree() and not bool(above.get("beside_info"))
	if in_column:
		var r: Rect2 = SPOT.rect_of(above)
		places.append(Vector2(r.position.x, r.position.y - block.y - gap))
		places.append(Vector2(r.end.x + gap, r.end.y - block.y))
	var stats := get_parent().get_node_or_null(^"FlockStats") as Control
	var column_right: float = margin
	if in_column:
		column_right = maxf(column_right, SPOT.rect_of(above).end.x)
	if stats != null and stats.is_visible_in_tree():
		var s: Rect2 = SPOT.rect_of(stats)
		places.append(Vector2(s.end.x + gap, s.position.y))
		column_right = maxf(column_right, s.end.x)
	# Right of the whole left column, just under the info card at the top (1920 x 1080: the
	# column is full from the top of the screen to the belt).
	var info := get_parent().get_node_or_null(^"InfoCard") as Control
	var under_info: float = SPOT.drawn_of(info).end.y + gap if info != null and info.is_visible_in_tree() else margin
	places.append(Vector2(column_right + gap if column_right > margin else margin, under_info))
	# Right of the belt too: with the paths window on top the pair is taller than the room between the info card
	# and the belt, and at 125% it lay over the belt's last slot.
	var belt := get_parent().get_node_or_null(^"Inventory") as Control
	var belt_r := Rect2()
	if belt != null and belt.is_visible_in_tree() and belt.has_method("belt_rect"):
		belt_r = belt.call("belt_rect")
		places.append(Vector2(maxf(column_right, belt_r.end.x) + gap, under_info))
	places.append(Vector2(margin, view.y * at_height - block.y))
	var ignore: Array = []
	for other in [^"CameraPicker", ^"Journal", ^"PathsPanel"]:
		var n: Node = get_parent().get_node_or_null(other)
		if n != null:
			ignore.append(n)
	var taken: Array = SPOT.taken(get_parent(), self, ignore)
	if belt_r.size != Vector2.ZERO:
		taken.append(belt_r)
	if not places_beside.is_empty() and SPOT.is_free(Rect2(places_beside[0], own), taken, view):
		position = places_beside[0]
		return
	position = SPOT.first(places, block, taken, view) + Vector2(0.0, top_h)


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
			if row != _title and row != _grass_button and row != _fold_button and not row.has_meta(&"always") and row is CanvasItem:
				(row as CanvasItem).visible = on
	_apply_fold()


## Folded: only the look, the fold's switch and Save settings show; open: the grass's rows as the grass is (on
## or off, _on_enabled).
func _toggle_fold() -> void:
	_folded = not _folded
	if not _folded and _box != null:
		for row in _box.get_children():
			if (row == _grass_button or row.has_meta(&"always")) and row is CanvasItem:
				(row as CanvasItem).visible = true
		_on_enabled(bool(grass.get("enabled")) if grass != null else false)
	else:
		_apply_fold()


func _apply_fold() -> void:
	if _fold_button != null:
		_fold_button.visible = true
		_fold_button.text = "Show grass" if _folded else "Hide grass"
		_paint(_fold_button, not _folded)
	if _hills_note != null:
		_hills_note.visible = not _folded
	if not _folded or _box == null:
		return
	for row in _box.get_children():
		if row != _look_box and row != _fold_button and row != _save_box and row is CanvasItem:
			(row as CanvasItem).visible = false


## The even green's button, lit as it stands (the grass sends glow_changed when it changes).
func _on_glow(_on: bool) -> void:
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
		# Was the centre glow's (retired 7 Oct); left doing nothing rather than turning the look.
		return
	elif (event as InputEventKey).shift_pressed:
		_set_ground(not bool(grass.get("ground_paint")))
		get_viewport().set_input_as_handled()
	else:
		var keys: Array = LOOKS.PRESETS.keys()
		keys.sort()
		var at: int = keys.find(int(grass.get("preset")))
		_pick(int(keys[(at + 1) % keys.size()]))
		get_viewport().set_input_as_handled()
