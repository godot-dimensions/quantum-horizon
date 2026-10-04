extends Control

## Kit: the research data panel, a fixed 2D panel on screen that slides in while you stand at a
## research console (kit_desk_4d.gd) and away when you leave (Ramon, 4 Oct: "data panel when you
## enter, should be dynamic, it can be a fixed 2d plane we can adjust as we wish to show
## metrics"; then "a bunch of metrics and diagrams ... relevant info for stakeholders, and add
## some icons").
##
## WHAT IT SHOWS, refreshed four times a second (the graphs every frame). Nothing the research wall
## already shows (Ramon, 4 Oct: "make sure the infos on the panel and overlay are different from
## the blue graphs"): the wall has the animal's measurements, the desk its balls, this the tool.
##   HOW THE TOOL WORKS         the four steps from balls to a walking animal, and when each runs
##   RIGHT NOW                  the slice, its offset, the turn, what is shown     showcase.live()
##   FRAME COST                 the engine's process time against a 60 fps budget
##   WHERE THE TOOL STANDS      what the tool can do yet, and authoring time per creature: SAMPLES,
##                              tagged as such, until someone measures them (ROADMAP below)
## Everything is laid out in _draw() in window-height units (`u`), so it never scales with
## distance and is easy to rearrange.
##
## NO class_name (engine_gotchas.md).

