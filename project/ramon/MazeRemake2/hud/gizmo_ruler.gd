extends Control
## GIZMO A, THE RULER: where you are in W, on a scale of the whole level.
##
## A horizontal bar at the bottom centre, kata on the left and ana on the right (Q and E, the keys that
## move you that way, sit at its ends and light while held). The bar is painted in the level's band
## colours, the same scale the floor shows, so the floor's hue and the bar agree. Your needle moves
## every frame. The doors you can see are marked at the W where they open, and their glyph parts as
## they open. Where the world would stop you shifting (a wall in W, the end of a room), the bar is
## hatched, and pushing into it turns the needle red.
##
## The vocabulary is the old Phase Maze's continuous W number and the pen's and Crosswise's rulers;
## what is new is the continuous needle over a whole-level scale with the doors on it.
##
## draw_ruler() is shared: the lens (gizmo_lens.gd, the chosen design) draws the compact form of it.

const D := preload("res://ramon/MazeRemake2/hud/mr2_draw.gd")

var state: Dictionary = {}
var fade: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	if state.is_empty() or fade <= 0.01:
		return
	var u: float = D.u_of(self)
	var vs: Vector2 = get_viewport_rect().size
	var w: float = 560.0 * u
	var h: float = 70.0 * u
	draw_ruler(self, Rect2((vs.x - w) * 0.5, vs.y - h - 58.0 * u, w, h), state, fade, u, false)


