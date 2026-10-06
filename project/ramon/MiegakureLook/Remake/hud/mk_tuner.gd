extends PanelContainer
## Crosswise: the artist dev panel (F1), after the Creation Lab's (CreationLab/kit/kit_tuner.gd):
## every number in the islands' light and framing on a live slider, and a SAVE button that writes
## them to crosswise_tuning.cfg, so what Ramon saves is where the islands starts next time
## (Ramon, 4 Oct, for the lab: "sliders I can use in realtime, then I can give you the numbers";
## 6 Oct, here: "add the 1 spotlight with adjustment dev panel").
##
##   LIGHT    sky fill (the blue in every shadow), the sun's strength, exposure
##   SUN      its height and turn
##   SPOT     the one spotlight: strength, cone, edge softness, reach, falloff, height, warmth, and
##            whether it follows the walker (1) or hangs over the island's middle (0)
##   SKY      sky lift (0 the lab's dark sky, 1 a pale Miegakure sky) and how far the sky shifts
##            when the view is turned into W
##   CAMERA   the diorama's pitch, yaw, distance and lens
##
## Hidden until F1 or F2. Unlike the lab's, it is named on the keys strip (Ramon could not find it,
## 6 Oct). Esc frees the mouse to drag.
##
## NO class_name (engine_gotchas.md).

const FONT := 15
const HEAD := Color(0.42, 0.72, 1.0)
const FONT_BOLD := "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Bold.ttf"
const FONT_BODY := "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf"

const LIGHT_ROWS := [["fill", "Sky fill (shadows)", 0.0, 3.0, 0.01], ["sun", "Sun strength", 0.0, 3.0, 0.01], ["exposure", "Exposure", 0.4, 2.5, 0.01]]
const SUN_ROWS := [["sun_up", "Height, degrees", 5.0, 90.0, 0.5], ["sun_turn", "Turn, degrees", -180.0, 180.0, 0.5]]
const SPOT_ROWS := [["spot_strength", "Strength", 0.0, 30.0, 0.01], ["spot_cone", "Cone, degrees", 10.0, 120.0, 0.1],
	["spot_softness", "Edge softness", 0.1, 10.0, 0.01], ["spot_reach", "Reach, m", 2.0, 30.0, 0.05], ["spot_falloff", "Falloff", 0.01, 2.0, 0.01],
	["spot_height", "Height, m", 2.0, 16.0, 0.01], ["spot_warmth", "Warmth", 0.0, 1.0, 0.01], ["spot_follow", "Follows him (1) / island (0)", 0.0, 1.0, 1.0]]
const SKY_ROWS := [["sky_lift", "Sky lift (lab dark / pale)", 0.0, 1.0, 0.01], ["turned_shift", "Sky shift when turned", 0.0, 1.0, 0.01]]
const CAMERA_ROWS := [["pitch_degrees", "Pitch, degrees", 20.0, 85.0, 0.5], ["yaw_degrees", "Yaw, degrees", -90.0, 90.0, 0.5],
	["distance", "Distance, m", 4.0, 40.0, 0.1], ["fov_degrees", "Lens, degrees", 8.0, 70.0, 0.5]]

var env: Node
var camera: Node

var _sliders: Dictionary = {}
var _labels: Dictionary = {}
var _names: Dictionary = {}
var _saved_note: Label
var _quiet: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2(14, 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.86)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	_load_camera()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var title := Label.new()
	title.text = "ARTIST DEV PANEL  ·  F1 / F2 to close  ·  Esc frees the mouse  ·  [ ] previous / next island"
	title.add_theme_font_override("font", load(FONT_BOLD))
	title.add_theme_font_size_override("font_size", FONT)
	box.add_child(title)
	_section(box, "LIGHT")
	for r in LIGHT_ROWS:
		_row(box, r)
	_section(box, "SUN")
	for r in SUN_ROWS:
		_row(box, r)
	_section(box, "SPOT")
	for r in SPOT_ROWS:
		_row(box, r)
	_section(box, "SKY")
	for r in SKY_ROWS:
		_row(box, r)
	_section(box, "CAMERA")
	for r in CAMERA_ROWS:
		_row(box, r)
	var save := Button.new()
	save.text = "SAVE SETTINGS"
	save.focus_mode = Control.FOCUS_NONE
	save.add_theme_font_override("font", load(FONT_BOLD))
	save.add_theme_font_size_override("font_size", FONT)
	save.pressed.connect(_save)
	box.add_child(save)
	_saved_note = Label.new()
	_saved_note.add_theme_font_size_override("font_size", FONT - 2)
	box.add_child(_saved_note)


