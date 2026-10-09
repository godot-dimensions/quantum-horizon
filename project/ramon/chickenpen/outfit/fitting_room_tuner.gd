extends PanelContainer

## THE FITTING ROOM'S LIGHT, TUNED BY EYE (Ramon, 8 Oct: "allow me to adjust the spotlight in the fitting
## room, and save as default (press tab to show hud). similar settings to kit"). Tab swaps the outfit
## panel for this one, in the same place down the right, so neither pedestal is covered while you look
## at the light. The rows are the Creation Lab's tuning panel's (CreationLab/kit/kit_tuner.gd), the ones
## this room has:
##   LIGHT  spots (every downlight at once), sky fill, the sun's strength, height and turn, exposure;
##          per mood, as in the lab (B switches it)
##   SPOT   strength (per mood), cone, edge softness, reach, falloff, height, warmth: on the light over
##          you, the one over the piece, or both at once
## SAVE AS DEFAULT writes it all to the room's own file (outfit_room_4d.gd TUNING), which the room reads
## when it starts; until there is one it starts from the lab's light. The lab's own file is never written.
##
## SIZED, NEVER SCALED, as the outfit panel is: every size from u, the screen's height over 720, set in
## layout(). The sliders are boxes only (a track, and its fill in the code blue), no picture of a knob,
## so they are as sharp at 4K as at 720.
##
## NO class_name (engine_gotchas.md): the room preloads it.

const KitStyle := preload("res://ramon/CreationLab/kit/kit_style.gd")
## Warmth runs from the lab's cool white to its warm one (kit_tuner.gd).
const COOL := Color(0.86, 0.92, 1.0)
const WARM := Color(1.0, 0.84, 0.62)
## Rows: [key, label, min, max, step]. The kit's ranges, the spot's reach and height to this room's size.
const LIGHT_ROWS := [["spots", "Spots", 0.0, 6.0, 0.01], ["fill", "Sky fill (shadows)", 0.0, 3.0, 0.01],
	["sun", "Sun", 0.0, 3.0, 0.01], ["sun_up", "Sun height, degrees", 5.0, 90.0, 0.5],
	["sun_turn", "Sun turn, degrees", -180.0, 180.0, 0.5], ["exposure", "Exposure", 0.4, 2.5, 0.01]]
const SPOT_ROWS := [["strength", "Strength", 0.0, 15.0, 0.01], ["cone", "Cone, degrees", 10.0, 120.0, 0.1],
	["softness", "Edge softness", 0.1, 10.0, 0.01], ["reach", "Reach, m", 1.0, 20.0, 0.05],
	["falloff", "Falloff", 0.01, 2.0, 0.01], ["height", "Height, m", 1.5, 4.9, 0.01], ["warmth", "Warmth", 0.0, 1.0, 0.01]]
const LIGHT_KEYS := ["spots", "fill", "sun", "sun_up", "sun_turn", "exposure"]
## Which light the SPOT rows move.
const TARGETS := ["Both", "Over you", "Over the piece"]

## The fitting room (outfit_room_4d.gd).
var room: Node

var _u: float = 1.0
var _target: int = 0
var _quiet: bool = false
var _sliders: Dictionary = {}
var _readouts: Dictionary = {}
var _target_buttons: Array[Button] = []
var _column: VBoxContainer
var _mood_label: Label
var _note: Label
## What layout() sizes again: [Control, ladder role], [StyleBoxFlat, pad x, pad y, corner] and the
## sliders' own boxes [StyleBoxFlat, half thickness].
var _type: Array = []
var _boxes: Array = []
var _tracks: Array = []
var _no_knob: ImageTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var glass: StyleBoxFlat = KitStyle.glass_box(10.0)
	glass.border_color = Color(1, 1, 1, 0.16)
	add_theme_stylebox_override("panel", glass)
	_boxes.append([glass, 18.0, 16.0, 8.0])
	# An empty knob: the fill shows where the value is, and a box is sharp at every size.
	var img := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_no_knob = ImageTexture.create_from_image(img)

	_column = VBoxContainer.new()
	add_child(_column)
	_column.add_child(_text("TRYM'S FITTING ROOM", "caption", KitStyle.UI_INK_DIM, "heading"))
	_column.add_child(_text("Light", "title", KitStyle.UI_INK, "title"))
	_column.add_child(_text("The Creation Lab's light, tuned for this room. Tab goes back to the outfit.", "body", KitStyle.UI_INK_SOFT, "text", true))
	_mood_label = _text("", "caption", KitStyle.UI_ACCENT, "heading")
	_column.add_child(_mood_label)
	for r in LIGHT_ROWS:
		_row(r)
	_column.add_child(_text("SPOT", "caption", KitStyle.UI_ACCENT, "heading"))
	var which := HBoxContainer.new()
	which.name = "Which"
	_column.add_child(which)
	for i in TARGETS.size():
		var b: Button = _button(String(TARGETS[i]), "caption")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose_target.bind(i))
		which.add_child(b)
		_target_buttons.append(b)
	for r in SPOT_ROWS:
		_row(r)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(gap)
	var save: Button = _button("Save as default", "subhead", true)
	save.pressed.connect(save_default)
	_column.add_child(save)
	_note = _text("", "caption", KitStyle.UI_INK_DIM, "text", true)
	_column.add_child(_note)
	_choose_target(0)


