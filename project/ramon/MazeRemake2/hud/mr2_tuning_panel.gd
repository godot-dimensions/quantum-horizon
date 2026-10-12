extends CanvasLayer
## THE TAB PANEL: the Annex's numbers, live, with SAVE (user://maze_remake_2_tuning.cfg) and RESET.
##
## Every row has a plain name and a line under it saying what it does (Ramon's rule from the Phase
## Maze remake's panel). While it is open the cursor is free, the game takes no keys and you stand
## still; Tab or Esc closes it and puts the mouse back as it was. The game reads the saved numbers when
## it starts (apply_saved).

const D := preload("res://ramon/MazeRemake2/hud/mr2_draw.gd")
const SAVE_PATH := "user://maze_remake_2_tuning.cfg"

## [key, name, note, min, max, step, getter target ("player" / "light" / "sound" / "game"), property]
const ROWS := [
	["mouse", "Mouse look", "How far the view turns for a move of the mouse.", 0.0006, 0.006, 0.0001, "player", "mouse_sensitivity"],
	["turn", "Turn into W", "How far a right-drag turns ahead into W.", 0.001, 0.012, 0.0005, "player", "turn_sensitivity"],
	["walk", "Walking speed", "Metres a second (Shift runs faster).", 1.5, 6.0, 0.1, "player", "walk_speed"],
	["wspeed", "Shift speed", "Metres of W a second while Q or E is held.", 0.4, 3.5, 0.05, "player", "w_speed"],
	["fov", "Field of view", "Degrees across the view.", 55.0, 105.0, 1.0, "player", "fov_degrees"],
	["key", "Sunlight", "The strength of the key light.", 0.2, 2.5, 0.05, "light", "key_gain"],
	["ambient", "Shadow brightness", "How light the shaded sides are.", 0.2, 2.5, 0.05, "light", "ambient_gain"],
	["exposure", "Exposure", "The whole picture, lighter or darker.", 0.5, 2.0, 0.02, "light", "exposure_gain"],
	["torch", "Torch", "The light you carry in DARK.", 0.0, 10.0, 0.1, "light", "torch_energy"],
	["volume", "Sound", "The hum, the W tone and the chimes, in dB.", -30.0, 8.0, 1.0, "sound", "volume_db"],
	["music", "Music", "The cave's track under it all, in dB.", -40.0, 6.0, 1.0, "sound", "music_db"],
]

var game: Node
var panel: PanelContainer
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _defaults: Dictionary = {}
var _mouse_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _status: Label
## [Control, base font size] and [Control, base minimum size]: set from the window's height (u = height
## / 720) when the panel opens and when the window changes, sized and never scaled (the kit's rule).
var _sized_fonts: Array = []
var _sized_mins: Array = []
var _sb: StyleBoxFlat
var _u: float = -1.0


func _ready() -> void:
	layer = 60
	visible = false
	_build()
	get_viewport().size_changed.connect(_size_to_window)


func _size_to_window() -> void:
	var u: float = maxf(0.5, get_viewport().get_visible_rect().size.y / 720.0)
	if absf(u - _u) < 0.001:
		return
	_u = u
	panel.offset_left = -400.0 * u
	panel.offset_right = -16.0 * u
	panel.offset_top = 16.0 * u
	panel.offset_bottom = -16.0 * u
	_sb.content_margin_left = 18.0 * u
	_sb.content_margin_right = 18.0 * u
	_sb.content_margin_top = 14.0 * u
	_sb.content_margin_bottom = 14.0 * u
	_sb.set_corner_radius_all(int(12.0 * u))
	for pair in _sized_fonts:
		if is_instance_valid(pair[0]):
			(pair[0] as Control).add_theme_font_size_override("font_size", maxi(7, int(round(float(pair[1]) * u))))
	for pair in _sized_mins:
		if is_instance_valid(pair[0]):
			(pair[0] as Control).custom_minimum_size = (pair[1] as Vector2) * u


func is_open() -> bool:
	return visible


func open() -> void:
	if visible:
		return
	_size_to_window()
	_mouse_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	(game.get("player") as Node).set("input_enabled", false)
	_refresh()
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	Input.mouse_mode = _mouse_before
	if String(game.get("mode")) == "play":
		(game.get("player") as Node).set("input_enabled", true)


func _target(which: String) -> Object:
	return game.get(which) as Object


## The numbers saved last time, onto the game (called once it is built).
func apply_saved() -> void:
	for r in ROWS:
		var t: Object = _target(String(r[6]))
		if t != null:
			_defaults[r[0]] = float(t.get(String(r[7])))
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for r in ROWS:
		if cfg.has_section_key("tuning", String(r[0])):
			_set_value(r, float(cfg.get_value("tuning", String(r[0]))))


func _set_value(r: Array, v: float) -> void:
	var t: Object = _target(String(r[6]))
	if t == null:
		return
	t.set(String(r[7]), v)
	_values[r[0]] = v
	match String(r[6]):
		"light":
			t.call("apply")
		"player":
			if String(r[7]) == "fov_degrees":
				var cam: Node = (t as Node).get("camera")
				if cam != null:
					cam.set("field_of_view_4d", deg_to_rad(v))
		"sound":
			t.call("set_level", int(game.get("level_index")))


