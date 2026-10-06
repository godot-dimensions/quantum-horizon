@tool
extends "res://ramon/VoxelLab/carried/kit/panels/kit_panel_page.gd"

## Kit: the research panel, denser and data-focused, in the same shell as the introduction (rule 3:
## "all retain the same header, content bounds, type roles, colors and lower supporting band").
## Three layout families share it, picked by the room's data (kit_room_info.gd research_layout):
##
##   "specimen"  frame 01's right panel. Left (196): the specimen, its glyph and its story, one row
##               a part, the part playing lit. A divider. Right (571): the part's page: chapter,
##               a two-line headline, what it means, a chart surface and three measured figures,
##               a caption. A new page comes in part by part, its figures counting up, the old one
##               lifting away; the bars grow in one after another.
##   "compare"   two equal columns, each a label, a headline, a line, two figures and a bar on a
##               shared scale, so the two read against each other.
##   "steps"     three columns in order, each a number, a title, what happens, and its figure.
##
## Under all three: the lower rule, the supporting band (a table such as the benchmark, or a few
## lines of text) and the footnote. The band starts where the introduction's controls start.
##
## refresh(d): see sample() for every key, the reference data of the Figma's frame 01 (shown in the
## editor and on the flat review sheet; never in the game, where the room's source measures them).
##
## NO class_name (engine_gotchas.md).

const Charts := preload("res://ramon/VoxelLab/carried/kit/panels/kit_panel_charts.gd")

var layout: String = "specimen"

# The specimen family.
var spec_label: E.Text
var spec_name: E.Text
var spec_meta: E.Text
var glyph: Charts.Glyph
var story_label: E.Text
var story_hint: E.Text
var rows: Array = []
var _page_g: Control
var _leaving: Control
var _page_id: String = ""
var _age: float = 99.0
var _leave_age: float = 0.0
var _metrics: Array = []
var _metric_data: Array = []
var _bars: E.Bars
var _chart: E.El
var _bar_values: Array = []
var _bar_lit: int = -1

# The other two families.
var _cols: Array = []

# The supporting band.
var support_heading: E.Text
var table: E.Table
var support_text: E.Text
var footnote: E.Text


func set_layout(l: String) -> void:
	layout = l if l in ["specimen", "compare", "steps", "methods"] else "specimen"


func _build() -> void:
	var main := group("Research")
	match layout:
		"compare":
			_build_compare(main)
		"steps":
			_build_steps(main)
		"methods":
			_build_methods(main)
		_:
			_build_specimen(main)
	var band := group("Supporting band")
	support_heading = text(band, "Benchmark heading", "label", "muted", Vector2(0, Spec.SUPPORT_Y), Spec.PANEL.x)
	table = E.Table.new("Table", k)
	band.add_child(table)
	table.place(Vector2(0, Spec.SUPPORT_Y + Spec.TABLE_HEAD_DY), Vector2(Spec.PANEL.x, 80))
	support_text = text(band, "Supporting text", "small", "muted", Vector2(0, Spec.SUPPORT_Y + Spec.TABLE_HEAD_DY), Spec.PANEL.x, 5)
	footnote = text(band, "Measurement footnote", "fine", "muted", Vector2(0, Spec.FOOTNOTE_Y), Spec.PANEL.x)


# -- specimen ----------------------------------------------------------------------------------------

