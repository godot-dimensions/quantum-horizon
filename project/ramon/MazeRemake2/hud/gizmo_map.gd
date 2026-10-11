extends Control
## THE SLICE MAP (round 2's gizmo; Ramon, 11 Oct: "look at the gizmo of the pen or the control room, or
## at the aquarium. you really see the power of the slice"). A round dark-glass map in the corner, drawn as
## the pen's dial draws the farm (chickenpen/scripts/pen_slice_plane_4d.gd): x and z fall away
## isometrically, W stands straight up. Forward is up and to the right, so the map turns with you.
##
##   the rooms near you   each a faint box through the W it exists in; where your slice cuts one, its
##                        floor plan is filled on the sheet in the colour of that W
##   your slice           a sheet through you at your W (gold edged): it rises and falls as you shift,
##                        and tilts when you turn into W, so what it cuts changes before your eyes
##   doors                small door glyphs at the W where they open, a stem down to the sheet; lit
##                        when your slice has them open
##   the Tall Ones        a figure at their W, grey, red once they have seen you, ringed when they share
##                        your slice: the danger is where your sheet meets them
##   the W scale          a bar down the left of the disc in the band colours, your needle on it
##
## It reads the state the game hands the HUD (rooms, doors, walkers, your position and frame).

const D := preload("res://ramon/MazeRemake2/hud/mr2_draw.gd")
const Build := preload("res://ramon/MazeRemake2/world/mr2_build.gd")

## Metres of ground from the centre to the disc's edge, and how tall a metre of W stands.
@export var reach_m: float = 13.0
@export var w_scale: float = 0.12

var state: Dictionary = {}
var fade: float = 1.0
var _c := Vector2.ZERO
var _r: float = 100.0
var _k: float = 1.0
var _kw: float = 1.0
var _p := Vector4.ZERO
var _right := Vector2(1, 0)
var _fwd := Vector2(0, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_d: float) -> void:
	queue_redraw()


## A 4D point (x, z, w used) on the disc.
func _to(x: float, z: float, w: float) -> Vector2:
	var d := Vector2(x - _p.x, z - _p.z)
	var u: float = d.dot(_right)
	var v: float = d.dot(_fwd)
	return _c + Vector2((u + v) * 0.866 * _k, (u - v) * 0.5 * _k - (w - _p.w) * _kw)


func _inside(q: Vector2, margin: float = 0.96) -> bool:
	return q.distance_to(_c) < _r * margin


