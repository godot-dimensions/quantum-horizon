extends PanelContainer

## The open world's sea settings (Ramon, 9 Oct: "when i press tab can you give me ocean settings i can
## change and save"). Tab opens and closes it (the cursor comes free to drag); SAVE writes the numbers
## to SAVE_PATH, and the field starts from them. Black glass, the F1 dev panel's look (room/vl_dev_panel.gd).
##
##   WATER    how high it lies over the land's own sea level (how far it climbs the coasts), the waves
##            (Trym's presets) and their size, the fine ripple on top
##   COLOUR   the deep colour and how strongly the water sends it back, how clear it is, the sun's glint
##            and its softness, how hard it answers the light
##   REACH    how far the sea goes (a new grid, built when the slider settles), where the waves calm
##            toward the horizon
##
## THE ONE SEA COLOUR. The gallery's pedestals have no moving sea, only the generator's voxel water; it
## is painted in voxel_tint(), worked out from the saved deep colour, so the two seas stay one colour
## when this one is retuned (Ramon, 9 Oct: "the blue of the water of the voxel surface will have to
## match somehow to the big ocean").
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")
const WaterSurface := preload("res://ramon/VoxelLab/carried/water4d/water4d_surface.gd")

const SAVE_PATH := "res://ramon/VoxelLab/field/voxel_field_sea.cfg"
const FONT := 14
const HEAD := Color(0.42, 0.72, 1.0)
## Trym's open-sea absorption, which the clearness divides.
const ABSORPTION := Vector3(0.42, 0.11, 0.07)
## The defaults: the calm sea of 9 Oct, a kilometre out.
const DEFAULTS := {
	"level": 1.1, "preset": 0.0, "wave_scale": 0.4, "detail": 0.085,
	"deep_r": 0.035, "deep_g": 0.175, "deep_b": 0.205, "scatter": 0.21, "clear": 1.0, "glint": 0.35, "glint_soft": 0.08, "light": 1.0,
	"reach": 1000.0, "calm_from": 120.0, "calm_to": 320.0,
}
## How much brighter the voxel water is painted than the sea's deep colour, to read as the same sea in
## the gallery's light (its deep colour is what is left at depth; the pedestal's water is a lit surface).
const TINT_GAIN := 1.65

## The field (voxel_field_4d.gd): its `water`, and remake_sea() when the reach changes.
var field: Node
var _rows: Dictionary = {}
var _values: Dictionary = {}
var _pending: Dictionary = {}
var _box: VBoxContainer
var _preset_label: Label


## The saved numbers over the defaults (no panel needed: the field reads them as it starts).
static func saved() -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK and cf.has_section("sea"):
		for k in cf.get_section_keys("sea"):
			out[k] = float(cf.get_value("sea", k))
	return out


## The voxel water's colour, the sea's deep colour made a lit surface (the pedestals, the recipe).
static func voxel_tint() -> Color:
	var v: Dictionary = saved()
	return Color(clampf(float(v["deep_r"]) * TINT_GAIN, 0.0, 1.0), clampf(float(v["deep_g"]) * TINT_GAIN, 0.0, 1.0), clampf(float(v["deep_b"]) * TINT_GAIN, 0.0, 1.0))


