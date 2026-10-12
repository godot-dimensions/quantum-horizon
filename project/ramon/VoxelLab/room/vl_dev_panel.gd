extends PanelContainer

## The Voxel Lab's artist dev panel (F1), after the Arboretum's (room/arb_dev_panel.gd there) and the
## Creation Lab's tuner: black glass, every number in the room worth turning, and SAVE, which writes
## them to SAVE_PATH; the panel reads that back when the room starts, so what was saved is where the
## room begins.
##
## Its defaults are Ramon's own saved Creation Lab light (CreationLab/creation_lab_tuning.cfg, 5 Oct:
## spots x3.26, sky fill x1.52, sun x0.66 at 64 degrees up and 25 round, exposure 1.05), so the Voxel
## Lab starts in the lab's light (startup.md, "one look across all prototypes").
##
##   LIGHT      the spots, the sky fill (the blue in every shadow), the sun's strength, height and
##              turn, the exposure, and how much of the fill stays in the black palette
##   SPECIMENS  the pedestals' height, the turntables' speed
##   CUTTING    the swap (new chunks drawable from a worker thread) for every specimen, the chunk
##              outlines that flash on a cut, how many quiet frames a swap waits
##   HALL       the hall's plan: half width, entrance and back walls, the panel walls' length and
##              angle, its height, the gallery door
##
##   LIGHTS     (its own page, 9 Oct) a top view of the corridor, hall and gallery with every light on
##              it: click one to pick it, drag it to move it; the hall's and the gallery's sliders,
##              specimens A, B and C's own strength, and the picked light's own (vl_lights.gd)
##
## Esc frees the mouse to drag; F1 hides it. Rows that rebuild something wait for the slider to settle.
## SAVE writes both pages (the lights to their own file).
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")
const LightMap := preload("res://ramon/VoxelLab/room/vl_light_map.gd")

const SAVE_PATH := "res://ramon/VoxelLab/voxel_lab_tuning.cfg"
const FONT := 14
const HEAD := Color(0.42, 0.72, 1.0)

