extends CanvasLayer
## THE ANNEX'S HUD: little on screen, and only what matters here and now.
##
##   the gizmo        one of three designs (gizmo_ruler, gizmo_dial, gizmo_lens), PLAN.md section 9
##   the crosshair    a dot, so you know where "ahead" is in first person
##   the V chip       "V ALIGN" under the crosshair when a reveal can be finished (the lens draws its own)
##   the key strip    the keys that matter now, in the labs' glass pill at the bottom
##   the title        the level's name, top left, fading after a few seconds; relics found under it
##   the mode chip    "DARK MODE OFF · B", top right, as in the labs
##   the toast        one line at the top for a moment (a relic, a stop, a hint)
##   the key card     the teaching card, bottom left: keys acting out what they do
##   the fade         black between levels and for a respawn
##   the end card     the finale's card: time, relics, replay or the menu
##
## The game hands it a state dictionary every frame (update_state); it draws, it decides nothing.

const D := preload("res://ramon/MazeRemake2/hud/mr2_draw.gd")
const Ruler := preload("res://ramon/MazeRemake2/hud/gizmo_ruler.gd")
const Dial := preload("res://ramon/MazeRemake2/hud/gizmo_dial.gd")
const Lens := preload("res://ramon/MazeRemake2/hud/gizmo_lens.gd")
const Card := preload("res://ramon/MazeRemake2/hud/mr2_key_card.gd")

const GIZMOS := ["RULER", "DIAL", "LENS"]

var gizmo_index: int = 2
var hud_visible: bool = true
var state: Dictionary = {}
var gizmos: Array[Control] = []
var overlay: Control
var card: Control
var fade_rect: ColorRect
var fade: float = 0.0
var _fade_to: float = 0.0
var _fade_speed: float = 2.0
var _title_t: float = 99.0
var _toast: String = ""
var _toast_left: float = 0.0
var _toast_total: float = 1.0
var _toast_color: Color = Color.WHITE
var end_card: Dictionary = {}
var film_bars: float = 0.0
var _film_to: float = 0.0
var caption: String = ""
var _caption_t: float = 0.0


func _ready() -> void:
	layer = 20
	for script in [Ruler, Dial, Lens]:
		var g: Control = script.new()
		add_child(g)
		gizmos.append(g)
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	card = Card.new()
	add_child(card)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade_rect)
	set_gizmo(gizmo_index)


func set_gizmo(i: int) -> void:
	gizmo_index = posmod(i, gizmos.size())
	for k in gizmos.size():
		gizmos[k].visible = hud_visible and k == gizmo_index


func update_state(s: Dictionary) -> void:
	state = s
	for g in gizmos:
		g.set("state", s)


## Fades to `alpha` (1 black) at `speed` per second.
func fade_to(alpha: float, speed: float = 2.0) -> void:
	_fade_to = clampf(alpha, 0.0, 1.0)
	_fade_speed = speed


func is_faded() -> bool:
	return absf(fade - _fade_to) < 0.01


func show_title() -> void:
	_title_t = 0.0


func toast(text: String, color: Color = Color.WHITE, seconds: float = 3.2) -> void:
	_toast = text
	_toast_color = color
	_toast_left = seconds
	_toast_total = seconds


func film(on: bool) -> void:
	_film_to = 1.0 if on else 0.0


func say(text: String, seconds: float = 4.0) -> void:
	caption = text
	_caption_t = seconds


func set_hud_visible(on: bool) -> void:
	hud_visible = on
	set_gizmo(gizmo_index)
	card.visible = on


func _process(delta: float) -> void:
	fade = move_toward(fade, _fade_to, _fade_speed * delta)
	fade_rect.color = Color(0, 0, 0, fade)
	film_bars = move_toward(film_bars, _film_to, delta * 2.5)
	_title_t += delta
	_toast_left -= delta
	_caption_t -= delta
	var g_fade: float = 1.0 - film_bars
	for g in gizmos:
		g.set("fade", g_fade)
	overlay.queue_redraw()


