extends Control
## GIZMO C, THE LENS (the hybrid): a slim ruler that stays out of the way, and the feedback where your
## eyes already are, on the door you are looking at.
##
## The compact ruler: the ruler (gizmo A) slimmer, its scale, keys, doors and stops, at the bottom; the
## door you face gets four corner brackets on screen,
## in its colour, and beside them a ring that fills as the door opens, with how open it is; when it is
## open enough for V, the V chip sits under it. Once you hold the Lens (level 3), the turn appears as a
## small quarter meter next to the ring.
##
## The pen's V prompts and in-world chips, and the Lookout's labels where a thing stands on screen, are
## where this comes from.

const D := preload("res://ramon/MazeRemake2/hud/mr2_draw.gd")
const Ruler := preload("res://ramon/MazeRemake2/hud/gizmo_ruler.gd")

var state: Dictionary = {}
var fade: float = 1.0
## Off when the lens rides on the slice map (the map has its own W scale).
var show_ruler: bool = true
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(d: float) -> void:
	_pulse += d
	queue_redraw()


func _draw() -> void:
	if state.is_empty() or fade <= 0.01:
		return
	var u: float = D.u_of(self)
	var vs: Vector2 = get_viewport_rect().size
	# THE RULER, compact: the full ruler's scale, keys and doors (gizmo_ruler.gd), slimmer.
	var rw: float = 440.0 * u
	var rh: float = 46.0 * u
	if show_ruler:
		Ruler.draw_ruler(self, Rect2((vs.x - rw) * 0.5, vs.y - rh - 54.0 * u, rw, rh), state, fade, u, true)
	# THE DOOR YOU FACE: brackets, the ring, the V chip.
	var t: Dictionary = state.get("target", {})
	if t.is_empty() or not t.has("screen"):
		return
	var sr: Rect2 = (t["screen"] as Rect2).grow(7.0 * u)
	if sr.size.x < 18.0 * u or sr.size.y < 18.0 * u:
		return
	var col: Color = (t.get("color", D.ACCENT) as Color).lerp(Color.WHITE, 0.45)
	var open: float = float(t.get("open", 0.0))
	var arm: float = clampf(minf(sr.size.x, sr.size.y) * 0.22, 8.0 * u, 26.0 * u)
	var lw: float = 2.4 * u
	for corner in [sr.position, Vector2(sr.end.x, sr.position.y), sr.end, Vector2(sr.position.x, sr.end.y)]:
		var sx: float = 1.0 if corner.x <= sr.position.x + 0.5 else -1.0
		var sy: float = 1.0 if corner.y <= sr.position.y + 0.5 else -1.0
		# A dark edge under each stroke, so the brackets read on the white lab walls too.
		draw_line(corner, corner + Vector2(arm * sx, 0), Color(0.03, 0.05, 0.09, 0.55 * fade), lw + 2.6 * u)
		draw_line(corner, corner + Vector2(0, arm * sy), Color(0.03, 0.05, 0.09, 0.55 * fade), lw + 2.6 * u)
		draw_line(corner, corner + Vector2(arm * sx, 0), Color(col, fade), lw)
		draw_line(corner, corner + Vector2(0, arm * sy), Color(col, fade), lw)
	# The ring beside the top right corner.
	var rc := Vector2(sr.end.x + 20.0 * u, sr.position.y + 14.0 * u)
	var rr: float = 11.0 * u
	# A glass chip behind the ring and its reading, for the same reason.
	var lab_w: float = maxf(D.text_width("100%", "key", "caption", u), D.text_width(String(t.get("label", "OPEN")), "key", "micro", u))
	D.glass(self, Rect2(rc.x - rr - 6.0 * u, rc.y - rr - 6.0 * u, rr * 2.0 + lab_w + 22.0 * u, rr * 2.0 + 12.0 * u), rr + 6.0 * u, fade)
	draw_arc(rc, rr, 0.0, TAU, 40, Color(1, 1, 1, 0.22 * fade), 3.0 * u)
	draw_arc(rc, rr, -PI * 0.5, -PI * 0.5 + TAU * open, 40, Color(col, fade), 3.0 * u)
	D.text(self, rc + Vector2(rr + 6.0 * u, 5.0 * u), "%d%%" % int(round(open * 100.0)), "key", "caption", u, Color(col, fade))
	D.text(self, rc + Vector2(rr + 6.0 * u, 5.0 * u + D.px("micro", u) + 4.0 * u), String(t.get("label", "OPEN")), "key", "micro", u, Color(D.INK_DIM, fade))
	if bool(state.get("turn_enabled", false)) and float(state.get("tilt", 0.0)) > 0.02:
		var tc := Vector2(rc.x, rc.y + 40.0 * u)
		var tt: float = clampf(float(state.get("tilt", 0.0)) / (PI * 0.5), 0.0, 1.0)
		draw_arc(tc, rr, -PI * 0.5, 0.0, 16, Color(1, 1, 1, 0.22 * fade), 3.0 * u)
		draw_arc(tc, rr, -PI * 0.5, -PI * 0.5 + PI * 0.5 * tt, 16, Color(D.ACCENT, fade), 3.0 * u)
		D.text(self, tc + Vector2(rr + 6.0 * u, 5.0 * u), "TURN %d%%" % int(round(tt * 100.0)), "key", "caption", u, Color(D.ACCENT, fade))
	if bool(t.get("offered", false)):
		var label: String = "ALIGN"
		var kw: float = 26.0 * u
		var tw: float = D.text_width(label, "key", "caption", u)
		var cw: float = kw + tw + 22.0 * u
		var pulse: float = 0.75 + 0.25 * sin(_pulse * 5.0)
		var cr := Rect2(sr.position.x + sr.size.x * 0.5 - cw * 0.5, sr.end.y + 10.0 * u, cw, 30.0 * u)
		D.glass(self, cr, 15.0 * u, fade)
		D.keycap(self, Rect2(cr.position.x + 5.0 * u, cr.position.y + 4.0 * u, kw, 22.0 * u), "V", u, true, fade * pulse)
		D.text(self, Vector2(cr.position.x + kw + 12.0 * u, cr.position.y + 20.0 * u), label, "key", "caption", u, Color(col, fade))
