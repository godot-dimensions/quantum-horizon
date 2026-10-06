extends PanelContainer

## F1: the range's light, live, for tuning by eye (Ramon tunes the look; his numbers are the ones that
## stay): the sun's strength, height and turn, the fill, the ambient light, the exposure, the one spot,
## and how far through W you can step. SAVE writes them to quantum_range_tuning.cfg next to the scene,
## read back every time the range opens; RESET puts back the range's own (scripts/range_style.gd).
##
## The mouse is let go while it is open, so the sliders can be dragged.
##
## NO class_name (engine_gotchas.md).

const Kit := preload("res://ramon/QuantumRange/carried/kit/kit_style.gd")
const Style := preload("res://ramon/QuantumRange/scripts/range_style.gd")
const SAVE := "res://ramon/QuantumRange/quantum_range_tuning.cfg"

## [key, label, min, max, step]
const ROWS := [
	["key_energy", "Sun", 0.0, 3.0, 0.01],
	["key_elevation", "Sun height", 5.0, 90.0, 0.5],
	["key_azimuth", "Sun turn", -180.0, 180.0, 1.0],
	["fill_energy", "Fill", 0.0, 1.5, 0.01],
	["ambient_k", "Ambient", 0.0, 1.6, 0.01],
	["exposure", "Exposure", 0.4, 2.0, 0.01],
	["spot_energy", "Spot", 0.0, 14.0, 0.1],
	["spot_angle", "Spot cone", 8.0, 80.0, 0.5],
	["w_limit", "W you can step", 0.5, 4.0, 0.05],
]

## Who applies the values (the range's root: apply_tuning(values)).
var range_root: Node
var values: Dictionary = {}
var _sliders: Dictionary = {}
var _readouts: Dictionary = {}


static func defaults() -> Dictionary:
	var l: Dictionary = Style.LIGHT
	return {"key_energy": l["key_energy"], "key_elevation": l["key_elevation"], "key_azimuth": l["key_azimuth"],
		"fill_energy": l["fill_energy"], "ambient_k": 1.0, "exposure": l["exposure"], "spot_energy": 12.0, "spot_angle": 28.0, "w_limit": 2.0}


## The saved values over the defaults (or the defaults alone).
static func load_saved() -> Dictionary:
	var v: Dictionary = defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		for k in v:
			if cfg.has_section_key("tuning", k):
				v[k] = float(cfg.get_value("tuning", k))
	return v


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", Kit.glass_box(10.0, 1.0, 0.92))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.text = "RANGE LIGHT  ·  F1"
	title.add_theme_font_override("font", Kit.ui_font("heading"))
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Kit.UI_ACCENT)
	box.add_child(title)
	values = load_saved()
	for r in ROWS:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = String(r[1])
		l.custom_minimum_size = Vector2(118, 0)
		l.add_theme_font_override("font", Kit.ui_font("text"))
		l.add_theme_font_size_override("font_size", 12)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = float(r[2])
		sl.max_value = float(r[3])
		sl.step = float(r[4])
		sl.custom_minimum_size = Vector2(170, 18)
		sl.value = float(values[r[0]])
		var key: String = String(r[0])
		sl.value_changed.connect(func(v: float) -> void: _changed(key, v))
		row.add_child(sl)
		var rd := Label.new()
		rd.custom_minimum_size = Vector2(52, 0)
		rd.add_theme_font_override("font", Kit.ui_font("key"))
		rd.add_theme_font_size_override("font_size", 12)
		rd.text = "%.2f" % float(values[r[0]])
		row.add_child(rd)
		box.add_child(row)
		_sliders[key] = sl
		_readouts[key] = rd
	var buttons := HBoxContainer.new()
	var save := Button.new()
	save.text = "SAVE SETTINGS"
	save.pressed.connect(save_values)
	buttons.add_child(save)
	var reset := Button.new()
	reset.text = "RESET"
	reset.pressed.connect(func() -> void:
		values = defaults()
		for k in _sliders:
			(_sliders[k] as HSlider).set_value_no_signal(float(values[k]))
			(_readouts[k] as Label).text = "%.2f" % float(values[k])
		_apply())
	buttons.add_child(reset)
	box.add_child(buttons)


func _changed(key: String, v: float) -> void:
	values[key] = v
	(_readouts[key] as Label).text = "%.2f" % v
	_apply()


func _apply() -> void:
	if range_root != null:
		range_root.call("apply_tuning", values)


func save_values() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("tuning", k, values[k])
	cfg.save(SAVE)


func toggle() -> void:
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED


func _process(_d: float) -> void:
	if visible:
		var u: float = get_viewport_rect().size.y / 720.0
		position = Vector2(22.0 * u, 200.0 * u)
