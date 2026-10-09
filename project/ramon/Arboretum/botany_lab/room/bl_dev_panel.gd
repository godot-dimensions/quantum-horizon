extends PanelContainer

## BOTANY LAB (fork of the Arboretum's room/arb_dev_panel.gd, 9 Oct): opened with the lights' editor on Tab
## (Ramon: "Make the developer HUD accessible through Tab"), F1 kept; the grove's rows gone with the
## grove, the corridor's ceiling added; its own tuning file.
##
## The Arboretum's dev panel (F1), Ramon's sliders, live while playing (Ramon, 5 Oct: "we also need
## the walls and dev options similar to the creator lab so i can tweak sizes and measurements"),
## after the Creation Lab's tuner (carried/kit/kit_tuner.gd): plain, black glass, every number in the
## room worth turning, and SAVE, which writes them to SAVE_PATH; the panel reads that back when the
## room starts, so what was saved is where the room begins.
##
##   LIGHT      the spots, the sky fill (the blue in every shadow), the sun's strength, its height
##              and its turn, the exposure
##   TREES      each pedestal's tree height, its pedestal's radius, the pedestals' height, how fast
##              they turn
##   WIND       its speed, its direction across the floor, how much of it blows through W, the gusts
##              (strength, how often), how far branches bend and how much they sway
##   LEAVES     the oak's leaf size, how deep in W a leaf is, how soft the crown's light is
##   GROVE      trees per plot and how far ana and kata they stand (the grove places them again)
##   HALL       the hall's plan: half width, entrance and back walls, the corner walls' length and
##              angle, its height, the grove door, with every wall's length as it comes out
##
## Esc frees the mouse to drag; F1 hides it. Rows that rebuild something wait for the slider to settle.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd")

const SAVE_PATH := "res://ramon/Arboretum/botany_lab/botany_lab_tuning.cfg"
const FONT := 14
const HEAD := Color(0.42, 0.72, 1.0)

var room: Node
var _rows: Dictionary = {}
var _values: Dictionary = {}
var _pending: Dictionary = {}
var _lengths: Label
var _box: VBoxContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", Style.glass_box(10.0, 1.0, 0.92))
	position = Vector2(16, 16)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_box)
	_title("BOTANY LAB  ·  ARTIST DEV PANEL")
	_section("LIGHT")
	_row("spots", "Spots", 0.0, 4.0, 0.01, 1.0)
	_row("fill", "Sky fill (shadows)", 0.0, 3.0, 0.01, 1.0)
	_row("sun", "Sun strength", 0.0, 3.0, 0.01, 1.0)
	_row("sun_up", "Sun height, degrees", 5.0, 90.0, 0.5, 64.0)
	_row("sun_turn", "Sun turn, degrees", -180.0, 180.0, 0.5, 25.0)
	_row("exposure", "Exposure", 0.4, 2.5, 0.01, 1.25)
	_section("TREES")
	for i in 4:
		var s: Node = _station(i)
		var ex: Node = s.get("exhibit") if s != null else null
		var nm: String = "%02d" % (i + 1)
		_row("tree_h_%d" % i, nm + " tree height, m", 2.0, 11.0, 0.05, float(ex.get("tree_height")) if ex != null else 4.3)
		_row("ped_r_%d" % i, nm + " pedestal radius, m", 1.2, 6.0, 0.05, float(s.get("radius")) if s != null else 2.2)
	_row("ped_h", "Pedestal height, m", 0.3, 1.8, 0.01, float(_station(0).get("height")) if _station(0) != null else 0.9)
	_row("turn", "Turntable, degrees a second", 0.0, 20.0, 0.1, 4.0)
	_section("WIND")
	var w: Node = room.call("wind") if room != null else null
	var d: Vector4 = w.get("direction") if w != null else Vector4(1, 0, 0.25, 0.35)
	_row("wind_speed", "Speed, m/s", 0.0, 25.0, 0.1, float(w.get("speed")) if w != null else 6.0)
	_row("wind_turn", "Direction, degrees", -180.0, 180.0, 1.0, rad_to_deg(atan2(d.x, d.z)))
	_row("wind_w", "Through W (0 none, 1 as much as across)", 0.0, 1.5, 0.01, d.w / maxf(Vector2(d.x, d.z).length(), 0.001))
	_row("gust", "Gust strength", 0.0, 1.0, 0.01, float(w.get("gust_strength")) if w != null else 0.22)
	_row("gust_every", "A gust every, seconds (0 never)", 0.0, 60.0, 0.5, float(w.get("gust_every")) if w != null else 9.0)
	_row("bend", "Bend", 0.0, 0.2, 0.001, float(w.get("bend")) if w != null else 0.05)
	_row("sway", "Sway", 0.0, 1.5, 0.01, float(w.get("sway")) if w != null else 0.35)
	_section("LEAVES")
	var lv: Node = (_station(3).get("exhibit") as Node).get("leaves") if _station(3) != null and _station(3).get("exhibit") != null else null
	_row("leaf_size", "Leaf size, m", 0.04, 0.5, 0.005, float(lv.get("leaf_size")) if lv != null else 0.22)
	_row("leaf_w", "Leaf depth in W, m", 0.02, 1.2, 0.005, float(lv.get("leaf_w")) if lv != null else 0.6)
	_row("crown_normals", "Crown light (0 every leaf, 1 one mass)", 0.0, 1.0, 0.01, 0.65)
	_section("HALL")
	for r in [["room_half_width", "Half width, m", 8.0, 30.0], ["room_front", "Entrance wall from middle, m", 6.0, 30.0],
			["room_back", "Back wall from middle, m", 6.0, 40.0], ["corner_length", "Panel walls' length, m", 0.0, 20.0],
			["corner_angle", "Panel walls' angle, degrees", 5.0, 85.0], ["hall_height", "Height, m", 6.0, 20.0], ["door_width", "Back door, m", 0.0, 8.0],
			["corridor_height", "Corridor ceiling, m", 4.5, 11.0], ["entrance_height", "Entrance doorway, m", 3.5, 8.0]]:
		_row(String(r[0]), String(r[1]), float(r[2]), float(r[3]), 0.1, float(room.get(String(r[0]))) if room != null else 10.0)
	_lengths = Label.new()
	_lengths.add_theme_font_size_override("font_size", FONT - 2)
	_lengths.add_theme_color_override("font_color", Style.UI_INK_DIM)
	_lengths.autowrap_mode = TextServer.AUTOWRAP_WORD
	_box.add_child(_lengths)
	var save := Button.new()
	save.text = "SAVE"
	save.add_theme_font_size_override("font_size", FONT)
	save.pressed.connect(save_now)
	_box.add_child(save)
	_load()


