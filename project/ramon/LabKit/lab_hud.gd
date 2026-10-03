extends CanvasLayer

## The lab's HUD: the guide panel, the controls card, the W ladder and the floor list.
##
##   guide panel (top left)   the Unreal tutorials' panel: STEP 3 OF 10 · BUILD, the title, the one
##                            idea, the one task with its keys as chips and a box that ticks, then
##                            what happened and what is next
##   controls card (bottom)   every key the bay answers to right now, the task's first; the extras
##                            dimmed under a rule
##   W ladder (right edge)    the stack of bays as a column of ticks along W, the one you are in
##                            lit, done ones filled: where you are, always
##   floor list (M)           every step, to ride the lift straight to one
##
## Styled from LabKit/lab_style.gd in the current mood: a light card with dark type in the bright
## mood, dark glass with light type in the dark one. Sizes follow the window (1080 px is 1.0).
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/LabKit/lab_style.gd")

signal floor_chosen(index: int)

var mood: String = "bright"
var _ui: float = 1.0
var _guide: PanelContainer
var _kicker: Label
var _title: Label
var _idea: Label
var _task_row: HBoxContainer
var _task_box: Control
var _task_keys: HBoxContainer
## The lift's marker on the ladder while riding, as a fractional step index; -1 when still.
var ladder_marker: float = -1.0
## Height kept free along the bottom edge, in pixels at 1080 p: the shared "back to menu" prompt
## (Demo/return_button.tscn) sits in the bottom-left corner of every prototype.
var bottom_reserve: float = 0.0
var _task_done: bool = false
var _task_text: Label
var _after: Label
var _next: Label
var _controls: PanelContainer
var _controls_box: VBoxContainer
var _ladder: Control
var _floor_list: PanelContainer
var _floor_box: VBoxContainer
var _chime: AudioStreamPlayer
var _toast: Label
var _toast_t: float = 0.0

## What the ladder draws: [{number, title, part, done}] and the index you are at.
var steps: Array = []
var current: int = 0
var _floor_sel: int = 0


func _enter_tree() -> void:
	add_to_group("lab_hud")
	add_to_group("lab_mood_listener")
	layer = 10


func _ready() -> void:
	mood = Style.mood_of(get_tree())
	_build()
	_resize()
	get_viewport().size_changed.connect(_resize)


func _resize() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_ui = clampf(vp.y / 1080.0, 0.7, 2.2)
	_restyle()


# -- building ------------------------------------------------------------------------------------

func _label(text: String, step: int, weight: String, role: String, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.set_meta("step", step)
	l.set_meta("weight", weight)
	l.set_meta("role", role)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_guide = PanelContainer.new()
	_guide.name = "Guide"
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_guide)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide.add_child(v)
	_kicker = _label("", Style.MICRO, "Bold", "part")
	_title = _label("", Style.TITLE, "SemiBold", "text", true)
	_idea = _label("", Style.BODY, "Regular", "text_dim", true)
	v.add_child(_kicker)
	v.add_child(_title)
	v.add_child(_idea)
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.custom_minimum_size = Vector2(0, 1)
	rule.set_meta("role", "rule")
	v.add_child(rule)
	_task_row = HBoxContainer.new()
	v.add_child(_task_row)
	# Drawn, not a glyph: Montserrat has no ballot-box characters.
	_task_box = Control.new()
	_task_box.custom_minimum_size = Vector2(22, 22)
	_task_box.draw.connect(_draw_task_box)
	_task_text = _label("", Style.BODY, "Medium", "text", true)
	_task_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_row.add_child(_task_box)
	var task_col := VBoxContainer.new()
	task_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_col.add_child(_task_text)
	_task_keys = HBoxContainer.new()
	_task_keys.name = "TaskKeys"
	task_col.add_child(_task_keys)
	_task_row.add_child(task_col)
	_after = _label("", Style.CAPTION, "Regular", "text_dim", true)
	_next = _label("", Style.CAPTION, "SemiBold", "w", true)
	v.add_child(_after)
	v.add_child(_next)

	_controls = PanelContainer.new()
	_controls.name = "Controls"
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_controls)
	_controls_box = VBoxContainer.new()
	_controls.add_child(_controls_box)

	_ladder = Control.new()
	_ladder.name = "Ladder"
	_ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ladder.draw.connect(_draw_ladder)
	root.add_child(_ladder)

	_floor_list = PanelContainer.new()
	_floor_list.name = "FloorList"
	_floor_list.visible = false
	root.add_child(_floor_list)
	_floor_box = VBoxContainer.new()
	_floor_list.add_child(_floor_box)

	_toast = _label("", Style.SUBTITLE, "SemiBold", "ok")
	_toast.visible = false
	root.add_child(_toast)

	_chime = AudioStreamPlayer.new()
	_chime.stream = _make_chime()
	_chime.volume_db = -10.0
	add_child(_chime)


