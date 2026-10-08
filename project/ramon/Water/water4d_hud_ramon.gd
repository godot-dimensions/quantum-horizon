extends Control

## Ramon's version of Trym's water readout (sandbox/water4d/water4d_hud.gd), on a dark see-through
## backing with larger type, and with a second mode for every light and environment property.
##
## Tab steps through three modes:
##   READOUT      the controls, the sea that is running (its dominant wave), how far the slice is
##                turned, where you stand
##   LIGHT        every property of the sun, the environment, the sky, the clouds and the water's look,
##                built from the engine's own property lists (the sun's direction as three angles);
##                SAVE writes them to water_ramon_tuning.cfg and the scene reads that back when it
##                opens; RESET puts back what the scene opened with. The mouse is freed here.
##   HIDDEN
##
## SIZE. The project does not stretch its UI with the window, so Trym's 16 px label was a sliver on a
## 4K screen. Here the type follows the window's height (22 px at 1080, 44 at 2160) times the HUD
## size slider at the top of the LIGHT mode.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/Water/carried/LabKit/lab_print.gd")
const Presets := preload("res://ramon/Water/carried/water4d/water4d_presets.gd")

const SAVE_PATH := "res://ramon/Water/water_ramon_tuning.cfg"
const BASE_PX := 22.0
const HEAD := Color(0.42, 0.72, 1.0)
## Properties of the objects that are not light or look (placement, editor-only, the shader's own
## uniform copies), left out of the LIGHT mode.
const SKIP := ["position", "rotation_degrees", "scale", "rotation_edit_mode", "should_notify_local_transform",
	"current", "sky_material", "cloud_material", "resource_local_to_scene", "resource_path", "resource_name"]
## The water's look: plain script variables on the surface (not editor properties), pushed to its
## shader every frame, so they are listed here with their ranges.
const WATER := [["wave_scale", 0.0, 2.0], ["detail_strength", 0.0, 0.3], ["specular_strength", 0.0, 2.0],
	["roughness", 0.0, 1.0], ["light_response", 0.0, 3.0], ["scatter_strength", 0.0, 1.0], ["scatter_color", 0, 0],
	["absorption", 0.0, 1.0]]

## The scene's root (water4d_test_ramon_4d.gd); it sets this.
var room: Node
var mode: int = 0
var hud_size: float = 1.0

var _readout_box: PanelContainer
var _readout: Label
var _editor_box: PanelContainer
var _editor_list: VBoxContainer
var _scroll: ScrollContainer
var _theme := Theme.new()
var _last_h: float = -1.0
## What the scene opened with, for RESET: {section: {property: value}}.
var _initial: Dictionary = {}
var _toast: Label
var _toast_left: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _theme
	_theme.default_font = LabPrint.font("body")
	_readout_box = _backing()
	add_child(_readout_box)
	_readout = Label.new()
	_readout_box.add_child(_readout)
	_editor_box = _backing()
	_editor_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_editor_box)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_editor_box.add_child(_scroll)
	_editor_list = VBoxContainer.new()
	_editor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_editor_list)
	_editor_box.visible = false
	_toast = Label.new()
	# Sized to the screen's width and centred every frame (_process), so a long line never runs
	# off one side or sits over the readout.
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(_toast)
	(func() -> void:
		_snapshot()
		load_tuning()).call_deferred()


## The dark see-through backing every panel of this HUD sits on.
func _backing() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.03, 0.05, 0.66)
	s.set_corner_radius_all(12)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 12.0
	s.content_margin_bottom = 14.0
	p.add_theme_stylebox_override("panel", s)
	p.position = Vector2(16, 16)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _u() -> float:
	return maxf(get_viewport_rect().size.y / 1080.0, 0.5) * hud_size


func _px(f: float = 1.0) -> int:
	return int(round(BASE_PX * f * _u()))


func _process(delta: float) -> void:
	_toast_left = maxf(_toast_left - delta, 0.0)
	_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)
	var vw: float = get_viewport_rect().size.x
	_toast.position = Vector2(0.0, get_viewport_rect().size.y * 0.16)
	_toast.size = Vector2(vw, 0.0)
	var h: float = get_viewport_rect().size.y * hud_size
	if not is_equal_approx(h, _last_h):
		_last_h = h
		_theme.default_font_size = _px(0.82)
		_readout.add_theme_font_size_override("font_size", _px())
		_readout_box.position = Vector2(16, 16) * _u()
		_editor_box.position = Vector2(16, 16) * _u()
		_scroll.custom_minimum_size = Vector2(620.0 * _u(), get_viewport_rect().size.y - 64.0 * _u())
		_toast.add_theme_font_size_override("font_size", _px(1.1))
		_toast.add_theme_constant_override("outline_size", int(6 * _u()))
	_readout_box.visible = mode == 0
	_editor_box.visible = mode == 1
	if mode == 0:
		_readout.text = _readout_text()


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_TAB:
		return
	mode = (mode + 1) % 3
	if mode == 1:
		_build_editor()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_viewport().set_input_as_handled()


