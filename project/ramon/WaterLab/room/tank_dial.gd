extends Control

## WATER LAB: the tank's gizmo (Ramon, 9 Oct: "i want to be able to W rotate whats in the fish tank but
## not the rest. and maybe theres a gizmo just in this room for us. look at all the gizmos we made so
## far"). After the pen's spirit level for the fourth axis (chickenpen/scripts/pen_slice_plane_4d.gd):
## one picture of the thing you are turning, against the slice you see it by.
##
## THE PICTURE is the tank's floor from above in x (across) and W (up the panel), which a level slice
## sees as one line:
##   the water's box   a fixed outline, the tank's 18 m by its 7 m of W;
##   your slice        a bright line across it, w = 0, where the glass shows you the tank;
##   the contents      their own box, turned by the gizmo's angle and slid through W, the dunes'
##                     outline in it, the arches as small arches;
##   the animals       each a dot where it is in x and W, lit and ringed while your slice passes
##                     through it, dim off it: the koi, the eel (long), the crab (red).
## Turn the contents and the line through them sweeps across their dots: the ones it crosses are the
## ones in the glass. Shown while you stand in the turning circle. A right drag turns, the wheel slides,
## R puts them back. IT READS AND YOU DRIVE: the room does the turning (water_lab_4d.gd).
##
## Sizes follow the window's height. NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/WaterLab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/WaterLab/carried/kit/kit_style.gd")

var tank: Node = null
var shown: bool = false
var _a: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	# Under a CanvasLayer the anchors have no parent rect to fill: the window's size, each frame.
	size = get_viewport_rect().size
	_a = move_toward(_a, 1.0 if shown else 0.0, delta * 4.0)
	if _a > 0.0 or shown:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.001 or tank == null or size.y < 100.0:
		return
	var u: float = size.y / 1080.0
	var w: float = 560.0 * u
	var h: float = 300.0 * u
	var box := Rect2(Vector2(size.x - w - 40.0 * u, size.y - h - 150.0 * u), Vector2(w, h))
	var glass := Style.glass_box(16.0 * u)
	glass.bg_color.a *= _a
	draw_style_box(glass, box)
	var ink := Color(1, 1, 1, 0.92 * _a)
	var dim := Color(1, 1, 1, 0.35 * _a)
	var accent := Color(Style.UI_ACCENT, _a)
	var gold := Color(1.0, 0.80, 0.35, _a)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var pad: float = 22.0 * u
	draw_string(fb, box.position + Vector2(pad, pad + 18.0 * u), "THE TANK THROUGH W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * u), ink)
	var turn: float = float(tank.get("contents_turn"))
	var slide: float = float(tank.get("contents_slide"))
	draw_string(fs, box.position + Vector2(pad, pad + 42.0 * u), "turned %+.0f°   slid %+.2f m through W" % [rad_to_deg(turn), slide], HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * u), Color(Style.UI_INK_DIM, _a))
	# The picture: x across, W up.
	var he: Vector4 = tank.call("half_extents")
	var area := Rect2(box.position + Vector2(pad, pad + 62.0 * u), Vector2(w - pad * 2.0, h - pad * 2.0 - 62.0 * u))
	var s: float = minf(area.size.x / (he.x * 2.0 + 1.0), area.size.y / (he.w * 2.0 + 1.0))
	var c: Vector2 = area.get_center()
	var at := func(x: float, ww: float) -> Vector2: return c + Vector2(x, -ww) * s
	# The water's box.
	draw_rect(Rect2(at.call(-he.x, he.w), Vector2(he.x * 2.0, he.w * 2.0) * s), dim, false, maxf(1.0, 1.2 * u))
	# The contents' box, turned and slid.
	var rot := func(x: float, ww: float) -> Vector2:
		return Vector2(x * cos(turn) - ww * sin(turn), x * sin(turn) + ww * cos(turn) + slide)
	var corners: Array = [rot.call(-he.x, -he.w), rot.call(he.x, -he.w), rot.call(he.x, he.w), rot.call(-he.x, he.w)]
	var poly := PackedVector2Array()
	for q in corners:
		poly.append(at.call((q as Vector2).x, (q as Vector2).y))
	poly.append(poly[0])
	draw_colored_polygon(poly.slice(0, 4), Color(Style.UI_ACCENT, 0.10 * _a))
	draw_polyline(poly, Color(Style.UI_ACCENT, 0.7 * _a), maxf(1.0, 1.4 * u), true)
	# The arches.
	var reef: Node = tank.get("reef")
	if reef != null:
		for nm in ["ArchLeft", "ArchRight", "ArchW"]:
			var a: Node4D = reef.get_node_or_null(nm) as Node4D
			if a == null:
				continue
			var q: Vector2 = rot.call(a.position.x, a.position.w)
			var p: Vector2 = at.call(q.x, q.y)
			draw_arc(p, 7.0 * u, PI, TAU, 12, Color(0.85, 0.78, 0.66, _a), maxf(1.0, 2.0 * u), true)
	# Your slice.
	draw_line(at.call(-he.x - 0.4, 0.0), at.call(he.x + 0.4, 0.0), gold, maxf(1.5, 2.2 * u), true)
	draw_string(fs, at.call(he.x + 0.5, 0.0) + Vector2(-58.0 * u, -6.0 * u), "YOUR SLICE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * u), gold)
	# The animals.
	var koi: Node = tank.get("koi")
	if koi != null:
		for f in koi.get("fish"):
			var fp: Vector4 = f["p"]
			var q2: Vector2 = rot.call(fp.x, fp.w)
			var on: bool = absf(q2.y) < 0.21 * float(f["len"])
			var pp: Vector2 = at.call(q2.x, q2.y)
			draw_circle(pp, (4.0 if on else 3.0) * u, ink if on else dim)
			if on:
				draw_arc(pp, 7.0 * u, 0.0, TAU, 16, accent, maxf(1.0, 1.2 * u), true)
	for pair in [["eel", Color(0.75, 0.68, 0.35)], ["crab", Color(1.0, 0.45, 0.32)]]:
		var n: Node = tank.get(String(pair[0]))
		if n == null:
			continue
		var np: Vector4 = n.get("_p")
		var q3: Vector2 = rot.call(np.x, np.w)
		draw_circle(at.call(q3.x, q3.y), 5.0 * u, Color(pair[1], _a))
	draw_string(fs, Vector2(box.position.x + pad, box.end.y - 12.0 * u), "RIGHT DRAG  turn     WHEEL  slide     R  back", HORIZONTAL_ALIGNMENT_LEFT, -1, int(12 * u), dim)
