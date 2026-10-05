extends PanelContainer

## Kit: Ramon's tuning panel for the goat room, live while playing (4 Oct: "sliders I can use ...
## in realtime, then I can give you the numbers"; "a bit bigger text, centre spot under light,
## category labels blue, and a save button which immediately saves the settings, so I can close
## without issues"). Temporary and for him: plain, but every number in the room he asked to turn.
##
##   LIGHT        per mood: spots and washes (multiplying every KitLight of that kind), sky fill
##                (the blue in every shadow), the sun's strength, exposure
##   CENTRE SPOT  the one spotlight: strength (per mood), cone, edge softness, reach, falloff,
##                height, warmth
##   SUN          its strength, height and turn (the Sun handle, kit_sun_4d.gd)
##   ROOM         ceiling height, pedestal radius
##   HOLOGRAM     the pedestal's hologram: height, strength at its foot, fade, fine grain
##   ROOM SHAPE   the goat room's five outline numbers and its back door (goat_room_4d.gd)
##   SAVE         writes everything to SAVE_PATH; the panel reads it back when the room starts,
##                so what he saved is where the room begins
##
## B switches mood (the LIGHT and spot strength rows show that mood's values); Esc frees the mouse
## to drag; F1 hides the panel. Rows that rebuild something (ceiling, pedestal, shape) wait for
## the slider to settle a moment.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const RoomScript := preload("res://ramon/CreationLab/LabKit/lab_room_4d.gd")
const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const SAVE_PATH := "res://ramon/CreationLab/creation_lab_tuning.cfg"
const FONT := 15
const HEAD := Color(0.42, 0.72, 1.0)
const COOL := Color(0.86, 0.92, 1.0)
const WARM := Color(1.0, 0.84, 0.62)

## Rows: [key, label, min, max, step].
const LIGHT_ROWS := [["spots", "Spots", 0.0, 4.0, 0.01], ["washes", "Washes", 0.0, 4.0, 0.01], ["fill", "Sky fill (shadows)", 0.0, 3.0, 0.01],
	["exposure", "Exposure", 0.4, 2.5, 0.01]]
## The sun in a section of its own, near the top (Ramon, 4 Oct: "I still need a way to rotate the sun
## in the tweaker dev panel"): its strength, how high it stands and which way it shines from, the
## angles moving the Sun handle (kit_sun_4d.gd), which turns the room's key light.
const SUN_ROWS := [["sun", "Strength", 0.0, 3.0, 0.01], ["sun_up", "Height, degrees", 5.0, 90.0, 0.5], ["sun_turn", "Turn, degrees", -180.0, 180.0, 0.5]]
const SPOT_ROWS := [["strength", "Strength", 0.0, 15.0, 0.01], ["cone", "Cone, degrees", 10.0, 120.0, 0.1], ["softness", "Edge softness", 0.1, 10.0, 0.01],
	["reach", "Reach, m", 2.0, 30.0, 0.05], ["falloff", "Falloff", 0.01, 2.0, 0.01], ["height", "Height, m", 3.0, 13.5, 0.01], ["warmth", "Warmth", 0.0, 1.0, 0.01]]
const ROOM_ROWS := [["ceiling", "Ceiling, m", 6.0, 14.0, 0.05], ["pedestal", "Pedestal radius, m", 2.0, 5.0, 0.05]]
## The pedestal's hologram (Ramon, 5 Oct: "make a height adjustment in my dev panel for the
## hologram"): its height, how solid at its foot, how fast it fades, and the fine grain (0 or 1).
const HOLO_ROWS := [["holo_height", "Height, m", 0.1, 4.0, 0.01], ["holo_base", "Strength at the foot", 0.0, 1.0, 0.01],
	["holo_falloff", "Fade upward", 0.3, 6.0, 0.05], ["holo_fine", "Fine grain (0 / 1)", 0.0, 1.0, 1.0]]
const SHAPE_ROWS := [["room_half_width", "Half width, m", 5.0, 20.0, 0.1], ["room_back", "Back wall from middle, m", 4.0, 20.0, 0.1],
	["room_front", "Entrance wall from middle, m", 4.0, 20.0, 0.1], ["back_wall_half", "Back wall half width, m", 1.0, 10.0, 0.1],
	["corner_z", "Angled walls start at z", -15.0, 15.0, 0.1], ["door_width", "Back door width, m", 0.0, 8.0, 0.1], ["door_height", "Back door height, m", 2.0, 8.0, 0.1]]