var room: Node
var _rows: Dictionary = {}
var _values: Dictionary = {}
var _pending: Dictionary = {}
var _lengths: Label
var _box: VBoxContainer
var _settings_box: VBoxContainer
var _lights_box: VBoxContainer
var _map: Control
var _sel_label: Label
## The room's light rig (vl_lights.gd), if it has one.
var _rig: Node


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", Style.glass_box(10.0, 1.0, 0.92))
	position = Vector2(16, 16)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	_box = pages
	_title("VOXEL LAB  ·  ARTIST DEV PANEL")
	var tabs := HBoxContainer.new()
	pages.add_child(tabs)
	_settings_box = VBoxContainer.new()
	_settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_child(_settings_box)
	_lights_box = VBoxContainer.new()
	_lights_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lights_box.visible = false
	pages.add_child(_lights_box)
	for t in [["SETTINGS", _settings_box], ["LIGHTS", _lights_box]]:
		var b := Button.new()
		b.text = String(t[0])
		b.toggle_mode = true
		b.button_pressed = t[1] == _settings_box
		b.add_theme_font_size_override("font_size", FONT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		b.pressed.connect(func() -> void:
			_settings_box.visible = t[1] == _settings_box
			_lights_box.visible = t[1] == _lights_box
			for o in tabs.get_children():
				(o as Button).set_pressed_no_signal(o == b))
	_box = _settings_box
	_section("LIGHT")
	_row("spots", "Spots, all of them (x)", 0.0, 6.0, 0.01, 3.26)
	_row("fill", "Sky fill (shadows)", 0.0, 3.0, 0.01, 1.52)
	_row("sun", "Sun strength", 0.0, 3.0, 0.01, 0.66)
	_row("sun_up", "Sun height, degrees", 5.0, 90.0, 0.5, 64.0)
	_row("sun_turn", "Sun turn, degrees", -180.0, 180.0, 0.5, 25.0)
	_row("exposure", "Exposure", 0.4, 2.5, 0.01, 1.05)
	_row("black_fill", "Black palette: fill kept", 0.0, 1.5, 0.01, 0.55)
	_section("SPECIMENS")
	_row("ped_h", "Pedestal height, m", 0.3, 1.8, 0.01, 0.9)
	_row("turn", "Turntable, degrees a second", 0.0, 20.0, 0.1, 5.0)
	_section("CUTTING")
	_row("swap", "Draw buffers on a worker (1) or in the frame (0)", 0.0, 1.0, 1.0, 1.0)
	_row("flash", "Chunk outlines on a cut (1 on)", 0.0, 1.0, 1.0, 0.0)
	_row("settle", "Swap: quiet frames before showing", 1.0, 8.0, 1.0, 3.0)
	_section("HALL")
	for r in [["room_half_width", "Half width, m", 8.0, 30.0], ["room_front", "Entrance wall from middle, m", 6.0, 30.0],
			["room_back", "Back wall from middle, m", 6.0, 40.0], ["corner_length", "Panel walls' length, m", 0.0, 20.0],
			["corner_angle", "Panel walls' angle, degrees", 5.0, 85.0], ["hall_height", "Height, m", 6.0, 20.0], ["door_width", "Gallery door, m", 0.0, 8.0]]:
		_row(String(r[0]), String(r[1]), float(r[2]), float(r[3]), 0.1, float(room.get(String(r[0]))) if room != null else 10.0)
	_lengths = Label.new()
	_lengths.add_theme_font_size_override("font_size", FONT - 2)
	_lengths.add_theme_color_override("font_color", Style.UI_INK_DIM)
	_lengths.autowrap_mode = TextServer.AUTOWRAP_WORD
	_box.add_child(_lengths)
	_build_lights_page()
	_box = pages
	var save := Button.new()
	save.text = "SAVE  (both pages)"
	save.add_theme_font_size_override("font_size", FONT)
	save.pressed.connect(save_now)
	_box.add_child(save)
	_load()
	# The light starts as the rows say (the lab's saved numbers, or this room's own once saved).
	for k in ["spots", "fill", "sun", "exposure", "sun_up", "turn"]:
		apply(k)


## The LIGHTS page: the top view, the rooms' sliders, A, B and C, and the picked light's own.
func _build_lights_page() -> void:
	_rig = room.get("lights") if room != null else null
	_box = _lights_box
	if _rig == null:
		_section("No light rig in this room")
		return
	_map = Control.new()
	_map.set_script(LightMap)
	_map.set("rig", _rig)
	_map.set("room", room)
	_box.add_child(_map)
	_map.connect("picked", _on_picked)
	var rooms: Dictionary = _rig.get("rooms")
	for r in [["hall", "HALL (every light in it)"], ["gallery", "GALLERY (every light in it)"]]:
		_section(String(r[1]))
		var vals: Dictionary = rooms[r[0]]
		_row("lt/%s/strength" % r[0], "Strength", 0.0, 8.0, 0.01, float(vals["strength"]))
		_row("lt/%s/cone" % r[0], "Cone, degrees", 8.0, 90.0, 0.5, float(vals["cone"]))
		_row("lt/%s/softness" % r[0], "Softness", 0.1, 8.0, 0.05, float(vals["softness"]))
		_row("lt/%s/height" % r[0], "Height, m", 3.0, 8.9, 0.05, float(vals["height"]))
		if r[0] == "hall":
			var groups: Dictionary = _rig.get("groups")
			for g in ["A", "B", "C"]:
				_row("lt/group/%s" % g, "Specimen %s strength" % g, 0.0, 8.0, 0.01, float(groups[g]))
	_section("THE PICKED LIGHT (click one on the map)")
	_sel_label = Label.new()
	_sel_label.text = "none picked"
	_sel_label.add_theme_font_size_override("font_size", FONT - 1)
	_sel_label.add_theme_color_override("font_color", Style.UI_INK_DIM)
	_box.add_child(_sel_label)
	_row("lt/own/strength_k", "Its strength (x the room's)", 0.0, 4.0, 0.01, 1.0)
	_row("lt/own/cone", "Its cone, degrees", 8.0, 90.0, 0.5, 34.0)
	_row("lt/own/softness", "Its softness", 0.1, 8.0, 0.05, 2.6)
	_row("lt/own/height", "Its height, m", 3.0, 8.9, 0.05, 8.2)
	var reset := Button.new()
	reset.text = "Back to the room's values"
	reset.add_theme_font_size_override("font_size", FONT - 1)
	reset.pressed.connect(func() -> void:
		var n: String = String(_map.get("selected"))
		if not n.is_empty():
			_rig.call("reset_own", n)
			_on_picked(n))
	_box.add_child(reset)


func _on_picked(n: String) -> void:
	var l: Node = _rig.call("light", n)
	if l == null:
		return
	var e: Dictionary = _rig.call("effective", l)
	var mine: Dictionary = (_rig.get("own") as Dictionary).get(n, {})
	_sel_label.text = "%s  ·  lights %s  ·  at x %.1f, z %.1f" % [n, String(l.get_meta("item", "")), float(e["x"]), float(e["z"])]
	for k in [["strength_k", float(mine.get("strength_k", 1.0))], ["cone", float(e["cone"])], ["softness", float(e["softness"])], ["height", float(e["height"])]]:
		var key: String = "lt/own/" + String(k[0])
		(_rows[key][0] as HSlider).set_value_no_signal(float(k[1]))
		(_rows[key][1] as Label).text = _fmt(float(k[1]), float(_rows[key][2]))
		_values[key] = float(k[1])


## A light row, applied at once (the map and the room follow the slider as it moves).
func _apply_light(key: String, x: float) -> void:
	if _rig == null:
		return
	var parts: PackedStringArray = key.split("/")
	match parts[1]:
		"group":
			_rig.call("set_group", parts[2], x)
		"own":
			var n: String = String(_map.get("selected")) if _map != null else ""
			if not n.is_empty():
				_rig.call("set_own", n, parts[2], x)
		_:
			_rig.call("set_room", parts[1], parts[2], x)


func _title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", LabPrint.font("black"))
	l.add_theme_font_size_override("font_size", FONT + 2)
	_box.add_child(l)


func _section(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", LabPrint.font("bold"))
	l.add_theme_font_size_override("font_size", FONT)
	l.add_theme_color_override("font_color", HEAD)
	_box.add_child(l)


func _row(key: String, label: String, lo: float, hi: float, step: float, value: float) -> void:
	var line := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(200, 0)
	l.add_theme_font_size_override("font_size", FONT - 1)
	line.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(130, 0)
	line.add_child(s)
	var v := Label.new()
	v.custom_minimum_size = Vector2(54, 0)
	v.add_theme_font_size_override("font_size", FONT - 1)
	v.text = _fmt(value, step)
	line.add_child(v)
	_box.add_child(line)
	_rows[key] = [s, v, step]
	_values[key] = value
	s.value_changed.connect(func(x: float) -> void:
		v.text = _fmt(x, step)
		_values[key] = x
		if key.begins_with("lt/"):
			_apply_light(key, x)
		else:
			_pending[key] = 0.25)


static func _fmt(x: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(round(x))
	if step >= 0.1:
		return "%.1f" % x
	if step >= 0.01:
		return "%.2f" % x
	return "%.3f" % x


func value(key: String, fallback: float = 0.0) -> float:
	return float(_values.get(key, fallback))


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F1:
		visible = not visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	for key in _pending.keys():
		_pending[key] = float(_pending[key]) - delta
		if float(_pending[key]) <= 0.0:
			_pending.erase(key)
			apply(key)
	if visible and _lengths != null and room != null:
		var lens: Dictionary = room.call("wall_lengths")
		var parts: PackedStringArray = PackedStringArray()
		for n in lens:
			parts.append("%s %.1f m" % [String(n).replace("_", " "), float(lens[n])])
		_lengths.text = "WALLS:  " + ",  ".join(parts) + "\n(a wall panel needs 10.6 m)"


func _specimens() -> Array:
	var out: Array = []
	if room == null:
		return out
	for s in room.get("stations"):
		var ex: Node = s.get("exhibit")
		if ex == null:
			continue
		for k in ["specimen", "spare"]:
			var sp: Node = ex.get(k)
			if sp != null:
				out.append(sp)
	return out


## Applies one row to the room.
func apply(key: String) -> void:
	if room == null:
		return
	var x: float = float(_values[key])
	var lab: Node = room.get_node_or_null("Room")
	match key:
		"spots":
			Style.gain["spot"] = x
			for n in get_tree().get_nodes_in_group("kit_light"):
				if room.is_ancestor_of(n):
					n.call("apply_mood", Style.mood, true)
		"fill", "sun", "exposure", "black_fill":
			if lab != null:
				var over: Dictionary = lab.get("mood_overrides")
				var b: Dictionary = over.get("bright", {})
				var fill: float = float(_values["fill"]) * (float(_values["black_fill"]) if Style.palette == "black" else 1.0)
				b["ambient"] = Color(0.20, 0.24, 0.33) * fill
				b["key_energy"] = 0.42 * float(_values["sun"])
				b["exposure"] = float(_values["exposure"])
				over["bright"] = b
				lab.set("mood_overrides", over)
				lab.call("set_mood", "bright", true, false)
		"sun_up", "sun_turn":
			var sun: Node = room.get_node_or_null("Sun")
			if sun != null and sun.has_method("set_angles"):
				sun.call("set_angles", float(_values["sun_up"]), float(_values["sun_turn"]))
		"ped_h":
			# Not the pedestals that keep their own height (the gallery's low terrain pedestal).
			for s in room.get("stations"):
				if not s.has_meta("own_height"):
					s.set("height", x)
		"turn":
			for s in room.get("stations"):
				var ex: Node = s.get("exhibit")
				if ex != null and float(ex.get("turn_speed")) > 0.0:
					ex.set("turn_speed", x)
		"swap":
			for sp in _specimens():
				sp.set("swap", x > 0.5)
		"flash":
			for sp in _specimens():
				sp.set("flash_on", x > 0.5)
		"settle":
			for sp in _specimens():
				sp.set("settle_frames", int(x))
		_:
			if room.get(key) != null:
				room.set(key, x)


func save_now() -> void:
	var cf := ConfigFile.new()
	for k in _values:
		if not String(k).begins_with("lt/"):
			cf.set_value("tuning", String(k), _values[k])
	cf.save(SAVE_PATH)
	var said: String = SAVE_PATH.get_file()
	if _rig != null and int(_rig.call("save")) == OK:
		said += " and voxel_lab_lights.cfg"
	if room != null and room.get("hud") != null:
		room.get("hud").call("toast", "Saved to " + said)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for k in cf.get_section_keys("tuning"):
		if _rows.has(k):
			var x: float = float(cf.get_value("tuning", k))
			(_rows[k][0] as HSlider).set_value_no_signal(x)
			(_rows[k][1] as Label).text = _fmt(x, float(_rows[k][2]))
			_values[k] = x
			apply(k)
