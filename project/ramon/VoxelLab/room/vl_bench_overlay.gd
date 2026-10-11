extends Control

## The Voxel Lab bench's screen layer, while you sit at a specimen (room/vl_bench_4d.gd sets it up):
##
##   THE OUTLINE   where the tool will cut, drawn over the specimen through the live camera: a ring for
##                 the ball, a square for the block, a ring and its depth for the drill, the blade's
##                 path for the saw; with what is under the cursor (crust, core, vein, lining) and at
##                 which W of the specimen.
##   THE TOOL CARD bottom middle, one size always: the tool's picture, its name and size, what it does,
##                 and the keys (the lab's rule: show the action and the key in a centred card).
##   THE COSTS     a black glass screen on the right: the last cut taken apart (voxels removed, chunks
##                 meshed again, how long until it showed, the worst frame, the worker's time), a pair
##                 of bars per cut, and the totals. T switches where the draw buffers are built, so the
##                 difference can be felt and read.
##
##   AT A BUILDER  (Build it, round 4) the card names the brick tool and its colour, shows the colours
##                 on Q/E as swatches, and a strip of the W layers: the one you are in lit, each one's
##                 bricks counted under it.
##   AT A STEPPER  (Overlapping geometry) the card names the piece that went in last and counts them all in a
##                 strip of boxes, and a glass panel on the left holds the exhibit's words.
##
## Sizes follow the window's height, never the distance to anything (Ramon's lab rule).
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/VoxelLab/carried/kit/kit_style.gd")
const Recipe := preload("res://ramon/VoxelLab/specimen/vl_recipe.gd")
const Cutter := preload("res://ramon/VoxelLab/specimen/vl_cutter.gd")

const MATERIAL_NAMES := {0: "CRUST", 1: "CORE", 2: "VEIN", 3: "LINING", 4: "CROWN", 5: "GRASS", 6: "DIRT", 7: "STONE", 8: "WATER"}

var camera: Camera4D
## Polylines in the world to draw (PackedVector4Array each), and whether each is closed.
var outline: Array = []
var hit_world: Vector4 = Vector4.INF
var hit_text: String = ""
var tool: String = "ball"
## The bench's own tools, in key order (a bench may offer fewer than all of them).
var tools: PackedStringArray = PackedStringArray(Cutter.TOOLS)
var size_index: int = 1
var records: Array = []
var swap: bool = true
var totals: Dictionary = {}
var show_costs: bool = true
## The tool card's own line under the name (the station can put its own words there).
var station_name: String = ""
## A builder's card (vl_build_exhibit_4d.gd overlay_info): empty at a cutting bench.
var build: Dictionary = {}
## A stepper's card (vl_hypercubes_exhibit_4d.gd overlay_info): empty elsewhere.
var step: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _to_canvas(p: Vector4) -> Vector2:
	var px: Vector2 = camera.world_to_viewport(p)
	var vs := Vector2(get_viewport().get_size())
	return px * (get_viewport_rect().size / vs) if vs.x > 0.0 else px


func _draw() -> void:
	if camera == null or not visible:
		return
	# Laid out from the viewport (this control's own size can still be zero in its first frames).
	var vs: Vector2 = get_viewport_rect().size
	var u: float = maxf(vs.y, 360.0) / 720.0
	_draw_outline(u)
	_draw_card(u)
	if show_costs:
		_draw_costs(u)


