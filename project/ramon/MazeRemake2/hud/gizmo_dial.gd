extends Control
## GIZMO B, THE DIAL: W as an angle, like the dial of a combination lock (which is what the original
## Phase Maze felt like: turn the number until the gap comes round).
##
## A ring in the bottom right corner, 270 degrees of it for the level's W range, painted in the band
## colours; a needle from the centre points at your W; the doors you can see are notches on the outside
## of the ring at the W where they open; the W stops are dark arcs. The reading sits in the middle. Once
## you hold the Lens (level 3) a small inner quarter shows how far your view is turned into W.

const D := preload("res://ramon/MazeRemake2/hud/mr2_draw.gd")

const SWEEP := 270.0

var state: Dictionary = {}
var fade: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_d: float) -> void:
	queue_redraw()


func _angle(v: float, w_min: float, w_max: float) -> float:
	var t: float = (clampf(v, w_min, w_max) - w_min) / maxf(w_max - w_min, 0.001)
	# From the lower left (225 degrees, screen angles run clockwise) round over the top to the lower right.
	return deg_to_rad(135.0 + t * SWEEP)


func _draw() -> void:
	if state.is_empty() or fade <= 0.01:
		return
	var u: float = D.u_of(self)
	var vs: Vector2 = get_viewport_rect().size
	var R: float = 64.0 * u
	var c := Vector2(vs.x - R - 34.0 * u, vs.y - R - 64.0 * u)
	draw_circle(c, R + 22.0 * u, Color(D.GLASS, D.GLASS.a * fade))
	draw_arc(c, R + 22.0 * u, 0.0, TAU, 64, Color(D.EDGE, D.EDGE.a * fade), 1.0)
	var w_min: float = float(state.get("w_min", -4.0))
	var w_max: float = float(state.get("w_max", 4.0))
	var w: float = float(state.get("w", 0.0))
	var bands: Array = state.get("bands", [])
	var thick: float = 9.0 * u
	var n: int = 72
	for i in n:
		var v0: float = lerpf(w_min, w_max, float(i) / n)
		var v1: float = lerpf(w_min, w_max, float(i + 1) / n)
		draw_arc(c, R, _angle(v0, w_min, w_max), _angle(v1, w_min, w_max) + 0.01, 3, Color(D.band_at(bands, (v0 + v1) * 0.5), 0.92 * fade), thick)
	var sk: float = float(state.get("stop_kata", -INF))
	var sa: float = float(state.get("stop_ana", INF))
	if sk > w_min:
		draw_arc(c, R, _angle(w_min, w_min, w_max), _angle(sk, w_min, w_max), 16, Color(0.02, 0.03, 0.05, 0.85 * fade), thick + 2.0 * u)
	if sa < w_max:
		draw_arc(c, R, _angle(sa, w_min, w_max), _angle(w_max, w_min, w_max), 16, Color(0.02, 0.03, 0.05, 0.85 * fade), thick + 2.0 * u)
	# Ticks every metre.
	for k in range(int(ceil(w_min)), int(floor(w_max)) + 1):
		var a: float = _angle(float(k), w_min, w_max)
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * (R - thick * 0.5 - 4.0 * u), c + dir * (R - thick * 0.5 - (9.0 if k == 0 else 6.0) * u), Color(1, 1, 1, 0.6 * fade), maxf(1.0, u))
	# Door notches outside the ring.
	for d in state.get("doors", []):
		var a: float = _angle(float(d["align_w"]), w_min, w_max)
		var dir := Vector2(cos(a), sin(a))
		var col: Color = d["color"]
		var lit: bool = bool(d.get("targeted", false))
		D.door_glyph(self, c + dir * (R + 14.0 * u), (13.0 if lit else 10.0) * u, Color(col.lerp(Color.WHITE, 0.25), fade), float(d.get("open", 0.0)), u)
	# The needle.
	var blocked: bool = bool(state.get("w_blocked", false))
	var ncol: Color = D.STOP if blocked else Color.WHITE
	var a: float = _angle(w, w_min, w_max)
	var tip: Vector2 = c + Vector2(cos(a), sin(a)) * (R + thick * 0.5)
	draw_line(c, tip, Color(0, 0, 0, 0.5 * fade), 5.0 * u)
	draw_line(c, tip, Color(ncol, fade), 2.4 * u)
	draw_circle(c, 4.0 * u, Color(ncol, fade))
	# The inner quarter: the turn into W (only with the Lens).
	if bool(state.get("turn_enabled", false)):
		var t: float = clampf(float(state.get("tilt", 0.0)) / (PI * 0.5), 0.0, 1.0)
		var r2: float = R * 0.52
		draw_arc(c, r2, deg_to_rad(-90.0), deg_to_rad(0.0), 16, Color(1, 1, 1, 0.18 * fade), 4.0 * u)
		draw_arc(c, r2, deg_to_rad(-90.0), deg_to_rad(-90.0 + 90.0 * t), 16, Color(D.ACCENT, fade), 4.0 * u)
	# The reading.
	D.text(self, c + Vector2(0, R * 0.42 + 6.0 * u), D.w_label(w), "title", "body", u, Color(ncol, fade), HORIZONTAL_ALIGNMENT_CENTER)
	var wi: float = float(state.get("w_input", 0.0))
	var ch: float = 20.0 * u
	var cw: float = 24.0 * u
	var la: float = _angle(w_min, w_min, w_max)
	var ra: float = _angle(w_max, w_min, w_max)
	var lp: Vector2 = c + Vector2(cos(la), sin(la)) * (R + 6.0 * u)
	var rp: Vector2 = c + Vector2(cos(ra), sin(ra)) * (R + 6.0 * u)
	D.keycap(self, Rect2(lp.x - cw * 0.5 - 12.0 * u, lp.y - ch * 0.2, cw, ch), "Q", u, wi < -0.1, fade)
	D.keycap(self, Rect2(rp.x - cw * 0.5 + 12.0 * u, rp.y - ch * 0.2, cw, ch), "E", u, wi > 0.1, fade)
