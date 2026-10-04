extends Control

## Kit: the slice view, a small HUD in the bottom right corner that shows what slicing means
## (Ramon, 4 Oct: "a slice UI gizmo as overlay HUD in the bottom right corner, perhaps something
## that allows you to see an actual model of the goat, and a slice over it, so you actually see
## what's happening ... the goat could be isometric and in an angle that makes sense").
##
## THE IDEA: the room shows you one 3D slice of a 4D goat. Here the goat stays put, drawn as a cloud
## of its own points (kit_showcase cloud()) with W as one of the three drawn axes, isometric:
## along the goat's length to the right, up the page for its height, and W receding into the
## corner. The SLICE MOVES (Ramon, 4 Oct: "you always see the base goat, and when YOU slice ...
## when you right drag, you see the slice rotating around the goat, showing where it cuts and
## where it doesn't"): it is drawn as the plane where the room's slice meets the goat, taken from
## where the goat actually is in the world (kit_showcase slice_plane()), so the wheel slides it and
## a right drag tilts it round the goat. The points it cuts, the part of the goat the room is
## showing you, glow; the rest is dim; where it misses the goat altogether, nothing glows.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")

var showcase: Node
var _cloud: PackedVector4Array = PackedVector4Array()
var _box: Array = []          # [lo, hi] of the cloud, Vector4s
var _plane: Array = []        # [n, d], the slice in the goat's space, eased
var _tick: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size
	if size != want or position != Vector2.ZERO:
		position = Vector2.ZERO
		size = want
	if showcase == null:
		return
	if _cloud.is_empty() and showcase.has_method("cloud"):
		_cloud = showcase.call("cloud")
		if not _cloud.is_empty():
			var lo := Vector4(INF, INF, INF, INF)
			var hi := Vector4(-INF, -INF, -INF, -INF)
			for p in _cloud:
				lo = Vector4(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z), minf(lo.w, p.w))
				hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
			_box = [lo, hi]
	if _box.is_empty():
		return
	var pl: Array = showcase.call("slice_plane") if showcase.has_method("slice_plane") else []
	if pl.size() == 2:
		if _plane.is_empty():
			_plane = pl.duplicate()
		var k: float = 1.0 - exp(-12.0 * delta)
		_plane = [(_plane[0] as Vector4).lerp(pl[0], k), lerpf(float(_plane[1]), float(pl[1]), k)]
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0 / 30.0
		queue_redraw()


