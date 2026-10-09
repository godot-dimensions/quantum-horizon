extends Control

## Kit: the slice view, a small HUD in the bottom right corner that shows what slicing means
## (Ramon, 4 Oct: "a slice UI gizmo as overlay HUD ... see an actual model of the goat, and a slice
## over it, so you actually see what's happening"; then "you always see the base goat ... when you
## right drag, you see the slice rotating around the goat, showing where it cuts and where it
## doesn't"; "why not a wireframe? turn it slightly more ... why doesn't the slicing work up and
## down also?").
##
## THE GOAT stays put, drawn as a wireframe of its own mesh (kit_showcase wire(): its longer
## tetrahedron edges, thinned), seen in gentle perspective from in front of its head, a little to
## the W side and above (Ramon: "face with its head to us ... add some subtle perspective"), in a
## space whose three axes are its length, its height and W (W drawn a little larger than life, so
## its 4D depth reads; there is no true scale between W and the other three anyway).
## THE SLICE MOVES: it is the plane where the room's slice meets the goat, read from where the goat
## actually is in the world (kit_showcase slice_plane()), so it follows whoever moves it: the wheel
## slides it, a right drag across swings it along the goat's length, a right drag up and down
## tilts it through the goat's height. It is drawn as a square as long and tall as the goat, its
## pivot in the goat's middle (Ramon's picture of it), lying in the slice. The edges it cuts
## through glow: that is the cross-section the room shows you. When it misses the goat, it says so.
##
## The one turn it cannot draw is the goat's width tipping into W, since width is the one axis left
## out of the picture; the drag no longer does that turn.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/Arboretum/botany_lab/carried/LabKit/lab_print.gd")
const Style := preload("res://ramon/Arboretum/botany_lab/carried/kit/kit_style.gd")
## The view: where the eye sits, as a direction from the goat's middle in (length, height, W)
## (length towards the head), how far off as a multiple of the goat's size (far: gentle
## perspective), and how much larger W is drawn.
const EYE := Vector3(0.62, 0.38, 0.68)
const EYE_DISTANCE := 3.2
const W_BOOST := 1.5

