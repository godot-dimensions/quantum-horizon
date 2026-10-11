extends Control
## Crosswise's HUD: small, black glass, white type (the lab kit's rule: screens and overlays are
## black; CreationLab/kit/kit_style.gd). Miegakure has no HUD at all; this one is for people new to
## 4D, so it answers "which way am I looking, and where am I in W" in one glance, and gets out of
## the way otherwise (PLAN.md step 49).
##
##   VIEW BADGE   top left: X Y Z or X Y W, the swapped letter in its axis colour (Z blue, W amber),
##                with the key that turns it
##   W RULER      under it: the island's five lanes as a column of their floor colours (ana up), you
##                as a coral bar, the island's crates as yellow squares, the goal as a gold diamond
##   KEYS         bottom centre: the keys, short
##   PROMPT       beside the thing in reach (E lift, E put down, CLICK strike), fixed size
##   TITLE        on arriving at an island: its number and name, held, then gone
##   HINT         F: the island's hint, for a while
##   FADE         a short fade for falls and restarts; the FINALE card at the end
##
## Text never scales with distance (Ramon's lab verdict, 4 Oct). It does scale with the window: the
## HUD is laid out for 720 lines and drawn larger in a taller window (the project's window is 1920 x
## 1080 with no stretch mode, so pixel sizes alone would shrink it there by a third).
##
## NO class_name (engine_gotchas.md).

const FONT_BLACK := "res://ramon/Demo/fonts/Montserrat/static/Montserrat-ExtraBold.ttf"
const FONT_BOLD := "res://ramon/Demo/fonts/Montserrat/static/Montserrat-Bold.ttf"
const FONT_BODY := "res://ramon/Demo/fonts/Montserrat/static/Montserrat-SemiBold.ttf"
const GLASS := Color(0.04, 0.06, 0.10, 0.86)
const INK := Color(1, 1, 1)
const INK_DIM := Color(0.80, 0.86, 0.96, 0.85)
const ACCENT := Color(0.40, 0.76, 1.0)
const Z_COL := Color(0.45, 0.62, 1.0)
const W_COL := Color(1.0, 0.64, 0.25)
const YOU := Color(0.95, 0.42, 0.33)
const CRATE := Color(1.0, 0.85, 0.30)
const GOAL := Color(1.0, 0.80, 0.35)
const LANE_COLS := [Color(0.62, 0.74, 0.98), Color(0.78, 0.86, 1.0), Color(0.92, 0.93, 0.95), Color(1.0, 0.90, 0.76), Color(1.0, 0.80, 0.58)]

var game: Node
var camera: Node
var walker: Node4D
var hands: Node

var _bold: Font
var _black: Font
var _body: Font
var _title_text: String = ""
var _title_sub: String = ""
var _title_t: float = -1.0
var _hint_text: String = ""
var _hint_t: float = -1.0
var _fade: float = 0.0
var _fade_target: float = 0.0
var _finale: Dictionary = {}
var _bubble: Dictionary = {}
var _note: String = ""
var _note_t: float = -1.0
var _ui: float = 1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bold = load(FONT_BOLD)
	_black = load(FONT_BLACK)
	_body = load(FONT_BODY)


func show_title(number: int, name: String, sub: String = "") -> void:
	_title_text = "%d  ·  %s" % [number, name]
	_title_sub = sub
	_title_t = 0.0


func show_hint(text: String) -> void:
	_hint_text = text
	_hint_t = 0.0


func show_note(text: String) -> void:
	_note = text
	_note_t = 0.0


func fade_to(v: float) -> void:
	_fade_target = clampf(v, 0.0, 1.0)


func show_finale(stats: Dictionary) -> void:
	_finale = stats


## A speech mark over someone's head: {"at": Vector4, "text": "?"} or {}.
func set_bubble(b: Dictionary) -> void:
	_bubble = b


func _process(delta: float) -> void:
	if _title_t >= 0.0:
		_title_t += delta
		if _title_t > 4.2:
			_title_t = -1.0
	if _hint_t >= 0.0:
		_hint_t += delta
		if _hint_t > 9.0:
			_hint_t = -1.0
	if _note_t >= 0.0:
		_note_t += delta
		if _note_t > 1.6:
			_note_t = -1.0
	_fade = move_toward(_fade, _fade_target, delta * 3.2)
	queue_redraw()


