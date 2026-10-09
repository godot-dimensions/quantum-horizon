extends PanelContainer

## Tab (or F1): the maze's numbers and colours, live, for tuning by eye (PLAN.md step 73; Ramon, 9 Oct:
## "sliders and a save mode when i press tab", then "allow me to change all the colors used in the scene?
## and save"). Two pages:
##   Numbers   the cameras, the turn and the settle, the step speed, 4D sight, the renderer, the light
##             and the spot.
##   Colours   every colour in the scene: the maze's surfaces, the colour code, the lobby and the
##             console, the sky and the light in each mood, the walker.
## SAVE writes both to user://phase_maze_remake_tuning.cfg, read back every time the scene opens; RESET
## puts back the maze's own (the page you are on). The mouse is let go while it is open.
##
## NO class_name (engine_gotchas.md).

const Kit := preload("res://ramon/PhaseMazeRemake/carried/kit/kit_style.gd")
const Style := preload("res://ramon/PhaseMazeRemake/maze/maze_style.gd")
const Walker := preload("res://ramon/PhaseMazeRemake/maze/maze_walker_build.gd")
const LabRoom := preload("res://ramon/PhaseMazeRemake/carried/LabKit/lab_room_4d.gd")
const SAVE := "user://phase_maze_remake_tuning.cfg"
const RENDERERS := ["Cross-section", "Combined", "Projected", "Wireframe Canvas"]

## [key, label, min, max, step]. step >= 1 with max 1 is a switch.
const ROWS := [
	["chase_distance", "Chase distance", 1.5, 8.0, 0.1],
	["chase_height", "Chase height", 0.8, 4.0, 0.05],
	["chase_pitch", "Chase tilt", -60.0, 0.0, 0.5],
	["turn_seconds", "Turn (F) seconds", 0.1, 1.2, 0.01],
	["settle", "Settle to quarter turns", 0.0, 1.0, 1.0],
	["w_cyan", "Walls across W in blue", 0.0, 1.0, 1.0],
	["w_step", "Q/E step speed", 0.1, 1.0, 0.05],
	["ghost", "4D sight (lower: stronger)", 0.02, 1.0, 0.01],
	["renderer", "Renderer 0 slice 1 comb 2 proj 3 wire", 0.0, 3.0, 1.0],
	["key_energy", "Sun", 0.0, 3.0, 0.01],
	["ambient_k", "Ambient", 0.0, 1.6, 0.01],
	["exposure", "Exposure", 0.4, 2.0, 0.01],
	["spot_follows", "Spot follows the walker", 0.0, 1.0, 1.0],
	["spot_bright", "Spot, bright", 0.0, 14.0, 0.1],
	["spot_dark", "Spot, dark", 0.0, 20.0, 0.1],
	["spot_angle", "Spot cone", 8.0, 80.0, 0.5],
	["spot_height", "Spot height", 4.0, 24.0, 0.25],
]

## [key, label] and headings ["", heading]. Keys: "sw:<swatch>" a surface, "role:<role>" the colour code,
## "light:<mood>:<field>" the sky and the light, "walker:<export>" the walker.
const COLOURS := [
	["", "THE MAZE"],
	["sw:maze_wall", "Walls"],
	["sw:maze_wall_w", "Walls across W"],
	["sw:maze_post", "Corner posts"],
	["sw:maze_cap", "Wall tops"],
	["sw:maze_floor", "Floor"],
	["sw:maze_climb", "Stairs and overlook"],
	["sw:maze_roof", "Roofs"],
	["", "THE COLOUR CODE"],
	["role:start", "Start, lift, roof lights"],
	["role:exit", "Exit and beacon"],
	["role:w", "W marks and doors"],
	["role:ghost", "4D sight ghosts"],
	["role:trail", "Breadcrumbs"],
	["role:done", "Finished dead ends"],
	["role:x", "Badge: X"],
	["role:z", "Badge: Z"],
	["", "THE LOBBY AND THE HALLS"],
	["sw:kit_wall", "Lobby and hall walls"],
	["sw:kit_floor", "Lobby floor"],
	["sw:kit_code_blue", "Teaching walls"],
	["sw:maze_bezel", "Console plate"],
	["sw:maze_screen", "Console glass"],
	["", "LIGHT, BRIGHT"],
	["light:bright:sky_top", "Sky, top"],
	["light:bright:sky_horizon", "Sky, horizon"],
	["light:bright:sky_bottom", "Sky, below"],
	["light:bright:ambient", "Ambient"],
	["light:bright:key_color", "Sun"],
	["light:bright:fill_color", "Fill"],
	["", "LIGHT, DARK (B)"],
	["light:dark:sky_top", "Sky, top"],
	["light:dark:sky_horizon", "Sky, horizon"],
	["light:dark:sky_bottom", "Sky, below"],
	["light:dark:ambient", "Ambient"],
	["light:dark:key_color", "Moon"],
	["", "THE WALKER"],
	["walker:skin", "Body"],
	["walker:accent", "Limbs"],
	["walker:face", "Face"],
	["walker:hair", "Hair"],
	["walker:belt_colour", "Belt"],
	["walker:boot_colour", "Boots"],
	["walker:eye_colour", "Eyes"],
]