## A soft two-tone chime, made here (no asset): a fifth, quickly decaying.
func _make_chime() -> AudioStreamWAV:
	var rate: int = 44100
	var n: int = int(rate * 0.55)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / float(rate)
		var a: float = sin(TAU * 880.0 * t) * exp(-t * 7.0)
		var b: float = (sin(TAU * 1318.5 * (t - 0.09)) * exp(-(t - 0.09) * 6.0)) if t > 0.09 else 0.0
		var v2: int = int(clampf((a * 0.45 + b * 0.4) * 0.6, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v2)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


# -- content -------------------------------------------------------------------------------------

## Fills the guide panel for a step (a LabKit/lab_step.gd resource) at `index` of `total`.
func show_step(step: Resource, index: int, total: int, done: bool) -> void:
	var part: String = String(step.get("part"))
	var kick: String = "STEP %d OF %d  ·  %s" % [index, total - 2, part.to_upper()] if part in ["build", "motion"] else part.to_upper()
	_kicker.text = "%s   %s" % [String(step.get("code")), kick]
	_kicker.set_meta("part", part)
	_title.text = String(step.get("title"))
	_idea.text = String(step.get("idea"))
	_task_text.text = String(step.get("task"))
	_clear(_task_keys)
	for k in step.get("task_keys"):
		_task_keys.add_child(_chip(String(k)))
	_task_keys.visible = _task_keys.get_child_count() > 0
	set_done(done, String(step.get("after")), index < total - 1)
	_restyle()


func set_done(done: bool, after: String, has_next: bool) -> void:
	_task_done = done
	_task_box.queue_redraw()
	_after.visible = done and not after.is_empty()
	_after.text = after
	_next.visible = done and has_next
	_next.text = "[N]  Ride the lift to the next step" if has_next else ""
	_restyle()


## The chime and, with `text`, a short line at the top of the screen in a colour role ("ok" for
## a finished task, "w" for the lift, "text" for a refusal). `sound` false is a silent notice.
func chime(text: String = "", role: String = "ok", sound: bool = true) -> void:
	if sound and _chime != null and _chime.stream != null:
		_chime.play()
	if not text.is_empty():
		_toast.text = text
		_toast.set_meta("role", role)
		_toast.visible = true
		_toast_t = 2.2
		_restyle()


## Rows for the controls card: [[key, what], ...]; extras dimmed under a rule.
func show_controls(rows: Array, extras: Array) -> void:
	_clear(_controls_box)
	for r in rows:
		_controls_box.add_child(_key_row(String(r[0]), String(r[1]), false))
	if not extras.is_empty():
		var rule := ColorRect.new()
		rule.custom_minimum_size = Vector2(0, 1)
		rule.set_meta("role", "rule")
		_controls_box.add_child(rule)
		for r in extras:
			_controls_box.add_child(_key_row(String(r[0]), String(r[1]), true))
	_restyle()


## Out of the tree at once, so a panel measures its new rows and not the ones on their way out.
func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _chip(key: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.set_meta("chip", true)
	var k := _label(key, Style.CAPTION, "SemiBold", "chip_text")
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(k)
	return chip


func _key_row(key: String, what: String, dim: bool) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_child(_chip(key))
	var w := _label(what, Style.CAPTION, "Medium", "text_faint" if dim else "text_dim")
	h.add_child(w)
	return h


func set_ladder(list: Array, at: int) -> void:
	steps = list
	current = at
	_ladder.queue_redraw()


func open_floor_list(at: int) -> void:
	_floor_sel = at
	_floor_list.visible = true
	_fill_floor_list()


func close_floor_list() -> void:
	_floor_list.visible = false


func floor_list_open() -> bool:
	return _floor_list.visible


func move_floor_selection(d: int) -> void:
	_floor_sel = clampi(_floor_sel + d, 0, steps.size() - 1)
	_fill_floor_list()


func floor_selection() -> int:
	return _floor_sel


func _fill_floor_list() -> void:
	for c in _floor_box.get_children():
		c.queue_free()
	_floor_box.add_child(_label("THE W-LIFT  ·  ride to a step", Style.MICRO, "Bold", "w"))
	for i in steps.size():
		var s: Dictionary = steps[i]
		var mark: String = "▶ " if i == _floor_sel else "   "
		var tick: String = "done" if s.get("done", false) else "    "
		var label: String = "%sW %+4d   %s   %s" % [mark, int(s.get("w", 0)), String(s.get("title", "")), tick]
		_floor_box.add_child(_label(label, Style.BODY, "SemiBold" if i == _floor_sel else "Regular", "text" if i == _floor_sel else "text_dim"))
	_floor_box.add_child(_label("Up / Down to choose   Enter to ride   M or Esc to close", Style.MICRO, "Regular", "text_faint"))
	_restyle()


# -- style ---------------------------------------------------------------------------------------

func apply_mood(m: String, _instant: bool = false) -> void:
	mood = m
	_restyle()


func _restyle() -> void:
	if _guide == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = Style.space(3.0, _ui)
	for p in [_guide, _controls, _floor_list]:
		var box: StyleBoxFlat = Style.panel_box(mood, _ui)
		box.content_margin_left = Style.space(2.5, _ui)
		box.content_margin_right = Style.space(2.5, _ui)
		box.content_margin_top = Style.space(2.0, _ui)
		box.content_margin_bottom = Style.space(2.0, _ui)
		(p as PanelContainer).add_theme_stylebox_override("panel", box)
	_guide.position = Vector2(margin, margin)
	_guide.custom_minimum_size = Vector2(420.0 * _ui, 0.0)
	_task_box.custom_minimum_size = Vector2(22.0, 22.0) * _ui
	_guide.size = Vector2(420.0 * _ui, 0.0)
	_controls.position = Vector2(margin, vp.y - margin - bottom_reserve * _ui - _controls.size.y)
	_floor_list.position = (vp - _floor_list.size) * 0.5
	_ladder.position = Vector2(vp.x - margin - 64.0 * _ui, vp.y * 0.22)
	_ladder.size = Vector2(64.0 * _ui, vp.y * 0.56)
	_toast.position = Vector2(vp.x * 0.5 - _toast.size.x * 0.5, vp.y * 0.18)
	_style_tree(self)
	_ladder.queue_redraw()


func _style_tree(n: Node) -> void:
	for c in n.get_children():
		if c is Label:
			var l: Label = c
			l.add_theme_font_override("font", Style.font(String(l.get_meta("weight", "Regular"))))
			l.add_theme_font_size_override("font_size", Style.size(int(l.get_meta("step", Style.BODY)), _ui))
			var role: String = String(l.get_meta("role", "text"))
			var col: Color
			match role:
				"part":
					var part: String = String(l.get_meta("part", "build"))
					col = Style.code(part, mood) if part in ["build", "motion"] else Style.ui("text_dim", mood)
				"interact", "ok", "w", "limit":
					col = Style.code(role, mood)
				_:
					col = Style.ui(role, mood)
			l.add_theme_color_override("font_color", col)
		elif c is ColorRect and String(c.get_meta("role", "")) == "rule":
			(c as ColorRect).color = Style.ui("rule", mood)
		elif c is PanelContainer and c.has_meta("chip"):
			var chip_box := StyleBoxFlat.new()
			chip_box.bg_color = Style.ui("chip", mood)
			chip_box.border_color = Style.ui("chip_border", mood)
			chip_box.set_border_width_all(1)
			chip_box.set_corner_radius_all(int(4 * _ui))
			chip_box.content_margin_left = 6.0 * _ui
			chip_box.content_margin_right = 6.0 * _ui
			chip_box.content_margin_top = 1.0 * _ui
			chip_box.content_margin_bottom = 1.0 * _ui
			(c as PanelContainer).add_theme_stylebox_override("panel", chip_box)
			(c as PanelContainer).custom_minimum_size = Vector2(34.0 * _ui, 0.0)
		if c is BoxContainer:
			(c as BoxContainer).add_theme_constant_override("separation", int(Style.space(1.0, _ui)))
		_style_tree(c)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)
		if _toast_t <= 0.0:
			_toast.visible = false
	# Panels change size as their text does: shrink them to their content (a container only ever
	# grows by itself) and keep the bottom-anchored ones anchored.
	for p in [_guide, _controls, _floor_list]:
		var pc: PanelContainer = p
		var want: Vector2 = pc.get_combined_minimum_size()
		if not pc.size.is_equal_approx(want):
			pc.size = want
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var margin: float = Style.space(3.0, _ui)
	_controls.position = Vector2(margin, vp.y - margin - bottom_reserve * _ui - _controls.size.y)
	_floor_list.position = (vp - _floor_list.size) * 0.5


func _draw_ladder() -> void:
	if steps.is_empty():
		return
	var h: float = _ladder.size.y
	var x: float = _ladder.size.x * 0.5
	var n: int = steps.size()
	var w_col: Color = Style.code("w", mood)
	var faint: Color = Style.ui("text_faint", mood)
	var font: Font = Style.font("SemiBold")
	var fs: int = Style.size(Style.MICRO, _ui)
	_ladder.draw_line(Vector2(x, 0.0), Vector2(x, h), Color(faint, 0.6), 1.5 * _ui, true)
	_ladder.draw_string(font, Vector2(x - 6.0 * _ui, -8.0 * _ui), "W", HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, w_col)
	for i in n:
		var y: float = h * float(i) / float(maxi(n - 1, 1))
		var s: Dictionary = steps[i]
		var here: bool = i == current
		var r: float = (7.0 if here else 4.5) * _ui
		if bool(s.get("done", false)) or here:
			_ladder.draw_circle(Vector2(x, y), r, w_col if here else Color(w_col, 0.7))
		else:
			_ladder.draw_arc(Vector2(x, y), r, 0.0, TAU, 20, faint, 1.5 * _ui, true)
		var num: String = str(s.get("number", "")) if int(s.get("number", -1)) >= 0 else String(s.get("short", ""))
		_ladder.draw_string(font, Vector2(x - 34.0 * _ui, y + fs * 0.35), num, HORIZONTAL_ALIGNMENT_RIGHT, 24.0 * _ui, fs, w_col if here else faint)
	if ladder_marker >= 0.0:
		var ym: float = h * ladder_marker / float(maxi(n - 1, 1))
		_ladder.draw_arc(Vector2(x, ym), 9.0 * _ui, 0.0, TAU, 28, w_col, 2.2 * _ui, true)
		_ladder.draw_line(Vector2(x + 12.0 * _ui, ym), Vector2(x + 22.0 * _ui, ym), w_col, 2.0 * _ui, true)


## The screen rectangles the HUD's panels take, for panels drawn over the world to keep clear of.
func occupied_rects() -> Array:
	var out: Array = []
	if not visible:
		return out
	for p in [_guide, _controls]:
		var c: Control = p
		if c.visible:
			out.append(Rect2(c.position, c.size).grow(6.0))
	return out


func set_ladder_marker(f: float) -> void:
	ladder_marker = f
	_ladder.queue_redraw()


func _draw_task_box() -> void:
	var r := Rect2(Vector2(2, 3) * _ui, Vector2(16, 16) * _ui)
	if _task_done:
		var ok: Color = Style.code("ok", mood)
		var box := StyleBoxFlat.new()
		box.bg_color = ok
		box.set_corner_radius_all(int(3 * _ui))
		_task_box.draw_style_box(box, r)
		var ink: Color = Color.WHITE if mood == Style.DARK else Color(1, 1, 1)
		var a: Vector2 = r.position + Vector2(3.5, 8.5) * _ui
		var b: Vector2 = r.position + Vector2(7.0, 12.0) * _ui
		var c: Vector2 = r.position + Vector2(13.0, 4.5) * _ui
		_task_box.draw_polyline(PackedVector2Array([a, b, c]), ink, 2.2 * _ui, true)
	else:
		var box2 := StyleBoxFlat.new()
		box2.bg_color = Color(0, 0, 0, 0)
		box2.border_color = Style.code("interact", mood)
		box2.set_border_width_all(int(maxf(2.0 * _ui, 1.0)))
		box2.set_corner_radius_all(int(3 * _ui))
		_task_box.draw_style_box(box2, r)
