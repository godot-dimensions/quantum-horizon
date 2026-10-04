extends RefCounted

## Kit: the research console's icons and diagrams, drawn with plain CanvasItem calls so the same
## painter serves the desk's printed screen (kit_desk_4d.gd, rendered once into a texture) and
## the 2D data panel (kit_data_panel.gd, drawn every frame).
##
##   icon(c, kind, rect, col)     line icons: ball, stages, tetra, slice, clock, gauge, chip,
##                                creatures, check, half, todo, axes, brush, graph, live
##   profile(c, rect, bins, ...)  the W profile: how much of the exhibit each W cuts, drawn as a
##                                mirrored silhouette with the slice ticks along its foot
##   bars(c, rect, values, col)   a bar chart, brightest last
##   tag(c, pos, text, ...)       a small rounded label (SAMPLE, LIVE, MEASURED)
##   wire(c, rect, shape, ...)    the exhibit as a triangulated wireframe from its own points
##   animal(c, kind, rect, ...)   an animal in profile, filled: goat, chicken
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const RD := preload("res://ramon/LabChambers/scripts/rd_build.gd")


static func icon(c: CanvasItem, kind: String, rect: Rect2, col: Color) -> void:
	var s: float = minf(rect.size.x, rect.size.y)
	var o: Vector2 = rect.get_center()
	var lw: float = maxf(1.5, s * 0.07)
	match kind:
		"ball":
			c.draw_arc(o, s * 0.38, 0.0, TAU, 48, col, lw, true)
			_ellipse(c, o, Vector2(s * 0.38, s * 0.12), Color(col, col.a * 0.55), lw * 0.7)
			c.draw_circle(o + Vector2(-s * 0.13, -s * 0.15), s * 0.07, col)
		"stages":
			for i in 3:
				var hh: float = s * (0.25 + 0.22 * float(i))
				c.draw_rect(Rect2(Vector2(o.x - s * 0.36 + s * 0.26 * float(i), o.y + s * 0.38 - hh), Vector2(s * 0.18, hh)), Color(col, col.a * (0.55 + 0.22 * float(i))))
		"tetra":
			var a := o + Vector2(0.0, -s * 0.4)
			var b := o + Vector2(-s * 0.38, s * 0.3)
			var d := o + Vector2(s * 0.38, s * 0.3)
			var e := o + Vector2(s * 0.08, s * 0.08)
			c.draw_polyline(PackedVector2Array([a, b, d, a]), col, lw, true)
			c.draw_line(a, e, Color(col, col.a * 0.6), lw * 0.7, true)
			c.draw_line(b, e, Color(col, col.a * 0.6), lw * 0.7, true)
			c.draw_line(d, e, Color(col, col.a * 0.6), lw * 0.7, true)
		"slice":
			RD.icon(c as Control, "slice", rect, col)
		"clock":
			c.draw_arc(o, s * 0.38, 0.0, TAU, 48, col, lw, true)
			c.draw_line(o, o + Vector2(0.0, -s * 0.24), col, lw, true)
			c.draw_line(o, o + Vector2(s * 0.17, s * 0.08), col, lw, true)
		"gauge":
			c.draw_arc(o + Vector2(0.0, s * 0.1), s * 0.38, PI * 0.85, PI * 2.15, 40, col, lw, true)
			c.draw_line(o + Vector2(0.0, s * 0.1), o + Vector2(s * 0.2, -s * 0.16), col, lw, true)
			c.draw_circle(o + Vector2(0.0, s * 0.1), s * 0.06, col)
		"chip":
			RD.icon(c as Control, "engine", rect, col)
		"creatures":
			# Three heads in a row, the middle one in front: the same tool, more animals.
			for i in 3:
				var k: float = float(i) - 1.0
				var at: Vector2 = o + Vector2(k * s * 0.26, (0.0 if i == 1 else -s * 0.06))
				c.draw_arc(at, s * (0.16 if i == 1 else 0.12), 0.0, TAU, 32, Color(col, col.a * (1.0 if i == 1 else 0.6)), lw, true)
			c.draw_line(o + Vector2(-s * 0.4, s * 0.32), o + Vector2(s * 0.4, s * 0.32), col, lw, true)
		"check":
			c.draw_arc(o, s * 0.38, 0.0, TAU, 48, col, lw, true)
			c.draw_polyline(PackedVector2Array([o + Vector2(-s * 0.17, 0.0), o + Vector2(-s * 0.04, s * 0.13), o + Vector2(s * 0.19, -s * 0.13)]), col, lw * 1.2, true)
		"half":
			c.draw_arc(o, s * 0.38, 0.0, TAU, 48, col, lw, true)
			var pts := PackedVector2Array([o])
			for i in 25:
				var t: float = -PI * 0.5 + PI * float(i) / 24.0
				pts.append(o + Vector2(cos(t), sin(t)) * s * 0.3)
			c.draw_colored_polygon(pts, col)
		"todo":
			for i in 12:
				var t0: float = TAU * float(i) / 12.0
				c.draw_arc(o, s * 0.38, t0, t0 + TAU / 24.0, 6, Color(col, col.a * 0.8), lw, true)
		"axes":
			var arms := [Vector2(1, 0), Vector2(0, -1), Vector2(-0.6, 0.55), Vector2(0.62, 0.5)]
			for i in arms.size():
				var tip: Vector2 = o + (arms[i] as Vector2).normalized() * s * 0.4
				c.draw_line(o, tip, Color(col, col.a * (1.0 if i < 3 else 0.55)), lw, true)
				c.draw_circle(tip, lw * 0.9, col)
		"brush":
			var p0 := o + Vector2(-s * 0.3, s * 0.3)
			var p1 := o + Vector2(s * 0.26, -s * 0.26)
			c.draw_line(p0, p1, col, lw * 2.2, true)
			c.draw_colored_polygon(PackedVector2Array([p0 + Vector2(-s * 0.06, -s * 0.02), p0 + Vector2(s * 0.02, s * 0.06), p0 + Vector2(-s * 0.1, s * 0.1)]), col)
		"graph":
			c.draw_polyline(PackedVector2Array([o + Vector2(-s * 0.38, s * 0.2), o + Vector2(-s * 0.14, -s * 0.04), o + Vector2(s * 0.06, s * 0.1), o + Vector2(s * 0.38, -s * 0.28)]), col, lw, true)
			c.draw_line(o + Vector2(-s * 0.4, s * 0.36), o + Vector2(s * 0.4, s * 0.36), Color(col, col.a * 0.6), lw * 0.7, true)
		"live":
			c.draw_circle(o, s * 0.16, col)
			c.draw_arc(o, s * 0.32, 0.0, TAU, 40, Color(col, col.a * 0.5), lw * 0.8, true)
		_:
			RD.icon(c as Control, kind, rect, col)


