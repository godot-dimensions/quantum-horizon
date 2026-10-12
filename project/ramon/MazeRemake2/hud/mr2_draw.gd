extends RefCounted
## Drawing helpers the Annex's HUD shares: the kit's type ladder and glass, key caps, a soft disc.
## Every size is worked out from the window's height (u = height / 720), never scaled after (the kit's
## rule: kit_prompt.gd, outfit_room_4d.gd "SIZED, NEVER SCALED").
##
## NO class_name (engine_gotchas.md): preload it.

const KitStyle := preload("res://ramon/MazeRemake2/carried/kit_style.gd")
const LabPrint := preload("res://ramon/MazeRemake2/carried/lab_print.gd")

const GLASS := Color(0.04, 0.06, 0.10, 0.82)
const EDGE := Color(1, 1, 1, 0.10)
const INK := Color(1, 1, 1)
const INK_SOFT := Color(0.86, 0.91, 1.0, 0.92)
const INK_DIM := Color(0.72, 0.80, 0.94, 0.70)
const ACCENT := Color(0.40, 0.76, 1.0)
const STOP := Color(1.0, 0.36, 0.30)


static func u_of(c: Control) -> float:
	return maxf(0.5, c.get_viewport_rect().size.y / 720.0)


static func font(role: String) -> Font:
	return KitStyle.ui_font(role)


static func px(role: String, u: float) -> int:
	return KitStyle.type_px(role, u)


## A rounded glass panel.
static func glass(c: Control, r: Rect2, radius: float, a: float = 1.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GLASS, GLASS.a * a)
	sb.border_color = Color(EDGE, EDGE.a * a)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	sb.draw(c.get_canvas_item(), r)


static func rounded(c: Control, r: Rect2, radius: float, col: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	sb.draw(c.get_canvas_item(), r)


## A key cap with `label`, lit (filled white, dark ink) when `lit`.
static func keycap(c: Control, r: Rect2, label: String, u: float, lit: bool = false, a: float = 1.0) -> void:
	var face: Color = Color(1, 1, 1, 0.95 * a) if lit else Color(1, 1, 1, 0.08 * a)
	var border: Color = Color(1, 1, 1, 0.0) if lit else Color(1, 1, 1, 0.55 * a)
	rounded(c, r, 4.0 * u, face, border, maxi(1, int(round(1.2 * u))))
	var f: Font = font("key")
	var s: int = px("caption", u)
	var tw: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	var ink: Color = Color(0.06, 0.08, 0.12, a) if lit else Color(1, 1, 1, a)
	c.draw_string(f, Vector2(r.position.x + (r.size.x - tw) * 0.5, r.position.y + r.size.y * 0.5 + s * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, s, ink)


## The width a key cap needs for `label`.
static func keycap_width(label: String, u: float) -> float:
	var f: Font = font("key")
	return maxf(24.0 * u, f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px("caption", u)).x + 14.0 * u)


static func text(c: Control, at: Vector2, s: String, role: String, size_role: String, u: float, col: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f: Font = font(role)
	var sz: int = px(size_role, u)
	var x: float = at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	c.draw_string(f, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, width, sz, col)


static func text_width(s: String, role: String, size_role: String, u: float) -> float:
	return font(role).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px(size_role, u)).x


## The band colour at W `w` from a level's bands ([[w, colour, name], ...]), as the floor shows it.
static func band_at(bands: Array, w: float) -> Color:
	if bands.is_empty():
		return ACCENT
	if w <= float(bands[0][0]):
		return bands[0][1]
	for i in range(1, bands.size()):
		var a: float = float(bands[i - 1][0])
		var b: float = float(bands[i][0])
		if w <= b:
			return (bands[i - 1][1] as Color).lerp(bands[i][1], clampf((w - a) / maxf(b - a, 0.0001), 0.0, 1.0))
	return bands[bands.size() - 1][1]


## Diagonal hatching over `r` (a W stop: you cannot shift there from where you stand).
static func hatch(c: Control, r: Rect2, col: Color, step: float, lw: float) -> void:
	c.draw_rect(r, Color(0.0, 0.0, 0.0, 0.45))
	var x: float = r.position.x - r.size.y
	for i in 200:
		if x > r.end.x:
			break
		var a := Vector2(maxf(x, r.position.x), r.end.y - maxf(0.0, r.position.x - x))
		var b := Vector2(minf(x + r.size.y, r.end.x), r.position.y + maxf(0.0, (x + r.size.y) - r.end.x))
		if a.x < b.x:
			c.draw_line(a, b, col, lw, true)
		x += step


## "W +1.6" style.
static func w_label(w: float) -> String:
	var v: float = snappedf(w, 0.1)
	if absf(v) < 0.05:
		return "W 0.0"
	return "W %s%.1f" % ["+" if v > 0.0 else "-", absf(v)]


## A small door glyph (a frame with two leaves parted by `open`), centred at `c0`, `h` tall.
static func door_glyph(c: Control, c0: Vector2, h: float, col: Color, open: float, u: float) -> void:
	var w: float = h * 0.72
	var r := Rect2(c0.x - w * 0.5, c0.y - h * 0.5, w, h)
	var lw: float = maxf(1.0, 1.6 * u)
	c.draw_rect(r, col, false, lw)
	var leaf: float = (w * 0.5 - lw) * (1.0 - clampf(open, 0.0, 1.0))
	if leaf > 0.5:
		c.draw_rect(Rect2(r.position.x + lw, r.position.y + lw, leaf, h - lw * 2.0), Color(col, 0.75))
		c.draw_rect(Rect2(r.end.x - lw - leaf, r.position.y + lw, leaf, h - lw * 2.0), Color(col, 0.75))
