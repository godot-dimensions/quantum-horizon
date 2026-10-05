@tool
extends RefCounted

## PathCreator: reads one symbol master (an SVG exported from Ramon's Figma sheet) into shapes the
## vector shader can draw (path_symbols.gd packs them). Each shape is a list of straight segments
## flattened from the SVG's path, with how it is painted:
##
##   {"kind": "fill" | "stroke", "width": stroke width (units), "rule": "nonzero" | "evenodd",
##    "color": the colour as written, "d": the path data as written (to tell layers apart),
##    "segs": PackedVector4Array of (x0, y0, x1, y1), in the SVG's own units, y down,
##    "caps": PackedVector4Array, two a segment: its run's start and end cap planes, each (point x,
##            point y, outward x, outward y), outward (0, 0) for none}
##
## STROKES as the SVG paints them (checked against Godot's own SVG renderer, 5 Oct; the first
## version drew every stroke with round ends and joins, and no dashes):
##   caps     "butt" (the default) and "square" ends are cut flat: every segment of an open run
##            carries the run's two end planes (its first point and the way out past it, its last
##            and the way out past that), and the shader draws nothing beyond either, so a run of
##            many short segments (a flattened curve) is cut square too; "round" ends stay round
##   joins    "miter" (the default) corners sharper than 15 degrees get their pointed wedge added as
##            a small fill of the same colour (up to the miter limit, 4); "round" and gentler turns
##            are the distance's own round join
##   dashes   stroke-dasharray splits the stroke into dashes, each an open stroke with its caps
##
## Path commands M L H V C S Q T Z, upper and lower case (A, the arc, is not in any Figma export
## seen so far and is reported if met). Curves are flattened finely enough that the distance the
## shader measures is the curve's to well under a hundredth of a unit. Fills whose area is nil
## (Figma writes a zero-width fill beside some strokes) are dropped; so are plain white rects (a
## frame's clip background).
##
## NO class_name (engine_gotchas.md).

const CURVE_STEPS := 16