const ROOM2_ROWS := [["big_room_width", "Width, m", 10.0, 80.0, 0.5], ["big_room_depth", "Depth, m", 10.0, 80.0, 0.5], ["big_room_height", "Height, m", 4.0, 24.0, 0.1]]
const BIG_SPOT_ROWS := [["strength", "Strength", 0.0, 30.0, 0.05], ["cone", "Cone, degrees", 10.0, 120.0, 0.1], ["softness", "Edge softness", 0.1, 10.0, 0.01],
	["reach", "Reach, m", 2.0, 60.0, 0.1], ["falloff", "Falloff", 0.01, 2.0, 0.01], ["height", "Height, m", 3.0, 23.5, 0.01], ["warmth", "Warmth", 0.0, 1.0, 0.01]]
## Where the light starts per mood when nothing is saved (Ramon's numbers for bright).
const START := {"bright": {"spots": 3.26, "washes": 0.0, "fill": 1.52, "sun": 0.66, "exposure": 1.05}}

## "main" (the goat room's panel, on the left) or "room2" (Room 2 and its big spot, on the right).
var panel: String = "main"
var room: Node
var spot: Node
var sun: Node
var showcase: Node
var goat_room: Node
var shape_root: Node
## LIGHT values per mood.
var values: Dictionary = {}
var _sliders: Dictionary = {}
var _labels: Dictionary = {}
var _names: Dictionary = {}
var _readout: Label
var _mood: String = ""
var _quiet: bool = false
var _pending: Dictionary = {}
var _wait: float = 0.0
var _saved_note: Label
var _scroll: ScrollContainer
var _box: VBoxContainer


func _ready() -> void:
	# Hidden until its key is pressed, and nothing on screen mentions the key (Ramon, 5 Oct: "keep the
	# dev panel closed by default, don't even let it show ... so someone can only find it by
	# accident"): F1 for the room's panel, F2 for Room 2's.
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2(14, 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.86)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	_load()
	if panel == "room2":
		_build_room2()
		return
	# It scrolls when it is taller than the window (free the mouse with Esc, then wheel over it).
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_scroll.add_child(box)
	_box = box
	var title := Label.new()
	title.text = "ARTIST DEV PANEL  ·  internal use  ·  F1 to close  ·  Esc frees the mouse"
	title.add_theme_font_override("font", LabPrint.font("bold"))
	title.add_theme_font_size_override("font_size", FONT)
	box.add_child(title)
	_section(box, "LIGHT")
	for r in LIGHT_ROWS:
		_row(box, r)
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", FONT - 2)
	box.add_child(_readout)
	_section(box, "SUN")
	for r in SUN_ROWS:
		if sun != null or String(r[0]) == "sun":
			_row(box, r)
	if spot != null:
		_section(box, "CENTRE SPOT")
		for r in SPOT_ROWS:
			_row(box, r)
	_section(box, "ROOM")
	for r in ROOM_ROWS:
		_row(box, r)
	if showcase != null:
		_section(box, "HOLOGRAM")
		for r in HOLO_ROWS:
			_row(box, r)
	if shape_root != null:
		_section(box, "ROOM SHAPE")
		for r in SHAPE_ROWS:
			_row(box, r)
	var save := Button.new()
	save.text = "SAVE SETTINGS"
	save.focus_mode = Control.FOCUS_NONE
	save.add_theme_font_size_override("font_size", FONT)
	save.pressed.connect(_save)
	box.add_child(save)
	_saved_note = Label.new()
	_saved_note.add_theme_font_size_override("font_size", FONT - 3)
	box.add_child(_saved_note)
	# Review: the two blue walls side by side, in the gallery beside the room, and back.
	if shape_root != null and shape_root.has_method("toggle_compare"):
		_section(box, "REVIEW")
		var cmp := Button.new()
		cmp.text = "BLUE WALLS SIDE BY SIDE"
		cmp.focus_mode = Control.FOCUS_NONE
		cmp.add_theme_font_size_override("font_size", FONT)
		cmp.pressed.connect(func() -> void:
			var there: bool = bool(shape_root.call("toggle_compare"))
			cmp.text = "BACK TO THE ROOM" if there else "BLUE WALLS SIDE BY SIDE")
		box.add_child(cmp)


