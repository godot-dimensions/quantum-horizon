extends Control

## Kit: the research data panel, a fixed 2D panel on screen that fades in while you stand at a
## data desk (kit_desk_4d.gd) and away when you leave (Ramon, 4 Oct: "data panel when you enter,
## should be dynamic, it can be a fixed 2d plane we can adjust as we wish to show metrics").
##
## WHAT IT SHOWS, refreshed four times a second:
##   the exhibit's measured facts      showcase.data()["rows"]  (balls, tetrahedra, stages, ...)
##   live values                       showcase.live()           (the slice, its W offset, ...)
##   the frame time, as a graph        the engine's own process time, the last ten seconds
##   a chart                           showcase.data()["bars"]   (tetrahedra per build stage)
## The layout is all in _draw() below, in window-height units (`u`), so it never scales with
## distance and is easy to rearrange: add a row to the exhibit's data() or live() and it appears.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const RD := preload("res://ramon/LabChambers/scripts/rd_build.gd")

var showcase: Node
var mood: String = "dark"
var shown: bool = false
var _a: float = 0.0
var _data: Dictionary = {}
var _live: Array = []
var _frames: PackedFloat32Array = PackedFloat32Array()
var _tick: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size
	if size != want or position != Vector2.ZERO:
		position = Vector2.ZERO
		size = want
	_a = move_toward(_a, 1.0 if shown else 0.0, delta / 0.3)
	_frames.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	if _frames.size() > 600:
		_frames = _frames.slice(_frames.size() - 600)
	_tick -= delta
	if _tick <= 0.0 and showcase != null and _a > 0.0:
		_tick = 0.25
		if _data.is_empty() and showcase.has_method("data"):
			_data = showcase.call("data")
		if showcase.has_method("live"):
			_live = showcase.call("live")
	queue_redraw()


func _draw() -> void:
	if _a <= 0.001:
		return
	var u: float = size.y / 720.0
	var a: float = _a
	var ink: Dictionary = RD.INK["dark"]
	var accent: Color = ink["accent"]
	var w: float = 420.0 * u
	var h: float = 470.0 * u
	var r := Rect2(Vector2(24.0 * u + (1.0 - a) * -40.0 * u, size.y * 0.5 - h * 0.55), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.10, 0.88 * a)
	sb.set_corner_radius_all(int(12 * u))
	sb.border_color = Color(accent, 0.8 * a)
	sb.border_width_left = int(maxf(2.0, 3.0 * u))
	draw_style_box(sb, r)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var x: float = r.position.x + 22.0 * u
	var cw: float = w - 44.0 * u
	var y: float = r.position.y + 36.0 * u
	draw_string(fb, Vector2(x, y), String(_data.get("title", "RESEARCH DATA")), HORIZONTAL_ALIGNMENT_LEFT, cw, int(17 * u), Color(1, 1, 1, a))
	y += 10.0 * u
	draw_line(Vector2(x, y), Vector2(x + cw, y), Color(accent, 0.6 * a), maxf(1.0, u))
	y += 24.0 * u
	# Measured facts.
	for row in _data.get("rows", []):
		draw_string(fl, Vector2(x, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, cw, int(13 * u), Color(1, 1, 1, 0.72 * a))
		draw_string(fs, Vector2(x, y), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, cw, int(14 * u), Color(1, 1, 1, a))
		y += 21.0 * u
	# Live values.
	y += 8.0 * u
	draw_string(fs, Vector2(x, y), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, cw, int(11 * u), Color(accent, a))
	y += 20.0 * u
	for row in _live:
		draw_string(fl, Vector2(x, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, cw, int(13 * u), Color(1, 1, 1, 0.72 * a))
		draw_string(fs, Vector2(x, y), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, cw, int(14 * u), Color(accent.lightened(0.3), a))
		y += 21.0 * u
	# The frame time, the last few seconds.
	y += 10.0 * u
	var gh: float = 54.0 * u
	var gr := Rect2(Vector2(x, y), Vector2(cw, gh))
	draw_rect(gr, Color(1, 1, 1, 0.05 * a))
	if _frames.size() > 2:
		var most: float = 16.7
		for f in _frames:
			most = maxf(most, f)
		var pts := PackedVector2Array()
		for i in _frames.size():
			pts.append(Vector2(gr.position.x + gr.size.x * float(i) / float(_frames.size() - 1), gr.end.y - gr.size.y * clampf(_frames[i] / most, 0.0, 1.0)))
		draw_polyline(pts, Color(accent, a), maxf(1.0, 1.5 * u), true)
		var last: float = _frames[_frames.size() - 1]
		draw_string(fs, Vector2(x, y - 6.0 * u), "Script time per frame  %.2f ms" % last, HORIZONTAL_ALIGNMENT_LEFT, cw, int(11 * u), Color(1, 1, 1, 0.8 * a))
	y += gh + 18.0 * u
	# The chart.
	var bars: Array = _data.get("bars", [])
	if not bars.is_empty() and y + 70.0 * u < r.end.y:
		var bh: float = r.end.y - y - 34.0 * u
		var most2: float = 1.0
		for b in bars:
			most2 = maxf(most2, float(b))
		var bw: float = cw / float(bars.size())
		for i in bars.size():
			var hh: float = bh * float(bars[i]) / most2
			draw_rect(Rect2(Vector2(x + bw * float(i) + bw * 0.15, y + bh - hh), Vector2(bw * 0.7, hh)), Color(accent, (0.35 + 0.65 * float(i + 1) / float(bars.size())) * a))
		draw_string(fl, Vector2(x, y + bh + 18.0 * u), String(_data.get("bar_label", "")), HORIZONTAL_ALIGNMENT_LEFT, cw, int(11 * u), Color(1, 1, 1, 0.7 * a))