static func read(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("PathCreator: cannot read " + path)
		return []
	return parse(f.get_as_text(), path)


static func parse(svg: String, origin: String = "") -> Array:
	var shapes: Array = []
	var rx := RegEx.new()
	rx.compile("<path\\b([^>]*)/?>")
	for m in rx.search_all(svg):
		var attrs: String = m.get_string(1)
		var d: String = _attr(attrs, "d")
		if d.is_empty():
			continue
		var polys: Array = _flatten(d, origin)
		var stroke: String = _attr(attrs, "stroke")
		var fill: String = _attr(attrs, "fill")
		# SVG paints a path's fill first and its stroke over it (06's hollow junction is a floor-coloured
		# fill under a blue ring).
		if not fill.is_empty() and fill != "none" and _area(polys) >= 0.01:
			shapes.append({"kind": "fill", "width": 0.0, "rule": _attr(attrs, "fill-rule", "nonzero"),
				"color": fill, "d": d, "segs": _segments(polys, true), "caps": PackedVector4Array()})
		if not stroke.is_empty() and stroke != "none":
			var sw: float = float(_attr(attrs, "stroke-width", "1"))
			var dashes := PackedFloat32Array()
			for v in _attr(attrs, "stroke-dasharray", "").replace(",", " ").split(" ", false):
				dashes.append(float(v))
			var st: Dictionary = _stroke(polys, sw, _attr(attrs, "stroke-linecap", "butt"), _attr(attrs, "stroke-linejoin", "miter"),
				float(_attr(attrs, "stroke-miterlimit", "4")), dashes)
			shapes.append({"kind": "stroke", "width": sw, "rule": "nonzero", "color": stroke, "d": d, "segs": st["segs"], "caps": st["caps"]})
			for wedge in st["wedges"]:
				shapes.append({"kind": "fill", "width": 0.0, "rule": "nonzero", "color": stroke, "d": d, "segs": _segments([wedge], true),
					"caps": PackedVector4Array()})
	return shapes


## The viewBox: Rect2 in SVG units.
static func view_box(svg_path: String) -> Rect2:
	var f := FileAccess.open(svg_path, FileAccess.READ)
	if f == null:
		return Rect2()
	var rx := RegEx.new()
	rx.compile("viewBox=\"([^\"]+)\"")
	var m := rx.search(f.get_as_text())
	if m == null:
		return Rect2()
	var v: PackedStringArray = m.get_string(1).split(" ", false)
	return Rect2(float(v[0]), float(v[1]), float(v[2]), float(v[3]))


static func _attr(attrs: String, name: String, fallback: String = "") -> String:
	var rx := RegEx.new()
	rx.compile("(?:^|\\s)" + name + "=\"([^\"]*)\"")
	var m := rx.search(attrs)
	return m.get_string(1) if m != null else fallback


## The path's subpaths, each a PackedVector2Array of points (closed ones end where they began).
static func _flatten(d: String, origin: String) -> Array:
	var toks: Array = _tokens(d)
	var polys: Array = []
	var cur := PackedVector2Array()
	var p := Vector2.ZERO
	var start := Vector2.ZERO
	var last_c := Vector2.ZERO
	var last_cmd: String = ""
	var i: int = 0
	var cmd: String = ""
	while i < toks.size():
		var t: Variant = toks[i]
		if t is String:
			cmd = t
			i += 1
		elif cmd.is_empty():
			i += 1
			continue
		var rel: bool = cmd == cmd.to_lower()
		var base: Vector2 = p if rel else Vector2.ZERO
		match cmd.to_upper():
			"M":
				if cur.size() > 1:
					polys.append(cur)
				p = base + Vector2(toks[i], toks[i + 1])
				i += 2
				start = p
				cur = PackedVector2Array([p])
				# Later pairs after an M are line-tos.
				cmd = "l" if rel else "L"
			"L":
				p = base + Vector2(toks[i], toks[i + 1])
				i += 2
				cur.append(p)
			"H":
				p = Vector2((p.x if rel else 0.0) + float(toks[i]), p.y)
				i += 1
				cur.append(p)
			"V":
				p = Vector2(p.x, (p.y if rel else 0.0) + float(toks[i]))
				i += 1
				cur.append(p)
			"C", "S":
				var c1: Vector2
				var c2: Vector2
				var e: Vector2
				if cmd.to_upper() == "C":
					c1 = base + Vector2(toks[i], toks[i + 1])
					c2 = base + Vector2(toks[i + 2], toks[i + 3])
					e = base + Vector2(toks[i + 4], toks[i + 5])
					i += 6
				else:
					c1 = (p * 2.0 - last_c) if last_cmd in ["C", "S"] else p
					c2 = base + Vector2(toks[i], toks[i + 1])
					e = base + Vector2(toks[i + 2], toks[i + 3])
					i += 4
				for k in range(1, CURVE_STEPS + 1):
					var u: float = float(k) / float(CURVE_STEPS)
					var v: float = 1.0 - u
					cur.append(p * v * v * v + c1 * 3.0 * v * v * u + c2 * 3.0 * v * u * u + e * u * u * u)
				last_c = c2
				p = e
			"Q", "T":
				var q1: Vector2
				var qe: Vector2
				if cmd.to_upper() == "Q":
					q1 = base + Vector2(toks[i], toks[i + 1])
					qe = base + Vector2(toks[i + 2], toks[i + 3])
					i += 4
				else:
					q1 = (p * 2.0 - last_c) if last_cmd in ["Q", "T"] else p
					qe = base + Vector2(toks[i], toks[i + 1])
					i += 2
				for k in range(1, CURVE_STEPS + 1):
					var u2: float = float(k) / float(CURVE_STEPS)
					var v2: float = 1.0 - u2
					cur.append(p * v2 * v2 + q1 * 2.0 * v2 * u2 + qe * u2 * u2)
				last_c = q1
				p = qe
			"Z":
				if cur.size() > 0 and cur[cur.size() - 1] != start:
					cur.append(start)
				if cur.size() > 1:
					polys.append(cur)
				cur = PackedVector2Array([start])
				p = start
			"A":
				push_warning("PathCreator: %s uses an arc command, not read; export it from Figma as outlines." % origin)
				i += 7
			_:
				i += 1
		last_cmd = cmd.to_upper()
	if cur.size() > 1:
		polys.append(cur)
	return polys


## Numbers and command letters from path data.
static func _tokens(d: String) -> Array:
	var out: Array = []
	var rx := RegEx.new()
	rx.compile("[MmLlHhVvCcSsQqTtAaZz]|-?(?:\\d+\\.?\\d*|\\.\\d+)(?:[eE][-+]?\\d+)?")
	for m in rx.search_all(d):
		var s: String = m.get_string()
		if s.length() == 1 and "MmLlHhVvCcSsQqTtAaZz".contains(s):
			out.append(s)
		else:
			out.append(float(s))
	return out


## A stroke's segments with their cap flags, and the wedges of its mitred corners (each a closed
## PackedVector2Array to fill).
static func _stroke(polys: Array, width: float, cap: String, join: String, limit: float, dashes: PackedFloat32Array) -> Dictionary:
	var hw: float = width * 0.5
	var lines: Array = []
	for poly in polys:
		var pts: PackedVector2Array = poly
		var closed: bool = pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) < 1e-4
		if dashes.size() > 0 and _sum(dashes) > 0.0:
			lines.append_array(_dash(pts, dashes))
		else:
			lines.append([pts, closed])
	var segs := PackedVector4Array()
	var caps := PackedVector4Array()
	var wedges: Array = []
	for line in lines:
		var pts: PackedVector2Array = (line[0] as PackedVector2Array).duplicate()
		var closed: bool = line[1]
		var n: int = pts.size()
		if n < 2:
			continue
		if not closed and cap == "square":
			pts[0] = pts[0] + (pts[0] - pts[1]).normalized() * hw
			pts[n - 1] = pts[n - 1] + (pts[n - 1] - pts[n - 2]).normalized() * hw
		var flat: bool = not closed and cap != "round"
		var start_plane := Vector4.ZERO
		var end_plane := Vector4.ZERO
		if flat:
			var out0: Vector2 = (pts[0] - pts[1]).normalized()
			var out1: Vector2 = (pts[n - 1] - pts[n - 2]).normalized()
			start_plane = Vector4(pts[0].x, pts[0].y, out0.x, out0.y)
			end_plane = Vector4(pts[n - 1].x, pts[n - 1].y, out1.x, out1.y)
		for k in n - 1:
			segs.append(Vector4(pts[k].x, pts[k].y, pts[k + 1].x, pts[k + 1].y))
			caps.append(start_plane)
			caps.append(end_plane)
		if join != "miter":
			continue
		var first: int = 0 if closed else 1
		for i in range(first, n - 1):
			var prev: Vector2 = pts[i - 1] if i > 0 else pts[n - 2]
			var p: Vector2 = pts[i]
			var nxt: Vector2 = pts[i + 1]
			var d1: Vector2 = (p - prev).normalized()
			var d2: Vector2 = (nxt - p).normalized()
			var turn: float = absf(d1.angle_to(d2))
			if turn < deg_to_rad(15.0) or turn > PI - 0.01:
				continue
			var side: float = signf(d1.cross(d2))
			var n1: Vector2 = d1.orthogonal() * side
			var n2: Vector2 = d2.orthogonal() * side
			var ratio: float = 1.0 / maxf(sin((PI - turn) * 0.5), 1e-4)
			if ratio > limit:
				continue
			var tip: Vector2 = p + (n1 + n2).normalized() * hw * ratio
			wedges.append(PackedVector2Array([p, p + n1 * hw, tip, p + n2 * hw, p]))
	return {"segs": segs, "caps": caps, "wedges": wedges}


