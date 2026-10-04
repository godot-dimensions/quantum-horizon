extends Control

## Kit: the research data panel, a fixed 2D panel on screen that slides in while you stand at a
## research console (kit_desk_4d.gd) and away when you leave (Ramon, 4 Oct: "data panel when you
## enter, should be dynamic, it can be a fixed 2d plane we can adjust as we wish to show
## metrics"; then "a bunch of metrics and diagrams ... relevant info for stakeholders, and add
## some icons").
##
## WHAT IT SHOWS, refreshed four times a second (the graphs every frame):
##   four tiles                 balls, tetrahedra, build stages, reach through W   showcase.data()
##   WHERE IT EXISTS THROUGH W  the W profile, its slice stops, the live slice      showcase.profile()
##   BUILD, STAGE BY STAGE      tetrahedra per stage, and the meshes' memory       showcase.data()
##   RIGHT NOW                  the slice, its offset, the turn, what is shown     showcase.live()
##   FRAME COST                 the engine's process time against a 60 fps budget
##   WHERE THE TOOL STANDS      what the tool can do yet, and authoring time per creature: SAMPLES,
##                              tagged as such, until someone measures them (ROADMAP below)
## Everything is laid out in _draw() in window-height units (`u`), so it never scales with
## distance and is easy to rearrange.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const RD := preload("res://ramon/LabChambers/scripts/rd_build.gd")
const Glyphs := preload("res://ramon/LabChambers/kit/kit_glyphs.gd")

## Placeholders for the stakeholder card, until measured: [icon, what the tool can do].
const ROADMAP := [
	["check", "Build a creature by hand"],
	["check", "Slice it through W"],
	["check", "Turn it through W"],
	["half", "Animate it: walk cycles"],
	["todo", "Collide with its true shape"],
]
## Placeholders: days to author each creature.
const AUTHORING := [["Goat", 1.0], ["Wolf", 2.0], ["Horse", 3.0], ["Chicken", 0.5]]
const BUDGET_MS := 16.7

var showcase: Node
var mood: String = "dark"
var shown: bool = false
var _a: float = 0.0
var _data: Dictionary = {}
var _live: Array = []
var _profile: Dictionary = {}
var _stops: Array = []
var _frames: PackedFloat32Array = PackedFloat32Array()
var _tick: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size
	if size != want or position != Vector2.ZERO:
		position = Vector2.ZERO
		size = want
	var was: float = _a
	_a = move_toward(_a, 1.0 if shown else 0.0, delta / 0.3)
	_clock += delta
	_frames.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	if _frames.size() > 300:
		_frames = _frames.slice(_frames.size() - 300)
	_tick -= delta
	if _tick <= 0.0 and showcase != null and _a > 0.0:
		_tick = 0.25
		if _data.is_empty() and showcase.has_method("data"):
			_data = showcase.call("data")
		if _profile.is_empty() and showcase.has_method("profile"):
			_profile = showcase.call("profile")
			_stops = showcase.call("slice_stops")
		if showcase.has_method("live"):
			_live = showcase.call("live")
	# Once more as it reaches nothing, or the last faint frame stays on screen.
	if _a > 0.0 or was > 0.0:
		queue_redraw()