## Every number onto a sea (the field's, as it starts, and the panel's live edits).
static func apply_all(water: Node, v: Dictionary) -> void:
	if water == null:
		return
	water.set("water_level", float(v["level"]))
	water.set("wave_scale", float(v["wave_scale"]))
	if int(water.get("preset_index")) != int(v["preset"]):
		water.call("set_preset", int(v["preset"]))
	water.set("detail_strength", float(v["detail"]))
	water.set("scatter_color", Color(float(v["deep_r"]), float(v["deep_g"]), float(v["deep_b"])))
	water.set("scatter_strength", float(v["scatter"]))
	water.set("absorption", ABSORPTION / maxf(float(v["clear"]), 0.05))
	water.set("specular_strength", float(v["glint"]))
	water.set("roughness", float(v["glint_soft"]))
	water.set("light_response", float(v["light"]))
	water.set("calm_from", float(v["calm_from"]))
	water.set("calm_to", maxf(float(v["calm_to"]), float(v["calm_from"]) + 10.0))


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", Style.glass_box(10.0, 1.0, 0.92))
	position = Vector2(16, 16)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	_values = saved()
	_title("THE OPEN WORLD  ·  THE SEA")
	_note("Tab closes. The numbers apply as you drag; SAVE keeps them.")
	_section("WATER")
	_row("level", "Height over the land's sea level, m", 0.0, 3.0, 0.05)
	_row("preset", "Waves", 0.0, float(WaterSurface.Presets.count() - 1), 1.0)
	_preset_label = Label.new()
	_preset_label.add_theme_font_size_override("font_size", FONT - 2)
	_preset_label.add_theme_color_override("font_color", Style.UI_INK_DIM)
	_box.add_child(_preset_label)
	_row("wave_scale", "Wave size", 0.05, 1.5, 0.01)
	_row("detail", "Fine ripple, m", 0.0, 0.3, 0.005)
	_section("COLOUR")
	_row("deep_r", "Deep colour, red", 0.0, 0.5, 0.005)
	_row("deep_g", "Deep colour, green", 0.0, 0.5, 0.005)
	_row("deep_b", "Deep colour, blue", 0.0, 0.5, 0.005)
	_row("scatter", "Colour strength", 0.0, 1.0, 0.01)
	_row("clear", "Clearness", 0.2, 3.0, 0.01)
	_row("glint", "Sun glint", 0.0, 1.0, 0.01)
	_row("glint_soft", "Glint softness", 0.02, 0.6, 0.01)
	_row("light", "Light response", 0.0, 2.0, 0.01)
	_section("REACH")
	_row("reach", "How far the sea goes, m", 150.0, 2000.0, 50.0)
	_row("calm_from", "Waves calm from, m", 20.0, 800.0, 5.0)
	_row("calm_to", "Flat calm by, m", 40.0, 1200.0, 5.0)
	var save := Button.new()
	save.text = "SAVE"
	save.add_theme_font_size_override("font_size", FONT)
	save.pressed.connect(save_now)
	_box.add_child(save)
	var reset := Button.new()
	reset.text = "Back to the defaults"
	reset.add_theme_font_size_override("font_size", FONT - 1)
	reset.pressed.connect(func() -> void:
		for k in DEFAULTS:
			_set_row(String(k), float(DEFAULTS[k]))
		_apply(true))
	_box.add_child(reset)
	_name_preset()


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
	l.add_theme_font_size_override("font_size", FONT - 1)
	line.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(120, 0)
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
		if key == "preset":
			_name_preset()
		if key == "reach":
			# A new grid: built once the slider has settled.
			_pending[key] = 0.4
		else:
			_apply(false))


func _set_row(key: String, x: float) -> void:
	if not _rows.has(key):
		return
	(_rows[key][0] as HSlider).set_value_no_signal(x)
	(_rows[key][1] as Label).text = _fmt(x, float(_rows[key][2]))
	_values[key] = x
	_name_preset()


func _name_preset() -> void:
	if _preset_label != null:
		_preset_label.text = "        " + WaterSurface.preset_name(int(_values.get("preset", 0.0)))


static func _fmt(x: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(round(x))
	if step >= 0.1:
		return "%.1f" % x
	if step >= 0.01:
		return "%.2f" % x
	return "%.3f" % x


## The numbers onto the field's sea; with `remake`, a new sea of the new reach first.
func _apply(remake: bool) -> void:
	if field == null:
		return
	if remake and absf(float(field.get("water").get("extent")) - float(_values["reach"])) > 1.0:
		field.call("remake_sea", float(_values["reach"]))
	apply_all(field.get("water"), _values)


func values() -> Dictionary:
	return _values


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


func save_now() -> void:
	var cf := ConfigFile.new()
	for k in _values:
		cf.set_value("sea", String(k), float(_values[k]))
	var err: int = cf.save(SAVE_PATH)
	if field != null and field.get("hud") != null:
		field.get("hud").call("toast", "Saved to %s" % SAVE_PATH.get_file() if err == OK else "Could not save (error %d)" % err)
