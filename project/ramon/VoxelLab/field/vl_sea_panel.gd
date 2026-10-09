extends Control

## The open world's settings on Tab (Ramon, 9 Oct: "when i press tab can you give me ocean settings i
## can change and save"; round 3: "make sure configured values can be saved as defaults"), in four windows
## since round 5 (Ramon: "create multiple windows in a logical fashion. right now its all one window"): THE SEA and
## SHORE FOAM down the left, LIGHT and LAND AND GRASS down the right, each with SAVE AS DEFAULTS. The light
## (since round 3, the Water Lab harbour's), the sea, the land. Tab opens and closes it (the cursor comes
## free to drag); SAVE AS DEFAULTS writes the numbers to SAVE_PATH, and the field starts from them.
## Black glass, the F1 dev panel's look (room/vl_dev_panel.gd).
##
## (The Water Lab is the Aquatic Lab on screen since 9 Oct: the four labs named alike, Voxel, Creature,
## Botany and Aquatic; its folder and these notes keep WaterLab.)
##
## ROUND 5 (#47: "use the same controls as the improved Water Lab Open World ... bring over the existing
## water presets ... switch between the water configurations and compare them in this scene"):
##
##   COMPARE    OURS (what is saved here) or THE WATER LAB'S (its harbour's saved water, read live from
##              WATER_LAB_SAVE, and the swell its harbour opens on): the sliders take the values, so
##              what you like of either can be saved as ours
##   SEA STATE  the Water Lab's eight presets as buttons (Calm, Moderate swell, Storm, Off-slice swell,
##              Short chop, Wind sea over swell, Sharp crests, Crossing seas), blended in half a second
##   WATER      the Water Lab panel's own eight, named and ranged as it has them (WATER_LAB_ROWS:
##              seascape_hud.gd WATER), and saved in its file's own [WATER] form, so a value means the
##              same in both labs
##   THIS SEA   ours alone: how high it lies over the land's own sea level, the Gerstner style (the
##              Water Lab's G key: 0 off, 1 to 3)
##   FOAM       the shore foam (#48: "reduce the foam intensity ... expose the foam intensity"): its
##              strength, how much of it only the crests bring, how deep it reaches, how far out it
##              has fallen to a third (field/vl_sea_4d.gd)
##   LIGHT      the sun's strength, height and turn, the ambient, the exposure
##   THE LAND   the island's green: hue, saturation, brightness (round 4)
##   GRASS      the experimental patches (#49), on or off, how wide and how tall a blade is, and the grass's
##              colour (Ramon, 9 Oct: "a grass size slider ... color coder for the grass color and save
##              function"; field.set_grass); how many patches, how big and how dense ("a slider ... that
##              informs the density and amount of the grass": the share of the ground covered, a patch's size,
##              the gap from blade to blade; field.set_grass_amount, the gap applied a moment after the drag
##              stops, as it builds the blades again); saved
##
## THE ONE SEA COLOUR. The gallery's pedestals have no moving sea, only the generator's voxel water; it
## is painted in voxel_tint(), worked out from the saved scatter colour, so the two seas stay one colour
## when this one is retuned (Ramon, 9 Oct: "the blue of the water of the voxel surface will have to
## match somehow to the big ocean").
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")
const WaterSurface := preload("res://ramon/WaterLab/carried/water4d/water4d_surface.gd")

const SAVE_PATH := "res://ramon/VoxelLab/field/voxel_field_sea.cfg"
## The Water Lab harbour's saved tuning, read (never written) for COMPARE.
const WATER_LAB_SAVE := "res://ramon/WaterLab/seascape/seascape_tuning.cfg"
## The swell the Water Lab's harbour opens on (seascape_4d.gd _ready).
const WATER_LAB_PRESET := 1
const FONT := 14
const WINDOW_W := 440.0
const HEAD := Color(0.42, 0.72, 1.0)
## The Water Lab panel's WATER rows, as it lists them (seascape_hud.gd): [property, min, max, step].
## scatter_color is a colour, absorption three numbers (r, g, b).
const WATER_LAB_ROWS := [["wave_scale", 0.0, 2.0, 0.001], ["detail_strength", 0.0, 0.3, 0.001], ["specular_strength", 0.0, 2.0, 0.001],
	["roughness", 0.0, 1.0, 0.001], ["light_response", 0.0, 3.0, 0.001], ["scatter_strength", 0.0, 1.0, 0.001]]
