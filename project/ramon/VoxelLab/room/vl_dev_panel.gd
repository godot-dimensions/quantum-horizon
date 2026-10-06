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
## Esc frees the mouse to drag; F1 hides it. Rows that rebuild something wait for the slider to settle.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")

const SAVE_PATH := "res://ramon/VoxelLab/voxel_lab_tuning.cfg"
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
	_title("VOXEL LAB  ·  ARTIST DEV PANEL")
	_section("LIGHT")
	_row("spots", "Spots", 0.0, 6.0, 0.01, 3.26)
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
	var save := Button.new()
	save.text = "SAVE"
	save.add_theme_font_size_override("font_size", FONT)
	save.pressed.connect(save_now)
	_box.add_child(save)
	_load()
	# The light starts as the rows say (the lab's saved numbers, or this room's own once saved).
	for k in ["spots", "fill", "sun", "exposure", "sun_up", "turn"]:
		apply(k)


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
			for s in room.get("stations"):
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
