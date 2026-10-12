extends Control

## The R&D gallery's screen layer, kept small (the walls carry the reading):
##   the strip    a rounded bar at the bottom centre with the controls that work where you stand,
##                as in Ramon's concept frames ("Move | Look | E Interact")
##   the caption  during a cinematic: the room, the shot's title and number, one line, and how to
##                skip
##   a toast      one short line at the top (a ball placed, a gait changed)
##   the switch   a dark / bright button at the top right (B does the same)
##
## Sizes follow the window's height (`u`), never the distance to anything. Colours follow the mood.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/WaterLab/carried/LabKit/lab_print.gd")
const RD := preload("res://ramon/WaterLab/carried/scripts/rd_build.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")

signal mood_pressed

var mood: String = "bright"
var strip: Array = []                 # [[key, label], ...]
## WATER LAB: where the strip's middle sits, as a share of the screen's height (-1: at the bottom).
## The feeding booth lifts its one key to the middle, over you (round 3: "place it in the middle of the
## screen ... make that button higher").
var strip_at: float = -1.0
## Dark glass in both moods, with white type, as the lab's other overlays (kit_style.gd); the goat
## room turns it on, the other rooms keep the mood-following strip.
var glass: bool = false
## The mood switch's label, if the room gives one (the goat room's palette switch).
var switch_text: String = ""
var caption_title: String = ""
var caption_line: String = ""
var caption_count: String = ""
var _caption_a: float = 0.0
var _caption_want: float = 0.0
var _toast: String = ""
var _toast_t: float = 0.0
var _button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = Button.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(func() -> void: mood_pressed.emit())
	add_child(_button)
	_style_button()


func show_caption(title_text: String, count: String, line: String) -> void:
	caption_title = title_text
	caption_count = count
	caption_line = line
	_caption_want = 1.0


func hide_caption() -> void:
	_caption_want = 0.0


func toast(text: String) -> void:
	_toast = text
	_toast_t = 2.4


func set_mood(m: String) -> void:
	mood = m
	_style_button()


func _style_button() -> void:
	if _button == null:
		return
	var u: float = maxf(size.y, 360.0) / 720.0
	var dark: bool = mood == "dark"
	_button.text = switch_text if not switch_text.is_empty() else ("BRIGHT  ·  B" if dark else "DARK  ·  B")
	if glass:
		_button.add_theme_font_override("font", LabPrint.font("bold"))
		_button.add_theme_font_size_override("font_size", Style.type_px("caption", u))
		for state in ["normal", "hover", "pressed"]:
			var gb: StyleBoxFlat = Style.glass_box(16 * u)
			if state == "hover":
				gb.bg_color = gb.bg_color.lightened(0.12)
			gb.content_margin_left = 16 * u
			gb.content_margin_right = 16 * u
			gb.content_margin_top = 6 * u
			gb.content_margin_bottom = 6 * u
			_button.add_theme_stylebox_override(state, gb)
		for c in ["font_color", "font_hover_color", "font_pressed_color"]:
			_button.add_theme_color_override(c, Style.UI_INK)
		return
	_button.add_theme_font_override("font", LabPrint.font("bold"))
	_button.add_theme_font_size_override("font_size", int(13 * u))
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.97, 0.97, 0.96, 0.92) if dark else Color(0.07, 0.08, 0.10, 0.88)
		if state == "hover":
			sb.bg_color = sb.bg_color.lightened(0.1) if dark else sb.bg_color.lightened(0.15)
		sb.set_corner_radius_all(int(16 * u))
		sb.content_margin_left = 16 * u
		sb.content_margin_right = 16 * u
		sb.content_margin_top = 6 * u
		sb.content_margin_bottom = 6 * u
		_button.add_theme_stylebox_override(state, sb)
	var ink: Color = Color(0.08, 0.09, 0.11) if dark else Color(0.96, 0.96, 0.94)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		_button.add_theme_color_override(c, ink)


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size
	if size != want or position != Vector2.ZERO:
		position = Vector2.ZERO
		size = want
		_style_button()
	var u: float = size.y / 720.0
	if _button != null:
		_button.reset_size()
		_button.position = Vector2(size.x - _button.size.x - 20.0 * u, 18.0 * u)
	_caption_a = move_toward(_caption_a, _caption_want, delta / 0.35)
	_toast_t = maxf(0.0, _toast_t - delta)
	queue_redraw()