## The defaults: the calm sea of 9 Oct, the Water Lab's absorption; the land's green darker and greyer
## than round 3's (round 4); the shore foam at under half the Water Lab's (round 5).
const DEFAULTS := {
	"level": 1.1, "preset": 0.0, "gerstner": 2.0,
	"wave_scale": 0.4, "detail_strength": 0.085, "specular_strength": 0.35, "roughness": 0.08, "light_response": 1.0,
	"scatter_strength": 0.21, "scatter_r": 0.035, "scatter_g": 0.175, "scatter_b": 0.205,
	"absorption_r": 0.42, "absorption_g": 0.11, "absorption_b": 0.07,
	"shore_foam": 0.4, "shore_breakup": 0.65, "shore_width": 0.25, "shore_far": 160.0, "see_depth": 10.0, "foam_cell": 0.45,
	"land_h": 0.27, "land_s": 0.5, "land_v": 0.36,
	"sun": 0.064, "sun_up": 10.5, "sun_turn": 137.5, "ambient": 1.0, "exposure": 0.99,
	"grass": 1.0, "grass_width": 2.2, "grass_height": 0.7, "grass_r": 0.31, "grass_g": 0.49, "grass_b": 0.16,
	"grass_cover": 35.0, "grass_patch_m": 6.0, "grass_spacing_cm": 7.0, "trees": 1.0, "grass_whole": 0.0,
}
## The rows that rebuild something (the grass's patches and blades): applied a moment after the drag stops.
const DEFERRED := ["grass_spacing_cm"]
## How much brighter the voxel water is painted than the sea's deep colour, to read as the same sea in
## the gallery's light (its deep colour is what is left at depth; the pedestal's water is a lit surface).
const TINT_GAIN := 1.65

## The field (voxel_field_4d.gd): its `water`, apply_light(), apply_land() and set_grass().
var field: Node
var _rows: Dictionary = {}
var _values: Dictionary = {}
var _pending: Dictionary = {}
var _box: VBoxContainer
var _preset_buttons: Array = []
var _compare_label: Label
var _colour: ColorPickerButton
var _grass_box: CheckBox
var _trees_box: CheckBox
var _whole_box: CheckBox
var _grass_colour: ColorPickerButton


## The saved numbers over the defaults (no panel needed: the field reads them as it starts). The water
## in the Water Lab's own [WATER] form, the rest in [sea].
static func saved() -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return out
	if cf.has_section("sea"):
		for k in cf.get_section_keys("sea"):
			out[k] = float(cf.get_value("sea", k))
	if cf.has_section("WATER"):
		out.merge(from_water_section(cf), true)
	return out


## A [WATER] section (ours or the Water Lab's) as our flat numbers.
static func from_water_section(cf: ConfigFile) -> Dictionary:
	var out: Dictionary = {}
	for row in WATER_LAB_ROWS:
		if cf.has_section_key("WATER", String(row[0])):
			out[String(row[0])] = float(cf.get_value("WATER", String(row[0])))
	if cf.has_section_key("WATER", "scatter_color"):
		var c: Color = cf.get_value("WATER", "scatter_color")
		out.merge({"scatter_r": c.r, "scatter_g": c.g, "scatter_b": c.b}, true)
	if cf.has_section_key("WATER", "absorption"):
		var a: Vector3 = cf.get_value("WATER", "absorption")
		out.merge({"absorption_r": a.x, "absorption_g": a.y, "absorption_b": a.z}, true)
	return out


## The Water Lab harbour's water as it is saved now, with the swell it opens on.
static func water_lab() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(WATER_LAB_SAVE) != OK or not cf.has_section("WATER"):
		return {}
	var out: Dictionary = from_water_section(cf)
	out["preset"] = float(WATER_LAB_PRESET)
	return out


## The voxel water's colour, the sea's deep colour made a lit surface (the pedestals, the recipe).
static func voxel_tint() -> Color:
	var v: Dictionary = saved()
	return Color(clampf(float(v["scatter_r"]) * TINT_GAIN, 0.0, 1.0), clampf(float(v["scatter_g"]) * TINT_GAIN, 0.0, 1.0),
		clampf(float(v["scatter_b"]) * TINT_GAIN, 0.0, 1.0))


