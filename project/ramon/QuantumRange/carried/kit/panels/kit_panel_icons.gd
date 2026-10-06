@tool
extends RefCounted

## Kit: the controls' icons for the wall panels, drawn as vectors (no pictures) on the Figma's
## 36 x 40 icon box. The first three are the handoff's own paths, point for point:
##   "wheel"   a mouse, its wheel filled, an up-and-down arrow beside it ("Slice through W")
##   "rdrag"   a mouse, its right button filled ("Rotate in 4D")
##   "key:E"   a key with an E on it ("Add a ball"); any other "key:X" puts X on the key in Bold
## and, in the same hand, for other prototypes:
##   "click"   a mouse, its left button filled
##   "drag"    a mouse, its left button filled, an arrow left and right beside it
##   "arrows"  two keys, left and right
##
## draw(c, kind, rect, col): `rect` is the icon box in the canvas's pixels; strokes scale with it.
##
## NO class_name (engine_gotchas.md).

const BOX := Vector2(36, 40)
const KEY_FONT := preload("res://ramon/Demo/fonts/Montserrat/static/Montserrat-Bold.ttf")


static func draw(c: CanvasItem, kind: String, rect: Rect2, col: Color) -> void:
	var s: float = rect.size.x / BOX.x
	var o: Vector2 = rect.position
	var at := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	if kind.begins_with("key:"):
		var label: String = kind.substr(4)
		_stroke(c, _rounded(at.call(2, 3), at.call(34, 37), 5.0 * s), col, 2.5 * s, true)
		if label == "E":
			_stroke(c, PackedVector2Array([at.call(24, 12), at.call(14, 12), at.call(14, 28), at.call(24, 28)]), col, 2.5 * s, false)
			_stroke(c, PackedVector2Array([at.call(14, 20), at.call(22, 20)]), col, 2.5 * s, false)
		else:
			var px: int = int(round((18.0 if label.length() == 1 else 11.0) * s))
			var w: float = KEY_FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var base: float = at.call(0, 20).y + (KEY_FONT.get_ascent(px) - KEY_FONT.get_descent(px)) * 0.5
			c.draw_string(KEY_FONT, Vector2(at.call(18, 0).x - w * 0.5, base), label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		return
	match kind:
		"wheel":
			_stroke(c, _rounded(at.call(3, 2), at.call(25, 38), 11.0 * s), col, 2.5 * s, true)
			_stroke(c, PackedVector2Array([at.call(3.5, 16), at.call(10.5, 16)]), col, 2.0 * s, false)
			_stroke(c, PackedVector2Array([at.call(17.5, 16), at.call(24.5, 16)]), col, 2.0 * s, false)
			c.draw_colored_polygon(_rounded(at.call(12, 7), at.call(16, 17), 2.0 * s), col)
			_stroke(c, PackedVector2Array([at.call(32, 10), at.call(32, 30)]), col, 1.7 * s, false, true)
			_stroke(c, PackedVector2Array([at.call(35, 13), at.call(32, 10), at.call(29, 13)]), col, 1.7 * s, false, true)
			_stroke(c, PackedVector2Array([at.call(35, 27), at.call(32, 30), at.call(29, 27)]), col, 1.7 * s, false, true)
		"rdrag", "click", "drag":
			var dx: float = 0.0 if kind == "rdrag" else -4.0
			var ox := func(x: float, y: float) -> Vector2: return at.call(x + dx, y)
			_stroke(c, _rounded(ox.call(7, 2), ox.call(29, 38), 11.0 * s), col, 2.5 * s, true)
			_stroke(c, PackedVector2Array([ox.call(7, 15), ox.call(29, 15)]), col, 2.5 * s, false)
			_stroke(c, PackedVector2Array([ox.call(18, 3), ox.call(18, 15)]), col, 2.5 * s, false)
			# The pressed button: the Figma's curve from the top of the button round to its side.
			var right: bool = kind == "rdrag"
			var pts := PackedVector2Array()
			var b0 := Vector2(20, 4)
			var b1 := Vector2(22.2928, 4.46751)
			var b2 := Vector2(24.349, 5.72424)
			var b3 := Vector2(25.8107, 7.55142)
			var b4 := Vector2(27.2725, 9.37861)
			var b5 := Vector2(28.0472, 11.6605)
			var b6 := Vector2(28, 14)
			for i in 9:
				pts.append(_bez(b0, b1, b2, b3, float(i) / 8.0))
			for i in range(1, 9):
				pts.append(_bez(b3, b4, b5, b6, float(i) / 8.0))
			pts.append(Vector2(20, 14))
			var out := PackedVector2Array()
			for p in pts:
				out.append(ox.call(p.x if right else 36.0 - p.x, p.y))
			c.draw_colored_polygon(out, col)
			if kind == "drag":
				_stroke(c, PackedVector2Array([at.call(27, 32), at.call(35, 32)]), col, 1.7 * s, false)
				_stroke(c, PackedVector2Array([at.call(32, 29), at.call(35, 32), at.call(32, 35)]), col, 1.7 * s, false)
		"arrows":
			for side in [0, 1]:
				var x0: float = 0.0 if side == 0 else 19.0
				_stroke(c, _rounded(at.call(x0 + 1, 10), at.call(x0 + 17, 30), 3.5 * s), col, 2.0 * s, true)
				var m: float = x0 + 9.0
				var d: float = -1.0 if side == 0 else 1.0
				_stroke(c, PackedVector2Array([at.call(m - 2.5 * d, 16), at.call(m + 2.5 * d, 20), at.call(m - 2.5 * d, 24)]), col, 2.0 * s, false)
		_:
			_stroke(c, _rounded(at.call(2, 3), at.call(34, 37), 5.0 * s), col, 2.5 * s, true)


static func _bez(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


## A rounded rectangle's outline from `lo` to `hi`, corners `r` (pixels), closed.
static func _rounded(lo: Vector2, hi: Vector2, r: float) -> PackedVector2Array:
	var rr: float = minf(r, minf(hi.x - lo.x, hi.y - lo.y) * 0.5)
	var pts := PackedVector2Array()
	var corners: Array = [[Vector2(hi.x - rr, lo.y + rr), -PI * 0.5], [Vector2(hi.x - rr, hi.y - rr), 0.0],
		[Vector2(lo.x + rr, hi.y - rr), PI * 0.5], [Vector2(lo.x + rr, lo.y + rr), PI]]
	for cn in corners:
		for i in 9:
			var a: float = float(cn[1]) + PI * 0.5 * float(i) / 8.0
			pts.append((cn[0] as Vector2) + Vector2(cos(a), sin(a)) * rr)
	return pts


static func _stroke(c: CanvasItem, pts: PackedVector2Array, col: Color, w: float, closed: bool, round_ends: bool = false) -> void:
	var p := pts
	if closed and p.size() > 0:
		p = pts.duplicate()
		p.append(pts[0])
		p.append(pts[1] if pts.size() > 1 else pts[0])
	c.draw_polyline(p, col, maxf(1.0, w), true)
	if closed:
		return
	# Joins as the SVG's: a square at each bend (its miter, the bends here being right angles),
	# round caps only where the SVG asks for them (the wheel's arrow).
	for i in range(1, pts.size() - 1):
		c.draw_rect(Rect2(pts[i] - Vector2(w, w) * 0.5, Vector2(w, w)), col)
	if round_ends:
		c.draw_circle(pts[0], w * 0.5, col)
		c.draw_circle(pts[pts.size() - 1], w * 0.5, col)