func _draw() -> void:
	if _box.is_empty():
		return
	var u: float = size.y / 720.0
	var w: float = 300.0 * u
	var h: float = 230.0 * u
	var r := Rect2(Vector2(size.x - w - 20.0 * u, size.y - h - 84.0 * u), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.05, 0.085, 0.62)
	sb.set_corner_radius_all(int(12 * u))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var blue: Color = Style.pick(Style.CODE_BLUE).lightened(0.35)
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	draw_string(fs, r.position + Vector2(14.0, 22.0) * u, "WHERE THE SLICE CUTS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(1, 1, 1))
	draw_string(fl, r.position + Vector2(14.0, 38.0) * u, "The room shows you this plane through the 4D goat", HORIZONTAL_ALIGNMENT_LEFT, w - 28.0 * u, int(9 * u), Color(0.8, 0.86, 0.95, 0.8))
	var lo: Vector4 = _box[0]
	var hi: Vector4 = _box[1]
	# The goat's long axis (whichever of x and z it is longer along), its height and W.
	var long_z: bool = (hi.z - lo.z) >= (hi.x - lo.x)
	var length: float = (hi.z - lo.z) if long_z else (hi.x - lo.x)
	var height: float = hi.y - lo.y
	var depth: float = maxf(hi.w - lo.w, 0.001)
	# The isometric axes on screen: length to the right and a little down, W up and to the right
	# (receding), height straight up.
	var area := Rect2(r.position + Vector2(18.0, 50.0) * u, r.size - Vector2(36.0, 72.0) * u)
	var ax := Vector2(0.86, 0.36)
	var aw := Vector2(0.62, -0.42)
	var ay := Vector2(0.0, -1.0)
	# Fit the projected box of the cloud into the area.
	var bmin := Vector2(INF, INF)
	var bmax := Vector2(-INF, -INF)
	for cl in [0.0, length]:
		for cy in [0.0, height]:
			for cw in [0.0, depth]:
				var q0: Vector2 = ax * cl + ay * cy + aw * cw
				bmin = Vector2(minf(bmin.x, q0.x), minf(bmin.y, q0.y))
				bmax = Vector2(maxf(bmax.x, q0.x), maxf(bmax.y, q0.y))
	var bsize: Vector2 = (bmax - bmin).max(Vector2(0.001, 0.001))
	var k: float = minf(area.size.x / bsize.x, area.size.y / bsize.y)
	var origin: Vector2 = area.get_center() - (bmin + bmax) * 0.5 * k
	var proj := func(p: Vector4) -> Vector2:
		var l: float = ((p.z - lo.z) if long_z else (p.x - lo.x))
		return origin + (ax * l + ay * (p.y - lo.y) + aw * (p.w - lo.w)) * k
	if _plane.size() != 2:
		return
	var n: Vector4 = _plane[0]
	var d: float = float(_plane[1])
	var reach_world: float = float(showcase.get("_extent")) if showcase != null else 1.0
	var band: float = maxf(reach_world, 0.2) * 0.07
	var ptsz: float = maxf(1.2, 1.6 * u)
	# The dim cloud, then the plane, then the points it cuts.
	var lit := PackedVector2Array()
	for p in _cloud:
		var q: Vector2 = proj.call(p)
		if absf(n.dot(p) + d) < band:
			lit.append(q)
		else:
			draw_rect(Rect2(q - Vector2(ptsz, ptsz) * 0.5, Vector2(ptsz, ptsz)), Color(blue, 0.42))
	# The slice as a square with its pivot in the middle of the goat (Ramon, 4 Oct: "the slice is a
	# square and has its pivot in the middle"): it is as long and tall as the goat, centred where
	# the slice passes the goat's middle, lying in the slice. Turning through W never touches
	# height, so one side of the square stays upright; the other runs along the goat's length
	# where the slice lets it, tilting into W as you turn.
	var mid_across: float = ((lo.x + hi.x) if long_z else (lo.z + hi.z)) * 0.5
	var centre := Vector4((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, (lo.z + hi.z) * 0.5, (lo.w + hi.w) * 0.5)
	if long_z:
		centre.x = mid_across
	else:
		centre.z = mid_across
	# The drawn space is (length, height, W): the slice's normal there, without the width part.
	var n3 := Vector4(n.x if not long_z else 0.0, 0.0, n.z if long_z else 0.0, n.w)
	var nn: float = n3.length_squared()
	if nn > 0.000001:
		var c2: Vector4 = centre - n3 * ((n.dot(centre) + d) / nn)
		var along_axis := Vector4(0.0 if long_z else 1.0, 0.0, 1.0 if long_z else 0.0, 0.0)
		var e1: Vector4 = along_axis - n3 * (along_axis.dot(n3) / nn)
		if e1.length() < 0.0001:
			e1 = Vector4(0, 0, 0, 1)
		e1 = e1.normalized()
		var half_l: float = length * 0.56
		var half_h: float = height * 0.54
		var e2 := Vector4(0, 1, 0, 0)
		var sq := PackedVector2Array()
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			sq.append(proj.call(c2 + e1 * (c.x * half_l) + e2 * (c.y * half_h)))
		draw_colored_polygon(sq, Color(1.0, 0.85, 0.35, 0.16))
		sq.append(sq[0])
		draw_polyline(sq, Color(1.0, 0.85, 0.35, 0.8), maxf(1.0, 1.5 * u), true)
		var pv: Vector2 = proj.call(c2)
		draw_circle(pv, maxf(2.0, 2.5 * u), Color(1.0, 0.85, 0.35, 0.95))
	for q in lit:
		var s2: float = ptsz * 1.6
		draw_rect(Rect2(q - Vector2(s2, s2) * 0.5, Vector2(s2, s2)), Color(1.0, 0.92, 0.55))
	if lit.is_empty():
		draw_string(fl, Vector2(r.position.x + 14.0 * u, r.end.y - 28.0 * u), "The slice misses the goat here", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Color(1.0, 0.75, 0.6))
	# The W axis, labelled.
	var w0: Vector2 = proj.call(Vector4(lo.x, lo.y, lo.z, lo.w)) + Vector2(-8.0, 10.0) * u
	var w1: Vector2 = w0 + aw * depth * k
	draw_line(w0, w1, Color(1, 1, 1, 0.6), maxf(1.0, u), true)
	draw_string(fs, w1 + Vector2(4.0, 4.0) * u, "W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(1, 1, 1, 0.8))
	var idx: int = int(showcase.get("slice_index")) + 1 if showcase != null else 0
	var tn: Vector2 = showcase.get("turn") if showcase != null else Vector2.ZERO
	draw_string(fl, Vector2(r.position.x + 14.0 * u, r.end.y - 12.0 * u), "Slice %d of 9   turned %.0f°, %.0f° through W" % [idx, rad_to_deg(tn.x), rad_to_deg(tn.y)],
		HORIZONTAL_ALIGNMENT_LEFT, w - 28.0 * u, int(10 * u), Color(1.0, 0.92, 0.55))
