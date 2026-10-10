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

## [key, label, min, max, step, what it does]; ["", heading] starts a group. step >= 1 with max 1 is a
## switch. Round 3 (Ramon, 10 Oct: "some settings are not self-explanatory ... Sun Ambiance isn't
## immediately clear"): every row says in plain words what it changes, under a heading for its group.
const ROWS := [
	["", "CAMERA"],
	["chase_distance", "Camera distance", 1.5, 8.0, 0.1, "How far behind the walker the camera sits, in metres."],
	["chase_height", "Camera height", 0.8, 4.0, 0.05, "How high above his feet it looks from, in metres."],
	["chase_pitch", "Camera tilt", -60.0, 0.0, 0.5, "How steeply it looks down, in degrees. 0 is level."],
	["", "TURNING AND STEPPING THROUGH W"],
	["turn_seconds", "F turn duration", 0.1, 1.2, 0.01, "Seconds the quarter turn into W takes."],
	["settle", "Square the slice after a drag", 0.0, 1.0, 1.0, "On: letting go of the right mouse eases the slice to the nearest quarter turn."],
	["w_cyan", "Colour the walls across W", 0.0, 1.0, 1.0, "On: walls that stand across W get their own colour, so a turn shows which they are."],
	["w_step", "Q / E step speed", 0.1, 1.0, 0.05, "How fast Q and E move you through W, as a share of walking speed."],
	["", "4D SIGHT AND RENDERING"],
	["ghost", "4D sight ghosts (G)", 0.02, 1.0, 0.01, "How faint the next layer's walls are with G on. Lower shows them stronger."],
	["renderer", "Renderer", 0.0, 3.0, 1.0, "0 cross-section, 1 combined, 2 projected, 3 wireframe."],
	["", "SKY LIGHT"],
	["key_energy", "Sunlight strength", 0.0, 3.0, 0.01, "The main light from the sky: what shades one side of a wall darker than the other."],
	["ambient_k", "Shadow brightness", 0.0, 1.6, 0.01, "The soft fill light (ambient) that lifts the shadows. 0 leaves them black."],
	["exposure", "Overall exposure", 0.4, 2.0, 0.01, "Brightens or darkens the whole picture, like a camera's exposure."],
	["", "SPOT LIGHT OVER THE WALKER"],
	["spot_follows", "Spot follows the walker", 0.0, 1.0, 1.0, "Off: the spot stays where it last was."],
	["spot_bright", "Spot strength, bright mood", 0.0, 14.0, 0.1, "Used while the light is bright. B switches bright and dark."],
	["spot_dark", "Spot strength, dark mood", 0.0, 20.0, 0.1, "Used while the light is dark (B). It changes nothing in the bright mood."],
	["spot_angle", "Spot cone size", 8.0, 80.0, 0.5, "How wide the pool of light is: the cone's half angle in degrees."],
	["spot_softness", "Spot edge softness", 0.05, 6.0, 0.05, "Low: a crisp rim. Around 1: an even fade to the rim. Higher: a soft glow, bright only in the middle."],
	["spot_falloff", "Spot fade with distance", 0.0, 3.0, 0.05, "How quickly the spot dims as it reaches further. 0 hardly dims, 2 to 3 dims fast."],
	["spot_reach", "Spot reach", 6.0, 60.0, 0.5, "The furthest the spot reaches, in metres. Nothing beyond it is lit."],
	["spot_height", "Spot height", 4.0, 24.0, 0.25, "How high above the walker it hangs, in metres."],
	["", "FINDING YOUR WAY"],
	["layer_tint", "Floor tint by W layer", 0.0, 1.0, 0.01, "How strongly each W layer's floor takes its own colour (the W ruler shows the same colours). 0 turns it off."],
]