## Every number onto a sea (the field's, as it starts, and the panel's live edits).
static func apply_all(water: Node, v: Dictionary) -> void:
	if water == null:
		return
	water.set("water_level", float(v["level"]))
	if int(water.get("preset_index")) != int(v["preset"]):
		water.call("set_preset", int(v["preset"]))
	for row in WATER_LAB_ROWS:
		water.set(String(row[0]), float(v[String(row[0])]))
	water.set("scatter_color", Color(float(v["scatter_r"]), float(v["scatter_g"]), float(v["scatter_b"])))
	water.set("absorption", Vector3(float(v["absorption_r"]), float(v["absorption_g"]), float(v["absorption_b"])))
	# The Water Lab's Gerstner styles (its G key): 0 off (plain sines), 1 to 3 the styles.
	var gs: int = int(v.get("gerstner", 2.0))
	water.set("solve_iterations", 0 if gs == 0 else 2)
	if gs > 0:
		water.set("gerstner_style", gs)
	# The shore foam: only the Voxel Lab's sea has it (field/vl_sea_4d.gd).
	if water.get("shore_foam") != null:
		for k in ["shore_foam", "shore_breakup", "shore_width", "shore_far", "see_depth", "foam_cell"]:
			water.set(k, float(v[k]))


func _ready() -> void:
	visible = false
	# The whole screen, letting the mouse through; the windows stop it.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_values = saved()
	var left: VBoxContainer = _column(false)
	var right: VBoxContainer = _column(true)
	# THE SEA, left: what water it is, compared, its presets, the Aquatic Lab's eight, and ours.
	_window(left, "THE SEA", "Tab closes. The numbers apply as you drag; SAVE AS DEFAULTS keeps them all for next time.")
	_section("COMPARE")
	var cmp := HBoxContainer.new()
	cmp.add_child(_button("OURS", func() -> void: _load(saved(), "Ours, as saved")))
	cmp.add_child(_button("THE AQUATIC LAB'S", func() -> void:
		var wl: Dictionary = water_lab()
		if wl.is_empty():
			_say("The Aquatic Lab has no saved water yet")
		else:
			_load(wl, "The Aquatic Lab harbour's water")))
	_box.add_child(cmp)
	_compare_label = Label.new()
	_compare_label.add_theme_font_size_override("font_size", FONT - 2)
	_compare_label.add_theme_color_override("font_color", Style.UI_INK_DIM)
	_compare_label.text = "Ours, as saved"
	_box.add_child(_compare_label)
	_section("SEA STATE  ·  THE AQUATIC LAB'S PRESETS")
	var grid := GridContainer.new()
	grid.columns = 2
	for i in WaterSurface.Presets.count():
		var index: int = i
		var pb := _button("%d  %s" % [i + 1, WaterSurface.preset_name(i)], func() -> void:
			_values["preset"] = float(index)
			_name_preset()
			_apply(false))
		pb.toggle_mode = true
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_preset_buttons.append(pb)
		grid.add_child(pb)
	_box.add_child(grid)
	_section("WATER  ·  AS THE AQUATIC LAB HAS IT")
	for row in WATER_LAB_ROWS:
		_row(String(row[0]), String(row[0]).capitalize(), float(row[1]), float(row[2]), float(row[3]))
	_colour = _colour_row("Scatter Color", Color(float(_values["scatter_r"]), float(_values["scatter_g"]), float(_values["scatter_b"])), func(c: Color) -> void:
		_values.merge({"scatter_r": c.r, "scatter_g": c.g, "scatter_b": c.b}, true)
		_apply(false))
	_row("absorption_r", "Absorption r", 0.0, 1.0, 0.001)
	_row("absorption_g", "Absorption g", 0.0, 1.0, 0.001)
	_row("absorption_b", "Absorption b", 0.0, 1.0, 0.001)
	_section("THIS SEA")
	_row("level", "Height over the land's sea level, m", 0.0, 3.0, 0.05)
	_row("gerstner", "Gerstner (0 off, styles 1 to 3)", 0.0, 3.0, 1.0)
	_row("see_depth", "How deep you see into it, m", 2.0, 40.0, 0.5)
	_footer(true)
	# SHORE FOAM, left under it.
	_window(left, "SHORE FOAM", "")
	_row("shore_foam", "Strength (the Aquatic Lab's 0.9)", 0.0, 1.0, 0.01)
	_row("shore_breakup", "Only where crests come in", 0.0, 1.0, 0.01)
	_row("shore_width", "How wide the band is, m", 0.05, 1.5, 0.01)
	_row("foam_cell", "Bubble size, m", 0.1, 1.5, 0.01)
	_row("shore_far", "Down to a third by, m", 30.0, 600.0, 5.0)
	_footer(false)
	# LIGHT, right.
	_window(right, "LIGHT", "")
	_row("sun", "Sun strength", 0.0, 3.0, 0.005)
	_row("sun_up", "Sun height, degrees", 1.0, 89.0, 0.5)
	_row("sun_turn", "Sun turn, degrees", -180.0, 180.0, 0.5)
	_row("ambient", "Sky light (ambient)", 0.0, 2.0, 0.01)
	_row("exposure", "Exposure", 0.3, 2.5, 0.01)
	_footer(false)
	# LAND AND GRASS, right under it.
	_window(right, "LAND AND GRASS", "")
	_section("THE LAND")
	_row("land_h", "Green: hue", 0.0, 1.0, 0.005)
	_row("land_s", "Green: saturation", 0.0, 1.0, 0.01)
	_row("land_v", "Green: brightness", 0.0, 1.0, 0.01)
	_section("GRASS  ·  EXPERIMENTAL")
	_grass_box = CheckBox.new()
	_grass_box.text = "Grass on the island"
	_grass_box.focus_mode = Control.FOCUS_NONE
	_grass_box.button_pressed = float(_values.get("grass", 1.0)) > 0.5
	_grass_box.add_theme_font_size_override("font_size", FONT - 1)
	_grass_box.toggled.connect(func(on: bool) -> void:
		_values["grass"] = 1.0 if on else 0.0
		_apply(false))
	_box.add_child(_grass_box)
	_whole_box = CheckBox.new()
	_whole_box.text = "Fill the whole island (every ground, all of it)"
	_whole_box.focus_mode = Control.FOCUS_NONE
	_whole_box.button_pressed = float(_values.get("grass_whole", 0.0)) > 0.5
	_whole_box.add_theme_font_size_override("font_size", FONT - 1)
	_whole_box.toggled.connect(func(on: bool) -> void:
		_values["grass_whole"] = 1.0 if on else 0.0
		_apply(false))
	_box.add_child(_whole_box)
	_row("grass_cover", "Ground covered, %", 0.0, 100.0, 1.0)
	_row("grass_patch_m", "Patch size, m", 1.0, 40.0, 0.5)
	_row("grass_spacing_cm", "Blade to blade, cm", 3.0, 30.0, 0.5)
	_row("grass_width", "Blade width, times the pen's", 0.5, 4.0, 0.05)
	_row("grass_height", "Blade height, m", 0.15, 2.5, 0.01)
	_grass_colour = _colour_row("Grass colour", Color(float(_values["grass_r"]), float(_values["grass_g"]), float(_values["grass_b"])), func(c: Color) -> void:
		_values.merge({"grass_r": c.r, "grass_g": c.g, "grass_b": c.b}, true)
		_apply(false))
	(_grass_colour.get_parent() as HBoxContainer).add_child(_button("The pen's", func() -> void:
		_grass_colour.color = Color(float(DEFAULTS["grass_r"]), float(DEFAULTS["grass_g"]), float(DEFAULTS["grass_b"]))
		_values.merge({"grass_r": float(DEFAULTS["grass_r"]), "grass_g": float(DEFAULTS["grass_g"]), "grass_b": float(DEFAULTS["grass_b"])}, true)
		_apply(false)))
	_section("TREES")
	_trees_box = CheckBox.new()
	_trees_box.text = "Clumps of tiny 24-cells, as trees"
	_trees_box.focus_mode = Control.FOCUS_NONE
	_trees_box.button_pressed = float(_values.get("trees", 1.0)) > 0.5
	_trees_box.add_theme_font_size_override("font_size", FONT - 1)
	_trees_box.toggled.connect(func(on: bool) -> void:
		_values["trees"] = 1.0 if on else 0.0
		_apply(false))
	_box.add_child(_trees_box)
	_footer(false)
	_name_preset()