const LabPrint := preload("res://ramon/LabKit/lab_print.gd")
const Style := preload("res://ramon/LabChambers/kit/kit_style.gd")
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
## The tool's four steps: [icon, what, when it runs].
const PIPELINE := [["ball", "Place balls", "By hand, in the editor"], ["tetra", "Loft the skin", "Once, when a ball moves"],
	["slice", "Slice through W", "Every frame, on the GPU"], ["creatures", "Animate", "Rigid pieces, transforms only"]]
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
var _serial: int = -1
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
		if int(showcase.get("serial")) != _serial:
			_serial = int(showcase.get("serial"))
			_data = {}
			_profile = {}
			_stops = []
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
	var sample := Color(Style.UI_GOLD, a)
	var fb: Font = LabPrint.font("black")
	var fs: Font = LabPrint.font("bold")
	var fl: Font = LabPrint.font("body")
	var w: float = 620.0 * u
	var h: float = 600.0 * u
	var r := Rect2(Vector2(24.0 * u + (1.0 - a) * -60.0 * u, (size.y - h) * 0.5), Vector2(w, h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Style.UI_GLASS, 0.6 * a)
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
	Glyphs.tag(self, Vector2(x, top + 30.0 * u), ("%s %s" % [String(_data.get("name", "specimen")).to_upper(), String(_data.get("code", "XX-01")).get_slice("-", 1)]), Style.type_px("caption", u), white, true)
	var pulse: float = 0.6 + 0.4 * sin(_clock * 4.0)
	Glyphs.icon(self, "live", Rect2(Vector2(x + cw - 62.0 * u, top + 21.0 * u), Vector2(18.0 * u, 18.0 * u)), Color(0.5, 1.0, 0.68, a * pulse))
	draw_string(fs, Vector2(x + cw - 40.0 * u, top + 35.0 * u), "LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("caption", u), soft)
	draw_string(fb, Vector2(x, top + 64.0 * u), "About the tool", HORIZONTAL_ALIGNMENT_LEFT, cw, Style.type_px("title", u), white)
	draw_string(fl, Vector2(x, top + 83.0 * u), "How it works, and where it stands. Numbers tagged SAMPLE are placeholders until measured.", HORIZONTAL_ALIGNMENT_LEFT, cw, Style.type_px("caption", u), dim)
	# How the tool works: four steps, an arrow between each, the step the story is on lit.
	var ty: float = top + 98.0 * u
	var pipe := Rect2(Vector2(x, ty), Vector2(cw, 210.0 * u))
	_card(pipe, u, a)
	_section(pipe, u, a, "chip", "HOW THE TOOL WORKS", accent)
	var lit_step: int = -1
	if showcase != null:
		var key: String = ""
		var si: int = int(showcase.get("seq_index"))
		if si >= 0:
			key = String((showcase.call("sequences") as Array)[si]["key"])
		lit_step = {"balls": 0, "skin": 1, "slice": 2, "rig": 3, "walk": 3}.get(key, -1)
	var gap: float = 12.0 * u
	var sw: float = (pipe.size.x - 24.0 * u - gap * 3.0) / 4.0
	for i in PIPELINE.size():
		var st2: Array = PIPELINE[i]
		var sr := Rect2(Vector2(pipe.position.x + 12.0 * u + (sw + gap) * float(i), pipe.position.y + 42.0 * u), Vector2(sw, 152.0 * u))
		var on: bool = i == lit_step
		var bx := StyleBoxFlat.new()
		bx.bg_color = Color(accent, 0.16 * a) if on else Color(1, 1, 1, 0.04 * a)
		bx.border_color = Color(accent, 0.9 * a) if on else Color(1, 1, 1, 0.0)
		bx.set_border_width_all(int(maxf(1.0, 2.0 * u)) if on else 0)
		bx.set_corner_radius_all(Style.type_px("caption", u))
		bx.anti_aliasing = true
		draw_style_box(bx, sr)
		draw_string(fb, sr.position + Vector2(12.0, 30.0) * u, "%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("subhead", u), Color(accent.lightened(0.3), a))
		Glyphs.icon(self, String(st2[0]), Rect2(sr.position + Vector2(sw - 46.0 * u, 12.0 * u), Vector2(34.0, 34.0) * u), Color(accent.lightened(0.25) if on else Color(1, 1, 1, 0.75), a))
		draw_multiline_string(fs, sr.position + Vector2(12.0, 82.0) * u, String(st2[1]), HORIZONTAL_ALIGNMENT_LEFT, sw - 24.0 * u, Style.type_px("body", u), 2, white)
		draw_multiline_string(fl, sr.position + Vector2(12.0, 118.0) * u, String(st2[2]), HORIZONTAL_ALIGNMENT_LEFT, sw - 24.0 * u, Style.type_px("caption", u), 2, soft)
		if i < PIPELINE.size() - 1:
			var ax2: float = sr.end.x + gap * 0.5
			var ay: float = sr.position.y + 26.0 * u
			draw_colored_polygon(PackedVector2Array([Vector2(ax2 - 4.0 * u, ay - 6.0 * u), Vector2(ax2 + 5.0 * u, ay), Vector2(ax2 - 4.0 * u, ay + 6.0 * u)]), Color(1, 1, 1, 0.5 * a))
	var col: float = (cw - 14.0 * u) * 0.5
	var y2: float = ty + 222.0 * u - 140.0 * u
	# Two cards: right now, the frame cost.
	var y3: float = y2 + 140.0 * u
	var left2 := Rect2(Vector2(x, y3), Vector2(col, 132.0 * u))
	var right2 := Rect2(Vector2(x + col + 14.0 * u, y3), Vector2(col, 132.0 * u))
	_card(left2, u, a)
	_card(right2, u, a)
	_section(left2, u, a, "live", "RIGHT NOW", accent)
	var ry: float = left2.position.y + 46.0 * u
	for row in _live.slice(0, 5):
		draw_string(fl, Vector2(left2.position.x + 12.0 * u, ry), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, left2.size.x - 24.0 * u, Style.type_px("caption", u), soft)
		draw_string(fs, Vector2(left2.position.x + 12.0 * u, ry), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, left2.size.x - 24.0 * u, Style.type_px("body", u), Color(accent.lightened(0.4), a))
		ry += 17.5 * u
	_section(right2, u, a, "graph", "FRAME COST", accent)
	_frame_graph(Rect2(right2.position + Vector2(12.0, 34.0) * u, Vector2(right2.size.x - 24.0 * u, 54.0 * u)), u, a, accent, dim)
	var last: float = _frames[_frames.size() - 1] if _frames.size() > 0 else 0.0
	var bar := Rect2(right2.position + Vector2(12.0, 100.0) * u, Vector2(right2.size.x - 24.0 * u, 7.0 * u))
	draw_rect(bar, Color(1, 1, 1, 0.08 * a))
	var share: float = clampf(last / BUDGET_MS, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), Color(accent.lightened(0.2), a) if share < 0.8 else Color(1.0, 0.55, 0.35, a))
	draw_string(fl, right2.position + Vector2(12.0, 124.0) * u, "%.2f ms of a %.1f ms frame (60 fps)" % [last, BUDGET_MS], HORIZONTAL_ALIGNMENT_LEFT, right2.size.x - 24.0 * u, Style.type_px("caption", u), soft)
	# The stakeholder card.
	var y4: float = y3 + 144.0 * u
	var road := Rect2(Vector2(x, y4), Vector2(cw, r.end.y - y4 - 16.0 * u))
	_card(road, u, a)
	var hw: float = _section(road, u, a, "check", "WHERE THE TOOL STANDS", accent)
	Glyphs.tag(self, Vector2(road.position.x + 40.0 * u + hw + 10.0 * u, road.position.y + 21.0 * u), "SAMPLE", Style.type_px("micro", u), sample)
	var ly: float = road.position.y + 40.0 * u
	for item in ROADMAP:
		var it: Array = item
		var done: bool = String(it[0]) == "check"
		Glyphs.icon(self, String(it[0]), Rect2(Vector2(road.position.x + 12.0 * u, ly - 1.0 * u), Vector2(15.0, 15.0) * u),
			Color(0.5, 1.0, 0.68, a) if done else Color(accent.lightened(0.3), a) if String(it[0]) == "half" else dim)
		draw_string(fl, Vector2(road.position.x + 34.0 * u, ly + 11.0 * u), String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, road.size.x * 0.5 - 40.0 * u, Style.type_px("caption", u), white if done else soft)
		ly += 17.0 * u
	var ax: float = road.position.x + road.size.x * 0.52
	draw_string(fs, Vector2(ax, road.position.y + 50.0 * u), "Days to author a creature", HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("caption", u), soft)
	var by: float = road.position.y + 62.0 * u
	var most: float = 0.0
	for e in AUTHORING:
		most = maxf(most, float(e[1]))
	for e in AUTHORING:
		var bw: float = (road.end.x - ax - 96.0 * u) * float(e[1]) / most
		draw_string(fl, Vector2(ax, by + 9.0 * u), String(e[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("caption", u), dim)
		draw_rect(Rect2(Vector2(ax + 52.0 * u, by), Vector2(bw, 10.0 * u)), Color(sample, 0.75 * a))
		draw_string(fs, Vector2(ax + 58.0 * u + bw, by + 9.0 * u), ("%.1f" % float(e[1])).trim_suffix(".0"), HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("caption", u), soft)
		by += 15.0 * u


func _card(rect: Rect2, u: float, a: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.045 * a)
	sb.set_corner_radius_all(Style.type_px("micro", u))
	sb.anti_aliasing = true
	draw_style_box(sb, rect)


## A card's heading: an icon and a label; returns the label's width.
func _section(rect: Rect2, u: float, a: float, kind: String, text: String, accent: Color) -> float:
	Glyphs.icon(self, kind, Rect2(rect.position + Vector2(10.0, 9.0) * u, Vector2(18.0, 18.0) * u), Color(accent.lightened(0.3), a))
	var f: Font = LabPrint.font("bold")
	draw_string(f, rect.position + Vector2(36.0, 24.0) * u, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("body", u), Color(1, 1, 1, a))
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("body", u)).x


func _frame_graph(gr: Rect2, u: float, a: float, accent: Color, dim: Color) -> void:
	draw_rect(gr, Color(1, 1, 1, 0.04 * a))
	var most: float = BUDGET_MS * 1.25
	for f in _frames:
		most = maxf(most, f)
	var budget_y: float = gr.end.y - gr.size.y * BUDGET_MS / most
	for i in 24:
		var x0: float = gr.position.x + gr.size.x * float(i) / 24.0
		draw_line(Vector2(x0, budget_y), Vector2(x0 + gr.size.x / 48.0, budget_y), Color(1.0, 0.86, 0.45, 0.6 * a), maxf(1.0, u))
	draw_string(LabPrint.font("body"), Vector2(gr.position.x + 4.0 * u, budget_y - 3.0 * u), "60 fps", HORIZONTAL_ALIGNMENT_LEFT, -1, Style.type_px("micro", u), dim)
	if _frames.size() > 2:
		var pts := PackedVector2Array()
		for i in _frames.size():
			pts.append(Vector2(gr.position.x + gr.size.x * float(i) / float(_frames.size() - 1), gr.end.y - gr.size.y * clampf(_frames[i] / most, 0.0, 1.0)))
		draw_polyline(pts, Color(accent.lightened(0.3), a), maxf(1.0, 1.5 * u), true)