## Every size from u (the screen's height over 720), and the panel at [param at], [param panel_size].
func layout(u: float, at: Vector2, panel_size: Vector2) -> void:
	_u = u
	for entry in _type:
		if is_instance_valid(entry[0]):
			(entry[0] as Control).add_theme_font_size_override("font_size", KitStyle.type_px(String(entry[1]), u))
	for entry in _boxes:
		var box := entry[0] as StyleBoxFlat
		box.content_margin_left = float(entry[1]) * u
		box.content_margin_right = float(entry[1]) * u
		box.content_margin_top = float(entry[2]) * u
		box.content_margin_bottom = float(entry[2]) * u
		box.set_corner_radius_all(int(float(entry[3]) * u))
	for entry in _tracks:
		var track := entry as StyleBoxFlat
		track.content_margin_top = 4.0 * u
		track.content_margin_bottom = 4.0 * u
		track.set_corner_radius_all(int(4.0 * u))
	for key in _sliders:
		(_sliders[key] as HSlider).custom_minimum_size = Vector2(0.0, 20.0 * u)
		(_readouts[key] as Label).custom_minimum_size = Vector2(52.0 * u, 0.0)
	_column.add_theme_constant_override("separation", int(5.0 * u))
	(_column.get_node("Which") as HBoxContainer).add_theme_constant_override("separation", int(5.0 * u))
	size = panel_size
	position = at


## Every slider to the light as it is now (after a mood change, or a change of target).
func refresh() -> void:
	if room == null:
		return
	var mood: String = String(room.call("current_mood"))
	_mood_label.text = "LIGHT   %s   B switches" % mood.to_upper()
	_quiet = true
	for key in _sliders:
		(_sliders[key] as HSlider).value = _read(String(key))
		_show(String(key))
	_quiet = false


func save_default() -> void:
	var err: Error = room.call("save_tuning") if room != null else ERR_UNCONFIGURED
	_note.text = ("Saved. The fitting room starts with this light now." if err == OK
		else "Could not save (%s)." % error_string(err))


func _choose_target(i: int) -> void:
	_target = i
	var blue: Color = KitStyle.CODE_BLUE["bright"]
	for j in _target_buttons.size():
		var box := _target_buttons[j].get_theme_stylebox("normal") as StyleBoxFlat
		box.bg_color = blue if j == i else Color(1, 1, 1, 0.08)
		box.border_color = Color(1, 1, 1, 0.55) if j == i else Color(1, 1, 1, 0.22)
	refresh()


## The downlights the SPOT rows move: over you, over the piece, or both.
func _lights() -> Array:
	if room == null:
		return []
	var out: Array = []
	for i in [1, 2]:
		if _target == 0 or _target == i:
			var light: Node = room.get_node_or_null("FigureLight" if i == 1 else "GarmentLight")
			if light != null:
				out.append(light)
	return out