# -- the readout ------------------------------------------------------------------------------------------

func _readout_text() -> String:
	var water: Node = room.get_node_or_null("Water") if room != null else null
	if water == null:
		return ""
	var d: Dictionary = water.call(&"dominant")
	var index: int = int(water.get(&"preset_index"))
	var iterations: int = int(water.get(&"solve_iterations"))
	var solve: String = ("%d iterations" % iterations) if iterations > 0 else "off (plain sines)"
	var turn: Vector2 = room.call("slice_degrees") if room.has_method("slice_degrees") else Vector2.ZERO
	var where: String = String(room.call("where_text")) if room.has_method("where_text") else ""
	# THE BRACKETS MATTER (Trym's note): `+` binds tighter than `%`.
	var layout := ("WASD walk   Shift sprint   Mouse look   P the other pier   Tab light and environment\n"
			+ "On a circle: right drag turns the slice, R levels it\n"
			+ "1-8 seas   F foam map   G Gerstner on/off   N detail noise   Esc free the cursor\n"
			+ "%d. %s    amplitude %.2f m   wavelength %.1f m   steepness %.2f   off W %.2f\n"
			+ "solve %s    slice turned %.0f / %.0f°    %d fps%s")
	return layout % [index + 1, Presets.preset_name(index), float(d["amplitude"]), float(d["wavelength"]),
			float(d["steepness"]), float(d["off_slice"]), solve, turn.x, turn.y, Engine.get_frames_per_second(),
			("\n" + where) if not where.is_empty() else ""]


# -- what can be edited -------------------------------------------------------------------------------------

## [section name, object, kind]: kind "props" lists the object's editor properties, "water" the
## surface's look variables.
func _targets() -> Array:
	if room == null:
		return []
	var out: Array = []
	var sun: Node = room.get_node_or_null("Sun")
	var env: Node = room.get_node_or_null("Environment")
	var water: Node = room.get_node_or_null("Water")
	if sun != null:
		out.append(["SUN", sun, "props"])
	if env != null:
		out.append(["ENVIRONMENT", env, "props"])
		if env.get("sky_material") != null:
			out.append(["SKY", env.get("sky_material"), "props"])
		if env.get("cloud_material") != null:
			out.append(["CLOUDS", env.get("cloud_material"), "props"])
	if water != null:
		out.append(["WATER", water, "water"])
	return out


## The editable properties of `obj`: [{name, type, hint, hint_string}].
func _props(obj: Object, kind: String) -> Array:
	var out: Array = []
	if kind == "water":
		for row in WATER:
			var v: Variant = obj.get(String(row[0]))
			if v == null:
				continue
			out.append({"name": String(row[0]), "type": typeof(v), "hint": PROPERTY_HINT_RANGE,
				"hint_string": "%s,%s,0.001" % [str(row[1]), str(row[2])]})
		return out
	for p in obj.get_property_list():
		var nm: String = String(p["name"])
		if (int(p["usage"]) & PROPERTY_USAGE_EDITOR) == 0 or nm in SKIP or nm.begins_with("shader_parameter/"):
			continue
		# Node's own plumbing, not light or look.
		if nm.begins_with("process_") or nm in ["physics_interpolation_mode", "auto_translate_mode", "editor_description"]:
			continue
		if int(p["type"]) in [TYPE_FLOAT, TYPE_INT, TYPE_BOOL, TYPE_COLOR, TYPE_VECTOR4, TYPE_VECTOR3]:
			out.append(p)
	return out


func _snapshot() -> void:
	_initial.clear()
	for t in _targets():
		var vals: Dictionary = {}
		for p in _props(t[1], String(t[2])):
			vals[String(p["name"])] = t[1].get(String(p["name"]))
		if String(t[0]) == "SUN":
			vals["basis"] = (t[1] as Node4D).basis
		_initial[String(t[0])] = vals


# -- the editor ---------------------------------------------------------------------------------------------