func _seg(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	# Clip a segment to the disc by sampling: draw the part inside.
	var ia: bool = _inside(a)
	var ib: bool = _inside(b)
	if not ia and not ib:
		return
	if ia and ib:
		draw_line(a, b, col, width, true)
		return
	var inside: Vector2 = a if ia else b
	var outside: Vector2 = b if ia else a
	var lo: float = 0.0
	var hi: float = 1.0
	for i in 12:
		var mid: float = (lo + hi) * 0.5
		if _inside(inside.lerp(outside, mid)):
			lo = mid
		else:
			hi = mid
	draw_line(inside, inside.lerp(outside, lo), col, width, true)


func _draw() -> void:
	if state.is_empty() or fade <= 0.01:
		return
	var u: float = D.u_of(self)
	var vs: Vector2 = get_viewport_rect().size
	_r = 112.0 * u
	_c = Vector2(vs.x - _r - 24.0 * u, vs.y - _r - 64.0 * u)
	_k = _r / reach_m * 0.75
	_kw = _r * w_scale
	_p = state.get("player_pos", Vector4.ZERO)
	var g: Projection = state.get("ground", Projection.IDENTITY)
	# The map turns with you: your heading (the frame's floor direction ahead) is up and to the right.
	var f4: Vector4 = -g.z
	var r4: Vector4 = g.x
	var f2 := Vector2(f4.x, f4.z)
	if f2.length() < 0.15:
		# Turned all the way into W, ahead has no floor direction: keep the hidden axis's.
		f2 = Vector2(-g.w.x, -g.w.z) if Vector2(g.w.x, g.w.z).length() > 0.1 else Vector2(0, -1)
	_fwd = f2.normalized()
	_right = Vector2(-_fwd.y, _fwd.x)
	var bands: Array = state.get("bands", [])
	draw_circle(_c, _r + 3.0 * u, Color(D.GLASS, D.GLASS.a * fade))
	draw_arc(_c, _r + 3.0 * u, 0.0, TAU, 72, Color(1, 1, 1, 0.10 * fade), 1.4 * u, true)
	# THE ROOMS: faint boxes through their W; filled on the sheet where your slice cuts them.
	for room in state.get("rooms", []):
		var rect: Rect2 = room["rect"]
		var w0: float = maxf(float(room["w0"]), _p.w - 4.5)
		var w1: float = minf(float(room["w1"]), _p.w + 4.5)
		if w1 < w0:
			continue
		var corners: Array = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		var col_lo: Color = D.band_at(bands, w0)
		var col_hi: Color = D.band_at(bands, w1)
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			_seg(_to(a.x, a.y, w0), _to(b.x, b.y, w0), Color(col_lo, 0.22 * fade), maxf(1.0, u))
			_seg(_to(a.x, a.y, w1), _to(b.x, b.y, w1), Color(col_hi, 0.22 * fade), maxf(1.0, u))
			_seg(_to(a.x, a.y, w0), _to(a.x, a.y, w1), Color(1, 1, 1, 0.07 * fade), maxf(1.0, u))
	# THE SHEET: your slice, through you, ±9 m along your right and your ahead (tilted with them).
	var sheet: Array = []
	for st in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var q: Vector4 = _p + r4 * st.x * 9.0 + f4 * st.y * 9.0
		sheet.append(_to(q.x, q.z, q.w))
	var tilt: float = float(state.get("tilt", 0.0))
	var sheet_col: Color = D.band_at(bands, _p.w)
	var poly := PackedVector2Array()
	for q in sheet:
		var qq: Vector2 = q
		if not _inside(qq, 0.98):
			qq = _c + (qq - _c).normalized() * _r * 0.98
		poly.append(qq)
	draw_colored_polygon(poly, Color(sheet_col, 0.16 * fade))
	# Where the sheet cuts a room, that room's plan fills on it (level slices only: a tilted sheet cuts
	# rooms along a slope the map leaves to the sheet itself).
	if tilt < 0.05:
		for room in state.get("rooms", []):
			if _p.w < float(room["w0"]) or _p.w > float(room["w1"]):
				continue
			var rect2: Rect2 = room["rect"]
			var pts := PackedVector2Array()
			var all_in: bool = true
			for cc in [rect2.position, Vector2(rect2.end.x, rect2.position.y), rect2.end, Vector2(rect2.position.x, rect2.end.y)]:
				var sp: Vector2 = _to(cc.x, cc.y, _p.w)
				if not _inside(sp, 0.98):
					sp = _c + (sp - _c).normalized() * _r * 0.98
					all_in = false
				pts.append(sp)
			# Clamped to the disc, a room far off can fold into a bow-tie or a sliver the triangulator refuses:
			# fill its convex hull instead, and only while that keeps some area.
			var fill: PackedVector2Array = pts
			if not all_in:
				fill = Geometry2D.convex_hull(pts)
				fill.remove_at(fill.size() - 1)
			var area: float = 0.0
			for i in fill.size():
				area += fill[i].cross(fill[(i + 1) % fill.size()])
			if fill.size() >= 3 and absf(area) > 4.0 * u * u:
				draw_colored_polygon(fill, Color(sheet_col, (0.22 if all_in else 0.16) * fade))
			for i in 4:
				_seg(pts[i], pts[(i + 1) % 4], Color(sheet_col.lerp(Color.WHITE, 0.4), 0.55 * fade), 1.2 * u)
	for i in 4:
		_seg(sheet[i], sheet[(i + 1) % 4], Color(D.STOP.lerp(Color(1.0, 0.8, 0.35), 0.8), 0.85 * fade), 1.8 * u)
	# DOORS: at their W, stems to the sheet.
	var n: Vector4 = g.w
	for d in state.get("level_doors", []):
		var at: Vector3 = d["at"]
		var aw: float = Build.align_for(d, _p.w)
		var top: Vector2 = _to(at.x, at.z, aw)
		if not _inside(top, 0.9):
			continue
		var sw: float = _slice_w_at(at.x, at.z, n)
		var base: Vector2 = _to(at.x, at.z, clampf(sw, _p.w - 6.0, _p.w + 6.0))
		var open: float = Build.openness(d, sw)
		var col: Color = Build.color_for(d, _p.w)
		_seg(base, top, Color(col, 0.6 * fade), 1.2 * u)
		D.door_glyph(self, top, 11.0 * u, Color(col.lerp(Color.WHITE, 0.25), fade), open, u)
	# THE TALL ONES: figures at their W.
	for wk in state.get("walkers", []):
		var q: Vector4 = wk["pos"]
		var foot: Vector2 = _to(q.x, q.z, q.w)
		if not _inside(foot, 0.92):
			continue
		var red: float = float(wk["red"])
		var col: Color = Color(0.72, 0.74, 0.78).lerp(Color(1.0, 0.16, 0.12), red)
		var sw2: float = _slice_w_at(q.x, q.z, n)
		var in_slice: bool = absf(sw2 - q.w) < 0.55
		_seg(_to(q.x, q.z, sw2), foot, Color(col, 0.45 * fade), 1.0 * u)
		var h: float = 15.0 * u
		draw_line(foot, foot - Vector2(0, h), Color(col, fade), 2.2 * u, true)
		draw_circle(foot - Vector2(0, h + 2.5 * u), 2.8 * u, Color(col, fade))
		if in_slice:
			draw_arc(foot - Vector2(0, h * 0.5), h * 0.8, 0.0, TAU, 24, Color(1.0, 0.25, 0.2, 0.9 * fade), 1.6 * u, true)
	# YOU: an arrow on the sheet, pointing ahead.
	var tip: Vector2 = _to(_p.x + _fwd.x * 1.6, _p.z + _fwd.y * 1.6, _p.w + f4.w * 1.6)
	var tail: Vector2 = _c
	var dirv: Vector2 = (tip - tail).normalized() if tip.distance_to(tail) > 0.5 else Vector2(0.7, -0.7)
	var side := Vector2(-dirv.y, dirv.x)
	var arrow := PackedVector2Array([tail + dirv * 10.0 * u, tail - dirv * 5.0 * u + side * 5.5 * u, tail - dirv * 2.0 * u, tail - dirv * 5.0 * u - side * 5.5 * u])
	draw_colored_polygon(arrow, Color(1, 1, 1, fade))
	# THE W SCALE down the left of the disc: the band colours, your needle.
	var w_min: float = float(state.get("w_min", -4.0))
	var w_max: float = float(state.get("w_max", 4.0))
	var x0: float = _c.x - _r - 16.0 * u
	var y_top: float = _c.y - _r * 0.8
	var y_bot: float = _c.y + _r * 0.8
	var nseg: int = 40
	for i in nseg:
		var t0: float = float(i) / nseg
		var wv: float = lerpf(w_max, w_min, t0)
		draw_rect(Rect2(x0 - 3.0 * u, lerpf(y_top, y_bot, t0), 6.0 * u, (y_bot - y_top) / nseg + 0.5), Color(D.band_at(bands, wv), 0.9 * fade))
	var ny: float = remap(clampf(_p.w, w_min, w_max), w_max, w_min, y_top, y_bot)
	var blocked: bool = bool(state.get("w_blocked", false))
	var ncol: Color = D.STOP if blocked else Color.WHITE
	draw_line(Vector2(x0 - 8.0 * u, ny), Vector2(x0 + 8.0 * u, ny), Color(ncol, fade), 2.4 * u)
	var sk: float = float(state.get("stop_kata", -INF))
	var sa: float = float(state.get("stop_ana", INF))
	if sk > w_min:
		draw_line(Vector2(x0 - 6.0 * u, remap(sk, w_max, w_min, y_top, y_bot)), Vector2(x0 + 6.0 * u, remap(sk, w_max, w_min, y_top, y_bot)), Color(1, 1, 1, 0.6 * fade), 1.4 * u)
	if sa < w_max:
		draw_line(Vector2(x0 - 6.0 * u, remap(sa, w_max, w_min, y_top, y_bot)), Vector2(x0 + 6.0 * u, remap(sa, w_max, w_min, y_top, y_bot)), Color(1, 1, 1, 0.6 * fade), 1.4 * u)
	D.text(self, Vector2(x0, y_top - 8.0 * u), "ANA", "key", "micro", u, Color(D.INK_DIM, fade), HORIZONTAL_ALIGNMENT_CENTER)
	D.text(self, Vector2(x0, y_bot + 16.0 * u), "KATA", "key", "micro", u, Color(D.INK_DIM, fade), HORIZONTAL_ALIGNMENT_CENTER)
	# The reading, under the disc.
	var label: String = ("STOP  ·  " if blocked else "") + "YOUR SLICE  ·  " + D.w_label(_p.w)
	if tilt > 0.05:
		label += "  ·  TURNED %d°" % int(round(rad_to_deg(tilt)))
	D.text(self, Vector2(_c.x, _c.y + _r + 18.0 * u), label, "key", "caption", u, Color(ncol if blocked else sheet_col.lerp(Color.WHITE, 0.5), fade), HORIZONTAL_ALIGNMENT_CENTER)
	# Q and E, lit while held, at the scale's ends.
	var wi: float = float(state.get("w_input", 0.0))
	D.keycap(self, Rect2(x0 - 11.0 * u, y_top - 40.0 * u, 22.0 * u, 18.0 * u), "E", u, wi > 0.1, fade)
	D.keycap(self, Rect2(x0 - 11.0 * u, y_bot + 22.0 * u, 22.0 * u, 18.0 * u), "Q", u, wi < -0.1, fade)


## The W at which your slice crosses the ground point (x, z) (the pen's _w_above).
func _slice_w_at(x: float, z: float, n: Vector4) -> float:
	if absf(n.w) < 0.06:
		return _p.w
	return _p.w - ((x - _p.x) * n.x + (z - _p.z) * n.z) / n.w