func _station(i: int) -> Node:
	return room.get_node_or_null("Station%02d" % (i + 1)) if room != null else null


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
		_pending[key] = 0.25)


static func _fmt(x: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(round(x))
	if step >= 0.1:
		return "%.1f" % x
	if step >= 0.01:
		return "%.2f" % x
	return "%.3f" % x


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F1:
		# The room opens this and the lights' editor together (Tab, or F1).
		if room != null and room.has_method("toggle_dev"):
			room.call("toggle_dev")
		else:
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


## Applies one row to the room.
func apply(key: String) -> void:
	if room == null:
		return
	var x: float = float(_values[key])
	var w: Node = room.call("wind")
	var lab: Node = room.get_node_or_null("Room")
	match key:
		"spots":
			Style.gain["spot"] = x
			for n in get_tree().get_nodes_in_group("kit_light"):
				if room.is_ancestor_of(n):
					n.call("apply_mood", Style.mood, true)
		"fill", "sun", "exposure":
			if lab != null:
				var over: Dictionary = lab.get("mood_overrides")
				var b: Dictionary = over.get("bright", {})
				match key:
					"fill":
						b["ambient"] = Color(0.20, 0.24, 0.33) * x
					"sun":
						b["key_energy"] = 0.42 * x
					"exposure":
						b["exposure"] = x
				over["bright"] = b
				lab.set("mood_overrides", over)
				lab.call("set_mood", "bright", true, false)
		"sun_up", "sun_turn":
			var sun: Node = room.get_node_or_null("Sun")
			if sun != null:
				sun.call("set_angles", float(_values["sun_up"]), float(_values["sun_turn"]))
		"ped_h":
			for i in 4:
				var s: Node = _station(i)
				if s != null:
					s.set("height", x)
		"turn":
			for i in 3:
				var ex: Node = _station(i).get("exhibit") if _station(i) != null else null
				if ex != null:
					ex.set("turn_speed", x)
			var oak: Node = _station(3).get("exhibit") if _station(3) != null else null
			if oak != null:
				oak.set("turn_speed", x * 0.6)
		"wind_speed":
			if w != null:
				w.set("speed", x)
		"wind_turn", "wind_w":
			if w != null:
				var a: float = deg_to_rad(float(_values["wind_turn"]))
				w.set("direction", Vector4(sin(a), 0.0, cos(a), float(_values["wind_w"])))
		"gust":
			if w != null:
				w.set("gust_strength", x)
		"gust_every":
			if w != null:
				w.set("gust_every", x)
		"bend":
			if w != null:
				w.set("bend", x)
		"sway":
			if w != null:
				w.set("sway", x)
		"leaf_size", "leaf_w", "crown_normals":
			var oak2: Node = _station(3).get("exhibit") if _station(3) != null else null
			var leaves: Node = oak2.get("leaves") if oak2 != null else null
			if leaves != null:
				var m: ShaderMaterial = leaves.get("material")
				if m != null:
					m.set_shader_parameter(key, x)
		_:
			if key.begins_with("tree_h_"):
				var ex2: Node = _station(int(key.get_slice("_", 2))).get("exhibit")
				if ex2 != null:
					ex2.set("tree_height", x)
					ex2.call("_setup_tree", String(ex2.get("method")) == "oak")
					for kk in (ex2.get("layers") as Dictionary):
						(ex2.get("layers")[kk] as MeshInstance4D).material_override = ex2.get("material")
			elif key.begins_with("ped_r_"):
				var st: Node = _station(int(key.get_slice("_", 2)))
				if st != null:
					st.set("radius", x)
			elif room.get(key) != null:
				room.set(key, x)


func save_now() -> void:
	var cf := ConfigFile.new()
	for k in _values:
		cf.set_value("tuning", String(k), _values[k])
	cf.save(SAVE_PATH)
	if room != null and room.get("hud") != null:
		room.get("hud").call("toast", "Saved to " + SAVE_PATH.get_file())


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