var maze_root: Node
var values: Dictionary = {}
var colours: Dictionary = {}
var _sliders: Dictionary = {}
var _readouts: Dictionary = {}
var _checks: Dictionary = {}
var _pickers: Dictionary = {}
var _tabs: TabContainer


static func defaults() -> Dictionary:
	var l: Dictionary = Style.LIGHT
	return {"chase_distance": 3.6, "chase_height": 2.1, "chase_pitch": -24.0, "turn_seconds": 0.35, "settle": 0.0, "w_cyan": 1.0,
		"w_step": 0.3, "ghost": 0.3, "renderer": 0.0, "key_energy": l["key_energy"], "ambient_k": 1.0,
		"exposure": l["exposure"], "spot_follows": 1.0, "spot_bright": 3.0, "spot_dark": 9.0, "spot_angle": 30.0,
		"spot_height": 10.0}


## Every colour's default, from where it is defined.
static func colour_defaults() -> Dictionary:
	var out: Dictionary = {}
	for row in COLOURS:
		var key: String = row[0]
		if key == "":
			continue
		var p: PackedStringArray = key.split(":")
		match p[0]:
			"sw":
				out[key] = Style.SWATCHES[p[1]][0]
			"role":
				out[key] = Style.ROLE[p[1]]
			"light":
				var mood: Dictionary = Style.LIGHT if p[1] == "bright" else LabRoom.MOODS["dark"]
				out[key] = mood[p[2]]
			"walker":
				out[key] = Walker.COLOURS[p[1]]
	return out


static func load_saved() -> Dictionary:
	var v: Dictionary = defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		for k in v:
			if cfg.has_section_key("tuning", k):
				v[k] = float(cfg.get_value("tuning", k))
	return v


static func load_saved_colours() -> Dictionary:
	var c: Dictionary = colour_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) == OK:
		for k in c:
			if cfg.has_section_key("colours", k):
				c[k] = cfg.get_value("colours", k)
	return c


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", Kit.glass_box(10.0, 1.0, 0.92))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "PHASE MAZE  ·  TAB TO CLOSE  ·  SAVE KEEPS IT"
	title.add_theme_font_override("font", Kit.ui_font("heading"))
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Kit.UI_ACCENT)
	box.add_child(title)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(430, 0)
	box.add_child(_tabs)
	values = load_saved()
	colours = load_saved_colours()
	_tabs.add_child(_numbers_page())
	_tabs.add_child(_colours_page())
	var buttons := HBoxContainer.new()
	var save := Button.new()
	save.text = "SAVE SETTINGS"
	save.pressed.connect(save_values)
	buttons.add_child(save)
	var reset := Button.new()
	reset.text = "RESET THIS PAGE"
	reset.pressed.connect(_reset_page)
	buttons.add_child(reset)
	box.add_child(buttons)