func _build_specimen(main: Control) -> void:
	var left := group("Specimen and story", main)
	var y: float = Spec.MAIN_Y
	spec_label = text(left, "Specimen label", "label", "muted", Vector2(0, y), Spec.LEFT_W)
	spec_name = text(left, "Specimen name", "specimen", "white", Vector2(0, y + Spec.SPEC_NAME_DY), Spec.LEFT_W)
	spec_meta = text(left, "Specimen metadata", "micro", "muted", Vector2(0, y + Spec.SPEC_META_DY), Spec.LEFT_W)
	glyph = Charts.Glyph.new("Specimen illustration", k)
	left.add_child(glyph)
	glyph.place(Vector2(0, y + Spec.SPEC_GLYPH_DY), Spec.SPEC_GLYPH)
	story_label = text(left, "Story label", "micro", "muted", Vector2(0, y + Spec.STORY_DY), 74.0)
	story_hint = text(left, "Story hint", "tiny", "muted", Vector2(74, y + Spec.STORY_DY), 122.0)
	rule(left, "Shared horizontal rule", Vector2(0, y + Spec.STORY_RULE_DY), Vector2(Spec.LEFT_W, 1))
	rows = []
	for i in 5:
		var r := E.StoryRow.new("Story %02d" % (i + 1), k)
		left.add_child(r)
		r.place(Vector2(0, y + Spec.STORY_ROW_DY + float(i) * Spec.STORY_ROW_H), Vector2(Spec.LEFT_W, Spec.STORY_ROW_H))
		r.build()
		rows.append(r)
	rule(main, "Column divider", Vector2(Spec.DIVIDER_X, y), Vector2(1, Spec.MAIN_H))


## The right column's page, built afresh for each part.
func _new_page(p: Dictionary, chart_kind: String) -> Control:
	var g := group("Page", get_node("Research"))
	var x: float = Spec.RIGHT_X
	var y: float = Spec.MAIN_Y
	var w: float = Spec.RIGHT_W
	var ch := text(g, "Chapter", "label", "muted", Vector2(x, y), w)
	ch.set_text(String(p.get("chapter", "")))
	ch.stagger = 0
	var hd := text(g, "Research title", "section", "white", Vector2(x, y + Spec.PAGE_HEAD_DY), w, 2)
	hd.set_text(String(p.get("headline", "")))
	hd.stagger = 1
	var ex := text(g, "Research explanation", "small", "muted", Vector2(x, y + Spec.PAGE_TEXT_DY), w, 2)
	ex.set_text(String(p.get("text", "")))
	ex.stagger = 2
	var sf := surface(g, "Chart surface", Vector2(x, y + Spec.PAGE_CHART_DY), Spec.CHART)
	sf.stagger = 3
	_bars = null
	_chart = null
	match chart_kind:
		"bars":
			_bars = E.Bars.new("Build-step chart", k)
			_chart = _bars
		"balls", "joints":
			_chart = Charts.Balls.new("Ball chart", k)
		"profile":
			_chart = Charts.Profile.new("W profile", k)
		"cost":
			_chart = Charts.Cost.new("Cost chart", k)
	if _chart != null:
		g.add_child(_chart)
		_chart.place(Vector2(x, y + Spec.PAGE_CHART_DY), Spec.CHART)
		_chart.stagger = 3
	_metrics = []
	for i in 3:
		var m := E.Metric.new("Metric %d" % (i + 1), k)
		g.add_child(m)
		m.place(Vector2(x + Spec.METRICS_DX, y + Spec.PAGE_CHART_DY + float(i) * Spec.METRIC_PITCH), Vector2(Spec.METRICS_W, 50))
		m.build()
		m.stagger = 4 + i
		_metrics.append(m)
	var cap := text(g, "Chart caption", "micro", "muted", Vector2(x, y + Spec.PAGE_CAPTION_DY), w)
	cap.set_text(String(p.get("caption", "")))
	cap.stagger = 3
	return g