func _build_editor() -> void:
	for c in _editor_list.get_children():
		c.queue_free()
	_title("LIGHT AND ENVIRONMENT  ·  TAB")
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(10 * _u()))
	_editor_list.add_child(bar)
	for b in [["SAVE", save_tuning], ["RESET", reset_tuning], ["CLOSE", _close]]:
		var btn := Button.new()
		btn.text = String(b[0])
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(b[1])
		bar.add_child(btn)
	var on_size := func(x: float) -> void:
		hud_size = x
		_last_h = -1.0
	_slider_row("HUD size", 0.6, 2.0, 0.01, hud_size, on_size, false, "")
	for t in _targets():
		_section(String(t[0]))
		var obj: Object = t[1]
		if String(t[0]) == "SUN":
			_sun_rows(obj as Node4D)
		for p in _props(obj, String(t[2])):
			_prop_row(obj, p)


func _close() -> void:
	mode = 2
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", LabPrint.font("black"))
	l.add_theme_font_size_override("font_size", _px(1.0))
	_editor_list.add_child(l)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", LabPrint.font("bold"))
	l.add_theme_color_override("font_color", HEAD)
	l.add_theme_font_size_override("font_size", _px(0.9))
	_editor_list.add_child(l)


## A label column, the control, and the value printed after it.
func _line(label: String) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", int(8 * _u()))
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(250.0 * _u(), 0.0)
	l.clip_text = true
	line.add_child(l)
	_editor_list.add_child(line)
	return line