func _draw() -> void:
	if _a <= 0.001:
		return
	var u: float = size.y / 720.0
	var a: float = _a
	var accent: Color = (RD.INK["dark"] as Dictionary)["accent"]
	var white := Color(1, 1, 1, a)
	var soft := Color(0.84, 0.89, 0.96, 0.85 * a)
	var dim := Color(0.70, 0.76, 0.86, 0.7 * a)
	var sample := Color(1.0, 0.86, 0.45, a)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var w: float = 620.0 * u
	var h: float = 600.0 * u
	var r := Rect2(Vector2(24.0 * u + (1.0 - a) * -60.0 * u, (size.y - h) * 0.5), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.05, 0.085, 0.9 * a)
	sb.set_corner_radius_all(int(14 * u))
	sb.border_color = Color(accent, 0.85 * a)
	sb.border_width_left = int(maxf(2.0, 3.0 * u))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
	var x: float = r.position.x + 22.0 * u
	var cw: float = w - 44.0 * u
	var top: float = r.position.y
	var st: Dictionary = _data.get("stats", {})
	# The header.
	Glyphs.tag(self, Vector2(x, top + 30.0 * u), "GOAT 01", int(10 * u), white, true)
	var pulse: float = 0.6 + 0.4 * sin(_clock * 4.0)
	Glyphs.icon(self, "live", Rect2(Vector2(x + cw - 62.0 * u, top + 21.0 * u), Vector2(18.0 * u, 18.0 * u)), Color(0.5, 1.0, 0.68, a * pulse))
	draw_string(fs, Vector2(x + cw - 40.0 * u, top + 35.0 * u), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), soft)
	draw_string(fb, Vector2(x, top + 64.0 * u), "Research data", HORIZONTAL_ALIGNMENT_LEFT, cw, int(22 * u), white)
	draw_string(fl, Vector2(x, top + 83.0 * u), "Measured live from the exhibit. Numbers tagged SAMPLE are placeholders until measured.", HORIZONTAL_ALIGNMENT_LEFT, cw, int(11 * u), dim)
	# Four tiles.
	var ty: float = top + 98.0 * u
	var tiles: Array = [
		["ball", str(int(st.get("balls", 0))), "Balls, placed by hand"],
		["tetra", Glyphs.short(int(st.get("tetra", 0))), "Tetrahedra in its skin"],
		["stages", str(int(st.get("stages", 0))), "Build stages, baked"],
		["axes", "%.2f m" % float(st.get("reach", 0.0)), "Reach through W"],
	]
	var gap: float = 10.0 * u
	var tw: float = (cw - gap * 3.0) / 4.0
	for i in tiles.size():
		var tr := Rect2(Vector2(x + (tw + gap) * float(i), ty), Vector2(tw, 70.0 * u))
		_card(tr, u, a)
		var t: Array = tiles[i]
		Glyphs.icon(self, String(t[0]), Rect2(tr.position + Vector2(10.0, 10.0) * u, Vector2(24.0, 24.0) * u), Color(accent.lightened(0.25), a))
		draw_string(fb, tr.position + Vector2(42.0, 32.0) * u, String(t[1]), HORIZONTAL_ALIGNMENT_LEFT, tw - 48.0 * u, int(21 * u), white)
		draw_string(fl, tr.position + Vector2(10.0, 58.0) * u, String(t[2]), HORIZONTAL_ALIGNMENT_LEFT, tw - 16.0 * u, int(10.5 * u), soft)
	# Two cards: the W profile, the build.
	var col: float = (cw - 14.0 * u) * 0.5
	var y2: float = ty + 82.0 * u
	var left := Rect2(Vector2(x, y2), Vector2(col, 128.0 * u))
	var right := Rect2(Vector2(x + col + 14.0 * u, y2), Vector2(col, 128.0 * u))
	_card(left, u, a)
	_card(right, u, a)
	_section(left, u, a, "slice", "WHERE IT EXISTS THROUGH W", accent)
	var bins: PackedFloat32Array = _profile.get("bins", PackedFloat32Array())
	var lit: int = int(showcase.get("slice_index")) if showcase != null else -1
	var frac: float = float(showcase.call("slice_fraction")) if showcase != null and showcase.has_method("slice_fraction") else NAN
	Glyphs.profile(self, Rect2(left.position + Vector2(12.0, 34.0) * u, Vector2(left.size.x - 24.0 * u, 66.0 * u)), bins,
		Color(accent, 0.22 * a), Color(accent.lightened(0.35), a), _stops, lit, frac, Color(1, 1, 1, a))
	draw_string(fl, left.position + Vector2(12.0, 118.0) * u, "-W", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), dim)
	draw_string(fl, left.position + Vector2(12.0, 118.0) * u, "+W", HORIZONTAL_ALIGNMENT_RIGHT, left.size.x - 24.0 * u, int(10 * u), dim)
	draw_string(fs, left.position + Vector2(12.0, 118.0) * u, "the line is the slice you see", HORIZONTAL_ALIGNMENT_CENTER, left.size.x - 24.0 * u, int(10 * u), soft)
	_section(right, u, a, "stages", "BUILD, STAGE BY STAGE", accent)
	var bars: Array = _data.get("bars", [])
	var labels: Array = []
	for i in bars.size():
		labels.append(str(i + 1))
	Glyphs.bars(self, Rect2(right.position + Vector2(12.0, 34.0) * u, Vector2(right.size.x - 24.0 * u, 70.0 * u)), bars, Color(accent.lightened(0.2), a), labels, int(9 * u), dim)
	Glyphs.icon(self, "chip", Rect2(right.position + Vector2(10.0, 106.0) * u, Vector2(16.0, 16.0) * u), soft)
	draw_string(fl, right.position + Vector2(32.0, 118.0) * u, "Tetrahedra per stage.  Meshes hold %.1f MB" % float(st.get("mb", 0.0)), HORIZONTAL_ALIGNMENT_LEFT, right.size.x - 40.0 * u, int(10 * u), soft)
	# Two cards: right now, the frame cost.
	var y3: float = y2 + 140.0 * u
	var left2 := Rect2(Vector2(x, y3), Vector2(col, 132.0 * u))
	var right2 := Rect2(Vector2(x + col + 14.0 * u, y3), Vector2(col, 132.0 * u))
	_card(left2, u, a)
	_card(right2, u, a)
	_section(left2, u, a, "live", "RIGHT NOW", accent)
	var ry: float = left2.position.y + 46.0 * u
	for row in _live.slice(0, 5):
		draw_string(fl, Vector2(left2.position.x + 12.0 * u, ry), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, left2.size.x - 24.0 * u, int(10.5 * u), soft)
		draw_string(fs, Vector2(left2.position.x + 12.0 * u, ry), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, left2.size.x - 24.0 * u, int(11 * u), Color(accent.lightened(0.4), a))
		ry += 17.5 * u
	_section(right2, u, a, "graph", "FRAME COST", accent)
	_frame_graph(Rect2(right2.position + Vector2(12.0, 34.0) * u, Vector2(right2.size.x - 24.0 * u, 54.0 * u)), u, a, accent, dim)
	var last: float = _frames[_frames.size() - 1] if _frames.size() > 0 else 0.0
	var bar := Rect2(right2.position + Vector2(12.0, 100.0) * u, Vector2(right2.size.x - 24.0 * u, 7.0 * u))
	draw_rect(bar, Color(1, 1, 1, 0.08 * a))
	var share: float = clampf(last / BUDGET_MS, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), Color(accent.lightened(0.2), a) if share < 0.8 else Color(1.0, 0.55, 0.35, a))
	draw_string(fl, right2.position + Vector2(12.0, 124.0) * u, "%.2f ms of a %.1f ms frame (60 fps)" % [last, BUDGET_MS], HORIZONTAL_ALIGNMENT_LEFT, right2.size.x - 24.0 * u, int(10 * u), soft)
	# The stakeholder card.
	var y4: float = y3 + 144.0 * u
	var road := Rect2(Vector2(x, y4), Vector2(cw, r.end.y - y4 - 16.0 * u))
	_card(road, u, a)
	var hw: float = _section(road, u, a, "check", "WHERE THE TOOL STANDS", accent)
	Glyphs.tag(self, Vector2(road.position.x + 40.0 * u + hw + 10.0 * u, road.position.y + 21.0 * u), "SAMPLE", int(8.5 * u), sample)
	var ly: float = road.position.y + 40.0 * u
	for item in ROADMAP:
		var it: Array = item
		var done: bool = String(it[0]) == "check"
		Glyphs.icon(self, String(it[0]), Rect2(Vector2(road.position.x + 12.0 * u, ly - 1.0 * u), Vector2(15.0, 15.0) * u),
			Color(0.5, 1.0, 0.68, a) if done else Color(accent.lightened(0.3), a) if String(it[0]) == "half" else dim)
		draw_string(fl, Vector2(road.position.x + 34.0 * u, ly + 11.0 * u), String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, road.size.x * 0.5 - 40.0 * u, int(10.5 * u), white if done else soft)
		ly += 17.0 * u
	var ax: float = road.position.x + road.size.x * 0.52
	draw_string(fs, Vector2(ax, road.position.y + 50.0 * u), "Days to author a creature", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), soft)
	var by: float = road.position.y + 62.0 * u
	var most: float = 0.0
	for e in AUTHORING:
		most = maxf(most, float(e[1]))
	for e in AUTHORING:
		var bw: float = (road.end.x - ax - 96.0 * u) * float(e[1]) / most
		draw_string(fl, Vector2(ax, by + 9.0 * u), String(e[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), dim)
		draw_rect(Rect2(Vector2(ax + 52.0 * u, by), Vector2(bw, 10.0 * u)), Color(sample, 0.75 * a))
		draw_string(fs, Vector2(ax + 58.0 * u + bw, by + 9.0 * u), ("%.1f" % float(e[1])).trim_suffix(".0"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), soft)
		by += 15.0 * u


func _card(rect: Rect2, u: float, a: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.045 * a)
	sb.set_corner_radius_all(int(9 * u))
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


## A card's heading: an icon and a label; returns the label's width.
func _section(rect: Rect2, u: float, a: float, kind: String, text: String, accent: Color) -> float:
	Glyphs.icon(self, kind, Rect2(rect.position + Vector2(10.0, 9.0) * u, Vector2(18.0, 18.0) * u), Color(accent.lightened(0.3), a))
	var f: Font = LabPrint.font("bold")
	draw_string(f, rect.position + Vector2(36.0, 24.0) * u, text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Color(1, 1, 1, a))
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u)).x


func _frame_graph(gr: Rect2, u: float, a: float, accent: Color, dim: Color) -> void:
	draw_rect(gr, Color(1, 1, 1, 0.04 * a))
	var most: float = BUDGET_MS * 1.25
	for f in _frames:
		most = maxf(most, f)
	var budget_y: float = gr.end.y - gr.size.y * BUDGET_MS / most
	for i in 24:
		var x0: float = gr.position.x + gr.size.x * float(i) / 24.0
		draw_line(Vector2(x0, budget_y), Vector2(x0 + gr.size.x / 48.0, budget_y), Color(1.0, 0.86, 0.45, 0.6 * a), maxf(1.0, u))
	draw_string(LabPrint.font("body"), Vector2(gr.position.x + 4.0 * u, budget_y - 3.0 * u), "60 fps", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), dim)
	if _frames.size() > 2:
		var pts := PackedVector2Array()
		for i in _frames.size():
			pts.append(Vector2(gr.position.x + gr.size.x * float(i) / float(_frames.size() - 1), gr.end.y - gr.size.y * clampf(_frames[i] / most, 0.0, 1.0)))
		draw_polyline(pts, Color(accent.lightened(0.3), a), maxf(1.0, 1.5 * u), true)