## An animal in profile, facing right, filled in `col`, its eye and inner lines cut in `cut` (the
## colour behind it): "goat" or "chicken". Drawn in a 100-unit square, fitted to `rect` and stood
## on its foot. For the specimen picker's slots (kit_exhibit_picker_4d.gd).
static func animal(c: CanvasItem, kind: String, rect: Rect2, col: Color, cut: Color) -> void:
	var s: float = minf(rect.size.x, rect.size.y) / 100.0
	var o: Vector2 = Vector2(rect.get_center().x - 50.0 * s, rect.end.y - 94.0 * s)
	var poly := func(pts: Array) -> void:
		var out := PackedVector2Array()
		for p in pts:
			out.append(o + (p as Vector2) * s)
		c.draw_colored_polygon(out, col)
	var line := func(pts: Array, w: float, ink: Color) -> void:
		var out := PackedVector2Array()
		for p in pts:
			out.append(o + (p as Vector2) * s)
		c.draw_polyline(out, ink, maxf(1.0, w * s), true)
	var dot := func(p: Vector2, r: float, ink: Color) -> void:
		c.draw_circle(o + p * s, r * s, ink)
	match kind:
		"goat":
			# The far legs, the body, the near legs, the neck and head, then the horns, ear, beard.
			poly.call([Vector2(56, 58), Vector2(61, 58), Vector2(60, 75), Vector2(60.5, 91), Vector2(56.5, 91), Vector2(56, 75)])
			poly.call([Vector2(33, 58), Vector2(39, 58), Vector2(37, 74), Vector2(37.5, 91), Vector2(33.5, 91), Vector2(33.5, 74)])
			poly.call([Vector2(21, 50), Vector2(24, 40), Vector2(34, 37), Vector2(50, 38.5), Vector2(64, 37), Vector2(70, 40), Vector2(72, 48),
				Vector2(70, 57), Vector2(62, 61.5), Vector2(44, 63), Vector2(30, 62), Vector2(24, 58)])
			poly.call([Vector2(24, 41), Vector2(18.5, 33), Vector2(21.5, 31.5), Vector2(27.5, 39)])
			poly.call([Vector2(26.5, 56), Vector2(34, 57), Vector2(31, 74), Vector2(31.5, 91), Vector2(27, 91), Vector2(27, 74)])
			poly.call([Vector2(62, 56), Vector2(68.5, 56), Vector2(67, 75), Vector2(68, 91), Vector2(63.5, 91), Vector2(63, 75)])
			poly.call([Vector2(63, 40), Vector2(71, 23), Vector2(79, 21), Vector2(81, 30), Vector2(72.5, 47)])
			poly.call([Vector2(72, 24), Vector2(76, 17), Vector2(84, 15.5), Vector2(92, 21), Vector2(95.5, 26.5), Vector2(92.5, 30), Vector2(85, 29.5), Vector2(79, 30)])
			line.call([Vector2(79.5, 17.5), Vector2(77, 10.5), Vector2(72, 6.5), Vector2(66.5, 7.5), Vector2(64.5, 12)], 3.6, col)
			poly.call([Vector2(77, 21), Vector2(67, 24.5), Vector2(76.5, 25.5)])
			poly.call([Vector2(85.5, 29), Vector2(90.5, 29), Vector2(87.5, 38)])
			dot.call(Vector2(84.5, 21.5), 1.7, cut)
		"chicken":
			# The legs and feet, the tail fan, the body, the neck and head, comb, beak and wattle.
			line.call([Vector2(44, 72), Vector2(42, 88)], 3.0, col)
			line.call([Vector2(53, 72), Vector2(55, 88)], 3.0, col)
			line.call([Vector2(35.5, 91), Vector2(42, 88), Vector2(48, 91)], 2.4, col)
			line.call([Vector2(48.5, 91), Vector2(55, 88), Vector2(61.5, 91)], 2.4, col)
			poly.call([Vector2(29, 50), Vector2(20, 27), Vector2(25.5, 22), Vector2(32, 34), Vector2(31, 19), Vector2(37.5, 18.5), Vector2(40, 42)])
			poly.call([Vector2(26, 52), Vector2(30, 45), Vector2(40, 41.5), Vector2(54, 42), Vector2(63, 45.5), Vector2(70, 54), Vector2(68.5, 64),
				Vector2(60, 72), Vector2(46, 75.5), Vector2(34, 71.5), Vector2(27, 62)])
			poly.call([Vector2(57, 47), Vector2(61.5, 31), Vector2(73, 29.5), Vector2(71, 49)])
			dot.call(Vector2(68, 28), 8.5, col)
			dot.call(Vector2(62.5, 19.5), 3.3, col)
			dot.call(Vector2(67.5, 17.5), 3.8, col)
			dot.call(Vector2(72.5, 19.5), 3.2, col)
			poly.call([Vector2(75, 24.5), Vector2(84.5, 28.5), Vector2(75, 31.5)])
			dot.call(Vector2(74.5, 37), 3.2, col)
			dot.call(Vector2(70.5, 26.5), 1.7, cut)
			line.call([Vector2(38, 52), Vector2(48, 50), Vector2(58, 53), Vector2(55, 61), Vector2(46, 64)], 2.2, cut)
		_:
			c.draw_arc(rect.get_center(), minf(rect.size.x, rect.size.y) * 0.3, 0.0, TAU, 40, col, maxf(1.5, s * 3.0), true)