## A column of windows down one side of the screen, scrolling when they are taller than it.
func _column(on_right: bool) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	if on_right:
		scroll.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
		scroll.offset_left = -WINDOW_W - 32.0
		scroll.offset_right = -16.0
	else:
		scroll.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		scroll.offset_left = 16.0
		scroll.offset_right = WINDOW_W + 32.0
	scroll.offset_top = 16.0
	scroll.offset_bottom = -64.0
	add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)
	return col


## A window in `col`: black glass, its title and a line under it; what follows goes in it.
func _window(col: VBoxContainer, title: String, note: String) -> void:
	var w := PanelContainer.new()
	w.mouse_filter = Control.MOUSE_FILTER_STOP
	w.add_theme_stylebox_override("panel", Style.glass_box(10.0, 1.0, 0.92))
	w.custom_minimum_size = Vector2(WINDOW_W, 0)
	col.add_child(w)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.add_child(_box)
	_title(title)
	if not note.is_empty():
		_note(note)


## The foot of a window: SAVE AS DEFAULTS (everything, from any window) and, on the sea's, back to the built-in values.
func _footer(with_reset: bool) -> void:
	var line := HBoxContainer.new()
	var save := Button.new()
	save.text = "SAVE AS DEFAULTS"
	save.focus_mode = Control.FOCUS_NONE
	save.add_theme_font_size_override("font_size", FONT - 1)
	save.pressed.connect(save_now)
	line.add_child(save)
	if with_reset:
		line.add_child(_button("Back to the built-in values", func() -> void: _load(DEFAULTS, "The built-in values")))
	_box.add_child(line)