func _draw_outline(u: float) -> void:
	var ink := Color(1, 1, 1, 0.95)
	var halo := Color(0.02, 0.04, 0.08, 0.55)
	for line in outline:
		var pts := PackedVector2Array()
		for p in (line[0] as PackedVector4Array):
			if bool(camera.is_position_behind(p)):
				continue
			pts.append(_to_canvas(p))
		if pts.size() < 2:
			continue
		if bool(line[1]):
			pts.append(pts[0])
		draw_polyline(pts, halo, 4.0 * u, true)
		draw_polyline(pts, ink if not bool(line[2]) else Style.UI_ACCENT, 1.6 * u, true)
	if hit_world != Vector4.INF and not bool(camera.is_position_behind(hit_world)):
		var c: Vector2 = _to_canvas(hit_world)
		var r: float = 5.0 * u
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), ink, 1.4 * u)
		draw_line(c - Vector2(0, r), c + Vector2(0, r), ink, 1.4 * u)
		if not hit_text.is_empty():
			var f: Font = Style.ui_font("key")
			var fs: int = int(11.0 * u)
			var tw: float = f.get_string_size(hit_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := c + Vector2(14.0 * u, -12.0 * u)
			draw_rect(Rect2(at - Vector2(6 * u, fs + 3 * u), Vector2(tw + 12 * u, fs + 9 * u)), Color(Style.UI_GLASS, 0.8))
			draw_string(f, at, hit_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Style.UI_INK_SOFT)


## The tool card: bottom middle, above the control strip.
func _draw_card(u: float) -> void:
	if not build.is_empty():
		_draw_build_card(u)
		return
	if not step.is_empty():
		_draw_step_card(u)
		_draw_side_text(u)
		return
	var w: float = 470.0 * u
	var h: float = 92.0 * u
	var vs: Vector2 = get_viewport_rect().size
	var r := Rect2(Vector2((vs.x - w) * 0.5, vs.y - h - 74.0 * u), Vector2(w, h))
	draw_style_box(Style.glass_box(14.0 * u), r)
	# The tool's picture.
	var pic := Rect2(r.position + Vector2(14, 14) * u, Vector2(h - 28 * u, h - 28 * u))
	_draw_tool_icon(tool, pic, Style.UI_ACCENT, u)
	var x: float = pic.end.x + 16.0 * u
	var fb: Font = Style.ui_font("title")
	var fk: Font = Style.ui_font("key")
	var ft: Font = Style.ui_font("text")
	var tname: String = "%s  ·  %s" % [String(Cutter.NAMES[tool]).to_upper(), Cutter.SIZE_NAMES[size_index]]
	draw_string(fb, Vector2(x, r.position.y + 30.0 * u), tname, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * u), Style.UI_INK)
	draw_string(ft, Vector2(x, r.position.y + 52.0 * u), String(Cutter.LINES[tool]), HORIZONTAL_ALIGNMENT_LEFT, w - (x - r.position.x) - 12 * u, int(12 * u), Style.UI_INK_SOFT)
	# The keys: 1 2 3 4 for the tools (numbered boxes are buttons: they answer the number keys), Q/E size.
	var kx: float = x
	var ky: float = r.position.y + 64.0 * u
	for i in tools.size():
		var on: bool = tools[i] == tool
		var cap := Rect2(Vector2(kx, ky), Vector2(18, 18) * u)
		draw_rect(cap, Color(1, 1, 1, 0.22 if on else 0.06))
		draw_rect(cap, Color(1, 1, 1, 0.9 if on else 0.4), false, 1.0 * u)
		draw_string(fk, Vector2(cap.position.x, cap.position.y + 13.5 * u), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, int(11 * u), Style.UI_INK)
		kx += 22.0 * u
	draw_string(fk, Vector2(kx + 6 * u, ky + 13.5 * u), "TOOL      Q / E  SIZE      R  WHOLE AGAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), Style.UI_INK_DIM)


## The builder's card: the tool and its colour, what it does, the keys and swatches, and the W layers.
func _draw_build_card(u: float) -> void:
	var w: float = 560.0 * u
	var h: float = 92.0 * u
	var vs: Vector2 = get_viewport_rect().size
	var r := Rect2(Vector2((vs.x - w) * 0.5, vs.y - h - 74.0 * u), Vector2(w, h))
	draw_style_box(Style.glass_box(14.0 * u), r)
	var colours: Array = build.get("colours", [])
	var ci: int = int(build.get("colour", 0))
	var col: Color = colours[ci] if ci < colours.size() else Style.UI_ACCENT
	var pic := Rect2(r.position + Vector2(14, 14) * u, Vector2(h - 28 * u, h - 28 * u))
	_draw_tool_icon(tool, pic, col if tool != "take" else Style.UI_ACCENT, u)
	var x: float = pic.end.x + 16.0 * u
	var fb: Font = Style.ui_font("title")
	var fk: Font = Style.ui_font("key")
	var ft: Font = Style.ui_font("text")
	var name_: String = String(build.get("name", "")) + ("" if tool == "take" else "  ·  " + String(build.get("colour_name", "")))
	draw_string(fb, Vector2(x, r.position.y + 30.0 * u), name_, HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * u), Style.UI_INK)
	var layers_w: float = 150.0 * u
	draw_string(ft, Vector2(x, r.position.y + 52.0 * u), String(build.get("line", "")), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - layers_w - x - 16 * u, int(12 * u), Style.UI_INK_SOFT)
	# The keys: numbered boxes for the tools (they answer the number keys), then the colours on Q/E.
	var kx: float = x
	var ky: float = r.position.y + 64.0 * u
	for i in tools.size():
		var on: bool = tools[i] == tool
		var cap := Rect2(Vector2(kx, ky), Vector2(18, 18) * u)
		draw_rect(cap, Color(1, 1, 1, 0.22 if on else 0.06))
		draw_rect(cap, Color(1, 1, 1, 0.9 if on else 0.4), false, 1.0 * u)
		draw_string(fk, Vector2(cap.position.x, cap.position.y + 13.5 * u), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, int(11 * u), Style.UI_INK)
		kx += 22.0 * u
	draw_string(fk, Vector2(kx + 6 * u, ky + 13.5 * u), "TOOL     Q / E", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), Style.UI_INK_DIM)
	kx += 6.0 * u + fk.get_string_size("TOOL     Q / E", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u)).x + 8.0 * u
	for i in colours.size():
		var sw := Rect2(Vector2(kx, ky + 2.0 * u), Vector2(14, 14) * u)
		draw_rect(sw, colours[i])
		if i == ci:
			draw_rect(sw.grow(2.5 * u), Color(1, 1, 1, 0.95), false, 1.4 * u)
		kx += 20.0 * u
	draw_string(fk, Vector2(kx + 6 * u, ky + 13.5 * u), "Z  UNDO", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u),
		Style.UI_INK_DIM if bool(build.get("undo", false)) else Color(Style.UI_INK_DIM, 0.4))
	# The W layers: one box each, the one you are in lit, its bricks counted under it.
	var n: int = int(build.get("layers", 5))
	var lit: int = int(build.get("layer", 0))
	var per: Array = build.get("per_layer", [])
	var lx: float = r.end.x - layers_w - 8.0 * u
	draw_string(fk, Vector2(lx, r.position.y + 24.0 * u), "W LAYER  %d / %d" % [lit + 1, n], HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), Style.UI_INK)
	var bw: float = (layers_w - 4.0 * u * float(n - 1)) / float(n)
	for i in n:
		var cell := Rect2(Vector2(lx + (bw + 4.0 * u) * float(i), r.position.y + 34.0 * u), Vector2(bw, bw))
		var count: int = int(per[i]) if i < per.size() else 0
		draw_rect(cell, Color(col, 0.55) if count > 0 else Color(1, 1, 1, 0.05))
		draw_rect(cell, Color(1, 1, 1, 0.95 if i == lit else 0.3), false, (2.0 if i == lit else 1.0) * u)
		draw_string(fk, Vector2(cell.position.x, cell.end.y + 13.0 * u), str(count), HORIZONTAL_ALIGNMENT_CENTER, bw, int(10 * u),
			Style.UI_INK if i == lit else Style.UI_INK_DIM)
	draw_string(ft, Vector2(lx, r.end.y - 6.0 * u), "WHEEL  NEXT LAYER", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Style.UI_INK_DIM)