## [key, label] and headings ["", heading]. Keys: "sw:<swatch>" a surface, "role:<role>" the colour code,
## "light:<mood>:<field>" the sky and the light, "walker:<export>" the walker.
const COLOURS := [
	["", "THE MAZE"],
	["sw:maze_wall", "Walls"],
	["line:maze_wall", "Walls, grid lines"],
	["sw:maze_wall_w", "Walls across W"],
	["line:maze_wall_w", "Walls across W, grid lines"],
	["sw:maze_post", "Corner posts"],
	["sw:maze_cap", "Wall tops"],
	["sw:maze_floor", "Floor"],
	["line:maze_floor", "Floor, grid lines"],
	["sw:maze_climb", "Stairs and overlook"],
	["line:maze_climb", "Stairs, grid lines"],
	["sw:maze_roof", "Roofs"],
	["line:maze_roof", "Roofs, grid lines"],
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

## Looks to start from (round 3, Ramon, 10 Oct: "I'd like to experiment with a stronger, more graphic
## visual language ... dark blue surfaces with crisp white gridlines ... deep red surfaces with white
## gridlines ... less reliance on soft orange and yellow tones"). A preset sets the colours it names
## over the defaults; everything stays editable after, and SAVE keeps it. ROUND 2 is the defaults.
const PRESETS := {
	"ROUND 2": {},
	"BLUEPRINT": {
		"sw:maze_wall": Color(0.04, 0.09, 0.26), "line:maze_wall": Color(0.90, 0.94, 1.0),
		"sw:maze_wall_w": Color(0.90, 0.93, 0.98), "line:maze_wall_w": Color(0.14, 0.28, 0.62),
		"sw:maze_post": Color(0.03, 0.06, 0.16), "sw:maze_cap": Color(0.92, 0.95, 1.0),
		"sw:maze_floor": Color(0.02, 0.05, 0.14), "line:maze_floor": Color(0.62, 0.74, 0.98),
		"sw:maze_climb": Color(0.92, 0.27, 0.20), "line:maze_climb": Color(1.0, 0.86, 0.82),
		"sw:maze_roof": Color(0.06, 0.12, 0.32), "line:maze_roof": Color(0.86, 0.91, 1.0),
		"role:start": Color(1.0, 1.0, 1.0), "role:exit": Color(1.0, 0.32, 0.20), "role:w": Color(0.40, 0.70, 1.0),
		"role:ghost": Color(0.50, 0.75, 1.0), "role:trail": Color(0.92, 0.95, 1.0), "role:done": Color(0.32, 0.38, 0.52),
		"light:bright:key_color": Color(1.0, 1.0, 1.0), "light:bright:fill_color": Color(0.86, 0.91, 1.0),
		"light:bright:ambient": Color(0.56, 0.60, 0.70), "light:bright:sky_top": Color(0.52, 0.64, 0.86),
		"light:bright:sky_horizon": Color(0.88, 0.91, 0.96), "light:bright:sky_bottom": Color(0.62, 0.66, 0.76),
	},
	"SIGNAL RED": {
		"sw:maze_wall": Color(0.55, 0.07, 0.09), "line:maze_wall": Color(1.0, 0.92, 0.90),
		"sw:maze_wall_w": Color(0.95, 0.93, 0.92), "line:maze_wall_w": Color(0.62, 0.10, 0.12),
		"sw:maze_post": Color(0.26, 0.03, 0.05), "sw:maze_cap": Color(0.98, 0.95, 0.94),
		"sw:maze_floor": Color(0.22, 0.04, 0.06), "line:maze_floor": Color(0.95, 0.70, 0.70),
		"sw:maze_climb": Color(0.16, 0.36, 0.86), "line:maze_climb": Color(0.88, 0.92, 1.0),
		"sw:maze_roof": Color(0.42, 0.06, 0.08), "line:maze_roof": Color(1.0, 0.90, 0.90),
		"role:start": Color(1.0, 1.0, 1.0), "role:exit": Color(1.0, 0.97, 0.92), "role:w": Color(0.35, 0.62, 1.0),
		"role:ghost": Color(0.45, 0.68, 1.0), "role:trail": Color(1.0, 0.80, 0.80), "role:done": Color(0.40, 0.22, 0.24),
		"light:bright:key_color": Color(1.0, 1.0, 1.0), "light:bright:fill_color": Color(0.90, 0.92, 1.0),
		"light:bright:ambient": Color(0.58, 0.58, 0.64), "light:bright:sky_top": Color(0.60, 0.66, 0.80),
		"light:bright:sky_horizon": Color(0.92, 0.92, 0.94), "light:bright:sky_bottom": Color(0.70, 0.68, 0.70),
	},
}

var maze_root: Node
var values: Dictionary = {}
var colours: Dictionary = {}
var _sliders: Dictionary = {}
var _readouts: Dictionary = {}
var _checks: Dictionary = {}
var _pickers: Dictionary = {}
var _tabs: TabContainer
## Each number row's name label and plain name, so the spot strength in force can say IN USE.
var _names: Dictionary = {}
## Behind the panel while it is open: takes the clicks beside it, so a click there never grabs the
## mouse back for looking (the walker's rig recaptures it on any unhandled left click).
var _scrim: Control
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _mood_shown: String = ""


static func defaults() -> Dictionary:
	var l: Dictionary = Style.LIGHT
	return {"chase_distance": 3.6, "chase_height": 2.1, "chase_pitch": -24.0, "turn_seconds": 0.35, "settle": 0.0, "w_cyan": 1.0,
		"w_step": 0.3, "ghost": 0.3, "renderer": 0.0, "key_energy": l["key_energy"], "ambient_k": 1.0,
		"exposure": l["exposure"], "spot_follows": 1.0, "spot_bright": 3.0, "spot_dark": 9.0, "spot_angle": 30.0,
		"spot_softness": 1.2, "spot_falloff": 0.15, "spot_reach": 30.0, "spot_height": 10.0, "layer_tint": 0.4}


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
			"line":
				out[key] = Style.SWATCHES[p[1]][1]
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
	title.text = "TUNING  ·  TAB OR ESC CLOSES  ·  SAVE SETTINGS KEEPS YOUR CHANGES"
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
		var key: String = String(r[0])
		if key == "":
			var head := _label(String(r[1]), 300, "heading", Kit.UI_ACCENT)
			head.add_theme_constant_override("line_spacing", 0)
			v.add_child(head)
			continue
		var row := HBoxContainer.new()
		var name_label := _label(String(r[1]), 196)
		row.add_child(name_label)
		_names[key] = [name_label, String(r[1])]
		if float(r[4]) >= 1.0 and float(r[3]) == 1.0:
			var cb := CheckBox.new()
			cb.button_pressed = float(values[key]) > 0.5
			cb.toggled.connect(func(on: bool) -> void: _changed(key, 1.0 if on else 0.0))
			cb.tooltip_text = String(r[5])
			row.add_child(cb)
			v.add_child(row)
			v.add_child(_note(String(r[5])))
			_checks[key] = cb
			continue
		var sl := HSlider.new()
		sl.min_value = float(r[2])
		sl.max_value = float(r[3])
		sl.step = float(r[4])
		sl.custom_minimum_size = Vector2(150, 18)
		sl.value = float(values[key])
		sl.value_changed.connect(func(x: float) -> void: _changed(key, x))
		# A slider with focus would otherwise eat the arrow keys and leave the number keys to the game;
		# the game ignores keys while this panel is open (phase_maze_remake_4d.gd), so this is only tidy.
		sl.focus_mode = Control.FOCUS_CLICK
		sl.tooltip_text = String(r[5])
		row.add_child(sl)
		var rd := _label(_show(key, float(values[key])), 52, "key")
		row.add_child(rd)
		v.add_child(row)
		v.add_child(_note(String(r[5])))
		_sliders[key] = sl
		_readouts[key] = rd
	return sv[0]


## The row's one line of what it does, small and soft, under it.
func _note(text: String) -> Label:
	var l := _label(text, 400, "text", Color(1, 1, 1, 0.55))
	l.add_theme_font_size_override("font_size", 10)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(400, 0)
	return l


func _colours_page() -> Control:
	var sv: Array = _scroll("Colours")
	var v: VBoxContainer = sv[1]
	v.add_child(_label("START FROM A LOOK", 300, "heading", Kit.UI_ACCENT))
	var looks := HBoxContainer.new()
	looks.add_theme_constant_override("separation", 6)
	for preset_name in PRESETS:
		var b := Button.new()
		b.text = String(preset_name)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void: apply_preset(String(preset_name)))
		looks.add_child(b)
	v.add_child(looks)
	v.add_child(_note("Sets the maze's colours, the colour code and the bright sky. Tune from there; SAVE SETTINGS keeps it."))
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