static func _sum(v: PackedFloat32Array) -> float:
	var t: float = 0.0
	for x in v:
		t += x
	return t


## A polyline cut into its dashes (the pattern from its start, as SVG does; an odd pattern repeats
## twice), each [points, false].
static func _dash(pts: PackedVector2Array, pattern: PackedFloat32Array) -> Array:
	var pat := PackedFloat32Array(pattern)
	if pat.size() % 2 == 1:
		pat.append_array(pattern)
	var out: Array = []
	var pi_: int = 0
	var left: float = pat[0]
	var on: bool = true
	var cur := PackedVector2Array([pts[0]])
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var seg_len: float = a.distance_to(b)
		var t: float = 0.0
		while seg_len - t > 1e-6:
			var step: float = minf(left, seg_len - t)
			t += step
			left -= step
			var q: Vector2 = a.lerp(b, t / seg_len)
			if on:
				cur.append(q)
			if left <= 1e-6:
				if on and cur.size() > 1:
					out.append([cur, false])
				on = not on
				pi_ = (pi_ + 1) % pat.size()
				left = pat[pi_]
				cur = PackedVector2Array([q])
	if on and cur.size() > 1:
		out.append([cur, false])
	return out


static func _segments(polys: Array, close: bool) -> PackedVector4Array:
	var out := PackedVector4Array()
	for poly in polys:
		var pts: PackedVector2Array = poly
		for k in range(pts.size() - 1):
			if pts[k].distance_to(pts[k + 1]) > 0.0001:
				out.append(Vector4(pts[k].x, pts[k].y, pts[k + 1].x, pts[k + 1].y))
		# A fill closes each subpath for its winding even when the data left it open.
		if close and pts.size() > 2 and pts[0].distance_to(pts[pts.size() - 1]) > 0.0001:
			out.append(Vector4(pts[pts.size() - 1].x, pts[pts.size() - 1].y, pts[0].x, pts[0].y))
	return out


static func _area(polys: Array) -> float:
	var a: float = 0.0
	for poly in polys:
		var pts: PackedVector2Array = poly
		for k in range(pts.size() - 1):
			a += pts[k].x * pts[k + 1].y - pts[k + 1].x * pts[k].y
	return absf(a) * 0.5