## The stepper's card, as the builder's: the piece that went in last and what it is, the key, and a box for
## each piece, lit once it is in.
func _draw_step_card(u: float) -> void:
	var w: float = 560.0 * u
	var h: float = 92.0 * u
	var vs: Vector2 = get_viewport_rect().size
	var r := Rect2(Vector2((vs.x - w) * 0.5, vs.y - h - 74.0 * u), Vector2(w, h))
	draw_style_box(Style.glass_box(14.0 * u), r)
	var col: Color = step.get("colour", Style.UI_ACCENT)
	var count: int = int(step.get("count", 0))
	var of: int = int(step.get("of", 1))
	var pic := Rect2(r.position + Vector2(14, 14) * u, Vector2(h - 28 * u, h - 28 * u))
	_draw_tool_icon("through", pic, col, u)
	var x: float = pic.end.x + 16.0 * u
	var fb: Font = Style.ui_font("title")
	var fk: Font = Style.ui_font("key")
	var ft: Font = Style.ui_font("text")
	draw_string(fb, Vector2(x, r.position.y + 30.0 * u), String(step.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, int(19 * u), Style.UI_INK)
	var boxes_w: float = 150.0 * u
	draw_string(ft, Vector2(x, r.position.y + 52.0 * u), String(step.get("line", "")), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - boxes_w - x - 16 * u, int(12 * u), Style.UI_INK_SOFT)
	var ky: float = r.position.y + 64.0 * u
	var more: bool = count < of
	var cap := Rect2(Vector2(x, ky), Vector2(18, 18) * u)
	draw_rect(cap, Color(1, 1, 1, 0.22 if more else 0.06))
	draw_rect(cap, Color(1, 1, 1, 0.9 if more else 0.4), false, 1.0 * u)
	draw_string(fk, Vector2(cap.position.x, cap.position.y + 13.5 * u), "1", HORIZONTAL_ALIGNMENT_CENTER, cap.size.x, int(11 * u), Style.UI_INK)
	draw_string(fk, Vector2(cap.end.x + 10 * u, ky + 13.5 * u), "ADD THE NEXT" if more else "ALL IN PLACE", HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), Style.UI_INK_DIM)
	var bx: float = r.end.x - boxes_w - 8.0 * u
	draw_string(fk, Vector2(bx, r.position.y + 24.0 * u), "IN PLACE  %d / %d" % [count, of], HORIZONTAL_ALIGNMENT_LEFT, -1, int(10 * u), Style.UI_INK)
	var bw: float = (boxes_w - 4.0 * u * float(of - 1)) / float(of)
	for i in of:
		var cell := Rect2(Vector2(bx + (bw + 4.0 * u) * float(i), r.position.y + 34.0 * u), Vector2(bw, bw))
		draw_rect(cell, Color(col, 0.55) if i < count else Color(1, 1, 1, 0.05))
		draw_rect(cell, Color(1, 1, 1, 0.95 if i == count - 1 else 0.3), false, (2.0 if i == count - 1 else 1.0) * u)