func _refresh_specimen(d: Dictionary) -> void:
	var sp: Dictionary = d.get("specimen", {})
	spec_label.set_text(String(sp.get("label", "")))
	spec_name.set_text(String(sp.get("name", "")))
	spec_meta.set_text(String(sp.get("meta", "")))
	glyph.set_kind(String(sp.get("glyph", "goat")))
	var st: Dictionary = d.get("story", {})
	story_label.set_text(String(st.get("label", "THE STORY")))
	story_hint.set_text(String(st.get("hint", "")))
	var parts: Array = st.get("rows", [])
	var now: int = int(st.get("now", -1))
	var playing: bool = bool(st.get("playing", false))
	for i in rows.size():
		var r: E.StoryRow = rows[i]
		r.visible = i < parts.size()
		if i >= parts.size():
			continue
		var state: String = "now" if i == now else ("done" if (playing and i < now) or now < 0 else "later")
		r.set_row(i + 1, String(parts[i][0]), String(parts[i][1]), state, float(st.get("progress", 1.0)))
	var p: Dictionary = d.get("page", {})
	var id: String = String(p.get("id", ""))
	if id != _page_id or _page_g == null:
		if _leaving != null:
			_leaving.free()
		_leaving = _page_g
		if _leaving != null:
			# The new page takes the name "Page"; the old one keeps out of its way as it leaves.
			_leaving.name = "Leaving"
		_leave_age = 0.0 if _leaving != null else 1.0
		_page_g = _new_page(p, String(p.get("chart", "")))
		_age = 0.0 if _page_id != "" else 99.0
		_page_id = id
		_bar_values = []
	_metric_data = p.get("metrics", [])
	var c: Dictionary = d.get("chart", {})
	if _bars != null:
		var vals: Array = c.get("values", [])
		var lit: int = int(c.get("lit", -1))
		if vals != _bar_values or lit != _bar_lit:
			_bar_values = vals.duplicate()
			_bar_lit = lit
			_bars.set_bars(vals, lit, _grow(vals.size()))
	elif _chart != null and _chart.has_method("set_data"):
		_chart.call("set_data", c)
	_show_metrics()


func _grow(n: int) -> Array:
	var out: Array = []
	for i in n:
		out.append(E.ease_out((_age - 0.15 - 0.07 * float(i)) / 0.5))
	return out


func _show_metrics() -> void:
	for i in _metrics.size():
		var m: E.Metric = _metrics[i]
		if i >= _metric_data.size():
			m.visible = false
			continue
		m.visible = true
		var f: Dictionary = _metric_data[i]
		var u: float = E.ease_out((_age - 0.3 - 0.1 * float(i)) / 0.9)
		var big: String = figure(f.get("value", -1.0), String(f.get("kind", "int")), u)
		m.set_metric(big, String(f.get("text", "")), bool(f.get("accent", false)), not big.is_empty())


## A figure as text, counted up to `v` by `u` (0..1); "" if not measured yet. `kind` "text" shows
## `v` as it is.
static func figure(v: Variant, kind: String, u: float) -> String:
	if kind == "text":
		return String(v)
	if kind == "zero":
		return "0"
	var x0: float = float(v)
	if x0 < 0.0:
		return ""
	var live: bool = kind.ends_with("_live") or kind == "slice"
	var x: float = x0 if live else x0 * u
	match kind:
		"int":
			return E.Bars._thousands(int(round(x)))
		"ratio":
			return "1 : %d" % int(round(x))
		"ms", "ms_live":
			return Charts.ms(x)
		"mb":
			return "%.1f MB" % x
		"pm":
			return "± %.2f m" % x
		"pct_live":
			return "%d%%" % int(round(x))
		"slice":
			return "%d / 9" % int(x)
		"times":
			return "%s×" % E.Bars._thousands(int(round(x)))
	return str(x)


# -- compare -----------------------------------------------------------------------------------------