func _slider_row(label: String, lo: float, hi: float, step: float, value: float, on_change: Callable, exp_edit: bool, unit: String) -> HSlider:
	var line: HBoxContainer = _line(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.exp_edit = exp_edit and lo > 0.0
	s.allow_greater = true
	s.allow_lesser = true
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(230.0 * _u(), 0.0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(s)
	var v := Label.new()
	v.text = _fmt(value, step) + unit
	line.add_child(v)
	var changed := func(x: float) -> void:
		v.text = _fmt(x, step) + unit
		on_change.call(x)
	s.value_changed.connect(changed)
	return s


static func _fmt(x: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(round(x))
	if step >= 0.01:
		return "%.2f" % x
	return "%.4f" % x


## One property, by its type and hint.
func _prop_row(obj: Object, p: Dictionary) -> void:
	var nm: String = String(p["name"])
	var label: String = nm.replace("_", " ")
	var v: Variant = obj.get(nm)
	match int(p["type"]):
		TYPE_BOOL:
			var line: HBoxContainer = _line(label)
			var c := CheckBox.new()
			c.button_pressed = bool(v)
			c.focus_mode = Control.FOCUS_NONE
			c.toggled.connect(func(on: bool) -> void: obj.set(nm, on))
			line.add_child(c)
		TYPE_COLOR:
			var line: HBoxContainer = _line(label)
			var c := ColorPickerButton.new()
			c.color = v
			c.edit_alpha = false
			c.focus_mode = Control.FOCUS_NONE
			c.custom_minimum_size = Vector2(120.0 * _u(), 26.0 * _u())
			c.color_changed.connect(func(col: Color) -> void: obj.set(nm, col))
			line.add_child(c)
		TYPE_INT:
			if int(p["hint"]) == PROPERTY_HINT_ENUM:
				var line: HBoxContainer = _line(label)
				var o := OptionButton.new()
				o.focus_mode = Control.FOCUS_NONE
				var items: PackedStringArray = String(p["hint_string"]).split(",")
				for i in items.size():
					o.add_item(items[i].split(":")[0], i)
				o.selected = int(v)
				o.item_selected.connect(func(i: int) -> void: obj.set(nm, i))
				line.add_child(o)
			else:
				var r: Array = _range(p, float(v))
				_slider_row(label, r[0], r[1], 1.0, float(v), func(x: float) -> void: obj.set(nm, int(x)), false, "")
		TYPE_FLOAT:
			var r: Array = _range(p, float(v))
			var hs: String = String(p["hint_string"])
			if hs.contains("radians_as_degrees"):
				_slider_row(label, r[0], r[1], r[2], rad_to_deg(float(v)), func(x: float) -> void: obj.set(nm, deg_to_rad(x)), false, "°")
			else:
				_slider_row(label, r[0], r[1], r[2], float(v), func(x: float) -> void: obj.set(nm, x), bool(r[3]), "")
		TYPE_VECTOR4, TYPE_VECTOR3:
			var n: int = 4 if int(p["type"]) == TYPE_VECTOR4 else 3
			var axes: Array = ["x", "z", "w"] if (n == 3 and nm == "absorption") else ["x", "y", "z", "w"]
			var r: Array = _range(p, 0.0)
			for i in n:
				var axis: int = i
				var lo: float = r[0] if nm == "absorption" else -maxf(30.0, absf(float(v[i])) * 2.0)
				var hi: float = r[1] if nm == "absorption" else maxf(30.0, absf(float(v[i])) * 2.0)
				var set_axis := func(x: float) -> void:
					var cur: Variant = obj.get(nm)
					cur[axis] = x
					obj.set(nm, cur)
				var axis_name: String = ["r", "g", "b"][i] if nm == "absorption" else String(axes[i])
				_slider_row("%s %s" % [label, axis_name], lo, hi, 0.001 if nm == "absorption" else 0.1, float(v[i]), set_axis, false, "")


## [min, max, step, exp] from a property's hint.
static func _range(p: Dictionary, v: float) -> Array:
	var hint: int = int(p["hint"])
	if hint == PROPERTY_HINT_RANGE:
		var parts: PackedStringArray = String(p["hint_string"]).split(",")
		if parts.size() >= 2:
			var step: float = float(parts[2]) if parts.size() >= 3 and parts[2].is_valid_float() else 0.001
			return [float(parts[0]), float(parts[1]), maxf(step, 0.0001), "exp" in parts]
	if hint == PROPERTY_HINT_EXP_EASING:
		return [0.001, 4.0, 0.001, true]
	return [0.0, maxf(absf(v) * 2.0, 1.0), 0.001, false]


# -- the sun's direction --------------------------------------------------------------------------------------

## The sun as three angles: its height over the horizon, its turn round the up axis, and how far it
## leans into W. The light travels along its basis's -Z (Trym's sun: z column up and toward the
## camera), so the sun itself is along +Z.
func _sun_rows(sun: Node4D) -> void:
	var a: Vector3 = sun_angles(sun)
	var rows: Array = [["sun height", 1.0, 89.0, a.x], ["sun turn", -180.0, 180.0, a.y], ["sun through W", -80.0, 80.0, a.z]]
	for i in 3:
		var which: int = i
		var set_angle := func(x: float) -> void:
			var cur: Vector3 = sun_angles(sun)
			cur[which] = x
			set_sun_angles(sun, cur)
		_slider_row(String(rows[i][0]), float(rows[i][1]), float(rows[i][2]), 0.5, float(rows[i][3]), set_angle, false, "°")


## Degrees: (height, turn, through W).
static func sun_angles(sun: Node4D) -> Vector3:
	var s: Vector4 = (sun.basis.z as Vector4).normalized()
	var flat: float = Vector2(s.x, s.z).length()
	return Vector3(rad_to_deg(asin(clampf(s.y, -1.0, 1.0))), rad_to_deg(atan2(s.x, s.z)), rad_to_deg(atan2(s.w, flat)))


static func set_sun_angles(sun: Node4D, deg: Vector3) -> void:
	var h: float = deg_to_rad(deg.x)
	var t: float = deg_to_rad(deg.y)
	var a: float = deg_to_rad(deg.z)
	var s := Vector4(cos(h) * sin(t) * cos(a), sin(h), cos(h) * cos(t) * cos(a), cos(h) * sin(a))
	sun.basis = Basis4D.looking_at(-s)


# -- save and reset -------------------------------------------------------------------------------------------

func save_tuning() -> void:
	var cf := ConfigFile.new()
	for t in _targets():
		var sec: String = String(t[0])
		for p in _props(t[1], String(t[2])):
			cf.set_value(sec, String(p["name"]), t[1].get(String(p["name"])))
		if sec == "SUN":
			cf.set_value(sec, "angles", sun_angles(t[1] as Node4D))
	cf.set_value("HUD", "size", hud_size)
	var err: int = cf.save(SAVE_PATH)
	_flash("Saved to %s" % SAVE_PATH.get_file() if err == OK else "Could not save (%d)" % err)


## The saved values, if there are any, over what the scene opened with.
func load_tuning() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	hud_size = float(cf.get_value("HUD", "size", hud_size))
	_last_h = -1.0
	for t in _targets():
		var sec: String = String(t[0])
		if not cf.has_section(sec):
			continue
		for key in cf.get_section_keys(sec):
			if key == "angles":
				set_sun_angles(t[1] as Node4D, cf.get_value(sec, key))
			elif t[1].get(key) != null:
				t[1].set(key, cf.get_value(sec, key))


func reset_tuning() -> void:
	for t in _targets():
		var vals: Dictionary = _initial.get(String(t[0]), {})
		for key in vals:
			if key == "basis":
				(t[1] as Node4D).basis = vals[key]
			else:
				t[1].set(key, vals[key])
	_build_editor()
	_flash("Back to the scene's own values")


## A line at the top of the screen for a moment (SAVE, RESET, P).
func _flash(text: String) -> void:
	_toast.text = text
	_toast_left = 2.5


func toast(text: String) -> void:
	_flash(text)