## The ruler in `r` on canvas `c`. `compact`: slimmer, no numbers, small caps.
static func draw_ruler(c: Control, r: Rect2, state: Dictionary, fade: float, u: float, compact: bool) -> void:
	D.glass(c, r, (r.size.y * 0.5 if compact else 10.0 * u), fade)
	var w_min: float = float(state.get("w_min", -4.0))
	var w_max: float = float(state.get("w_max", 4.0))
	var w: float = float(state.get("w", 0.0))
	var bands: Array = state.get("bands", [])
	var cap_w: float = (24.0 if compact else 30.0) * u
	var m: float = (8.0 if compact else 12.0) * u
	var bar_h: float = (7.0 if compact else 10.0) * u
	var bar_y: float = r.position.y + r.size.y * (0.62 if compact else 0.52)
	var bar := Rect2(r.position.x + m + cap_w + 8.0 * u, bar_y, r.size.x - (m + cap_w + 8.0 * u) * 2.0, bar_h)
	var span: float = maxf(w_max - w_min, 0.001)
	# The bands.
	var n: int = maxi(8, int(bar.size.x / (3.0 * u)))
	for i in n:
		var v0: float = lerpf(w_min, w_max, float(i) / n)
		var x0: float = bar.position.x + (v0 - w_min) / span * bar.size.x
		var x1: float = bar.position.x + (lerpf(w_min, w_max, float(i + 1) / n) - w_min) / span * bar.size.x
		c.draw_rect(Rect2(x0, bar.position.y, x1 - x0 + 0.5, bar.size.y), Color(D.band_at(bands, v0 + 0.5 * span / n), 0.92 * fade))
	# The stops: where shifting from here would hit something.
	var sk: float = float(state.get("stop_kata", -INF))
	var sa: float = float(state.get("stop_ana", INF))
	if sk > w_min:
		var xk: float = bar.position.x + (minf(sk, w_max) - w_min) / span * bar.size.x
		D.hatch(c, Rect2(bar.position.x, bar.position.y - 3.0 * u, xk - bar.position.x, bar.size.y + 6.0 * u), Color(1, 1, 1, 0.35 * fade), 6.0 * u, maxf(1.0, u))
		c.draw_line(Vector2(xk, bar.position.y - 5.0 * u), Vector2(xk, bar.end.y + 5.0 * u), Color(1, 1, 1, 0.8 * fade), 2.0 * u)
	if sa < w_max:
		var xa: float = bar.position.x + (maxf(sa, w_min) - w_min) / span * bar.size.x
		D.hatch(c, Rect2(xa, bar.position.y - 3.0 * u, bar.end.x - xa, bar.size.y + 6.0 * u), Color(1, 1, 1, 0.35 * fade), 6.0 * u, maxf(1.0, u))
		c.draw_line(Vector2(xa, bar.position.y - 5.0 * u), Vector2(xa, bar.end.y + 5.0 * u), Color(1, 1, 1, 0.8 * fade), 2.0 * u)
	# Ticks every metre; numbers on the full ruler.
	var f_small: int = D.px("micro", u)
	for k in range(int(ceil(w_min)), int(floor(w_max)) + 1):
		var x: float = bar.position.x + (float(k) - w_min) / span * bar.size.x
		var tick_h: float = (5.0 if k == 0 else 3.0) * u if compact else 4.0 * u
		c.draw_line(Vector2(x, bar.end.y + 2.0 * u), Vector2(x, bar.end.y + 2.0 * u + tick_h), Color(1, 1, 1, 0.55 * fade), maxf(1.0, u))
		if not compact:
			var t: String = "0" if k == 0 else ("%+d" % k)
			var tw: float = D.font("key").get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, f_small).x
			c.draw_string(D.font("key"), Vector2(x - tw * 0.5, bar.end.y + 6.0 * u + f_small), t, HORIZONTAL_ALIGNMENT_LEFT, -1, f_small, Color(1, 1, 1, 0.5 * fade))
	# The doors in view, at the W they open.
	for d in state.get("doors", []):
		var x: float = bar.position.x + (clampf(float(d["align_w"]), w_min, w_max) - w_min) / span * bar.size.x
		var col: Color = d["color"]
		var lit: bool = bool(d.get("targeted", false))
		var gh: float = ((13.0 if lit else 10.0) if compact else (16.0 if lit else 12.0)) * u
		var c0 := Vector2(x, bar.position.y - gh * 0.5 - 4.0 * u)
		if lit:
			c.draw_circle(c0, gh * 0.85, Color(col, 0.22 * fade))
		D.door_glyph(c, c0, gh, Color(col.lerp(Color.WHITE, 0.25), fade), float(d.get("open", 0.0)), u)
	# The needle.
	var nx: float = bar.position.x + (clampf(w, w_min, w_max) - w_min) / span * bar.size.x
	var blocked: bool = bool(state.get("w_blocked", false))
	var ncol: Color = D.STOP if blocked else Color.WHITE
	c.draw_line(Vector2(nx, bar.position.y - 7.0 * u), Vector2(nx, bar.end.y + 4.0 * u), Color(0, 0, 0, 0.5 * fade), 5.0 * u)
	c.draw_line(Vector2(nx, bar.position.y - 7.0 * u), Vector2(nx, bar.end.y + 4.0 * u), Color(ncol, fade), 2.4 * u)
	var tri := PackedVector2Array([Vector2(nx - 5.0 * u, bar.position.y - 12.0 * u), Vector2(nx + 5.0 * u, bar.position.y - 12.0 * u), Vector2(nx, bar.position.y - 6.0 * u)])
	c.draw_colored_polygon(tri, Color(ncol, fade))
	var label: String = ("STOP  " if blocked else "") + D.w_label(w)
	var ly: float = r.position.y + (13.0 if compact else 15.0) * u
	D.text(c, Vector2(nx, ly), label, "key", ("micro" if compact else "caption"), u, Color(ncol, fade), HORIZONTAL_ALIGNMENT_CENTER)
	# The keys at the ends.
	var wi: float = float(state.get("w_input", 0.0))
	var ch: float = (19.0 if compact else 24.0) * u
	var ky: float = bar.position.y + bar.size.y * 0.5 - ch * 0.5
	D.keycap(c, Rect2(r.position.x + m, ky, cap_w, ch), "Q", u, wi < -0.1, fade)
	D.keycap(c, Rect2(r.end.x - m - cap_w, ky, cap_w, ch), "E", u, wi > 0.1, fade)
	if compact:
		D.text(c, Vector2(r.position.x + m + cap_w * 0.5, ky - 4.0 * u), "KATA", "key", "micro", u, Color(D.INK_DIM, fade), HORIZONTAL_ALIGNMENT_CENTER)
		D.text(c, Vector2(r.end.x - m - cap_w * 0.5, ky - 4.0 * u), "ANA", "key", "micro", u, Color(D.INK_DIM, fade), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		D.text(c, Vector2(r.position.x + m + cap_w * 0.5, ky + ch + 12.0 * u), "KATA", "key", "micro", u, Color(D.INK_DIM, fade), HORIZONTAL_ALIGNMENT_CENTER)
		D.text(c, Vector2(r.end.x - m - cap_w * 0.5, ky + ch + 12.0 * u), "ANA", "key", "micro", u, Color(D.INK_DIM, fade), HORIZONTAL_ALIGNMENT_CENTER)