func _build_compare(main: Control) -> void:
	_cols = []
	for c in 2:
		var g := group("Column %d" % (c + 1), main)
		var x: float = float(c) * (Spec.COMPARE_W + Spec.STEP * 2.0)
		var col: Dictionary = {}
		col["label"] = text(g, "Label", "label", "muted", Vector2(x, Spec.MAIN_Y), Spec.COMPARE_W)
		col["title"] = text(g, "Title", "section", "white", Vector2(x, Spec.MAIN_Y + Spec.PAGE_HEAD_DY), Spec.COMPARE_W, 2)
		col["text"] = text(g, "Text", "small", "muted", Vector2(x, Spec.MAIN_Y + Spec.PAGE_TEXT_DY), Spec.COMPARE_W, 2)
		var ms: Array = []
		for i in 2:
			var m := E.Metric.new("Metric %d" % (i + 1), k)
			g.add_child(m)
			m.place(Vector2(x + float(i) * (Spec.COMPARE_W * 0.5 + Spec.STEP), Spec.MAIN_Y + Spec.PAGE_CHART_DY), Vector2(Spec.COMPARE_W * 0.5 - Spec.STEP, 50))
			m.build()
			ms.append(m)
		col["metrics"] = ms
		col["surface"] = surface(g, "Bar surface", Vector2(x, Spec.MAIN_Y + Spec.PAGE_CHART_DY + 72.0), Vector2(Spec.COMPARE_W, 112))
		col["bar"] = surface(g, "Bar", Vector2(x + 16, Spec.MAIN_Y + Spec.PAGE_CHART_DY + 72.0 + 48.0), Vector2(1, 28), "accent", Spec.BAR_RADIUS)
		col["bar_label"] = text(g, "Bar label", "micro", "muted", Vector2(x + 16, Spec.MAIN_Y + Spec.PAGE_CHART_DY + 72.0 + 20.0), Spec.COMPARE_W - 32.0)
		col["caption"] = text(g, "Caption", "micro", "muted", Vector2(x, Spec.MAIN_Y + Spec.PAGE_CAPTION_DY), Spec.COMPARE_W)
		_cols.append(col)
	rule(main, "Column divider", Vector2(Spec.COMPARE_W + Spec.STEP, Spec.MAIN_Y), Vector2(1, Spec.MAIN_H))


func _refresh_compare(d: Dictionary) -> void:
	var data: Array = d.get("columns", [])
	var top: float = 0.0
	for cd in data:
		top = maxf(top, float((cd as Dictionary).get("bar", 0.0)))
	for c in _cols.size():
		var col: Dictionary = _cols[c]
		var cd: Dictionary = data[c] if c < data.size() else {}
		(col["label"] as E.Text).set_text(String(cd.get("label", "")))
		(col["title"] as E.Text).set_text(String(cd.get("title", "")))
		(col["text"] as E.Text).set_text(String(cd.get("text", "")))
		(col["caption"] as E.Text).set_text(String(cd.get("caption", "")))
		(col["bar_label"] as E.Text).set_text(String(cd.get("bar_label", "")))
		var mm: Array = cd.get("metrics", [])
		for i in 2:
			var m: E.Metric = col["metrics"][i]
			m.visible = i < mm.size()
			if i < mm.size():
				m.set_metric(String(mm[i][0]), String(mm[i][1]), bool(mm[i][2]) if (mm[i] as Array).size() > 2 else false)
		var b: E.Surface = col["bar"]
		var frac: float = float(cd.get("bar", 0.0)) / top if top > 0.0 else 0.0
		b.place(b.u_pos, Vector2(maxf(1.0, (Spec.COMPARE_W - 32.0) * frac), 28))


# -- steps ---------------------------------------------------------------------------------------------

func _build_steps(main: Control) -> void:
	_cols = []
	for c in 3:
		var g := group("Step %d" % (c + 1), main)
		var x: float = float(c) * (Spec.STEPS_W + Spec.STEP * 2.0)
		var col: Dictionary = {}
		col["number"] = text(g, "Number", "label", "accent", Vector2(x, Spec.MAIN_Y), Spec.STEPS_W)
		col["title"] = text(g, "Title", "section", "white", Vector2(x, Spec.MAIN_Y + Spec.PAGE_HEAD_DY), Spec.STEPS_W, 2)
		col["text"] = text(g, "Text", "small", "muted", Vector2(x, Spec.MAIN_Y + Spec.PAGE_TEXT_DY), Spec.STEPS_W, 8)
		var m := E.Metric.new("Metric", k)
		g.add_child(m)
		m.place(Vector2(x, Spec.MAIN_Y + Spec.PAGE_CAPTION_DY - 62.0), Vector2(Spec.STEPS_W, 50))
		m.build()
		col["metric"] = m
		_cols.append(col)
		if c < 2:
			rule(main, "Step divider %d" % (c + 1), Vector2(x + Spec.STEPS_W + Spec.STEP, Spec.MAIN_Y), Vector2(1, Spec.MAIN_H))