func _draw() -> void:
	var u: float = size.y / 720.0
	if u <= 0.0:
		return
	var dark: bool = mood == "dark"
	var bg: Color = Color(0.06, 0.07, 0.09, 0.86) if dark else Color(0.98, 0.98, 0.97, 0.92)
	var ink: Color = Color(0.95, 0.95, 0.93) if dark else Color(0.09, 0.10, 0.12)
	if glass:
		bg = Color(Style.UI_GLASS, Style.UI_GLASS_ALPHA)
		ink = Style.UI_INK
	var accent: Color = RD.INK[mood]["accent"]
	if not strip.is_empty() and _caption_a < 0.5:
		_draw_strip(u, bg, ink, accent)
	if _caption_a > 0.001:
		_draw_caption(u, ink, accent)
	if _toast_t > 0.0:
		var a: float = clampf(_toast_t / 0.4, 0.0, 1.0)
		var f: Font = LabPrint.font("bold")
		var px: int = Style.type_px("lead", u) if glass else int(15 * u)
		var w: float = f.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 40.0 * u
		var r := Rect2(Vector2((size.x - w) * 0.5, 22.0 * u), Vector2(w, 36.0 * u))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(bg, bg.a * a)
		sb.set_corner_radius_all(int(18 * u))
		draw_style_box(sb, r)
		draw_string(f, Vector2(r.position.x, r.get_center().y + 5.5 * u), _toast, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px, Color(ink, a))