static func _ellipse(c: CanvasItem, o: Vector2, r: Vector2, col: Color, lw: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var t: float = TAU * float(i) / 40.0
		pts.append(o + Vector2(cos(t) * r.x, sin(t) * r.y))
	c.draw_polyline(pts, col, lw, true)


## The W profile: `bins` (0..1, from -W reach to +W reach) as a silhouette mirrored about the
## band's middle, `ticks` (fractions -1..1) as small marks along its foot, `lit` the tick that is
## the current slice (-1: none) and `marker` (-1..1, or NAN for none) a line across it.
static func profile(c: CanvasItem, rect: Rect2, bins: PackedFloat32Array, fill: Color, line: Color,
		ticks: Array = [], lit: int = -1, marker: float = NAN, mark: Color = Color.WHITE) -> void:
	var foot: float = rect.size.y * 0.16
	var band := Rect2(rect.position, Vector2(rect.size.x, rect.size.y - foot))
	var mid: float = band.get_center().y
	var lw: float = maxf(1.0, rect.size.y * 0.018)
	c.draw_line(Vector2(band.position.x, mid), Vector2(band.end.x, mid), Color(line, line.a * 0.35), lw, true)
	if bins.size() >= 2:
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		for i in bins.size():
			var x: float = band.position.x + band.size.x * float(i) / float(bins.size() - 1)
			var h: float = band.size.y * 0.48 * clampf(bins[i], 0.0, 1.0)
			top.append(Vector2(x, mid - h))
			bottom.append(Vector2(x, mid + h))
		var poly := PackedVector2Array(top)
		for i in range(bottom.size() - 1, -1, -1):
			poly.append(bottom[i])
		if Geometry2D.triangulate_polygon(poly).size() > 0:
			c.draw_colored_polygon(poly, fill)
		c.draw_polyline(top, line, lw * 1.4, true)
		c.draw_polyline(bottom, line, lw * 1.4, true)
	for i in ticks.size():
		var x2: float = band.position.x + band.size.x * (float(ticks[i]) * 0.5 + 0.5)
		var on: bool = i == lit
		var th: float = foot * (0.75 if on else 0.45)
		c.draw_line(Vector2(x2, rect.end.y - th), Vector2(x2, rect.end.y), Color(line, line.a * (1.0 if on else 0.55)), lw * (2.4 if on else 1.4), true)
	if is_finite(marker):
		var x3: float = band.position.x + band.size.x * (clampf(marker, -1.0, 1.0) * 0.5 + 0.5)
		c.draw_line(Vector2(x3, band.position.y - lw * 2.0), Vector2(x3, band.end.y + lw * 2.0), mark, lw * 2.6, true)


## A bar chart over `rect`, brightest last; `labels` (optional) are drawn under the bars.
static func bars(c: CanvasItem, rect: Rect2, values: Array, col: Color, labels: Array = [], label_px: int = 10, label_col: Color = Color.WHITE) -> void:
	if values.is_empty():
		return
	var most: float = 0.0001
	for v in values:
		most = maxf(most, float(v))
	var lab_h: float = float(label_px) * 1.5 if not labels.is_empty() else 0.0
	var h: float = rect.size.y - lab_h
	var bw: float = rect.size.x / float(values.size())
	for i in values.size():
		var hh: float = maxf(1.0, h * float(values[i]) / most)
		c.draw_rect(Rect2(Vector2(rect.position.x + bw * float(i) + bw * 0.16, rect.position.y + h - hh), Vector2(bw * 0.68, hh)),
			Color(col, col.a * (0.35 + 0.65 * float(i + 1) / float(values.size()))))
		if i < labels.size():
			c.draw_string(LabPrint.font("body"), Vector2(rect.position.x + bw * float(i), rect.end.y - float(label_px) * 0.2), String(labels[i]),
				HORIZONTAL_ALIGNMENT_CENTER, bw, label_px, label_col)
	c.draw_line(Vector2(rect.position.x, rect.position.y + h), Vector2(rect.end.x, rect.position.y + h), Color(col, col.a * 0.5), maxf(1.0, rect.size.y * 0.01))


## A small rounded tag with `text`, its left edge at `pos.x` and centred on `pos.y`; returns its width.
static func tag(c: CanvasItem, pos: Vector2, text: String, px: int, col: Color, filled: bool = false) -> float:
	var f: Font = LabPrint.font("bold")
	var tw: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var r := Rect2(Vector2(pos.x, pos.y - float(px) * 0.8), Vector2(tw + float(px) * 1.1, float(px) * 1.6))
	var sb := StyleBoxFlat.new()
	sb.draw_center = filled
	sb.bg_color = col
	sb.border_color = col
	sb.set_border_width_all(maxi(1, int(float(px) * 0.12)))
	sb.set_corner_radius_all(int(float(px) * 0.8))
	sb.anti_aliasing = true
	c.draw_style_box(sb, r)
	c.draw_string(f, Vector2(r.position.x, pos.y + f.get_ascent(px) * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, px,
		Color(0.04, 0.06, 0.10, col.a) if filled else col)
	return r.size.x


## 18432 -> "18.4k", 960 -> "960".
static func short(n: int) -> String:
	if n >= 10000:
		return "%.1fk" % (float(n) / 1000.0)
	return str(n)


## The exhibit (kit_showcase shape(): its mesh's points and its balls, seen from the side) as a
## wireframe in `rect`: the points thinned to an even spread, joined by a Delaunay triangulation
## with every long edge dropped (so the web hugs the body and does not bridge the gaps between
## legs), faintly filled; the balls' centres as bright nodes. Faces left, as an animal on a label.
## wire_geometry() works it out once (the triangulation is the costly part); wire_draw() draws it,
## the first `lit` balls bright and the rest dim (-1: all bright).
static func wire(c: CanvasItem, rect: Rect2, shape: Dictionary, line: Color, node: Color, fill: Color) -> void:
	wire_draw(c, wire_geometry(rect, shape), line, node, fill)


static func wire_geometry(rect: Rect2, shape: Dictionary) -> Dictionary:
	var pts: PackedVector2Array = shape.get("points", PackedVector2Array())
	var balls: Array = shape.get("balls", [])
	if pts.size() < 3:
		return {}
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var size: Vector2 = (hi - lo).max(Vector2(0.0001, 0.0001))
	var s: float = minf(rect.size.x / size.x, rect.size.y / size.y)
	var mid: Vector2 = (lo + hi) * 0.5
	# The head is the highest ball: keep it on the left.
	var flip: float = 1.0
	var top: float = -INF
	for b in balls:
		var bc: Vector2 = b[0]
		if bc.y > top:
			top = bc.y
			flip = -1.0 if bc.x > mid.x else 1.0
	var o: Vector2 = rect.get_center()
	var to_px := func(p: Vector2) -> Vector2: return o + Vector2((p.x - mid.x) * flip, -(p.y - mid.y)) * s
	# An even spread: one point per cell of a grid about 30 cells tall.
	var cell: float = size.y / 30.0
	var keep: Dictionary = {}
	for p in pts:
		var k := Vector2i(int(floor(p.x / cell)), int(floor(p.y / cell)))
		if not keep.has(k):
			keep[k] = p
	var px := PackedVector2Array()
	for p in keep.values():
		px.append(to_px.call(p))
	var nodes: int = px.size()
	var ball_px := PackedVector2Array()
	for b in balls:
		var bp: Vector2 = to_px.call(b[0])
		px.append(bp)
		ball_px.append(bp)
	var tris: PackedInt32Array = Geometry2D.triangulate_delaunay(px)
	var longest: float = cell * s * 2.6
	var keep_tris: Array = []
	var edges: Dictionary = {}
	for t in range(0, tris.size() - 2, 3):
		var a: Vector2 = px[tris[t]]
		var b2: Vector2 = px[tris[t + 1]]
		var d: Vector2 = px[tris[t + 2]]
		if a.distance_to(b2) > longest or b2.distance_to(d) > longest or d.distance_to(a) > longest:
			continue
		keep_tris.append(PackedVector2Array([a, b2, d]))
		for e in [[tris[t], tris[t + 1]], [tris[t + 1], tris[t + 2]], [tris[t + 2], tris[t]]]:
			edges[Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))] = true
	var lines := PackedVector2Array()
	for key in edges:
		lines.append(px[key.x])
		lines.append(px[key.y])
	return {"tris": keep_tris, "lines": lines, "nodes": px.slice(0, nodes), "balls": ball_px, "lw": maxf(1.0, rect.size.y * 0.004)}


static func wire_draw(c: CanvasItem, geo: Dictionary, line: Color, node: Color, fill: Color, lit: int = -1) -> void:
	if geo.is_empty():
		return
	var lw: float = float(geo["lw"])
	for t in geo["tris"]:
		c.draw_colored_polygon(t, fill)
	c.draw_multiline(geo["lines"], line, lw, true)
	for p in geo["nodes"]:
		c.draw_circle(p, lw * 1.1, Color(line, line.a * 0.9))
	var balls: PackedVector2Array = geo["balls"]
	for i in balls.size():
		var on: bool = lit < 0 or i < lit
		c.draw_circle(balls[i], lw * (2.6 if on else 1.8), node if on else Color(node, node.a * 0.3))