func _read(key: String) -> float:
	var mood: String = String(room.call("current_mood"))
	if key in LIGHT_KEYS:
		return float((room.call("light_for", mood) as Dictionary).get(key, 0.0))
	var lights: Array = _lights()
	if lights.is_empty():
		return 0.0
	var light: Node4D = lights[0]
	match key:
		"strength":
			return float((light.get("energy") as Dictionary).get(mood, 1.0))
		"cone":
			return float(light.get("angle"))
		"softness":
			return float(light.get("softness"))
		"reach":
			return float(light.get("reach"))
		"falloff":
			return float(light.get("attenuation"))
		"height":
			return light.position.y
		"warmth":
			var c: Color = (light.get("color") as Dictionary).get(mood, COOL)
			return clampf((COOL.b - c.b) / maxf(COOL.b - WARM.b, 0.001), 0.0, 1.0)
	return 0.0


func _write(key: String, v: float) -> void:
	var mood: String = String(room.call("current_mood"))
	if key in LIGHT_KEYS:
		(room.call("light_for", mood) as Dictionary)[key] = v
		room.call("push_light")
		return
	for node in _lights():
		var light := node as Node4D
		match key:
			"strength":
				var e: Dictionary = (light.get("energy") as Dictionary).duplicate()
				e[mood] = v
				light.set("energy", e)
			"cone":
				light.set("angle", v)
			"softness":
				light.set("softness", v)
			"reach":
				light.set("reach", v)
			"falloff":
				light.set("attenuation", v)
			"height":
				light.position = Vector4(light.position.x, v, light.position.z, light.position.w)
			"warmth":
				var c: Dictionary = (light.get("color") as Dictionary).duplicate()
				c[mood] = COOL.lerp(WARM, v)
				light.set("color", c)
		light.call("apply_mood", mood, true)


func _on_change(key: String, v: float) -> void:
	if _quiet:
		return
	_write(key, v)
	_show(key)
	_note.text = ""


func _show(key: String) -> void:
	(_readouts[key] as Label).text = "%.2f" % (_sliders[key] as HSlider).value


# --- Pieces -----------------------------------------------------------------------------------------

## A row: its name, a slider, and the number.
func _row(r: Array) -> void:
	var key: String = r[0]
	var row := HBoxContainer.new()
	_column.add_child(row)
	var name_label: Label = _text(String(r[1]), "caption", KitStyle.UI_INK_SOFT, "text")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	var s := HSlider.new()
	s.min_value = float(r[2])
	s.max_value = float(r[3])
	s.step = float(r[4])
	s.focus_mode = Control.FOCUS_NONE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_stretch_ratio = 1.3
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.anti_aliasing = true
	track.bg_color = Color(1, 1, 1, 0.14)
	var fill := StyleBoxFlat.new()
	fill.anti_aliasing = true
	fill.bg_color = KitStyle.CODE_BLUE["bright"].lightened(0.15)
	var fill_hover := fill.duplicate() as StyleBoxFlat
	fill_hover.bg_color = KitStyle.UI_ACCENT
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill_hover)
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		s.add_theme_icon_override(icon, _no_knob)
	_tracks.append_array([track, fill, fill_hover])
	s.value_changed.connect(func(v: float) -> void: _on_change(key, v))
	row.add_child(s)
	var readout: Label = _text("", "caption", KitStyle.UI_INK, "heading")
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(readout)
	_sliders[key] = s
	_readouts[key] = readout


func _text(words: String, role: String, colour: Color, family: String, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", KitStyle.ui_font(family))
	label.add_theme_color_override("font_color", colour)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_type.append([label, role])
	label.add_theme_font_size_override("font_size", KitStyle.type_px(role, _u))
	return label


## The outfit panel's buttons (outfit_room_4d.gd _button): black glass, the primary one in the code blue.
func _button(words: String, role: String, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = words
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", KitStyle.ui_font("heading"))
	for colour_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(colour_name, KitStyle.UI_INK)
	var blue: Color = KitStyle.CODE_BLUE["bright"]
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.anti_aliasing = true
		box.border_color = Color(1, 1, 1, 0.22)
		box.set_border_width_all(1)
		if primary:
			box.bg_color = blue.lightened(0.12) if state == "hover" else blue
		else:
			box.bg_color = Color(1, 1, 1, 0.16 if state.begins_with("hover") else (0.22 if state == "pressed" else 0.08))
		b.add_theme_stylebox_override(state, box)
		_boxes.append([box, 8.0, 5.0 if not primary else 9.0, 5.0])
	_type.append([b, role])
	b.add_theme_font_size_override("font_size", KitStyle.type_px(role, _u))
	return b
