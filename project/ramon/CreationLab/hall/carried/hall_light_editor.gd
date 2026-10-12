extends PanelContainer

## CARRIED into the Creature Lab's hall (10 Oct 2026, round 3, Ramon's item 40: "make the developer HUD accessible through
## Tab ... the individual lighting controls for the room") from Arboretum/botany_lab/room/bl_light_editor.gd: its two
## preloads point at the Creation Lab's kit and it saves to hall/creature_hall_lights.cfg. Nothing else changed.
##
## BOTANY LAB (carried from the Aquatic Lab's room/light_editor.gd, 9 Oct, Ramon: "Include controls for the
## individual lights in the scene ... Reuse the developer lighting controls already established in the
## other labs"): the same editor; the layout draws the hall's own outline and the four pedestals, and
## the room opens it (with the artist panel) on Tab, so `own_key` is off here.
##
## WATER LAB, THE TANK ROOM: the lights' dev HUD (Ramon, 9 Oct, round 2: "If I press tab, it would be cool
## if a dev HUD appears that I can manipulate the lights in this room, ideally with a layout, so I can
## manipulate each one. That should be also the softness of the spotlights and the strength").
##
## Tab opens and closes it, along the right edge (the mouse is freed while it is open):
##   THE LAYOUT  the hall from above (its walls, the tank, the showcase, the fish wall), every light a
##               numbered dot where it hangs, a line to where it points; click one to choose it.
##   THE ROWS    the chosen light's strength (this mood's), spread, softness, reach and fall-off, as
##               sliders; each change is live.
##   SAVE        writes every light to water_lab_lights.cfg, which the room reads back when it opens;
##               RESET puts back what the room opened with.
##
## Every kit light (carried/kit/kit_light_4d.gd) that is a child of the room is listed. NO class_name.

const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")
const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")
const SAVE_PATH := "res://ramon/CreationLab/hall/creature_hall_lights.cfg"
## THE HALL, round 5 (10 Oct, Ramon's items 57 and 58): under the chosen light, ALL LIGHTS AND THE ROOM. "All spotlights"
## is the kit's own shared multiplier for every kit light (Style.gain "spot"), so each light keeps its own values and its
## own row still works; the hall owns it now (room 1 sets it to 3.26 for itself, and the hall used to inherit that when
## you came through the door, and run at 1.0 when opened on its own). The rest is the room's own light, nothing added:
## exposure, the ambient light (how much, and warmer or cooler), the sky's colours (how bright), the key light the Sun
## handle aims (strength, elevation, direction) and the fill. Live; SAVE keeps them with the lights, RESET puts back
## the room's own.
const ENV_ROWS := [["gain", "All spotlights (x)", 0.0, 6.0, 0.01], ["exposure", "Exposure", 0.3, 3.0, 0.01],
	["ambient_k", "Ambient (x)", 0.0, 3.0, 0.01], ["warmth", "Ambient warmth", -1.0, 1.0, 0.01], ["sky_k", "Sky (x)", 0.0, 3.0, 0.01],
	["key_energy", "Sun strength", 0.0, 3.0, 0.01], ["key_elevation", "Sun elevation", 5.0, 90.0, 1.0],
	["key_azimuth", "Sun direction", -180.0, 180.0, 1.0], ["fill_energy", "Fill strength", 0.0, 1.0, 0.01]]
## The hall's spotlight multiplier unless saved otherwise: what it has been seen at, coming in from room 1.
const HALL_GAIN := 3.26
const WARM := Color(1.0, 0.82, 0.62)
const COOL := Color(0.62, 0.78, 1.0)
const ROWS := [["energy", "Strength", 0.0, 8.0, 0.05], ["angle", "Spread (degrees)", 5.0, 120.0, 1.0], ["softness", "Softness", 0.1, 10.0, 0.1],
	["reach", "Reach (m)", 1.0, 40.0, 0.5], ["attenuation", "Fall-off", 0.01, 2.0, 0.01]]