func _section(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", load(FONT_BOLD))
	l.add_theme_font_size_override("font_size", FONT)
	l.add_theme_color_override("font_color", HEAD)
	box.add_child(l)


func _row(box: VBoxContainer, r: Array) -> void:
	var key: String = r[0]
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(270, 0)
	name_label.add_theme_font_override("font", load(FONT_BODY))
	name_label.add_theme_font_size_override("font_size", FONT)
	row.add_child(name_label)
	var s := HSlider.new()
	s.custom_minimum_size = Vector2(240, 22)
	s.min_value = float(r[2])
	s.max_value = float(r[3])
	s.step = float(r[4])
	s.focus_mode = Control.FOCUS_NONE
	_quiet = true
	s.value = _read(key)
	_quiet = false
	s.value_changed.connect(func(v: float) -> void: _on_change(key, v))
	row.add_child(s)
	box.add_child(row)
	_sliders[key] = s
	_labels[key] = name_label
	_names[key] = r[1]
	_show(key)


func _is_camera(key: String) -> bool:
	for r in CAMERA_ROWS:
		if r[0] == key:
			return true
	return false


func _read(key: String) -> float:
	if _is_camera(key):
		return float(camera.get(key)) if camera != null else 0.0
	return float((env.get("values") as Dictionary).get(key, 0.0)) if env != null else 0.0


func _on_change(key: String, v: float) -> void:
	if _quiet:
		return
	if _is_camera(key):
		if camera != null:
			camera.set(key, v)
			camera.call("refresh_lens")
	elif env != null:
		env.call("set_value", key, v)
	_show(key)


func _show(key: String) -> void:
	var l: Label = _labels.get(key)
	if l != null:
		l.text = "%s  %.2f" % [_names[key], _read(key)]


func _save() -> void:
	var err: int = OK
	if env != null:
		err = int(env.call("save_values"))
	var path: String = String(env.get("SAVE_PATH")) if env != null else ""
	if camera != null and not path.is_empty():
		var cfg := ConfigFile.new()
		cfg.load(path)
		for r in CAMERA_ROWS:
			cfg.set_value("camera", r[0], float(camera.get(r[0])))
		err = cfg.save(path)
	_saved_note.text = ("Saved to %s at %s" % [path, Time.get_time_string_from_system()]) if err == OK else "Could not save (%d)" % err


## The camera's saved framing, applied before the panel reads it.
func _load_camera() -> void:
	if env == null or camera == null:
		return
	var cfg := ConfigFile.new()
	if cfg.load(String(env.get("SAVE_PATH"))) != OK or not cfg.has_section("camera"):
		return
	for k in cfg.get_section_keys("camera"):
		camera.set(k, float(cfg.get_value("camera", k)))
	camera.call("refresh_lens")


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	# F1 or F2 (Ramon reached for F2 first, as in the Creation Lab; and on some keyboards one of the
	# F-keys is a media key unless Fn is held), by the key's letter or its place on the keyboard.
	if k != null and k.pressed and not k.echo and (k.keycode in [KEY_F1, KEY_F2] or k.physical_keycode in [KEY_F1, KEY_F2]):
		visible = not visible
		if visible:
			for key in _sliders:
				_quiet = true
				(_sliders[key] as HSlider).value = _read(key)
				_quiet = false
				_show(key)
		get_viewport().set_input_as_handled()
	elif k != null and k.pressed and k.keycode == KEY_ESCAPE and visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