func _refresh_steps(d: Dictionary) -> void:
	var data: Array = d.get("steps", [])
	for c in _cols.size():
		var col: Dictionary = _cols[c]
		var sd: Dictionary = data[c] if c < data.size() else {}
		(col["number"] as E.Text).set_text("%02d" % (c + 1))
		(col["title"] as E.Text).set_text(String(sd.get("title", "")))
		(col["text"] as E.Text).set_text(String(sd.get("text", "")))
		var m: E.Metric = col["metric"]
		m.visible = sd.has("value")
		if sd.has("value"):
			m.set_metric(String(sd["value"]), String(sd.get("value_text", "")), bool(sd.get("accent", false)))


# -- methods (ARBORETUM, carried copy) -------------------------------------------------------------------
# Four equal columns in the main track, one a method, read across as a comparison: its number and code,
# a two-line title, what it does, two measured figures, and a bar on one scale for all four (the
# tetrahedra each holds), its state (baked or live) under it. The column of the pedestal you are at is
# marked with the accent.

const METHODS_N := 4


func _methods_w() -> float:
	return (Spec.PANEL.x - Spec.STEP * 2.0 * float(METHODS_N - 1)) / float(METHODS_N)


func _build_methods(main: Control) -> void:
	_cols = []
	var cw: float = _methods_w()
	for c in METHODS_N:
		var g := group("Method %d" % (c + 1), main)
		var x: float = float(c) * (cw + Spec.STEP * 2.0)
		var col: Dictionary = {}
		col["label"] = text(g, "Label", "label", "accent", Vector2(x, Spec.MAIN_Y), cw)
		col["title"] = text(g, "Title", "section", "white", Vector2(x, Spec.MAIN_Y + Spec.PAGE_HEAD_DY), cw, 2)
		col["text"] = text(g, "Text", "small", "muted", Vector2(x, Spec.MAIN_Y + Spec.PAGE_TEXT_DY), cw, 6)
		var ms: Array = []
		for i in 2:
			var m := E.Metric.new("Metric %d" % (i + 1), k)
			g.add_child(m)
			m.place(Vector2(x, Spec.MAIN_Y + 172.0 + float(i) * 56.0), Vector2(cw, 50))
			m.build()
			ms.append(m)
		col["metrics"] = ms
		col["bar_label"] = text(g, "Bar label", "micro", "muted", Vector2(x, Spec.MAIN_Y + 284.0), cw)
		col["surface"] = surface(g, "Bar surface", Vector2(x, Spec.MAIN_Y + 296.0), Vector2(cw, 12), "surface", Spec.BAR_RADIUS)
		col["bar"] = surface(g, "Bar", Vector2(x, Spec.MAIN_Y + 296.0), Vector2(1, 12), "accent", Spec.BAR_RADIUS)
		_cols.append(col)
		if c < METHODS_N - 1:
			rule(main, "Method divider %d" % (c + 1), Vector2(x + cw + Spec.STEP, Spec.MAIN_Y), Vector2(1, Spec.MAIN_H))


func _refresh_methods(d: Dictionary) -> void:
	var data: Array = d.get("methods", [])
	var top: float = 0.0
	for md in data:
		top = maxf(top, float((md as Dictionary).get("bar", 0.0)))
	var cw: float = _methods_w()
	for c in _cols.size():
		var col: Dictionary = _cols[c]
		var md: Dictionary = data[c] if c < data.size() else {}
		var here: bool = bool(md.get("here", false))
		(col["label"] as E.Text).set_text(String(md.get("label", "")) + ("   ·   YOU ARE HERE" if here else ""))
		(col["title"] as E.Text).set_text(String(md.get("title", "")))
		(col["text"] as E.Text).set_text(String(md.get("text", "")))
		(col["bar_label"] as E.Text).set_text(String(md.get("bar_label", "")))
		var mm: Array = md.get("metrics", [])
		for i in 2:
			var m: E.Metric = col["metrics"][i]
			m.visible = i < mm.size()
			if i < mm.size():
				m.set_metric(String(mm[i][0]), String(mm[i][1]), bool(mm[i][2]) if (mm[i] as Array).size() > 2 else false)
		var b: E.Surface = col["bar"]
		var frac: float = float(md.get("bar", 0.0)) / top if top > 0.0 else 0.0
		b.place(b.u_pos, Vector2(maxf(1.0, cw * frac), 12))