## The room (water_lab_4d.gd).
var room: Node4D
var lights: Array = []
var chosen: int = 0
var _initial: Dictionary = {}
var _layout: Control
var _rows: VBoxContainer
var _title: Label
var _flash: Label
var _flash_t: float = 0.0
var _mouse_before: int = Input.MOUSE_MODE_CAPTURED
## Whether Tab is this panel's own (the Aquatic Lab), or the room's to give (the Botany Lab).
var own_key: bool = true
## The room's light as the scene set it (its mood's values), and the sliders' values over it.
var _env_base: Dictionary = {}
var env: Dictionary = {}
var _env_initial: Dictionary = {}


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := Style.glass_box(14.0)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = Label.new()
	_title.text = "LIGHTS  ·  TAB"
	_title.add_theme_font_override("font", LabPrint.font("black"))
	box.add_child(_title)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	for b in [["SAVE", save], ["RESET", reset], ["CLOSE", close]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(b[1])
		buttons.add_child(btn)
	_layout = Control.new()
	_layout.custom_minimum_size = Vector2(520, 330)
	_layout.mouse_filter = Control.MOUSE_FILTER_STOP
	_layout.draw.connect(_draw_layout)
	_layout.gui_input.connect(_layout_input)
	box.add_child(_layout)
	_rows = VBoxContainer.new()
	box.add_child(_rows)
	_flash = Label.new()
	_flash.modulate = Style.UI_ACCENT
	box.add_child(_flash)
	(func() -> void:
		_find()
		_snapshot()
		_env_snapshot()
		load_saved()
		_apply_env()
		_build_rows()).call_deferred()


func _find() -> void:
	lights = []
	if room == null:
		return
	for c in room.get_children():
		if c.get("softness") != null and c.get("energy") != null and c.get("aim") != null:
			lights.append(c)


func _snapshot() -> void:
	for l in lights:
		_initial[String(l.name)] = _values(l)


func _values(l: Node) -> Dictionary:
	return {"energy": (l.get("energy") as Dictionary).duplicate(), "angle": l.get("angle"), "softness": l.get("softness"),
		"reach": l.get("reach"), "attenuation": l.get("attenuation")}


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not own_key or k == null or not k.pressed or k.echo or k.keycode != KEY_TAB:
		return
	if visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_rows()


func close() -> void:
	visible = false
	Input.mouse_mode = _mouse_before if _mouse_before != Input.MOUSE_MODE_VISIBLE else Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not visible:
		return
	var vs: Vector2 = get_viewport_rect().size
	var u: float = maxf(vs.y / 1080.0, 0.6)
	add_theme_constant_override("separation", int(8 * u))
	_layout.custom_minimum_size = Vector2(520, 330) * u
	position = Vector2(vs.x - size.x - 16.0 * u, 16.0 * u)
	_flash_t = maxf(_flash_t - delta, 0.0)
	_flash.visible = _flash_t > 0.0
	_layout.queue_redraw()


# -- the layout -----------------------------------------------------------------------------------------------

## The hall's floor from above: x across, z down the panel (north, the tank, at the top).
func _plan() -> Dictionary:
	var hall: Node4D = room.get_node_or_null("Hall") as Node4D
	var hs: Vector3 = hall.get("size") if hall != null else Vector3(30, 11, 18)
	var hp: Vector4 = hall.global_position if hall != null else Vector4.ZERO
	# The hall and every light in the picture (the entrance's hangs in the corridor, outside the hall).
	var lo := Vector2(hp.x - hs.x * 0.5, hp.z - hs.z * 0.5)
	var hi := Vector2(hp.x + hs.x * 0.5, hp.z + hs.z * 0.5)
	# A hall with an outline (the Botany Lab's chamfered plan) is framed by its corners.
	var outline: PackedVector2Array = hall.get("outline") if hall != null and hall.get("outline") != null else PackedVector2Array()
	if outline.size() >= 3:
		lo = Vector2(INF, INF)
		hi = Vector2(-INF, -INF)
		for q in outline:
			lo = Vector2(minf(lo.x, hp.x + q.x), minf(lo.y, hp.z + q.y))
			hi = Vector2(maxf(hi.x, hp.x + q.x), maxf(hi.y, hp.z + q.y))
	for l in lights:
		var lp: Vector4 = (l as Node4D).global_position
		lo = Vector2(minf(lo.x, lp.x - 1.0), minf(lo.y, lp.z - 1.0))
		hi = Vector2(maxf(hi.x, lp.x + 1.0), maxf(hi.y, lp.z + 1.0))
	var r := Rect2(Vector2.ZERO, _layout.size).grow(-14.0)
	var s: float = minf(r.size.x / (hi.x - lo.x), r.size.y / (hi.y - lo.y))
	var origin: Vector2 = r.get_center() - (lo + hi) * 0.5 * s
	return {"s": s, "o": origin, "hs": hs, "hp": hp, "outline": outline}


func _to(p: Vector2, pl: Dictionary) -> Vector2:
	return pl["o"] + p * float(pl["s"])


func _draw_layout() -> void:
	if room == null:
		return
	var pl: Dictionary = _plan()
	var hs: Vector3 = pl["hs"]
	var hp: Vector4 = pl["hp"]
	var s: float = pl["s"]
	var dim := Color(1, 1, 1, 0.35)
	var fs: Font = LabPrint.font("bold")
	# The walls: the outline where there is one, else the box.
	var outline: PackedVector2Array = pl["outline"]
	if outline.size() >= 3:
		var pts := PackedVector2Array()
		for q in outline:
			pts.append(_to(Vector2(hp.x + q.x, hp.z + q.y), pl))
		pts.append(pts[0])
		_layout.draw_polyline(pts, dim, 2.0, true)
	else:
		_layout.draw_rect(Rect2(_to(Vector2(hp.x - hs.x * 0.5, hp.z - hs.z * 0.5), pl), Vector2(hs.x, hs.z) * s), dim, false, 2.0)
	# The Botany Lab's pedestals.
	for i in 4:
		var st: Node4D = room.get_node_or_null("Station%02d" % (i + 1)) as Node4D
		if st != null:
			var c: Vector2 = _to(Vector2(st.global_position.x, st.global_position.z), pl)
			_layout.draw_arc(c, float(st.get("radius")) * s, 0.0, TAU, 40, dim, 2.0, true)
			_layout.draw_string(fs, c + Vector2(-9, 5), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	# The tank, the showcase, the fish wall, where they are.
	var tank: Node4D = room.get_node_or_null("Tank") as Node4D
	if tank != null:
		var ws: Vector4 = tank.get("water_size")
		_layout.draw_rect(Rect2(_to(Vector2(tank.global_position.x - ws.x * 0.5, tank.global_position.z - ws.z * 0.5), pl), Vector2(ws.x, ws.z) * s), Color(Style.UI_ACCENT, 0.25))
		_layout.draw_string(fs, _to(Vector2(tank.global_position.x, tank.global_position.z), pl) + Vector2(-20, 5), "TANK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, dim)
	var show: Node4D = room.get_node_or_null("Showcase") as Node4D
	if show != null:
		_layout.draw_arc(_to(Vector2(show.global_position.x, show.global_position.z), pl), float(show.get("radius")) * s, 0.0, TAU, 40, dim, 2.0, true)
	# The lights.
	for i in lights.size():
		var l: Node4D = lights[i]
		var at: Vector2 = _to(Vector2(l.global_position.x, l.global_position.z), pl)
		var aim: Vector3 = l.get("aim")
		var to: Vector2 = _to(Vector2(aim.x, aim.z), pl)
		var lit: bool = i == chosen
		var col: Color = Style.UI_ACCENT if lit else Color(1.0, 0.85, 0.45)
		_layout.draw_line(at, to, Color(col, 0.5), 1.5, true)
		_layout.draw_circle(at, 11.0 if lit else 8.0, col)
		_layout.draw_string(fs, at + Vector2(-12, 4), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 24, 11, Color(0.04, 0.06, 0.10))


func _layout_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var pl: Dictionary = _plan()
	var best: int = -1
	var best_d: float = 18.0
	for i in lights.size():
		var l: Node4D = lights[i]
		var d: float = _to(Vector2(l.global_position.x, l.global_position.z), pl).distance_to(mb.position)
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		chosen = best
		_build_rows()


# -- the rows -------------------------------------------------------------------------------------------------------

func _build_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()
	if lights.is_empty():
		return
	chosen = clampi(chosen, 0, lights.size() - 1)
	var l: Node = lights[chosen]
	var head := Label.new()
	head.text = "%d   %s" % [chosen + 1, String(l.name)]
	head.add_theme_font_override("font", LabPrint.font("bold"))
	head.modulate = Style.UI_ACCENT
	_rows.add_child(head)
	for r in ROWS:
		var nm: String = r[0]
		var v: float = float((l.get("energy") as Dictionary).get(Style.mood, 1.0)) if nm == "energy" else float(l.get(nm))
		var line := HBoxContainer.new()
		var label := Label.new()
		label.text = String(r[1])
		label.custom_minimum_size = Vector2(170, 0)
		line.add_child(label)
		var sl := HSlider.new()
		sl.min_value = float(r[2])
		sl.max_value = float(r[3])
		sl.step = float(r[4])
		sl.value = v
		sl.custom_minimum_size = Vector2(240, 24)
		sl.focus_mode = Control.FOCUS_NONE
		line.add_child(sl)
		var val := Label.new()
		val.text = _fmt(v, float(r[4]))
		val.custom_minimum_size = Vector2(60, 0)
		line.add_child(val)
		sl.value_changed.connect(func(x: float) -> void:
			_apply_value(l, nm, x)
			val.text = _fmt(x, float(r[4])))
		_rows.add_child(line)
	_rows_env()


## ALL LIGHTS AND THE ROOM: the shared spotlight multiplier and the room's own light, live.
func _rows_env() -> void:
	if env.is_empty():
		return
	var head := Label.new()
	head.text = "ALL LIGHTS AND THE ROOM"
	head.add_theme_font_override("font", LabPrint.font("bold"))
	head.modulate = Style.UI_ACCENT
	_rows.add_child(head)
	for r in ENV_ROWS:
		var nm: String = r[0]
		var line := HBoxContainer.new()
		var label := Label.new()
		label.text = String(r[1])
		label.custom_minimum_size = Vector2(170, 0)
		line.add_child(label)
		var sl := HSlider.new()
		sl.min_value = float(r[2])
		sl.max_value = float(r[3])
		sl.step = float(r[4])
		sl.value = float(env.get(nm, 0.0))
		sl.custom_minimum_size = Vector2(240, 24)
		sl.focus_mode = Control.FOCUS_NONE
		line.add_child(sl)
		var val := Label.new()
		val.text = _fmt(float(env.get(nm, 0.0)), float(r[4]))
		val.custom_minimum_size = Vector2(60, 0)
		line.add_child(val)
		sl.value_changed.connect(func(x: float) -> void:
			env[nm] = x
			_apply_env()
			val.text = _fmt(x, float(r[4])))
		_rows.add_child(line)


## The room's values as the scene set them, and the sliders at them (the spotlights at the hall's own multiplier).
func _env_snapshot() -> void:
	var r: Node = room.get_node_or_null("Room") if room != null else null
	if r == null:
		return
	var mood: String = String(r.get("mood"))
	var over: Dictionary = (r.get("mood_overrides") as Dictionary).get(mood, {})
	_env_base = Style.ROOM_LIGHT.get(mood, {}).duplicate()
	_env_base.merge(over, true)
	var sun: Node = room.get_node_or_null("Sun")
	var ang: Vector2 = sun.call("angles") if sun != null and sun.has_method("angles") else \
		Vector2(float(_env_base.get("key_elevation", 60.0)), float(_env_base.get("key_azimuth", 25.0)))
	env = {"gain": HALL_GAIN, "exposure": float(_env_base.get("exposure", 1.0)), "ambient_k": 1.0, "warmth": 0.0, "sky_k": 1.0,
		"key_energy": float(_env_base.get("key_energy", 0.4)), "key_elevation": ang.x, "key_azimuth": ang.y,
		"fill_energy": float(_env_base.get("fill_energy", 0.08))}
	_env_initial = env.duplicate()


## The sliders onto the lights and the room, now.
func _apply_env() -> void:
	if env.is_empty() or room == null:
		return
	Style.gain["spot"] = float(env["gain"])
	room.get_tree().call_group("kit_light", "apply_mood", Style.mood, true)
	var r: Node = room.get_node_or_null("Room")
	if r == null:
		return
	var mood: String = String(r.get("mood"))
	var all: Dictionary = (r.get("mood_overrides") as Dictionary).duplicate(true)
	var over: Dictionary = (all.get(mood, {}) as Dictionary).duplicate()
	var w: float = float(env["warmth"])
	var tint: Color = Color.WHITE.lerp(WARM, w) if w >= 0.0 else Color.WHITE.lerp(COOL, -w)
	var amb: Color = _env_base.get("ambient", Color(0.2, 0.24, 0.33))
	over["ambient"] = Color(amb.r * tint.r, amb.g * tint.g, amb.b * tint.b) * float(env["ambient_k"])
	for k in ["sky_top", "sky_horizon", "sky_bottom"]:
		var c: Color = _env_base.get(k, Color(0.1, 0.1, 0.15))
		over[k] = Color(c.r, c.g, c.b) * float(env["sky_k"])
	over["exposure"] = float(env["exposure"])
	over["key_energy"] = float(env["key_energy"])
	over["fill_energy"] = float(env["fill_energy"])
	over["key_elevation"] = float(env["key_elevation"])
	over["key_azimuth"] = float(env["key_azimuth"])
	all[mood] = over
	r.set("mood_overrides", all)
	r.call("set_mood", mood, true, false)
	# The Sun handle stands where the key light comes from (it writes the same two angles when it is moved).
	var sun: Node = room.get_node_or_null("Sun")
	if sun != null and sun.has_method("set_angles"):
		sun.call("set_angles", float(env["key_elevation"]), float(env["key_azimuth"]))


func _apply_value(l: Node, nm: String, x: float) -> void:
	if nm == "energy":
		var e: Dictionary = (l.get("energy") as Dictionary).duplicate()
		e[Style.mood] = x
		l.set("energy", e)
	else:
		l.set(nm, x)


static func _fmt(x: float, step: float) -> String:
	return ("%.0f" % x) if step >= 1.0 else (("%.1f" % x) if step >= 0.1 else "%.2f" % x)


# -- save, load, reset ---------------------------------------------------------------------------------------------

func save() -> void:
	var cf := ConfigFile.new()
	for l in lights:
		var v: Dictionary = _values(l)
		for key in v:
			cf.set_value(String(l.name), key, v[key])
	for key in env:
		cf.set_value("room", String(key), env[key])
	var err: int = cf.save(SAVE_PATH)
	_say("Saved to %s" % SAVE_PATH.get_file() if err == OK else "Could not save (%d)" % err)


func load_saved() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for l in lights:
		var sec: String = String(l.name)
		if not cf.has_section(sec):
			continue
		for key in cf.get_section_keys(sec):
			l.set(key, cf.get_value(sec, key))
	if cf.has_section("room"):
		for key in cf.get_section_keys("room"):
			env[key] = float(cf.get_value("room", key))


func reset() -> void:
	for l in lights:
		var v: Dictionary = _initial.get(String(l.name), {})
		for key in v:
			l.set(key, v[key])
	env = _env_initial.duplicate()
	_apply_env()
	_build_rows()
	_say("Back to the room's own values")


func _say(text: String) -> void:
	_flash.text = text
	_flash_t = 2.5