## World point to the HUD's own units (Camera4D answers in window pixels, engine_gotchas.md; the
## HUD is drawn at _ui times its layout size).
func _to_screen(p: Vector4) -> Vector2:
	if camera == null:
		return Vector2(-1000, -1000)
	var px: Vector2 = (camera as Camera4D).world_to_viewport(p)
	var scale: Vector2 = get_viewport_rect().size / Vector2(get_viewport().get_size())
	return px * scale / _ui


func _glass(r: Rect2, radius: float = 10.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = GLASS
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)


func _text(at: Vector2, s: String, font: Font, size: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
	draw_string(font, at, s, align, width, size, col)


func _draw() -> void:
	_ui = clampf(get_viewport_rect().size.y / 720.0, 1.0, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_ui, _ui))
	var vp: Vector2 = get_viewport_rect().size / _ui
	var turned: bool = camera != null and bool(camera.call("is_turned"))
	var amount: float = float(camera.call("turn_amount")) if camera != null else 0.0
	# VIEW BADGE
	var badge := Rect2(Vector2(18, 18), Vector2(186, 66))
	_glass(badge)
	_text(Vector2(32, 52), "X  Y", _black, 26, INK)
	var third: String = "W" if turned else "Z"
	_text(Vector2(98, 52), third, _black, 26, Z_COL.lerp(W_COL, amount))
	if amount > 0.02 and amount < 0.98:
		# Between the two views (a drag): how far round, in degrees.
		_text(Vector2(132, 52), "%d°" % int(round(amount * 90.0)), _bold, 14, Z_COL.lerp(W_COL, amount))
	_text(Vector2(32, 74), "RIGHT MOUSE click / drag  turn", _bold, 10, INK_DIM)
	# W RULER: the island's lanes (ana up).
	var ruler := Rect2(Vector2(18, 92), Vector2(186, 168))
	_glass(ruler)
	_text(Vector2(32, 114), "W", _black, 15, W_COL)
	_text(Vector2(52, 114), "ana", _bold, 11, INK_DIM)
	_text(Vector2(32, 250), "kata", _bold, 11, INK_DIM)
	var col_x: float = 96.0
	var top: float = 104.0
	var lane_h: float = 28.0
	for i in 5:
		var lane_index: int = 2 - i
		var r := Rect2(Vector2(col_x, top + float(i) * lane_h), Vector2(40, lane_h - 3))
		draw_rect(r, LANE_COLS[lane_index + 2])
		_text(Vector2(col_x + 48, top + float(i) * lane_h + 19), "%+d" % lane_index if lane_index != 0 else "0", _bold, 12, INK_DIM)
	var w_to_y := func(w: float) -> float:
		return top + (2.5 - (w / 1.6 + 0.0)) * lane_h - 1.5
	if game != null:
		var info: Dictionary = game.call("current_island")
		if info.has("goal"):
			var gy: float = w_to_y.call((info["goal"] as Vector4).w)
			var d := PackedVector2Array([Vector2(col_x - 14, gy - 6), Vector2(col_x - 8, gy), Vector2(col_x - 14, gy + 6), Vector2(col_x - 20, gy)])
			draw_colored_polygon(d, GOAL)
		for c in info.get("crates", []):
			if c == null or not is_instance_valid(c):
				continue
			var cy: float = w_to_y.call((c as Node4D).global_position.w)
			draw_rect(Rect2(Vector2(col_x + 30, cy - 4), Vector2(8, 8)), CRATE)
	if walker != null:
		var wy: float = w_to_y.call(walker.global_position.w)
		draw_rect(Rect2(Vector2(col_x - 4, wy - 2.5), Vector2(48, 5)), YOU)
	# KEYS
	var keys := "WASD walk    SPACE jump    RIGHT MOUSE turn into W (drag: by hand)    E lift / put down    CLICK strike    R restart    F hint    F2 light"
	# From the menu (11 Oct): M is the way back, and the shared BACK TO MENU button is hidden, so the
	# strip says M and centres in the whole width.
	var from_menu: bool = get_tree().root.has_node(^"WayHome")
	if from_menu:
		keys += "    M menu"
	var kw: float = _body.get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 40
	# Centred in the room right of the shared BACK TO MENU button (bottom left, about 270 px wide).
	var left: float = 20.0 if from_menu else 296.0
	var kx: float = maxf(left, left + (vp.x - left - 20.0 - kw) * 0.5)
	var kr := Rect2(Vector2(kx, vp.y - 50), Vector2(kw, 34))
	_glass(kr, 17)
	_text(Vector2(kr.position.x + 20, kr.position.y + 22), keys, _body, 13, INK)
	# PROMPT
	if hands != null and _finale.is_empty():
		var p: Dictionary = hands.call("prompt")
		if not p.is_empty():
			var at: Vector2 = _to_screen(p["at"])
			var label: String = "%s   %s" % [p["key"], p["text"]]
			var w: float = _bold.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28
			var r := Rect2(at - Vector2(w * 0.5, 40), Vector2(w, 30))
			_glass(r, 15)
			_text(r.position + Vector2(14, 20), label, _bold, 14, INK if bool(p.get("ok", true)) else Color(1.0, 0.6, 0.55))
	# BUBBLE
	if not _bubble.is_empty():
		var bat: Vector2 = _to_screen(_bubble["at"])
		var br := Rect2(bat - Vector2(18, 46), Vector2(36, 36))
		_glass(br, 18)
		_text(br.position + Vector2(0, 27), String(_bubble["text"]), _black, 22, INK, HORIZONTAL_ALIGNMENT_CENTER, 36)
	# NOTE (a refusal, a crate going home)
	if _note_t >= 0.0 and walker != null:
		var nat: Vector2 = _to_screen(walker.global_position + Vector4(0, 2.6, 0, 0))
		var nw: float = _bold.get_string_size(_note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24
		var nr := Rect2(nat - Vector2(nw * 0.5, 34), Vector2(nw, 26))
		_glass(nr, 13)
		_text(nr.position + Vector2(12, 18), _note, _bold, 13, Color(1.0, 0.78, 0.6))
	# TITLE
	if _title_t >= 0.0:
		var a: float = clampf(_title_t / 0.4, 0.0, 1.0) * clampf((4.2 - _title_t) / 0.6, 0.0, 1.0)
		var tw: float = maxf(_black.get_string_size(_title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x, _body.get_string_size(_title_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x) + 60
		var tr := Rect2(Vector2((vp.x - tw) * 0.5, 34), Vector2(tw, 84 if _title_sub != "" else 58))
		var g := GLASS
		g.a *= a
		var sb := StyleBoxFlat.new()
		sb.bg_color = g
		sb.set_corner_radius_all(12)
		draw_style_box(sb, tr)
		_text(tr.position + Vector2(0, 42), _title_text, _black, 30, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, tw)
		if _title_sub != "":
			_text(tr.position + Vector2(0, 70), _title_sub, _body, 15, Color(0.85, 0.9, 1.0, a), HORIZONTAL_ALIGNMENT_CENTER, tw)
	# HINT
	if _hint_t >= 0.0:
		var hw: float = minf(vp.x - 80.0, 760.0)
		var lines: PackedStringArray = _wrap(_hint_text, hw - 40, 15)
		var hr := Rect2(Vector2((vp.x - hw) * 0.5, vp.y - 70 - 26.0 * float(lines.size()) - 30), Vector2(hw, 26.0 * float(lines.size()) + 26))
		_glass(hr, 12)
		draw_rect(Rect2(hr.position + Vector2(0, 8), Vector2(4, hr.size.y - 16)), ACCENT)
		for i in lines.size():
			_text(hr.position + Vector2(22, 32 + 26.0 * float(i)), lines[i], _body, 15, INK)
	# FADE
	if _fade > 0.001:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.92, 0.94, 0.97, _fade))
	# FINALE
	if not _finale.is_empty():
		# Low in the frame, so the shrine and its tower stay in view above it.
		var fw := 520.0
		var fr := Rect2(Vector2((vp.x - fw) * 0.5, vp.y - 290), Vector2(fw, 210))
		_glass(fr, 14)
		_text(fr.position + Vector2(0, 58), "THE SHRINE", _black, 34, INK, HORIZONTAL_ALIGNMENT_CENTER, fw)
		_text(fr.position + Vector2(0, 92), "Four islands, through the fourth dimension.", _body, 15, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, fw)
		var stats: String = "%s     %d turns into W     %d falls" % [_finale.get("time", ""), int(_finale.get("turns", 0)), int(_finale.get("falls", 0))]
		_text(fr.position + Vector2(0, 134), stats, _bold, 16, ACCENT, HORIZONTAL_ALIGNMENT_CENTER, fw)
		_text(fr.position + Vector2(0, 178), "R  play again          M  back to menu" if get_tree().root.has_node(^"WayHome") else "R  play again          H  back to menu", _bold, 14, INK, HORIZONTAL_ALIGNMENT_CENTER, fw)


func _wrap(text: String, width: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var trial: String = word if line == "" else line + " " + word
		if _body.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out
