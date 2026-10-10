extends Control
## THE KEY CARD: a small card that acts out a control, bottom left, the first times it matters (the pen's
## and the Aquatic Lab's animated cards, with the Annex's keys). It shows, it does not explain: the keys
## press themselves and what they do moves beside them.
##
##   "shift"   Q and E press in turn; a dot slides along a W axis painted in the level's bands
##   "align"   V presses; a door glyph opens the rest of the way
##   "turn"    the mouse with its right button held moves up; a quarter turns from level to W
##
## play(kind, seconds, title, line) shows it; it fades out on its own, or on stop().

const D := preload("res://ramon/MazeRemake2/hud/mr2_draw.gd")

var kind: String = ""
var title: String = ""
var line: String = ""
var bands: Array = []
var _t: float = 0.0
var _left: float = 0.0
var _a: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func play(k: String, seconds: float, t: String, l: String) -> void:
	kind = k
	title = t
	line = l
	_t = 0.0
	_left = seconds


func stop() -> void:
	_left = minf(_left, 0.3)


func is_playing() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	_t += delta
	_left -= delta
	var was: float = _a
	_a = move_toward(_a, 1.0 if _left > 0.0 else 0.0, delta * 3.0)
	# One more redraw as it reaches nothing: a CanvasItem keeps its last drawing (the pen's lesson).
	if _a > 0.0 or _left > 0.0 or was > 0.0:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.01 or kind == "":
		return
	var u: float = D.u_of(self)
	var vs: Vector2 = get_viewport_rect().size
	var w: float = 250.0 * u
	var h: float = 168.0 * u
	var r := Rect2(22.0 * u, vs.y - h - 70.0 * u, w, h)
	D.glass(self, r, 12.0 * u, _a)
	D.text(self, Vector2(r.position.x + 16.0 * u, r.position.y + 24.0 * u), title, "key", "caption", u, Color(D.ACCENT, _a))
	var stage := Rect2(r.position.x + 16.0 * u, r.position.y + 36.0 * u, w - 32.0 * u, 84.0 * u)
	match kind:
		"shift":
			_shift(stage, u)
		"align":
			_align(stage, u)
		"turn":
			_turn(stage, u)
	D.text(self, Vector2(r.position.x + 16.0 * u, r.end.y - 18.0 * u), line, "text", "caption", u, Color(1, 1, 1, 0.92 * _a), HORIZONTAL_ALIGNMENT_LEFT, w - 32.0 * u)


func _shift(s: Rect2, u: float) -> void:
	# 2.4 s a cycle: E held (dot to the right), then Q held (dot back).
	var p: float = fmod(_t, 2.4) / 2.4
	var e_on: bool = p < 0.5
	var k: float = (p / 0.5) if e_on else ((p - 0.5) / 0.5)
	var dot_t: float = smoothstep(0.0, 1.0, k) if e_on else 1.0 - smoothstep(0.0, 1.0, k)
	var cw: float = 30.0 * u
	var ch: float = 26.0 * u
	D.keycap(self, Rect2(s.position.x, s.position.y + 4.0 * u, cw, ch), "Q", u, not e_on, _a)
	D.keycap(self, Rect2(s.end.x - cw, s.position.y + 4.0 * u, cw, ch), "E", u, e_on, _a)
	D.text(self, Vector2(s.position.x + cw * 0.5, s.position.y + ch + 18.0 * u), "KATA", "key", "micro", u, Color(D.INK_DIM, _a), HORIZONTAL_ALIGNMENT_CENTER)
	D.text(self, Vector2(s.end.x - cw * 0.5, s.position.y + ch + 18.0 * u), "ANA", "key", "micro", u, Color(D.INK_DIM, _a), HORIZONTAL_ALIGNMENT_CENTER)
	var ax := Rect2(s.position.x + cw + 12.0 * u, s.position.y + 14.0 * u, s.size.x - (cw + 12.0 * u) * 2.0, 6.0 * u)
	var n: int = 40
	for i in n:
		var t0: float = float(i) / n
		draw_rect(Rect2(ax.position.x + ax.size.x * t0, ax.position.y, ax.size.x / n + 0.5, ax.size.y), Color(D.band_at(bands, lerpf(-2.5, 2.5, t0)), 0.9 * _a))
	var dx: float = ax.position.x + ax.size.x * lerpf(0.5, 0.92, dot_t)
	draw_circle(Vector2(dx, ax.position.y + ax.size.y * 0.5), 7.0 * u, Color(1, 1, 1, _a))
	# A door glyph under the axis parting as the dot goes ana.
	D.door_glyph(self, Vector2(ax.position.x + ax.size.x * 0.5, ax.end.y + 34.0 * u), 30.0 * u, Color(D.band_at(bands, 2.0).lerp(Color.WHITE, 0.2), _a), dot_t, u)


func _align(s: Rect2, u: float) -> void:
	var p: float = fmod(_t, 2.0) / 2.0
	var pressed: bool = p > 0.25 and p < 0.45
	var open: float = 0.72 if p < 0.3 else lerpf(0.72, 1.0, smoothstep(0.3, 0.6, p))
	D.keycap(self, Rect2(s.position.x, s.position.y + 20.0 * u, 34.0 * u, 30.0 * u), "V", u, pressed, _a)
	D.door_glyph(self, Vector2(s.position.x + s.size.x * 0.62, s.position.y + 38.0 * u), 56.0 * u, Color(D.band_at(bands, 2.0).lerp(Color.WHITE, 0.2), _a), open, u)


func _turn(s: Rect2, u: float) -> void:
	var p: float = fmod(_t, 2.6) / 2.6
	var up: float = smoothstep(0.1, 0.55, p) * (1.0 - smoothstep(0.75, 0.95, p))
	# The mouse.
	var mc := Vector2(s.position.x + 26.0 * u, s.position.y + 50.0 * u - up * 26.0 * u)
	var mr := Rect2(mc.x - 15.0 * u, mc.y - 22.0 * u, 30.0 * u, 44.0 * u)
	D.rounded(self, mr, 14.0 * u, Color(1, 1, 1, 0.08 * _a), Color(1, 1, 1, 0.7 * _a), maxi(1, int(1.4 * u)))
	draw_rect(Rect2(mc.x + 1.0 * u, mr.position.y + 3.0 * u, 11.0 * u, 16.0 * u), Color(D.ACCENT, 0.95 * _a))
	draw_line(Vector2(mc.x, mr.position.y + 2.0 * u), Vector2(mc.x, mr.position.y + 20.0 * u), Color(1, 1, 1, 0.6 * _a), maxf(1.0, u))
	# The quarter: from level (along the floor) to W (up), the needle following the drag.
	var qc := Vector2(s.position.x + s.size.x * 0.62, s.end.y - 6.0 * u)
	var qr: float = 52.0 * u
	draw_arc(qc, qr, -PI * 0.5, 0.0, 24, Color(1, 1, 1, 0.25 * _a), 3.0 * u)
	var a: float = -up * PI * 0.5
	draw_line(qc, qc + Vector2(cos(a), sin(a)) * qr, Color(D.ACCENT, _a), 3.0 * u)
	D.text(self, qc + Vector2(qr + 4.0 * u, -2.0 * u), "LEVEL", "key", "micro", u, Color(D.INK_DIM, _a))
	D.text(self, qc + Vector2(4.0 * u, -qr - 4.0 * u), "W", "key", "micro", u, Color(D.INK_DIM, _a))
