extends Control

## WATER LAB: the tank's gizmo (Ramon, 9 Oct: "i want to be able to W rotate whats in the fish tank but
## not the rest. and maybe theres a gizmo just in this room for us. look at all the gizmos we made so
## far"). After the pen's spirit level for the fourth axis (chickenpen/scripts/pen_slice_plane_4d.gd):
## pictures of the thing you are turning, against the slice you see it by.
##
## TWO PICTURES, one over the other (round 2, Ramon: "underneath you could create another [one], but
## then it shows the slice rotating the other way ... the rectangle that becomes less in width from
## one side"; round 4: that one on top, a better name, and the two boxes the same size, "matching
## views of the same object"):
##   FRONT TO BACK  the tank from its end in z (glass to back, across) and W: the wheel's turn, the
##                  z-W plane;
##   SIDE TO SIDE   the tank from above in x (across) and W (up the panel): the right drag's sideways
##                  turn, the x-W plane.
## Each picture draws the tank's box the same size, its across axis scaled to fill it (the tank is
## 20 m along x and 3 m front to back), so they read as two views of one tank.
## In each: the water's box (fixed), the contents' box turned and slid, your slice as a gold line,
## and where that line runs through the contents drawn thick (what the glass shows you: turn the
## other way and it shortens from one side); the animals as dots, lit and ringed in your slice. The
## shark is drawn bigger, so you can find it (V aligns it). A right drag forward and back slides
## the contents through W (the line moves up and down through them).
##
## IT READS AND YOU DRIVE: the room does the turning (water_lab_4d.gd). Sizes follow the window's
## height. NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/WaterLab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")

var tank: Node = null
var shown: bool = false
## Following the shark (V): the room says so, the picture marks it.
var following: bool = false
var _a: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	# Under a CanvasLayer the anchors have no parent rect to fill: the window's size, each frame.
	size = get_viewport_rect().size
	var before: float = _a
	_a = move_toward(_a, 1.0 if shown else 0.0, delta * 4.0)
	# Redrawn while it fades too, down to the frame it reaches nothing (it left a ghost otherwise).
	if _a > 0.0 or shown or before != _a:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.001 or tank == null or size.y < 100.0:
		return
	var u: float = size.y / 1080.0
	var w: float = 540.0 * u
	var h: float = 250.0 * u
	var gap: float = 14.0 * u
	var right: float = size.x - w - 40.0 * u
	var bottom: float = size.y - 140.0 * u
	var lower := Rect2(Vector2(right, bottom - h), Vector2(w, h))
	var upper := Rect2(Vector2(right, bottom - h * 2.0 - gap), Vector2(w, h))
	var turn: float = float(tank.get("contents_turn"))
	var turn2: float = float(tank.get("contents_turn2"))
	var slide: float = float(tank.get("contents_slide"))
	var basis: Projection = tank.call("contents_basis")
	_panel(upper, u, "FRONT TO BACK", "z and W   ·   turned %+.0f°" % rad_to_deg(turn2), 2, basis, slide, "WHEEL  turn front to back      V  the shark      R  back")
	_panel(lower, u, "SIDE TO SIDE", "x and W   ·   turned %+.0f°   slid %+.2f m" % [rad_to_deg(turn), slide], 0, basis, slide, "RIGHT DRAG  sideways: turn     forward and back: slide")


