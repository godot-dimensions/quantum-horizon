extends RefCounted

## The six level glyphs on the console, drawn in the kit's line hand (kit_glyphs.gd draws the animals the
## same way): one picture per level's one idea.
##   step       two layers, offset, a door between them
##   turn       a corridor, and the turn that swings it ahead
##   both       two turns, one ahead, one to the side
##   sealed     a closed room with the exit in it, its door from the layer beside
##   cube       a cube of cells
##   generated  a die
##
## NO class_name (engine_gotchas.md).


static func draw(c: CanvasItem, kind: String, r: Rect2, col: Color) -> void:
	var s: float = minf(r.size.x, r.size.y)
	var o: Vector2 = r.get_center()
	var w: float = maxf(1.5, s * 0.045)
	match kind:
		"step":
			var a := Rect2(o + Vector2(-0.42, -0.30) * s, Vector2(0.5, 0.5) * s)
			var b := Rect2(o + Vector2(-0.08, -0.20) * s, Vector2(0.5, 0.5) * s)
			_box(c, a, col, w)
			_box(c, b, Color(col, 0.55), w)
			c.draw_circle(a.get_center() + Vector2(0.10, 0.06) * s, s * 0.07, col)
			_arrow(c, a.get_center() + Vector2(0.10, 0.06) * s, b.get_center() + Vector2(0.06, 0.04) * s, col, w)
		"turn":
			c.draw_line(o + Vector2(-0.12, 0.42) * s, o + Vector2(-0.12, -0.05) * s, col, w, true)
			c.draw_line(o + Vector2(0.12, 0.42) * s, o + Vector2(0.12, 0.05) * s, col, w, true)
			c.draw_arc(o + Vector2(0.12, -0.05) * s, s * 0.24, PI, PI * 1.5, 16, Color(col, 0.6), w, true)
			_arrow(c, o + Vector2(-0.12, -0.05) * s, o + Vector2(0.40, -0.30) * s, col, w)
		"both":
			_arrow(c, o + Vector2(-0.30, 0.35) * s, o + Vector2(-0.30, -0.40) * s, col, w)
			_arrow(c, o + Vector2(-0.30, 0.0) * s, o + Vector2(0.42, 0.0) * s, Color(col, 0.6), w)
			c.draw_circle(o + Vector2(-0.30, 0.0) * s, s * 0.06, col)
		"sealed":
			var room := Rect2(o + Vector2(-0.28, -0.24) * s, Vector2(0.48, 0.48) * s)
			_box(c, Rect2(room.position + Vector2(0.16, -0.10) * s, room.size), Color(col, 0.4), w)
			_box(c, room, col, w)
			c.draw_circle(room.get_center(), s * 0.08, col)
		"cube":
			var f := Rect2(o + Vector2(-0.38, -0.18) * s, Vector2(0.52, 0.52) * s)
			var b2 := Rect2(f.position + Vector2(0.22, -0.22) * s, f.size)
			_box(c, b2, Color(col, 0.5), w)
			_box(c, f, col, w)
			for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				c.draw_line(f.position + f.size * corner, b2.position + b2.size * corner, Color(col, 0.7), w, true)
		"generated":
			var d := Rect2(o - Vector2(0.34, 0.34) * s, Vector2(0.68, 0.68) * s)
			_box(c, d, col, w)
			for p in [Vector2(0.25, 0.25), Vector2(0.75, 0.75), Vector2(0.5, 0.5), Vector2(0.75, 0.25), Vector2(0.25, 0.75)]:
				c.draw_circle(d.position + d.size * p, s * 0.055, col)
		_:
			_box(c, Rect2(o - Vector2(0.3, 0.3) * s, Vector2(0.6, 0.6) * s), col, w)


static func _box(c: CanvasItem, r: Rect2, col: Color, w: float) -> void:
	c.draw_rect(r, col, false, w, true)


static func _arrow(c: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	c.draw_line(a, b, col, w, true)
	var d: Vector2 = (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var head: float = w * 3.2
	c.draw_colored_polygon(PackedVector2Array([b + d * head * 0.4, b - d * head + n * head * 0.7, b - d * head - n * head * 0.7]), col)