# -- every family ------------------------------------------------------------------------------------

func refresh(d: Dictionary) -> void:
	header_left.set_text(String(d.get("header_left", "")))
	header_right.set_text(String(d.get("header_right", "")))
	match layout:
		"compare":
			_refresh_compare(d)
		"steps":
			_refresh_steps(d)
		"methods":
			_refresh_methods(d)
		_:
			_refresh_specimen(d)
	var tb: Dictionary = d.get("table", {})
	support_heading.set_text(String(tb.get("heading", d.get("support_heading", ""))))
	table.visible = not tb.is_empty()
	support_text.visible = tb.is_empty()
	if not tb.is_empty():
		table.set_table(tb.get("heads", []), tb.get("rows", []), int(tb.get("current", -1)))
	else:
		support_text.set_text(String(d.get("support_text", "")))
	footnote.set_text(String(d.get("footnote", "")))


func tick(dt: float) -> bool:
	if layout != "specimen":
		return false
	var busy: bool = false
	if _leaving != null:
		_leave_age += dt
		var t: float = _leave_age / 0.3
		if t >= 1.0:
			_leaving.queue_free()
			_leaving = null
		else:
			animate(_leaving, 99.0, 1.0 - t, -14.0 * t)
		busy = true
	if _page_g != null and _age < 1.8:
		_age += dt
		# The new page waits a moment for the old one to start lifting away.
		animate(_page_g, _age - 0.12)
		if _bars != null:
			_bars.set_bars(_bar_values, _bar_lit, _grow(_bar_values.size()))
		_show_metrics()
		busy = true
	elif _page_g != null and _age < 90.0:
		_age = 99.0
		animate(_page_g, 99.0)
		_show_metrics()
	return busy