func _build_room2() -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_scroll.add_child(box)
	_box = box
	var title := Label.new()
	title.text = "ARTIST DEV PANEL, ROOM 2  ·  internal use  ·  F2 to close"
	title.add_theme_font_override("font", LabPrint.font("bold"))
	title.add_theme_font_size_override("font_size", FONT)
	box.add_child(title)
	_section(box, "ROOM 2 SIZE")
	for r in ROOM2_ROWS:
		_row(box, r)
	if spot != null:
		_section(box, "BIG SPOT")
		for r in BIG_SPOT_ROWS:
			_row(box, r)
	var save := Button.new()
	save.text = "SAVE SETTINGS"
	save.focus_mode = Control.FOCUS_NONE
	save.add_theme_font_size_override("font_size", FONT)
	save.pressed.connect(_save)
	box.add_child(save)
	_saved_note = Label.new()
	_saved_note.add_theme_font_size_override("font_size", FONT - 3)
	box.add_child(_saved_note)


func _section(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", LabPrint.font("bold"))
	l.add_theme_font_size_override("font_size", FONT)
	l.add_theme_color_override("font_color", HEAD)
	box.add_child(l)


func _row(box: VBoxContainer, r: Array) -> void:
	var key: String = r[0]
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(250, 0)
	name_label.add_theme_font_size_override("font_size", FONT)
	row.add_child(name_label)
	var s := HSlider.new()
	s.custom_minimum_size = Vector2(240, 22)
	s.min_value = float(r[2])
	s.max_value = float(r[3])
	s.step = float(r[4])
	s.focus_mode = Control.FOCUS_NONE
	_quiet = true
	s.value = _read_value(key)
	_quiet = false
	s.value_changed.connect(func(v: float) -> void: _on_change(key, v))
	row.add_child(s)
	box.add_child(row)
	_sliders[key] = s
	_labels[key] = name_label
	_names[key] = r[1]
	_show(key)


# -- reading and writing the room ------------------------------------------------------------------

func _light(m: String) -> Dictionary:
	if not values.has(m):
		if START.has(m):
			values[m] = (START[m] as Dictionary).duplicate()
		else:
			var exp_v: float = float((Style.ROOM_LIGHT.get(m, {}) as Dictionary).get("exposure", (RoomScript.MOODS[m] as Dictionary)["exposure"]))
			values[m] = {"spots": 1.0, "washes": float(Style.gain.get("wash", 0.0)), "fill": 1.0, "sun": 1.0, "exposure": exp_v}
	return values[m]


func _read_value(key: String) -> float:
	var m: String = Style.mood
	match key:
		"spots", "washes", "fill", "sun", "exposure":
			return float(_light(m)[key])
		"strength":
			return float((spot.get("energy") as Dictionary).get(m, 1.0))
		"cone":
			return float(spot.get("angle"))
		"softness":
			return float(spot.get("softness"))
		"reach":
			return float(spot.get("reach"))
		"falloff":
			return float(spot.get("attenuation"))
		"height":
			return float((spot as Node4D).position.y)
		"warmth":
			var c: Color = (spot.get("color") as Dictionary).get(m, COOL)
			return clampf((COOL.b - c.b) / maxf(COOL.b - WARM.b, 0.001), 0.0, 1.0)
		"ceiling":
			return (goat_room.get("size") as Vector3).y if goat_room != null else 10.0
		"pedestal":
			return float(showcase.get("radius")) if showcase != null else 3.4
		"holo_height", "holo_base", "holo_falloff":
			return float(showcase.get(key)) if showcase != null else 0.0
		"holo_fine":
			return 1.0 if showcase != null and bool(showcase.get("holo_fine_grain")) else 0.0
		"sun_up":
			return (sun.call("angles") as Vector2).x if sun != null else 64.0
		"sun_turn":
			return (sun.call("angles") as Vector2).y if sun != null else 25.0
	if shape_root != null and shape_root.get(key) != null:
		return float(shape_root.get(key))
	return 0.0


func _write_value(key: String, v: float) -> void:
	var m: String = Style.mood
	match key:
		"spots", "washes", "fill", "sun", "exposure":
			_light(m)[key] = v
			_push_light()
		"strength":
			var e: Dictionary = (spot.get("energy") as Dictionary).duplicate()
			e[m] = v
			spot.set("energy", e)
		"cone":
			spot.set("angle", v)
		"softness":
			spot.set("softness", v)
		"reach":
			spot.set("reach", v)
		"falloff":
			spot.set("attenuation", v)
		"height":
			var n := spot as Node4D
			n.position = Vector4(n.position.x, v, n.position.z, n.position.w)
		"warmth":
			var cd: Dictionary = (spot.get("color") as Dictionary).duplicate()
			cd[m] = COOL.lerp(WARM, v)
			spot.set("color", cd)
		"ceiling":
			if goat_room != null:
				var sz: Vector3 = goat_room.get("size")
				goat_room.set("size", Vector3(sz.x, v, sz.z))
		"pedestal":
			if showcase != null:
				showcase.set("radius", v)
		"holo_height", "holo_base", "holo_falloff":
			if showcase != null:
				showcase.set(key, v)
		"holo_fine":
			if showcase != null:
				showcase.set("holo_fine_grain", v > 0.5)
		"sun_up", "sun_turn":
			if sun != null:
				var a: Vector2 = sun.call("angles")
				sun.call("set_angles", v if key == "sun_up" else a.x, v if key == "sun_turn" else a.y)
		_:
			if shape_root != null:
				shape_root.set(key, v)
	if spot != null and key in ["strength", "cone", "softness", "reach", "falloff", "height", "warmth"]:
		spot.call("apply_mood", m, true)


## The light rows act at once; the rows that rebuild something wait for the slider to settle.
func _on_change(key: String, v: float) -> void:
	if _quiet:
		return
	if key in ["ceiling", "pedestal"] or (shape_root != null and shape_root.get(key) != null):
		_pending[key] = v
		_wait = 0.35
	else:
		_write_value(key, v)
	_show(key)
	_saved_note.text = ""


func _push_light() -> void:
	if room == null:
		return
	var v: Dictionary = _light(Style.mood)
	Style.gain["spot"] = float(v["spots"])
	Style.gain["wash"] = float(v["washes"])
	get_tree().call_group("kit_light", "apply_mood", Style.mood, true)
	var base: Dictionary = (RoomScript.MOODS[Style.mood] as Dictionary).duplicate()
	base.merge(Style.ROOM_LIGHT.get(Style.mood, {}), true)
	var all: Dictionary = (room.get("mood_overrides") as Dictionary).duplicate(true)
	var over: Dictionary = (Style.ROOM_LIGHT.get(Style.mood, {}) as Dictionary).duplicate()
	# Keep what others set (the sun handle's angles).
	for key in ["key_elevation", "key_azimuth"]:
		if (all.get(Style.mood, {}) as Dictionary).has(key):
			over[key] = all[Style.mood][key]
	over["ambient"] = (base["ambient"] as Color) * float(v["fill"])
	over["key_energy"] = float(base["key_energy"]) * float(v["sun"])
	over["exposure"] = float(v["exposure"])
	all[Style.mood] = over
	room.set("mood_overrides", all)
	room.call("set_mood", Style.mood, true, false)


func _show(key: String) -> void:
	if not _labels.has(key):
		return
	var v: float = float(_pending.get(key, _read_value(key)))
	(_labels[key] as Label).text = "%s  %.2f" % [_names[key], v]
	if _readout != null:
		var l: Dictionary = _light(Style.mood)
		_readout.text = "%s: spots %.2f  washes %.2f  fill %.2f  sun %.2f  exposure %.2f" % [Style.mood.to_upper(), l["spots"], l["washes"], l["fill"], l["sun"], l["exposure"]]


func _process(delta: float) -> void:
	if _scroll != null and _box != null:
		var vh: float = get_viewport_rect().size.y
		var room_for: float = (vh * 0.42) if panel == "room2" else (vh - 52.0)
		var want := Vector2(_box.get_combined_minimum_size().x + 14.0, minf(_box.get_combined_minimum_size().y, room_for))
		if _scroll.custom_minimum_size != want:
			_scroll.custom_minimum_size = want
		if panel == "room2":
			var at := Vector2(get_viewport_rect().size.x - size.x - 14.0, 64.0)
			if position != at:
				position = at
	if not _pending.is_empty():
		_wait -= delta
		if _wait <= 0.0:
			for k in _pending:
				_write_value(k, float(_pending[k]))
			_pending.clear()
	if room == null:
		return
	var m: String = String(room.get("mood"))
	if m != _mood:
		_mood = m
		if panel == "main":
			_push_light()
		_quiet = true
		for k in _sliders:
			(_sliders[k] as HSlider).value = _read_value(k)
		_quiet = false
		for k in _sliders:
			_show(k)


# -- saving ----------------------------------------------------------------------------------------

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	if panel == "room2":
		if spot != null:
			cfg.set_value("spot_room2", "energy", spot.get("energy"))
			cfg.set_value("spot_room2", "color", spot.get("color"))
			for k in ["angle", "softness", "reach", "attenuation"]:
				cfg.set_value("spot_room2", k, spot.get(k))
			cfg.set_value("spot_room2", "height", (spot as Node4D).position.y)
		for r in ROOM2_ROWS:
			cfg.set_value("room2", r[0], float(_pending.get(r[0], _read_value(r[0]))))
		var err2: int = cfg.save(SAVE_PATH)
		_saved_note.text = ("Saved to %s at %s" % [SAVE_PATH, Time.get_time_string_from_system()]) if err2 == OK else "Could not save (%d)" % err2
		return
	for m in ["bright", "dark"]:
		for k in (_light(m) as Dictionary):
			cfg.set_value("light_" + m, k, _light(m)[k])
	if spot != null:
		cfg.set_value("spot", "energy", spot.get("energy"))
		cfg.set_value("spot", "color", spot.get("color"))
		for k in ["angle", "softness", "reach", "attenuation"]:
			cfg.set_value("spot", k, spot.get(k))
		cfg.set_value("spot", "height", (spot as Node4D).position.y)
	for r in ROOM_ROWS:
		cfg.set_value("room", r[0], float(_pending.get(r[0], _read_value(r[0]))))
	if showcase != null:
		for r in HOLO_ROWS:
			cfg.set_value("hologram", r[0], float(_pending.get(r[0], _read_value(r[0]))))
	if sun != null:
		for k in ["sun_up", "sun_turn"]:
			cfg.set_value("room", k, float(_read_value(k)))
	if shape_root != null:
		for r in SHAPE_ROWS:
			cfg.set_value("shape", r[0], float(_pending.get(r[0], _read_value(r[0]))))
	var err: int = cfg.save(SAVE_PATH)
	_saved_note.text = ("Saved to %s at %s" % [SAVE_PATH, Time.get_time_string_from_system()]) if err == OK else "Could not save (%d)" % err


## Reads the saved settings, if any, into the room before the panel is built.
func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	if panel == "room2":
		if spot != null and cfg.has_section("spot_room2"):
			spot.set("energy", cfg.get_value("spot_room2", "energy", spot.get("energy")))
			spot.set("color", cfg.get_value("spot_room2", "color", spot.get("color")))
			for k in ["angle", "softness", "reach", "attenuation"]:
				spot.set(k, cfg.get_value("spot_room2", k, spot.get(k)))
			var n2 := spot as Node4D
			n2.position = Vector4(n2.position.x, float(cfg.get_value("spot_room2", "height", n2.position.y)), n2.position.z, n2.position.w)
		if shape_root != null and cfg.has_section("room2"):
			for k in cfg.get_section_keys("room2"):
				shape_root.set(k, float(cfg.get_value("room2", k)))
		return
	for m in ["bright", "dark"]:
		if cfg.has_section("light_" + m):
			var d: Dictionary = {}
			for k in cfg.get_section_keys("light_" + m):
				d[k] = float(cfg.get_value("light_" + m, k))
			values[m] = d
	if spot != null and cfg.has_section("spot"):
		spot.set("energy", cfg.get_value("spot", "energy", spot.get("energy")))
		spot.set("color", cfg.get_value("spot", "color", spot.get("color")))
		for k in ["angle", "softness", "reach", "attenuation"]:
			spot.set(k, cfg.get_value("spot", k, spot.get(k)))
		var n := spot as Node4D
		n.position = Vector4(n.position.x, float(cfg.get_value("spot", "height", n.position.y)), n.position.z, n.position.w)
	if shape_root != null and cfg.has_section("shape"):
		for k in cfg.get_section_keys("shape"):
			shape_root.set(k, float(cfg.get_value("shape", k)))
	if cfg.has_section("room"):
		for k in cfg.get_section_keys("room"):
			_write_value(k, float(cfg.get_value("room", k)))
	if cfg.has_section("hologram"):
		for k in cfg.get_section_keys("hologram"):
			_write_value(k, float(cfg.get_value("hologram", k)))


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == (KEY_F2 if panel == "room2" else KEY_F1):
		visible = not visible