func _draw_overlay() -> void:
	var c: Control = overlay
	var u: float = D.u_of(c)
	var vs: Vector2 = c.get_viewport_rect().size
	# The film's bars.
	if film_bars > 0.001:
		var bh: float = vs.y * 0.11 * film_bars
		c.draw_rect(Rect2(0, 0, vs.x, bh), Color(0, 0, 0, 0.92))
		c.draw_rect(Rect2(0, vs.y - bh, vs.x, bh), Color(0, 0, 0, 0.92))
	if not end_card.is_empty():
		_draw_end(c, u, vs)
		return
	if _caption_t > 0.0 and caption != "":
		var a: float = clampf(_caption_t * 2.0, 0.0, 1.0)
		var cw: float = D.text_width(caption, "text", "lead", u)
		var cy: float = vs.y - vs.y * 0.11 * film_bars - 26.0 * u
		D.glass(c, Rect2(vs.x * 0.5 - cw * 0.5 - 18.0 * u, cy - 22.0 * u, cw + 36.0 * u, 32.0 * u), 16.0 * u, a)
		D.text(c, Vector2(vs.x * 0.5, cy), caption, "text", "lead", u, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
	if not hud_visible or state.is_empty():
		return
	var gf: float = 1.0 - film_bars
	if gf < 0.02:
		return
	# The crosshair.
	c.draw_circle(vs * 0.5, 2.6 * u, Color(0, 0, 0, 0.45 * gf))
	c.draw_circle(vs * 0.5, 1.6 * u, Color(1, 1, 1, 0.85 * gf))
	# The V chip (the lens draws its own on the door).
	var t: Dictionary = state.get("target", {})
	var lens_has_it: bool = gizmo_index == 2 and t.has("screen")
	if bool(t.get("offered", false)) and not lens_has_it:
		var col: Color = (t.get("color", D.ACCENT) as Color).lerp(Color.WHITE, 0.2)
		var label: String = String(t.get("verb", "ALIGN"))
		var kw: float = 26.0 * u
		var tw: float = D.text_width(label, "key", "caption", u)
		var cw: float = kw + tw + 22.0 * u
		var cr := Rect2(vs.x * 0.5 - cw * 0.5, vs.y * 0.5 + 34.0 * u, cw, 30.0 * u)
		D.glass(c, cr, 15.0 * u, gf)
		D.keycap(c, Rect2(cr.position.x + 5.0 * u, cr.position.y + 4.0 * u, kw, 22.0 * u), "V", u, true, gf)
		D.text(c, Vector2(cr.position.x + kw + 12.0 * u, cr.position.y + 20.0 * u), label, "key", "caption", u, Color(col, gf))
	_draw_strip(c, u, vs, gf)
	_draw_title(c, u, vs, gf)
	_draw_mode(c, u, vs, gf)
	if _toast_left > 0.0 and _toast != "":
		var a2: float = clampf(minf((_toast_total - _toast_left) * 5.0, _toast_left * 2.0), 0.0, 1.0) * gf
		var tw2: float = D.text_width(_toast, "heading", "lead", u)
		var tr := Rect2(vs.x * 0.5 - tw2 * 0.5 - 18.0 * u, 54.0 * u, tw2 + 36.0 * u, 36.0 * u)
		D.glass(c, tr, 18.0 * u, a2)
		D.text(c, Vector2(vs.x * 0.5, tr.position.y + 24.0 * u), _toast, "heading", "lead", u, Color(_toast_color, a2), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_strip(c: Control, u: float, vs: Vector2, a: float) -> void:
	var items: Array = state.get("strip", [])
	if items.is_empty():
		return
	var gap: float = 14.0 * u
	var ch: float = 22.0 * u
	var widths: Array = []
	var total: float = 0.0
	for it in items:
		var kw: float = D.keycap_width(String(it[0]), u)
		var lw: float = D.text_width(String(it[1]), "text", "caption", u)
		widths.append([kw, lw])
		total += kw + 7.0 * u + lw + gap
	total -= gap
	var pr := Rect2(vs.x * 0.5 - total * 0.5 - 14.0 * u, vs.y - 44.0 * u, total + 28.0 * u, 34.0 * u)
	D.glass(c, pr, 17.0 * u, a)
	var x: float = pr.position.x + 14.0 * u
	for i in items.size():
		var it: Array = items[i]
		var lit: bool = it.size() > 2 and bool(it[2])
		D.keycap(c, Rect2(x, pr.position.y + 6.0 * u, widths[i][0], ch), String(it[0]), u, lit, a)
		x += widths[i][0] + 7.0 * u
		D.text(c, Vector2(x, pr.position.y + 21.5 * u), String(it[1]), "text", "caption", u, Color(1, 1, 1, (1.0 if lit else 0.86) * a))
		x += widths[i][1] + gap


func _draw_title(c: Control, u: float, _vs: Vector2, a: float) -> void:
	var tf: float = clampf(1.0 - (_title_t - 5.0) / 1.2, 0.0, 1.0)
	var x: float = 22.0 * u
	var y: float = 22.0 * u
	var kicker: String = "THE ANNEX  ·  %d" % int(state.get("level", 1))
	var title: String = String(state.get("title", ""))
	var relics: String = String(state.get("relics", ""))
	var w: float = maxf(D.text_width(title, "title", "title", u), D.text_width(kicker, "key", "caption", u)) + 36.0 * u
	var h: float = 64.0 * u if tf > 0.01 else 0.0
	if tf > 0.01:
		D.glass(c, Rect2(x, y, w, h + (18.0 * u if relics != "" else 0.0)), 10.0 * u, a * tf)
		D.text(c, Vector2(x + 18.0 * u, y + 22.0 * u), kicker, "key", "caption", u, Color(D.ACCENT, a * tf))
		D.text(c, Vector2(x + 18.0 * u, y + 50.0 * u), title, "title", "title", u, Color(1, 1, 1, a * tf))
		if relics != "":
			D.text(c, Vector2(x + 18.0 * u, y + 72.0 * u), relics, "key", "micro", u, Color(D.INK_DIM, a * tf))
	elif relics != "":
		D.text(c, Vector2(x, y + 12.0 * u), relics, "key", "micro", u, Color(D.INK_DIM, a * 0.8))


func _draw_mode(c: Control, u: float, vs: Vector2, a: float) -> void:
	var s: String = "DARK MODE %s  ·  B" % ("ON" if bool(state.get("dark", false)) else "OFF")
	var tw: float = D.text_width(s, "key", "micro", u)
	var r := Rect2(vs.x - tw - 40.0 * u, 18.0 * u, tw + 24.0 * u, 24.0 * u)
	D.glass(c, r, 12.0 * u, a)
	D.text(c, Vector2(r.position.x + 12.0 * u, r.position.y + 16.0 * u), s, "key", "micro", u, Color(1, 1, 1, 0.9 * a))


func _draw_end(c: Control, u: float, vs: Vector2) -> void:
	var w: float = 520.0 * u
	var h: float = 260.0 * u
	var r := Rect2((vs.x - w) * 0.5, (vs.y - h) * 0.5, w, h)
	D.glass(c, r, 14.0 * u, 1.0)
	D.text(c, Vector2(r.position.x + 30.0 * u, r.position.y + 40.0 * u), "THE ANNEX", "key", "caption", u, D.ACCENT)
	D.text(c, Vector2(r.position.x + 30.0 * u, r.position.y + 84.0 * u), String(end_card.get("title", "COMPLETE")), "title", "headline", u, Color.WHITE)
	var y: float = r.position.y + 124.0 * u
	for line in end_card.get("lines", []):
		D.text(c, Vector2(r.position.x + 30.0 * u, y), String(line), "text", "body", u, D.INK_SOFT)
		y += 22.0 * u
	var ky: float = r.end.y - 46.0 * u
	var x: float = r.position.x + 30.0 * u
	for it in [["ENTER", "Play again"], ["ESC", "Back to the menu"]]:
		var kw: float = D.keycap_width(String(it[0]), u)
		D.keycap(c, Rect2(x, ky, kw, 24.0 * u), String(it[0]), u, false, 1.0)
		x += kw + 8.0 * u
		D.text(c, Vector2(x, ky + 17.0 * u), String(it[1]), "text", "caption", u, Color.WHITE)
		x += D.text_width(String(it[1]), "text", "caption", u) + 26.0 * u
