extends Control

## Kit: the slice view, a small HUD in the bottom right corner that shows what slicing means
## (Ramon, 4 Oct: "a slice UI gizmo as overlay HUD in the bottom right corner, perhaps something
## that allows you to see an actual model of the goat, and a slice over it, so you actually see
## what's happening ... the goat could be isometric and in an angle that makes sense").
##
## THE IDEA: the room shows you one 3D slice of a 4D goat. Here the goat is drawn as a cloud of its
## own points (kit_showcase cloud()), but with W as one of the three drawn axes, isometric: along
## the goat's length to the right, up the page for its height, and W receding into the corner. The
## slice you are looking at is a translucent plane standing at its W; the points the plane cuts,
## the part of the goat the room is showing you, glow; the rest is dim. Wheel the slice and the
## plane slides through the goat. Drawn back to front: the far half of the cloud, the plane, the
## near half.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")

var showcase: Node
var _cloud: PackedVector4Array = PackedVector4Array()
var _box: Array = []          # [lo, hi] of the cloud, Vector4s
var _plane_w: float = 0.0
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
	# Where the slice cuts, in the goat's own W (the showcase gives -1..1 of its reach).
	var frac: float = float(showcase.call("slice_fraction")) if showcase.has_method("slice_fraction") else 0.0
	var reach: float = maxf(absf((_box[0] as Vector4).w), absf((_box[1] as Vector4).w))
	var want_w: float = frac * reach
	_plane_w = lerpf(_plane_w, want_w, 1.0 - exp(-10.0 * delta))
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
	var band: float = depth * 0.06
	var ptsz: float = maxf(1.2, 1.6 * u)
	# The far half, the plane, the near half.
	for pass_i in 2:
		for p in _cloud:
			var behind: bool = p.w > _plane_w
			if (pass_i == 0) != behind:
				continue
			var on: bool = absf(p.w - _plane_w) < band
			var col: Color = Color(1.0, 0.92, 0.55) if on else Color(blue, 0.42)
			var s: float = ptsz * (1.6 if on else 1.0)
			var q: Vector2 = proj.call(p)
			draw_rect(Rect2(q - Vector2(s, s) * 0.5, Vector2(s, s)), col)
		if pass_i == 0:
			var corners := PackedVector2Array()
			for c in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]:
				var pl := Vector4(lo.x, lo.y, lo.z, _plane_w)
				if long_z:
					pl.z = lo.z - length * 0.06 + length * 1.12 * c.x
				else:
					pl.x = lo.x - length * 0.06 + length * 1.12 * c.x
				pl.y = lo.y - height * 0.04 + height * 1.08 * c.y
				corners.append(proj.call(pl))
			draw_colored_polygon(corners, Color(1.0, 0.85, 0.35, 0.16))
			corners.append(corners[0])
			draw_polyline(corners, Color(1.0, 0.85, 0.35, 0.8), maxf(1.0, 1.5 * u), true)
	# The W axis, labelled.
	var w0: Vector2 = proj.call(Vector4(lo.x, lo.y, lo.z, lo.w)) + Vector2(-8.0, 10.0) * u
	var w1: Vector2 = w0 + aw * depth * k
	draw_line(w0, w1, Color(1, 1, 1, 0.6), maxf(1.0, u), true)
	draw_string(fs, w1 + Vector2(4.0, 4.0) * u, "W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(1, 1, 1, 0.8))
	var idx: int = int(showcase.get("slice_index")) + 1 if showcase != null else 0
	draw_string(fl, Vector2(r.position.x + 14.0 * u, r.end.y - 12.0 * u), "Slice %d of 9" % idx, HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), Color(1.0, 0.92, 0.55))