## A preset over the defaults: every picker set, the scene recoloured, the light taken up.
func apply_preset(preset_name: String) -> void:
	# The walker keeps the colours he has: a look is the maze's, not his.
	var keep: Dictionary = {}
	for k in colours:
		if String(k).begins_with("walker:"):
			keep[k] = colours[k]
	colours = colour_defaults()
	for k in keep:
		colours[k] = keep[k]
	var p: Dictionary = PRESETS.get(preset_name, {})
	for k in p:
		if colours.has(k):
			colours[k] = p[k]
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


## Tab, F1 or Esc. Open: the cursor free, the clicks beside the panel taken. Closed: the mouse back as
## it was when it opened (captured for looking, or free if you were choosing a level).
func toggle() -> void:
	set_open(not visible)


func set_open(on: bool) -> void:
	if on == visible:
		return
	if on:
		_mouse_before = Input.mouse_mode
		visible = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		visible = false
		Input.mouse_mode = _mouse_before
	if _scrim == null and get_parent() != null:
		_scrim = Control.new()
		_scrim.name = "DevPanelScrim"
		_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		get_parent().add_child(_scrim)
		get_parent().move_child(_scrim, get_index())
	if _scrim != null:
		_scrim.visible = visible


func _process(_d: float) -> void:
	if visible:
		var u: float = get_viewport_rect().size.y / 720.0
		position = Vector2(22.0 * u, 130.0 * u)
		_mark_mood()


## "IN USE" beside the spot strength the light's mood is using.
func _mark_mood() -> void:
	var m: String = "bright"
	if maze_root != null:
		var light: Node = maze_root.get_node_or_null("Light")
		if light != null:
			m = String(light.get("mood"))
	if m == _mood_shown:
		return
	_mood_shown = m
	for key in ["spot_bright", "spot_dark"]:
		if not _names.has(key):
			continue
		var used: bool = (key == "spot_dark") == (m == "dark")
		var l: Label = _names[key][0]
		l.text = String(_names[key][1]) + ("  · IN USE" if used else "")
		l.add_theme_color_override("font_color", Kit.UI_ACCENT if used else Color(1, 1, 1, 0.9))
