extends Control

## Kit: a room seen from straight above, drawn live as a diagram in the dev panel (Ramon, 5 Oct:
## "being able to see the topview in a preview diagram would be good"), so the room's shape can be
## set by eye while the sliders move (kit_tuner.gd ROOM SHAPE). From the room (a KitRoom with an
## outline, kit_room_4d.gd, shaped by kit_room_plan.gd):
##
##   the walls          thick, in their colour: code blue where a panel or a code paints them,
##                      grey where they are the room's own; a gap for each doorway
##   their names        and lengths, in metres, just inside each wall
##   the wall panels    a white bar on their wall where each one hangs (`panels`, kit_wall_panel_4d.gd)
##   the plinth         a circle where the showcase stands (`showcase`, its radius)
##   the box            its width and depth along the foot and the side
##
## The entrance is at the bottom, as you walk in. It draws again only when something it shows has
## changed, and only while it is on screen: shut, the dev panel costs it nothing.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/VoxelLab/carried/LabKit/lab_print.gd")
const BLUE := Color(0.25, 0.55, 1.0)
const GREY := Color(0.62, 0.66, 0.72)
const INK := Color(0.86, 0.92, 1.0)
const DIM := Color(0.62, 0.70, 0.82)

var room: Node
var showcase: Node4D
var panels: Array = []
var _sig: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(380, 330)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or room == null:
		return
	var sig: String = str(room.get("outline")) + str(room.get("doorways")) + str(_marks())
	for e in (room.get("outline") as PackedVector2Array).size():
		sig += String(room.call("wall_code", e))
	if sig != _sig:
		_sig = sig
		queue_redraw()


func _marks() -> Array:
	var out: Array = []
	for p in panels:
		if is_instance_valid(p) and p.has_method("plan_mark"):
			var m: Array = p.call("plan_mark")
			if not m.is_empty() and m[0] == room:
				out.append(m)
	return out


func _draw() -> void:
	if room == null:
		return
	var ol: PackedVector2Array = room.get("outline")
	var n: int = ol.size()
	if n < 3:
		return
	var names: PackedStringArray = room.get("wall_names")
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in ol:
		lo = lo.min(p)
		hi = hi.max(p)
	var ext: Vector2 = (hi - lo).max(Vector2(0.1, 0.1))
	var pad := Vector2(46, 34)
	var box: Vector2 = size - pad * 2.0
	var k: float = minf(box.x / ext.x, box.y / ext.y)
	var origin: Vector2 = pad + (box - ext * k) * 0.5
	# Room x to the right, room -z up the page: the entrance (largest z) at the bottom, as you walk in.
	var at := func(p: Vector2) -> Vector2: return origin + Vector2(p.x - lo.x, p.y - lo.y) * k
	var f: Font = LabPrint.font("bold")
	var fs: int = 11
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.04, 0.06, 0.6))
	# The floor.
	var ground := PackedVector2Array()
	for p in ol:
		ground.append(at.call(p))
	draw_colored_polygon(ground, Color(0.16, 0.19, 0.25))
	# The walls, each in its colour, broken by its doorways; its name and length just inside it. The
	# room's own walls first and the blue ones over them, so where two walls meet in a corner the
	# grey one never covers a blue one's end (it made a centred panel look off centre).
	var doors: Array = room.get("doorways")
	for blue_pass in [false, true]:
		for e in n:
			var a: Vector2 = ol[e]
			var c: Vector2 = ol[(e + 1) % n]
			var len: float = a.distance_to(c)
			if len < 0.05:
				continue
			var is_blue: bool = not String(room.call("wall_code", e)).is_empty()
			if is_blue != blue_pass:
				continue
			var col: Color = BLUE if is_blue else GREY
			var gaps: Array = []
			for d in doors:
				if int(room.call("wall_key", d[0])) == e:
					gaps.append(Vector2(float(d[1]), float(d[2])))
			gaps.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)
			var t0: float = 0.0
			var dir: Vector2 = (c - a) / len
			for g in gaps:
				if g.x > t0:
					draw_line(at.call(a + dir * t0), at.call(a + dir * minf(g.x, len)), col, 5.0, true)
				t0 = maxf(t0, g.y)
			if t0 < len:
				draw_line(at.call(a + dir * t0), at.call(c), col, 5.0, true)
			var inward := Vector2(-dir.y, dir.x)
			var mid: Vector2 = at.call((a + c) * 0.5 + inward * (1.6 / maxf(k / 14.0, 0.5)))
			var label: String = "%s  %.1f m" % [names[e] if e < names.size() else "wall %d" % e, len]
			var w: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, mid - Vector2(w * 0.5, -4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK if is_blue else DIM)
	# The panels on their walls.
	for m in _marks():
		var e2: int = int(m[1])
		var a2: Vector2 = ol[e2]
		var c2: Vector2 = ol[(e2 + 1) % n]
		var d2: Vector2 = (c2 - a2).normalized()
		var in2 := Vector2(-d2.y, d2.x)
		var p0: Vector2 = a2 + d2 * float(m[2]) + in2 * 0.35
		var p1: Vector2 = a2 + d2 * float(m[3]) + in2 * 0.35
		draw_line(at.call(p0), at.call(p1), Color(1, 1, 1), 3.0, true)
	# The plinth.
	if showcase != null and room is Node4D:
		var rp: Vector4 = (room as Node4D).global_position
		var sp: Vector4 = showcase.global_position - rp
		draw_arc(at.call(Vector2(sp.x, sp.z)), float(showcase.get("radius")) * k, 0.0, TAU, 40, Color(0.45, 0.85, 1.0), 2.0, true)
	# The box.
	var wtxt: String = "width %.1f m" % ext.x
	var dtxt: String = "depth %.1f m" % ext.y
	draw_string(f, Vector2(size.x * 0.5 - f.get_string_size(wtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, size.y - 10.0), wtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, DIM)
	draw_string(f, Vector2(6.0, 16.0), dtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, DIM)
	draw_string(f, Vector2(size.x - 6.0 - f.get_string_size("ENTRANCE BELOW", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1).x, 16.0), "ENTRANCE BELOW", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, DIM)
