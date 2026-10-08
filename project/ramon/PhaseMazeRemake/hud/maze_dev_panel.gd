extends PanelContainer

## F1: the maze's numbers, live, for tuning by eye (PLAN.md step 73; the range's panel pattern). The
## cameras, the turn and the settle, how fast Q and E step, 4D sight's strength, the renderer (the R&D
## views: Projected and Wireframe show the whole maze at once), and the light. SAVE makes them the
## defaults in user://phase_maze_remake_tuning.cfg (the range's panel writes into the project folder; this
## one does not); RESET puts back the maze's own.
##
## The mouse is let go while it is open, so the sliders can be dragged.
##
## NO class_name (engine_gotchas.md).

const Kit := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")
const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")
const SAVE := "user://phase_maze_remake_tuning.cfg"
const RENDERERS := ["Cross-section", "Combined", "Projected", "Wireframe Canvas"]

## [key, label, min, max, step]. step >= 1 with max 1 is a switch.
const ROWS := [
	["chase_distance", "Chase distance", 1.5, 8.0, 0.1],
	["chase_height", "Chase height", 0.8, 4.0, 0.05],
	["chase_pitch", "Chase tilt", -60.0, 0.0, 0.5],
	["turn_seconds", "Turn (F) seconds", 0.1, 1.2, 0.01],
	["settle", "Settle to quarter turns", 0.0, 1.0, 1.0],
	["w_cyan", "Walls across W in cyan", 0.0, 1.0, 1.0],
	["w_step", "Q/E step speed", 0.1, 1.0, 0.05],
	["ghost", "4D sight (lower: stronger)", 0.02, 1.0, 0.01],
	["renderer", "Renderer 0 slice 1 comb 2 proj 3 wire", 0.0, 3.0, 1.0],
	["key_energy", "Sun", 0.0, 3.0, 0.01],
	["ambient_k", "Ambient", 0.0, 1.6, 0.01],
	["exposure", "Exposure", 0.4, 2.0, 0.01],
	["spot_energy", "Spot", 0.0, 14.0, 0.1],
	["spot_angle", "Spot cone", 8.0, 80.0, 0.5],
]

var maze_root: Node
var values: Dictionary = {}
var _sliders: Dictionary = {}
var _readouts: Dictionary = {}
var _checks: Dictionary = {}


static func defaults() -> Dictionary:
	var l: Dictionary = Style.LIGHT
	return {"chase_distance": 3.6, "chase_height": 2.1, "chase_pitch": -24.0, "turn_seconds": 0.35, "settle": 1.0, "w_cyan": 1.0,
		"w_step": 0.3, "ghost": 0.3, "renderer": 0.0, "key_energy": l["key_energy"], "ambient_k": 1.0,
		"exposure": l["exposure"], "spot_energy": 3.0, "spot_angle": 34.0}


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
	title.text = "PHASE MAZE  ·  F1"
	title.add_theme_font_override("font", Kit.ui_font("heading"))
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Kit.UI_ACCENT)
	box.add_child(title)
	values = load_saved()
	for r in ROWS:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = String(r[1])
		l.custom_minimum_size = Vector2(196, 0)
		l.add_theme_font_override("font", Kit.ui_font("text"))
		l.add_theme_font_size_override("font_size", 12)
		row.add_child(l)
		var key: String = String(r[0])
		if float(r[4]) >= 1.0 and float(r[3]) == 1.0:
			var cb := CheckBox.new()
			cb.button_pressed = float(values[key]) > 0.5
			cb.toggled.connect(func(on: bool) -> void: _changed(key, 1.0 if on else 0.0))
			row.add_child(cb)
			box.add_child(row)
			_checks[key] = cb
			continue
		var sl := HSlider.new()
		sl.min_value = float(r[2])
		sl.max_value = float(r[3])
		sl.step = float(r[4])
		sl.custom_minimum_size = Vector2(160, 18)
		sl.value = float(values[key])
		sl.value_changed.connect(func(v: float) -> void: _changed(key, v))
		row.add_child(sl)
		var rd := Label.new()
		rd.custom_minimum_size = Vector2(52, 0)
		rd.add_theme_font_override("font", Kit.ui_font("key"))
		rd.add_theme_font_size_override("font_size", 12)
		rd.text = _show(key, float(values[key]))
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
			(_readouts[k] as Label).text = _show(k, float(values[k]))
		for k in _checks:
			(_checks[k] as CheckBox).set_pressed_no_signal(float(values[k]) > 0.5)
		_apply())
	buttons.add_child(reset)
	box.add_child(buttons)


func _show(key: String, v: float) -> String:
	if key == "renderer":
		return ["slice", "comb", "proj", "wire"][clampi(int(v), 0, 3)]
	return "%.2f" % v


func _changed(key: String, v: float) -> void:
	values[key] = v
	if _readouts.has(key):
		(_readouts[key] as Label).text = _show(key, v)
	_apply()


func _apply() -> void:
	if maze_root != null:
		maze_root.call("apply_tuning", values)


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
		position = Vector2(22.0 * u, 140.0 * u)