func _scroll(nm: String) -> Array:
	var sc := ScrollContainer.new()
	sc.name = nm
	sc.custom_minimum_size = Vector2(430, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return [sc, v]


func _label(text: String, width: float, font: String = "text", col: Color = Color(1, 1, 1, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_font_override("font", Kit.ui_font(font))
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", col)
	return l


func _numbers_page() -> Control:
	var sv: Array = _scroll("Numbers")
	var v: VBoxContainer = sv[1]
	for r in ROWS:
		var row := HBoxContainer.new()
		row.add_child(_label(String(r[1]), 196))
		var key: String = String(r[0])
		if float(r[4]) >= 1.0 and float(r[3]) == 1.0:
			var cb := CheckBox.new()
			cb.button_pressed = float(values[key]) > 0.5
			cb.toggled.connect(func(on: bool) -> void: _changed(key, 1.0 if on else 0.0))
			row.add_child(cb)
			v.add_child(row)
			_checks[key] = cb
			continue
		var sl := HSlider.new()
		sl.min_value = float(r[2])
		sl.max_value = float(r[3])
		sl.step = float(r[4])
		sl.custom_minimum_size = Vector2(150, 18)
		sl.value = float(values[key])
		sl.value_changed.connect(func(x: float) -> void: _changed(key, x))
		row.add_child(sl)
		var rd := _label(_show(key, float(values[key])), 52, "key")
		row.add_child(rd)
		v.add_child(row)
		_sliders[key] = sl
		_readouts[key] = rd
	return sv[0]


func _colours_page() -> Control:
	var sv: Array = _scroll("Colours")
	var v: VBoxContainer = sv[1]
	for row_def in COLOURS:
		var key: String = row_def[0]
		if key == "":
			v.add_child(_label(String(row_def[1]), 300, "heading", Kit.UI_ACCENT))
			continue
		var row := HBoxContainer.new()
		row.add_child(_label(String(row_def[1]), 220))
		var pick := ColorPickerButton.new()
		pick.custom_minimum_size = Vector2(120, 20)
		pick.edit_alpha = false
		pick.color = colours[key]
		pick.color_changed.connect(func(c: Color) -> void: _colour_changed(key, c))
		row.add_child(pick)
		var hex := _label("#" + (colours[key] as Color).to_html(false), 70, "key", Color(1, 1, 1, 0.6))
		row.add_child(hex)
		v.add_child(row)
		_pickers[key] = [pick, hex]
	return sv[0]


func _show(key: String, v: float) -> String:
	if key == "renderer":
		return ["slice", "comb", "proj", "wire"][clampi(int(v), 0, 3)]
	return "%.2f" % v


func _changed(key: String, v: float) -> void:
	values[key] = v
	if _readouts.has(key):
		(_readouts[key] as Label).text = _show(key, v)
	_apply()


func _colour_changed(key: String, c: Color) -> void:
	colours[key] = c
	if _pickers.has(key):
		(_pickers[key][1] as Label).text = "#" + c.to_html(false)
	if maze_root != null:
		maze_root.call("apply_colours", {key: c})
		if key.begins_with("light:"):
			_apply()


func _apply() -> void:
	if maze_root != null:
		maze_root.call("apply_tuning", values)


func _reset_page() -> void:
	if _tabs.current_tab == 0:
		values = defaults()
		for k in _sliders:
			(_sliders[k] as HSlider).set_value_no_signal(float(values[k]))
			(_readouts[k] as Label).text = _show(k, float(values[k]))
		for k in _checks:
			(_checks[k] as CheckBox).set_pressed_no_signal(float(values[k]) > 0.5)
		_apply()
	else:
		colours = colour_defaults()
		for k in _pickers:
			(_pickers[k][0] as ColorPickerButton).color = colours[k]
			(_pickers[k][1] as Label).text = "#" + (colours[k] as Color).to_html(false)
		if maze_root != null:
			maze_root.call("apply_colours", colours)
		_apply()


func save_values() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("tuning", k, values[k])
	for k in colours:
		cfg.set_value("colours", k, colours[k])
	cfg.save(SAVE)


func toggle() -> void:
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED


func _process(_d: float) -> void:
	if visible:
		var u: float = get_viewport_rect().size.y / 720.0
		position = Vector2(22.0 * u, 130.0 * u)