func _draw_strip(u: float, bg: Color, ink: Color, accent: Color) -> void:
	var fk: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	# THE MENU'S KEY, BROKEN OFF (Ramon, 11 Oct: "menu is placed [off] what I just called strip, so a
	# breakage, and this should be the only blue part"). A last entry tagged "menu" (the scene's
	# _menu_key(), while it runs from the menu) is drawn as its own pill right of the strip, in the
	# strip's shape and type, on the menu's blue; the strip keeps its place.
	var items: Array = strip
	var menu_item: Array = []
	if not strip.is_empty() and (strip[strip.size() - 1] as Array).size() > 2 and String(strip[strip.size() - 1][2]) == "menu":
		menu_item = strip[strip.size() - 1]
		items = strip.slice(0, strip.size() - 1)
	# On the lab's type ladder when it is the glass HUD: the key a caption, its label body text.
	var kpx: int = Style.type_px("caption", u) if glass else int(11 * u)
	var lpx: int = Style.type_px("body", u) if glass else int(13 * u)
	var gap: float = 22.0 * u
	var widths: Array = []
	var total: float = 0.0
	for it in items:
		var kw: float = 0.0 if String(it[0]).is_empty() else maxf(24.0 * u, fk.get_string_size(String(it[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, kpx).x + 14.0 * u)
		var lw: float = fl.get_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
		widths.append([kw, lw])
		total += kw + 8.0 * u + lw
	total += gap * float(items.size() - 1) + 40.0 * u
	var h: float = 40.0 * u
	var r := Rect2(Vector2((size.x - total) * 0.5, size.y - h - 22.0 * u), Vector2(total, h))
	if strip_at >= 0.0:
		r.position.y = size.y * strip_at - h * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(int(h * 0.5))
	draw_style_box(sb, r)
	var x: float = r.position.x + 20.0 * u
	for i in items.size():
		var kw: float = widths[i][0]
		var lw: float = widths[i][1]
		var kr := Rect2(Vector2(x, r.get_center().y - 11.0 * u), Vector2(kw, 22.0 * u))
		var lx: float = kr.end.x + 8.0 * u
		if kw > 0.0:
			var kb := StyleBoxFlat.new()
			kb.draw_center = false
			kb.border_color = Color(ink, 0.7)
			kb.set_border_width_all(int(maxf(1.0, 1.5 * u)))
			kb.set_corner_radius_all(int(5 * u))
			draw_style_box(kb, kr)
			draw_string(fk, Vector2(kr.position.x, kr.get_center().y + 4.0 * u), String(items[i][0]), HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, kpx, ink)
		else:
			lx = x
		draw_string(fl, Vector2(lx, r.get_center().y + 4.5 * u), String(items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, ink)
		x = lx + lw + gap
		if i < items.size() - 1:
			draw_line(Vector2(x - gap * 0.5, r.position.y + 11.0 * u), Vector2(x - gap * 0.5, r.end.y - 11.0 * u), Color(ink, 0.25), maxf(1.0, u))
	if not menu_item.is_empty():
		_draw_menu_pill(u, menu_item, r if not items.is_empty() else Rect2(Vector2(size.x * 0.5, r.position.y), Vector2(0.0, h)), fk, fl, kpx, lpx, items.is_empty())


## The menu's key as its own blue pill, `gap` right of the strip `beside` (or centred on it when the
## strip is empty), the strip's height and type.
func _draw_menu_pill(u: float, item: Array, beside: Rect2, fk: Font, fl: Font, kpx: int, lpx: int, centred: bool) -> void:
	var white := Color(0.97, 0.98, 1.0)
	var kw: float = maxf(24.0 * u, fk.get_string_size(String(item[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, kpx).x + 14.0 * u)
	var lw: float = fl.get_string_size(String(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx).x
	var w: float = 20.0 * u + kw + 8.0 * u + lw + 20.0 * u
	var x0: float = beside.position.x - w * 0.5 if centred else beside.end.x + 12.0 * u
	var r := Rect2(Vector2(x0, beside.position.y), Vector2(w, beside.size.y))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.125, 0.384, 0.863)
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var kr := Rect2(Vector2(r.position.x + 20.0 * u, r.get_center().y - 11.0 * u), Vector2(kw, 22.0 * u))
	var kb := StyleBoxFlat.new()
	kb.draw_center = false
	kb.border_color = Color(white, 0.85)
	kb.set_border_width_all(int(maxf(1.0, 1.5 * u)))
	kb.set_corner_radius_all(int(5 * u))
	draw_style_box(kb, kr)
	draw_string(fk, Vector2(kr.position.x, kr.get_center().y + 4.0 * u), String(item[0]), HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, kpx, white)
	draw_string(fl, Vector2(kr.end.x + 8.0 * u, r.get_center().y + 4.5 * u), String(item[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, lpx, white)


func _draw_caption(u: float, ink: Color, accent: Color) -> void:
	var a: float = _caption_a
	var band_h: float = 92.0 * u
	var r := Rect2(Vector2(0.0, size.y - band_h - 60.0 * u), Vector2(size.x, band_h))
	draw_rect(r, Color(0.04, 0.05, 0.07, 0.78 * a))
	var pad: float = size.x * 0.08
	draw_rect(Rect2(Vector2(pad, r.position.y), Vector2(size.x - pad * 2.0, 2.0 * u)), Color(accent, a))
	var fb: Font = LabPrint.font("black")
	var fl: Font = LabPrint.font("body")
	var fs: Font = LabPrint.font("bold")
	draw_string(fb, Vector2(pad, r.position.y + 34.0 * u), caption_title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * u), Color(accent.lightened(0.2), a))
	draw_string(fs, Vector2(0.0, r.position.y + 34.0 * u), caption_count + "      CLICK TO SKIP", HORIZONTAL_ALIGNMENT_RIGHT, size.x - pad, int(12 * u), Color(1, 1, 1, 0.65 * a))
	draw_string(fl, Vector2(pad, r.position.y + 66.0 * u), caption_line, HORIZONTAL_ALIGNMENT_LEFT, size.x - pad * 2.0, int(18 * u), Color(1, 1, 1, a))


## The switch's label has changed.
func refresh_switch() -> void:
	_style_button()