func _refresh() -> void:
	for r in ROWS:
		var t: Object = _target(String(r[6]))
		if t == null or not _sliders.has(r[0]):
			continue
		(_sliders[r[0]] as HSlider).set_value_no_signal(float(t.get(String(r[7]))))
		_label_for(r)


func _label_for(r: Array) -> void:
	var s: HSlider = _sliders[r[0]]
	var lab: Label = s.get_meta("value_label")
	var v: float = s.value
	lab.text = ("%.4f" % v) if r[5] < 0.001 else (("%.2f" % v) if r[5] < 1.0 else ("%.0f" % v))


func save() -> void:
	var cfg := ConfigFile.new()
	for r in ROWS:
		var t: Object = _target(String(r[6]))
		if t != null:
			cfg.set_value("tuning", String(r[0]), float(t.get(String(r[7]))))
	var err: Error = cfg.save(SAVE_PATH)
	_status.text = "Saved." if err == OK else "Could not save (%d)." % err


func reset() -> void:
	for r in ROWS:
		if _defaults.has(r[0]):
			_set_value(r, float(_defaults[r[0]]))
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())
	_refresh()
	_status.text = "Back to the defaults."


func _build() -> void:
	var u: float = 1.0
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	_sb = sb
	sb.bg_color = Color(D.GLASS, 0.94)
	sb.border_color = D.EDGE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -400
	panel.offset_right = -16
	panel.offset_top = 16
	panel.offset_bottom = -16
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	scroll.add_child(col)
	var title := Label.new()
	title.text = "THE ANNEX  ·  TUNING"
	title.add_theme_font_override("font", D.font("title"))
	title.add_theme_font_size_override("font_size", 18)
	_sized_fonts.append([title, 18])
	title.add_theme_color_override("font_color", D.ACCENT)
	col.add_child(title)
	var hint := Label.new()
	hint.text = "Live as you drag. SAVE keeps them; Tab or Esc closes."
	hint.add_theme_font_override("font", D.font("text"))
	hint.add_theme_font_size_override("font_size", 12)
	_sized_fonts.append([hint, 12])
	hint.add_theme_color_override("font_color", D.INK_DIM)
	col.add_child(hint)
	for r in ROWS:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var head := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = String(r[1])
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_font_override("font", D.font("heading"))
		name_l.add_theme_font_size_override("font_size", 14)
		_sized_fonts.append([name_l, 14])
		head.add_child(name_l)
		var val := Label.new()
		val.add_theme_font_override("font", D.font("key"))
		val.add_theme_font_size_override("font_size", 13)
		_sized_fonts.append([val, 13])
		val.add_theme_color_override("font_color", D.ACCENT)
		head.add_child(val)
		row.add_child(head)
		var note := Label.new()
		note.text = String(r[2])
		note.add_theme_font_override("font", D.font("text"))
		note.add_theme_font_size_override("font_size", 11)
		_sized_fonts.append([note, 11])
		note.add_theme_color_override("font_color", D.INK_DIM)
		row.add_child(note)
		var s := HSlider.new()
		s.min_value = float(r[3])
		s.max_value = float(r[4])
		s.step = float(r[5])
		s.custom_minimum_size = Vector2(0, 20)
		_sized_mins.append([s, Vector2(0, 20)])
		s.set_meta("value_label", val)
		var rr: Array = r
		s.value_changed.connect(func(v: float) -> void:
			_set_value(rr, v)
			_label_for(rr))
		row.add_child(s)
		col.add_child(row)
		_sliders[r[0]] = s
	var gz := HBoxContainer.new()
	gz.add_theme_constant_override("separation", 6)
	var gl := Label.new()
	gl.text = "Gizmo"
	gl.add_theme_font_override("font", D.font("heading"))
	gl.add_theme_font_size_override("font_size", 14)
	_sized_fonts.append([gl, 14])
	gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gz.add_child(gl)
	for i in 4:
		var b := Button.new()
		b.text = ["MAP", "RULER", "DIAL", "LENS"][i]
		b.add_theme_font_override("font", D.font("key"))
		b.add_theme_font_size_override("font_size", 11)
		_sized_fonts.append([b, 11])
		var idx: int = i
		b.pressed.connect(func() -> void:
			(game.get("hud") as Node).call("set_gizmo", idx))
		gz.add_child(b)
	col.add_child(gz)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	for pair in [["SAVE", save], ["RESET", reset], ["CLOSE", close]]:
		var b := Button.new()
		b.text = String(pair[0])
		b.add_theme_font_override("font", D.font("key"))
		b.add_theme_font_size_override("font_size", 13)
		_sized_fonts.append([b, 13])
		b.custom_minimum_size = Vector2(96, 30)
		_sized_mins.append([b, Vector2(96, 30)])
		b.pressed.connect(pair[1])
		buttons.add_child(b)
	col.add_child(buttons)
	_status = Label.new()
	_status.add_theme_font_override("font", D.font("text"))
	_status.add_theme_font_size_override("font_size", 12)
	_sized_fonts.append([_status, 12])
	_status.add_theme_color_override("font_color", D.INK_SOFT)
	col.add_child(_status)