## The reference data drawn in the Figma's frame 01, for the editor's preview and the flat review
## sheet. The intermediate bar heights there were read off a screenshot for placement only.
static func sample(layout_family: String = "specimen") -> Dictionary:
	var d: Dictionary = {
		"header_left": "CREATION LAB  /  RESEARCH WALL",
		"header_right": "●  MEASURED LIVE ON THIS MACHINE",
		"specimen": {"label": "SPECIMEN  GT-01", "name": "Goat", "meta": "24 BALLS  ·  14,240 TETRAHEDRA", "glyph": "goat"},
		"story": {"label": "THE STORY", "hint": "PLAYING  ·  CLICK FOR THE NEXT PART", "now": 1, "playing": true, "progress": 1.0,
			"rows": [["The Balls", "placed by a designer"], ["The Skin", "lofted by the tool"], ["The Slice", "seen through W"],
				["The Rig", "joints from the balls"], ["The Walk", "rigid pieces in motion"]]},
		"page": {"id": "sample:skin", "chapter": "02 / 05  ·  THE SKIN", "headline": "The tool lofts the skin.\nNothing is modelled by hand.",
			"text": "Between neighbouring balls the loft fills in tetrahedra, the four-dimensional cousin of triangles. Each bar is the mesh after one more build step.",
			"chart": "bars", "caption": "Tetrahedra after each build step of the goat.",
			"metrics": [{"value": 14240.0, "kind": "int", "text": "tetrahedra in the finished body", "accent": false},
				{"value": 176.0, "kind": "ms", "text": "to loft all of it from its balls, on this machine", "accent": true},
				{"value": 2.7, "kind": "mb", "text": "of mesh data in memory", "accent": false}]},
		"chart": {"values": [1384.0, 3956.0, 6131.0, 7911.0, 9295.0, 11075.0, 14240.0], "lit": 6},
		"table": {"heading": "BENCHMARK  every specimen, measured the same way in this room",
			"heads": ["SPECIMEN", "BALLS", "TETRAHEDRA", "LOFTED IN", "ONE LEG", "WALK EACH FRAME", "IF RE-LOFTED", "RIGID IS"],
			"rows": [["Chicken CK-02", "27", "9,780", "190 ms", "8.84 ms", "0.033 ms", "18 ms", "534× cheaper"],
				["Goat GT-01", "24", "14,240", "176 ms", "17 ms", "not yet", "66 ms", "not yet"],
				["Wolf WF-03", "20", "13,248", "162 ms", "20 ms", "0.011 ms", "80 ms", "7,495× cheaper"]], "current": 1},
		"footnote": "Measured in this room on NVIDIA GeForce RTX 5080, Windows. Loft times recorded 2026-10-04; the walk is timed every frame it plays. One machine, one scene.",
	}
	if layout_family == "compare":
		d["header_left"] = "TEST ROOM  /  COMPARISON"
		d["columns"] = [
			{"label": "RIGID PIECES", "title": "Cut once,\nmoved every frame.", "text": "The skin is cut into pieces once; a frame moves a few transforms.",
				"metrics": [["0.033 ms", "a frame, measured", true], ["14", "pieces"]], "bar": 0.033, "bar_label": "COST A FRAME", "caption": "The chicken's walk."},
			{"label": "RE-LOFTING", "title": "Rebuilt from its balls,\nevery frame.", "text": "Every leg is lofted again each frame, as the first creatures were.",
				"metrics": [["18 ms", "a frame, measured"], ["4", "legs re-lofted"]], "bar": 18.0, "bar_label": "COST A FRAME", "caption": "The chicken's legs, re-lofted."}]
	elif layout_family == "methods":
		d["header_left"] = "ARBORETUM  /  THE FOUR METHODS"
		d["header_right"] = "●  MEASURED ON THIS MACHINE"
		d["methods"] = [
			{"label": "01  ·  VX-01", "title": "Voxels", "text": "The skeleton written into 4D cells, one box a cell.", "metrics": [["149K", "tetrahedra"], ["0.4 s", "built in GDScript"]], "bar": 149450.0, "bar_label": "PRE-BAKED"},
			{"label": "02  ·  DC-02", "title": "Smooth voxels", "text": "The engine's voxel world, meshed by dual contouring in C++.", "metrics": [["148K", "tetrahedra"], ["185 ms", "meshed in C++", true]], "bar": 148330.0, "bar_label": "PRE-BAKED"},
			{"label": "03  ·  LF-03", "title": "Lofted", "text": "Our loft tool: a cross-section at every point, skinned.", "metrics": [["16K", "tetrahedra"], ["0.3 s", "lofted in GDScript"]], "bar": 16000.0, "bar_label": "PRE-BAKED"},
			{"label": "04  ·  OK-04", "title": "The oak", "text": "Lofted wood, and leaves the graphics card places.", "metrics": [["40K", "tetrahedra"], ["30K", "leaves, no tetrahedra", true]], "bar": 40000.0, "bar_label": "PRE-BAKED", "here": true}]
	elif layout_family == "steps":
		d["header_left"] = "TEST ROOM  /  THREE STEPS"
		d["steps"] = [
			{"title": "Place the balls.", "text": "A designer sets each ball: its size, two stretches, a squareness and its reach into W.", "value": "24", "value_text": "balls"},
			{"title": "Loft the skin.", "text": "The tool fills tetrahedra between neighbouring balls. Nothing is modelled by hand.", "value": "176 ms", "value_text": "to loft, on this machine", "accent": true},
			{"title": "Walk it.", "text": "The skin is cut into rigid pieces that move without rebuilding the mesh.", "value": "0.011 ms", "value_text": "a frame for the walk"}]
	return d