## A label and a colour picker; returns the picker.
func _colour_row(label: String, value: Color, on_change: Callable) -> ColorPickerButton:
	var line := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(210, 0)
	l.add_theme_font_size_override("font_size", FONT - 1)
	line.add_child(l)
	var c := ColorPickerButton.new()
	c.focus_mode = Control.FOCUS_NONE
	c.custom_minimum_size = Vector2(120, 24)
	c.edit_alpha = false
	c.color = value
	c.color_changed.connect(on_change)
	line.add_child(c)
	_box.add_child(line)
	return c


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FONT - 2)
	b.pressed.connect(on_press)
	return b


## Every slider to `v` (those it has), applied.
func _load(v: Dictionary, what: String) -> void:
	for k in v:
		_set_row(String(k), float(v[k]))
	if v.has("scatter_r") and _colour != null:
		_colour.color = Color(float(v["scatter_r"]), float(v["scatter_g"]), float(v["scatter_b"]))
		_values.merge({"scatter_r": float(v["scatter_r"]), "scatter_g": float(v["scatter_g"]), "scatter_b": float(v["scatter_b"])}, true)
	if v.has("preset"):
		_values["preset"] = float(v["preset"])
	if v.has("grass_r") and _grass_colour != null:
		_grass_colour.color = Color(float(v["grass_r"]), float(v["grass_g"]), float(v["grass_b"]))
		_values.merge({"grass_r": float(v["grass_r"]), "grass_g": float(v["grass_g"]), "grass_b": float(v["grass_b"])}, true)
	if v.has("grass_whole") and _whole_box != null:
		_whole_box.set_pressed_no_signal(float(v["grass_whole"]) > 0.5)
		_values["grass_whole"] = float(v["grass_whole"])
	if v.has("trees") and _trees_box != null:
		_trees_box.set_pressed_no_signal(float(v["trees"]) > 0.5)
		_values["trees"] = float(v["trees"])
	if v.has("grass") and _grass_box != null:
		_grass_box.set_pressed_no_signal(float(v["grass"]) > 0.5)
		_values["grass"] = float(v["grass"])
	if _compare_label != null:
		_compare_label.text = what
	_name_preset()
	_apply(true)


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", LabPrint.font("black"))
	l.add_theme_font_size_override("font_size", FONT + 2)
	_box.add_child(l)