var showcase: Node
var _edges: PackedVector4Array = PackedVector4Array()
var _box: Array = []          # [lo, hi] of the goat, Vector4s
var _plane: Array = []        # [n, d], the slice in the goat's space, eased
var _tick: float = 0.0
var _serial: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size
	if size != want or position != Vector2.ZERO:
		position = Vector2.ZERO
		size = want
	if showcase == null:
		return
	if int(showcase.get("serial")) != _serial:
		_serial = int(showcase.get("serial"))
		_edges = PackedVector4Array()
		_box = []
		_plane = []
	if _edges.is_empty() and showcase.has_method("wire"):
		_edges = showcase.call("wire")
		if not _edges.is_empty():
			var lo := Vector4(INF, INF, INF, INF)
			var hi := Vector4(-INF, -INF, -INF, -INF)
			for p in _edges:
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
	if _box.is_empty() or _plane.size() != 2:
		return
	var u: float = size.y / 720.0
	var w: float = 320.0 * u
	var h: float = 250.0 * u
	var r := Rect2(Vector2(size.x - w - 20.0 * u, size.y - h - 84.0 * u), Vector2(w, h))
	draw_style_box(Style.glass_box(12 * u), r)
	var blue: Color = Style.UI_ACCENT
	var hot: Color = Style.UI_GOLD
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	draw_string(fs, r.position + Vector2(14.0, 22.0) * u, "WHERE THE SLICE CUTS", HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("caption", u), Color(1, 1, 1))
	draw_string(fl, r.position + Vector2(14.0, 38.0) * u, "The room shows you this plane through the 4D %s" % _name(), HORIZONTAL_ALIGNMENT_LEFT, w - 28.0 * u, Style.type_px("micro", u), Style.UI_INK_SOFT)
	var lo: Vector4 = _box[0]
	var hi: Vector4 = _box[1]
	var long_z: bool = (hi.z - lo.z) >= (hi.x - lo.x)
	var length: float = (hi.z - lo.z) if long_z else (hi.x - lo.x)
	var height: float = hi.y - lo.y
	var depth: float = maxf(hi.w - lo.w, 0.001)
	# The eye: in (length, height, W) space, W scaled up; length runs towards the head (the goat's
	# head is at its +length end), and the eye looks at the goat's middle from in front of it.
	var to3 := func(p: Vector4) -> Vector3:
		var l: float = ((p.z - lo.z) if long_z else (p.x - lo.x))
		return Vector3(l, p.y - lo.y, (p.w - lo.w) * W_BOOST)
	var mid3 := Vector3(length * 0.5, height * 0.5, depth * W_BOOST * 0.5)
	var size3: float = Vector3(length, height, depth * W_BOOST).length()
	var eye: Vector3 = mid3 + EYE.normalized() * size3 * EYE_DISTANCE
	var fwd: Vector3 = (mid3 - eye).normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var upv: Vector3 = right.cross(fwd)
	var view := func(p3: Vector3) -> Vector2:
		var v: Vector3 = p3 - eye
		var zc: float = maxf(v.dot(fwd), 0.001)
		return Vector2(v.dot(right) / zc, -v.dot(upv) / zc)
	var area := Rect2(r.position + Vector2(16.0, 48.0) * u, r.size - Vector2(32.0, 76.0) * u)
	var bmin := Vector2(INF, INF)
	var bmax := Vector2(-INF, -INF)
	for cl in [0.0, length]:
		for cy in [0.0, height]:
			for cw in [0.0, depth * W_BOOST]:
				var q0: Vector2 = view.call(Vector3(cl, cy, cw))
				bmin = Vector2(minf(bmin.x, q0.x), minf(bmin.y, q0.y))
				bmax = Vector2(maxf(bmax.x, q0.x), maxf(bmax.y, q0.y))
	var bsize: Vector2 = (bmax - bmin).max(Vector2(0.0001, 0.0001))
	var k: float = minf(area.size.x / bsize.x, area.size.y / bsize.y)
	var origin: Vector2 = area.get_center() - (bmin + bmax) * 0.5 * k
	var proj := func(p: Vector4) -> Vector2:
		return origin + (view.call(to3.call(p)) as Vector2) * k
	var n: Vector4 = _plane[0]
	var d: float = float(_plane[1])
	# The wireframe: the edges the slice passes through glow.
	var dim := PackedVector2Array()
	var cut := PackedVector2Array()
	var hits := PackedVector2Array()
	for i in range(0, _edges.size() - 1, 2):
		var a: Vector4 = _edges[i]
		var b: Vector4 = _edges[i + 1]
		var fa: float = n.dot(a) + d
		var fb: float = n.dot(b) + d
		if (fa > 0.0) != (fb > 0.0):
			cut.append(proj.call(a))
			cut.append(proj.call(b))
			hits.append(proj.call(a.lerp(b, fa / (fa - fb))))
		else:
			dim.append(proj.call(a))
			dim.append(proj.call(b))
	if not dim.is_empty():
		draw_multiline(dim, Color(blue, 0.38), maxf(1.0, u))
	# The slice: a square as long and tall as the goat, its pivot in the goat's middle, lying in
	# the slice; its sides along the goat's length and height as far as the slice lets them.
	var centre := Vector4((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, (lo.z + hi.z) * 0.5, (lo.w + hi.w) * 0.5)
	var n3 := Vector4(0.0 if long_z else n.x, n.y, n.z if long_z else 0.0, n.w)
	var nn: float = n3.length_squared()
	if nn > 0.000001:
		var c2: Vector4 = centre - n3 * ((n.dot(centre) + d) / nn)
		var along_axis := Vector4(0.0 if long_z else 1.0, 0.0, 1.0 if long_z else 0.0, 0.0)
		var e1: Vector4 = along_axis - n3 * (along_axis.dot(n3) / nn)
		if e1.length() < 0.0001:
			e1 = Vector4(0, 0, 0, 1) - n3 * (n3.w / nn)
		e1 = e1.normalized()
		var up := Vector4(0, 1, 0, 0)
		var e2: Vector4 = up - n3 * (up.dot(n3) / nn)
		e2 = e2 - e1 * e2.dot(e1)
		if e2.length() < 0.0001:
			e2 = Vector4(0, 0, 0, 1)
		e2 = e2.normalized()
		var sq := PackedVector2Array()
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			sq.append(proj.call(c2 + e1 * (c.x * length * 0.56) + e2 * (c.y * height * 0.54)))
		draw_colored_polygon(sq, Color(hot, 0.14))
		sq.append(sq[0])
		draw_polyline(sq, Color(hot, 0.85), maxf(1.0, 1.5 * u), true)
		draw_circle(proj.call(c2), maxf(2.0, 2.5 * u), Color(hot, 0.95))
	if not cut.is_empty():
		draw_multiline(cut, Color(hot, 0.4), maxf(1.0, u))
		for q in hits:
			draw_circle(q, maxf(1.5, 1.8 * u), hot)
	else:
		draw_string(fl, Vector2(r.position.x + 14.0 * u, r.end.y - 28.0 * u), "The slice misses the %s here" % _name(), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("micro", u), Style.UI_WARM)
	# The W axis, labelled.
	var w0: Vector2 = proj.call(Vector4(lo.x, lo.y, lo.z, lo.w))
	var w1: Vector2 = proj.call(Vector4(lo.x, lo.y, lo.z, hi.w))
	draw_line(w0, w1, Color(1, 1, 1, 0.6), maxf(1.0, u), true)
	draw_string(fs, w1 + Vector2(-14.0, -2.0) * u, "W", HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("caption", u), Color(1, 1, 1, 0.8))
	var idx: int = int(showcase.get("slice_index")) + 1 if showcase != null else 0
	var tn: Vector2 = showcase.get("turn") if showcase != null else Vector2.ZERO
	draw_string(fl, Vector2(r.position.x + 14.0 * u, r.end.y - 12.0 * u), "Slice %d of 9   swung %.0f°, tilted %.0f°" % [idx, rad_to_deg(tn.x), rad_to_deg(tn.y)],
		HORIZONTAL_ALIGNMENT_LEFT, w - 28.0 * u, Style.type_px("micro", u), hot)


## The exhibit's name in lower case, for the lines under the drawing.
func _name() -> String:
	var d: Dictionary = showcase.call("data") if showcase != null and showcase.has_method("data") else {}
	return String(d.get("name", "animal")).to_lower()