## The stepper's words: a glass panel on the left, as tall as its text.
func _draw_side_text(u: float) -> void:
	var text: String = String(step.get("text", ""))
	if text.is_empty():
		return
	var w: float = 300.0 * u
	var fb: Font = Style.ui_font("title")
	var ft: Font = Style.ui_font("text")
	var inner: float = w - 32.0 * u
	var fs: int = int(13 * u)
	var body_h: float = ft.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, inner, fs).y
	var r := Rect2(Vector2(22.0 * u, 96.0 * u), Vector2(w, 50.0 * u + body_h + 16.0 * u))
	draw_style_box(Style.glass_box(14.0 * u), r)
	var x: float = r.position.x + 16.0 * u
	draw_string(fb, Vector2(x, r.position.y + 28.0 * u), String(step.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, inner, int(16 * u), Style.UI_INK)
	draw_multiline_string(ft, Vector2(x, r.position.y + 50.0 * u + float(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, inner, fs, -1, Style.UI_INK_SOFT)


static func _draw_tool_icon_static(c: CanvasItem, t: String, r: Rect2, col: Color, u: float) -> void:
	var m: Vector2 = r.get_center()
	var s: float = r.size.y * 0.5
	var lw: float = 2.2 * u
	# The block it cuts into, then the cut.
	c.draw_rect(Rect2(r.position + Vector2(0, s * 0.35), Vector2(r.size.x, r.size.y - s * 0.35)), Color(1, 1, 1, 0.10))
	var top: float = r.position.y + s * 0.35
	match t:
		"ball":
			c.draw_arc(Vector2(m.x, top), s * 0.62, 0.0, PI, 24, col, lw, true)
		"block":
			c.draw_rect(Rect2(Vector2(m.x - s * 0.5, top), Vector2(s, s * 0.8)), col, false, lw)
		"drill":
			c.draw_line(Vector2(m.x - s * 0.22, top), Vector2(m.x - s * 0.22, r.end.y - s * 0.1), col, lw)
			c.draw_line(Vector2(m.x + s * 0.22, top), Vector2(m.x + s * 0.22, r.end.y - s * 0.1), col, lw)
			c.draw_arc(Vector2(m.x, r.end.y - s * 0.1), s * 0.22, 0.0, PI, 12, col, lw, true)
		"saw":
			c.draw_line(Vector2(r.position.x + s * 0.2, top), Vector2(r.end.x - s * 0.2, top), col, lw)
			c.draw_rect(Rect2(Vector2(r.position.x + s * 0.2, top), Vector2(r.size.x - s * 0.4, s * 0.55)), col, false, lw)
		"brick":
			# A brick set on the surface.
			c.draw_rect(Rect2(Vector2(m.x - s * 0.5, top - s * 0.85), Vector2(s, s * 0.85)), col)
		"through":
			# The brick in every W layer: copies stepped back behind it.
			for k in [2, 1, 0]:
				var o := Vector2(s * 0.2, -s * 0.16) * float(k)
				var b := Rect2(Vector2(m.x - s * 0.62, top - s * 0.8) + o, Vector2(s * 0.8, s * 0.8))
				if k == 0:
					c.draw_rect(b, col)
				else:
					c.draw_rect(b, Color(col, 0.35 if k == 1 else 0.2))
		"take":
			# The brick lifted off, dashed where it was.
			var was := Rect2(Vector2(m.x - s * 0.5, top - s * 0.85), Vector2(s, s * 0.85))
			for e in [[was.position, Vector2(was.end.x, was.position.y)], [Vector2(was.end.x, was.position.y), was.end],
					[was.end, Vector2(was.position.x, was.end.y)], [Vector2(was.position.x, was.end.y), was.position]]:
				c.draw_dashed_line(e[0], e[1], col, lw * 0.7, 3.0 * u)
			c.draw_line(Vector2(m.x, top - s * 0.3), Vector2(m.x, top - s * 1.3), col, lw)
			c.draw_line(Vector2(m.x - s * 0.22, top - s * 1.05), Vector2(m.x, top - s * 1.3), col, lw)
			c.draw_line(Vector2(m.x + s * 0.22, top - s * 1.05), Vector2(m.x, top - s * 1.3), col, lw)


func _draw_tool_icon(t: String, r: Rect2, col: Color, u: float) -> void:
	_draw_tool_icon_static(self, t, r, col, u)


## The cost screen: black glass on the right.
func _draw_costs(u: float) -> void:
	var w: float = 300.0 * u
	var h: float = 392.0 * u
	var vs: Vector2 = get_viewport_rect().size
	var r := Rect2(Vector2(vs.x - w - 22.0 * u, 96.0 * u), Vector2(w, h))
	draw_style_box(Style.glass_box(14.0 * u), r)
	var fb: Font = Style.ui_font("title")
	var fk: Font = Style.ui_font("key")
	var ft: Font = Style.ui_font("text")
	var x: float = r.position.x + 16.0 * u
	var y: float = r.position.y + 28.0 * u
	var right: float = r.end.x - 16.0 * u
	var edits: bool = not build.is_empty() or not step.is_empty()
	draw_string(fb, Vector2(x, y), ("EDITS  ·  %d" if edits else "CUTS  ·  %d") % records.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * u), Style.UI_INK)
	draw_string(fk, Vector2(x, y + 18.0 * u), ("DRAW BUFFERS ON A WORKER THREAD" if swap else "THE ENGINE'S WAY: ALL IN ONE FRAME"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Style.UI_LIVE if swap else Style.UI_WARM)
	y += 42.0 * u
	var last: Dictionary = records[-1] if not records.is_empty() else {}
	var rows: Array = [
		["Last edit" if edits else "Last cut", String(last.get("label", "none yet"))],
		["Voxels added" if int(last.get("fill", Recipe.AIR)) != Recipe.AIR else "Voxels removed", ("not counted (noise)" if int(last.get("voxels", 0)) < 0 else _thousands(int(last.get("voxels", 0)))) if not last.is_empty() else "-"],
		["Chunks meshed again", str(int(last.get("chunks", 0))) if not last.is_empty() else "-"],
		["On screen after", "%.0f ms" % float(last.get("latency_ms", 0.0)) if not last.is_empty() else "-"],
		["Worst frame", "%.1f ms" % float(last.get("worst_ms", 0.0)) if not last.is_empty() else "-"],
		["Worker thread", ("%.0f ms" % float(last.get("worker_ms", 0.0))) if bool(last.get("swap", true)) and not last.is_empty() else "-"],
	]
	for row in rows:
		draw_string(ft, Vector2(x, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Style.UI_INK_DIM)
		draw_string(fk, Vector2(x, y), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, right - x, int(11 * u), Style.UI_INK)
		y += 19.0 * u
	# The bars: the last 14 cuts, how long until each showed (pale) and its worst frame (accent), on one
	# scale to 200 ms, with a line at one 60 Hz frame.
	y += 8.0 * u
	var chart := Rect2(Vector2(x, y), Vector2(right - x, 92.0 * u))
	draw_rect(chart, Color(1, 1, 1, 0.04))
	var full: float = 200.0
	var fps_y: float = chart.end.y - chart.size.y * (16.7 / full)
	draw_dashed_line(Vector2(chart.position.x, fps_y), Vector2(chart.end.x, fps_y), Color(1, 1, 1, 0.35), 1.0 * u, 4.0 * u)
	draw_string(ft, Vector2(chart.end.x - 64 * u, fps_y - 3 * u), "one frame", HORIZONTAL_ALIGNMENT_RIGHT, 60 * u, int(8 * u), Style.UI_INK_DIM)
	var shown: Array = records.slice(maxi(0, records.size() - 14))
	var bw: float = chart.size.x / 14.0
	for i in shown.size():
		var rec: Dictionary = shown[i]
		var bx: float = chart.position.x + bw * float(i) + bw * 0.12
		var lat: float = clampf(float(rec.get("latency_ms", 0.0)) / full, 0.0, 1.0) * chart.size.y
		var worst: float = clampf(float(rec.get("worst_ms", 0.0)) / full, 0.0, 1.0) * chart.size.y
		draw_rect(Rect2(Vector2(bx, chart.end.y - lat), Vector2(bw * 0.36, lat)), Color(1, 1, 1, 0.38))
		var wc: Color = Style.UI_ACCENT if bool(rec.get("swap", true)) else Style.UI_WARM
		draw_rect(Rect2(Vector2(bx + bw * 0.4, chart.end.y - worst), Vector2(bw * 0.36, worst)), wc)
	y = chart.end.y + 16.0 * u
	draw_rect(Rect2(Vector2(x, y - 8 * u), Vector2(8, 8) * u), Color(1, 1, 1, 0.38))
	draw_string(ft, Vector2(x + 12 * u, y), "until it showed", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Style.UI_INK_DIM)
	draw_rect(Rect2(Vector2(x + 110 * u, y - 8 * u), Vector2(8, 8) * u), Style.UI_ACCENT if swap else Style.UI_WARM)
	draw_string(ft, Vector2(x + 122 * u, y), "worst frame", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Style.UI_INK_DIM)
	y += 22.0 * u
	for row in [["Tetrahedra now", String(totals.get("tets", "-"))], ["Video memory", String(totals.get("mb", "-"))], ["Voxel", String(totals.get("voxel", "-"))]]:
		draw_string(ft, Vector2(x, y), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Style.UI_INK_DIM)
		draw_string(fk, Vector2(x, y), String(row[1]), HORIZONTAL_ALIGNMENT_RIGHT, right - x, int(11 * u), Style.UI_INK)
		y += 18.0 * u
	draw_string(fk, Vector2(x, r.end.y - 12.0 * u), "T  " + ("BUILD THEM IN THE FRAME INSTEAD" if swap else "BUILD THEM ON A WORKER AGAIN"),
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * u), Style.UI_INK_DIM)


static func _thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