func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", FONT - 2)
	l.add_theme_color_override("font_color", Style.UI_INK_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	_box.add_child(l)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", LabPrint.font("bold"))
	l.add_theme_font_size_override("font_size", FONT)
	l.add_theme_color_override("font_color", HEAD)
	_box.add_child(l)


func _row(key: String, label: String, lo: float, hi: float, step: float) -> void:
	var value: float = float(_values.get(key, DEFAULTS.get(key, lo)))
	var line := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(210, 0)
	l.clip_text = true
	l.add_theme_font_size_override("font_size", FONT - 1)
	line.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(120, 0)
	s.focus_mode = Control.FOCUS_NONE
	line.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(54, 0)
	v.add_theme_font_size_override("font_size", FONT - 1)
	v.text = _fmt(value, step)
	line.add_child(v)
	_box.add_child(line)
	_rows[key] = [s, v, step]
	s.value_changed.connect(func(x: float) -> void:
		v.text = _fmt(x, step)
		_values[key] = x
		if key in DEFERRED:
			_pending["grass_amount"] = 0.45
		else:
			_apply(false))


func _set_row(key: String, x: float) -> void:
	_values[key] = x
	if not _rows.has(key):
		return
	(_rows[key][0] as HSlider).set_value_no_signal(x)
	(_rows[key][1] as Label).text = _fmt(x, float(_rows[key][2]))


func _name_preset() -> void:
	var p: int = int(_values.get("preset", 0.0))
	for i in _preset_buttons.size():
		(_preset_buttons[i] as Button).set_pressed_no_signal(i == p)


static func _fmt(x: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(round(x))
	if step >= 0.1:
		return "%.1f" % x
	if step >= 0.01:
		return "%.2f" % x
	return "%.3f" % x


## The numbers onto the field's sea, its light, its land and its grass.
func _apply(_remake: bool) -> void:
	if field == null:
		return
	apply_all(field.get("water"), _values)
	field.call("apply_light", _values)
	field.call("apply_land", _values)
	if field.has_method("set_grass"):
		field.call("set_grass", float(_values.get("grass", 1.0)) > 0.5, float(_values.get("grass_width", 2.2)), float(_values.get("grass_height", 0.7)),
			Color(float(_values.get("grass_r", 0.31)), float(_values.get("grass_g", 0.49)), float(_values.get("grass_b", 0.16))))
	if field.has_method("set_grass_whole"):
		field.call("set_grass_whole", float(_values.get("grass_whole", 0.0)) > 0.5)
	if field.has_method("set_trees"):
		field.call("set_trees", float(_values.get("trees", 1.0)) > 0.5)
	if field.has_method("set_grass_amount"):
		field.call("set_grass_amount", float(_values.get("grass_cover", 35.0)), float(_values.get("grass_patch_m", 6.0)),
			float(_values.get("grass_spacing_cm", 7.0)))


func values() -> Dictionary:
	return _values


func _say(text: String) -> void:
	if field != null and field.get("hud") != null:
		field.get("hud").call("toast", text)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_TAB:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	for key in _pending.keys():
		_pending[key] = float(_pending[key]) - delta
		if float(_pending[key]) <= 0.0:
			_pending.erase(key)
			_apply(true)


## The water in the Water Lab's [WATER] form (the same names and types as its seascape_tuning.cfg), the
## rest in [sea].
func save_now() -> void:
	var cf := ConfigFile.new()
	var water_keys: Array = ["scatter_r", "scatter_g", "scatter_b", "absorption_r", "absorption_g", "absorption_b"]
	for row in WATER_LAB_ROWS:
		cf.set_value("WATER", String(row[0]), float(_values[String(row[0])]))
		water_keys.append(String(row[0]))
	cf.set_value("WATER", "scatter_color", Color(float(_values["scatter_r"]), float(_values["scatter_g"]), float(_values["scatter_b"])))
	cf.set_value("WATER", "absorption", Vector3(float(_values["absorption_r"]), float(_values["absorption_g"]), float(_values["absorption_b"])))
	for k in _values:
		if not String(k) in water_keys:
			cf.set_value("sea", String(k), float(_values[k]))
	var err: int = cf.save(SAVE_PATH)
	_say("Saved to %s" % SAVE_PATH.get_file() if err == OK else "Could not save (error %d)" % err)
