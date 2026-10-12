extends PanelContainer

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

const LabPrint := preload("res://ramon/WaterLab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")
const SAVE_PATH := "res://ramon/WaterLab/water_lab_lights.cfg"
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
		load_saved()
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
	if k == null or not k.pressed or k.echo or k.keycode != KEY_TAB:
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
	for l in lights:
		var lp: Vector4 = (l as Node4D).global_position
		lo = Vector2(minf(lo.x, lp.x - 1.0), minf(lo.y, lp.z - 1.0))
		hi = Vector2(maxf(hi.x, lp.x + 1.0), maxf(hi.y, lp.z + 1.0))
	var r := Rect2(Vector2.ZERO, _layout.size).grow(-14.0)
	var s: float = minf(r.size.x / (hi.x - lo.x), r.size.y / (hi.y - lo.y))
	var origin: Vector2 = r.get_center() - (lo + hi) * 0.5 * s
	return {"s": s, "o": origin, "hs": hs, "hp": hp}


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
	# The walls.
	_layout.draw_rect(Rect2(_to(Vector2(hp.x - hs.x * 0.5, hp.z - hs.z * 0.5), pl), Vector2(hs.x, hs.z) * s), dim, false, 2.0)
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


func reset() -> void:
	for l in lights:
		var v: Dictionary = _initial.get(String(l.name), {})
		for key in v:
			l.set(key, v[key])
	_build_rows()
	_say("Back to the room's own values")


func _say(text: String) -> void:
	_flash.text = text
	_flash_t = 2.5