## One picture: across is x (axis 0) or z (axis 2), up is W.
func _panel(box: Rect2, u: float, title: String, sub: String, axis: int, basis: Projection, slide: float, foot: String) -> void:
	var glass := Style.glass_box(16.0 * u)
	glass.bg_color.a *= _a
	draw_style_box(glass, box)
	var ink := Color(1, 1, 1, 0.92 * _a)
	var dim := Color(1, 1, 1, 0.35 * _a)
	var accent := Color(Style.UI_ACCENT, _a)
	var gold := Color(1.0, 0.80, 0.35, _a)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var pad: float = 20.0 * u
	draw_string(fb, box.position + Vector2(pad, pad + 16.0 * u), title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * u), ink)
	draw_string(fs, box.position + Vector2(pad, pad + 38.0 * u), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, int(13 * u), Color(Style.UI_INK_DIM, _a))
	var he: Vector4 = tank.call("half_extents")
	var ha: float = he.x if axis == 0 else he.z
	var area := Rect2(box.position + Vector2(pad, pad + 52.0 * u), Vector2(box.size.x - pad * 2.0, box.size.y - pad * 2.0 - 70.0 * u))
	# The box the same size in both pictures: W to the height, the across axis to 1.9 times that.
	var sw: float = area.size.y * 0.5 / (he.w + 0.5)
	var sa: float = sw * he.w * 1.9 / ha
	var c: Vector2 = area.get_center()
	var at := func(a: float, ww: float) -> Vector2: return c + Vector2(a * sa, -ww * sw)
	# Where a point of the contents lands: across (x or z) and W.
	var place := func(p: Vector4) -> Vector2:
		var q: Vector4 = basis * p + Vector4(0.0, 0.0, 0.0, slide)
		return Vector2(q.x if axis == 0 else q.z, q.w)
	# The water's box.
	draw_rect(Rect2(at.call(-ha, he.w), Vector2(ha * 2.0 * sa, he.w * 2.0 * sw)), dim, false, maxf(1.0, 1.2 * u))
	# The contents' box (its middle section in the other axis), turned and slid.
	var corners: Array = []
	for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := Vector4.ZERO
		p[axis] = k.x * ha
		p.w = k.y * he.w
		corners.append(place.call(p))
	var poly := PackedVector2Array()
	for q in corners:
		poly.append(at.call((q as Vector2).x, (q as Vector2).y))
	draw_colored_polygon(poly, Color(Style.UI_ACCENT, 0.10 * _a))
	var ring: PackedVector2Array = poly.duplicate()
	ring.append(poly[0])
	draw_polyline(ring, Color(Style.UI_ACCENT, 0.7 * _a), maxf(1.0, 1.4 * u), true)
	# Your slice, and where it runs through the contents (what the glass shows).
	draw_line(at.call(-ha - 0.4, 0.0), at.call(ha + 0.4, 0.0), gold, maxf(1.5, 2.0 * u), true)
	var cut: Vector2 = _cut(corners)
	if cut.y > cut.x:
		draw_line(at.call(cut.x, 0.0), at.call(cut.y, 0.0), accent, maxf(3.0, 5.0 * u), true)
	draw_string(fs, at.call(ha + 0.45, 0.0) + Vector2(-64.0 * u, -7.0 * u), "YOUR SLICE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), gold)
	# The arches.
	var reef: Node = tank.get("reef")
	if reef != null:
		for nm in ["ArchLeft", "ArchRight", "ArchW"]:
			var a: Node4D = reef.get_node_or_null(nm) as Node4D
			if a != null:
				draw_arc(at.call((place.call(a.position) as Vector2).x, (place.call(a.position) as Vector2).y), 6.0 * u, PI, TAU, 12, Color(0.85, 0.78, 0.66, _a), maxf(1.0, 2.0 * u), true)
	# The animals.
	var koi: Node = tank.get("koi")
	if koi != null:
		for f in koi.get("fish"):
			var q2: Vector2 = place.call(f["p"])
			var on: bool = absf(q2.y) < 0.21 * float(f["len"])
			var pp: Vector2 = at.call(q2.x, q2.y)
			draw_circle(pp, (3.6 if on else 2.6) * u, ink if on else dim)
			if on:
				draw_arc(pp, 6.5 * u, 0.0, TAU, 16, accent, maxf(1.0, 1.2 * u), true)
	for pair in [["eel", Color(0.75, 0.68, 0.35), 4.5], ["crab", Color(1.0, 0.45, 0.32), 4.5], ["shark", Color(0.86, 0.90, 0.96), 7.0]]:
		var n: Node = tank.get(String(pair[0]))
		if n == null:
			continue
		var np: Vector4 = n.get("p") if String(pair[0]) == "shark" else n.get("_p")
		var q3: Vector2 = place.call(np)
		var pp3: Vector2 = at.call(q3.x, q3.y)
		draw_circle(pp3, float(pair[2]) * u, Color(pair[1], _a))
		if String(pair[0]) == "shark":
			draw_string(fs, pp3 + Vector2(10.0 * u, 4.0 * u), "SHARK" + ("  ·  FOLLOWING" if following else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(pair[1], _a))
	draw_string(fs, Vector2(box.position.x + pad, box.end.y - 12.0 * u), foot, HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * u), dim)


## Where the line w = 0 runs inside the polygon `corners` (across values), as (from, to); empty when it
## misses.
static func _cut(corners: Array) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for i in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		if (a.y <= 0.0 and b.y >= 0.0) or (a.y >= 0.0 and b.y <= 0.0):
			if absf(b.y - a.y) < 0.000001:
				lo = minf(lo, minf(a.x, b.x))
				hi = maxf(hi, maxf(a.x, b.x))
			else:
				var x: float = a.x + (b.x - a.x) * (0.0 - a.y) / (b.y - a.y)
				lo = minf(lo, x)
				hi = maxf(hi, x)
	return Vector2(lo, hi)
