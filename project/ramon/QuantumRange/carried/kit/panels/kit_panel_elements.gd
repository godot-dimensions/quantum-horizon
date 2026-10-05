@tool
extends RefCounted

## Kit: the wall panels' elements, each one a node of its own (the handoff: "implement text, icons,
## chart elements and controls as individually addressable elements"; "no rasterized panel images
## in the game"). A panel (kit_panel_page.gd) builds its layout from these, named after the Figma's
## layers, so "Header/Section label" or "Story/02/Title" can be found, read and changed by name.
##
## Geometry is in Figma units (kit_panel_spec.gd); an element is drawn at `k` pixels a unit.
## `rise` and `fade` let a page bring its parts in one after another (kit_panel_page.gd animate).
##
##   Text      one role, one token, wrapped to its width; never shrunk (overflow is reported)
##   Rule      a hairline or a divider
##   Surface   a rounded card
##   Icon      a control's icon (kit_panel_icons.gd), lit when its control is used
##   StoryRow  number, title and line of one part of a story: done, now (underlined), or later
##   Metric    a figure and what it measures
##   Bars      the build-step bar chart, its steps, its axis, the lit bar's count
##   Table     column heads and rows, the current row marked
##
## NO class_name (engine_gotchas.md).

const Spec := preload("res://ramon/QuantumRange/carried/kit/panels/kit_panel_spec.gd")
const Icons := preload("res://ramon/QuantumRange/carried/kit/panels/kit_panel_icons.gd")


static func ease_out(x: float) -> float:
	var u: float = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - u, 3.0)


## Every element: placed and sized in units.
class El extends Control:
	var k: float = Spec.PPU
	var u_pos: Vector2 = Vector2.ZERO
	var u_size: Vector2 = Vector2.ZERO
	## Arrival order on its page (-1: always shown as is).
	var stagger: int = -1
	## Units it sits below its place while arriving, and its opacity (set by its page).
	var rise: float = 0.0:
		set(v):
			rise = v
			position = (u_pos + Vector2(0.0, rise)) * k

	func _init(nm: String = "", px_per_unit: float = Spec.PPU) -> void:
		if not nm.is_empty():
			name = nm
		k = px_per_unit
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func place(pos_u: Vector2, size_u: Vector2) -> El:
		u_pos = pos_u
		u_size = size_u
		position = (pos_u + Vector2(0.0, rise)) * k
		size = size_u * k
		queue_redraw()
		return self


## One role, one token. Wrapped to its width over at most `max_lines`; text that would need more is
## cut at the last line and `overflow` set, never made smaller (rule 2).
class Text extends El:
	var role: String = "body"
	var token: String = "white"
	var alpha: float = 1.0
	var align: int = HORIZONTAL_ALIGNMENT_LEFT
	var max_lines: int = 1
	var underline: float = 0.0          # 0..1: how much of an accent underline is drawn solid
	var underline_token: String = "accent"
	var overflow: bool = false
	var text: String = ""
	var _lines: PackedStringArray = PackedStringArray()

	func setup(r: String, tok: String = "white", lines: int = 1, al: int = HORIZONTAL_ALIGNMENT_LEFT) -> Text:
		role = r
		token = tok
		max_lines = lines
		align = al
		return self

	func set_text(t: String) -> void:
		if t == text and not _lines.is_empty():
			return
		text = t
		_wrap()
		queue_redraw()

	func set_token(tok: String, a: float = 1.0) -> void:
		if tok == token and is_equal_approx(a, alpha):
			return
		token = tok
		alpha = a
		queue_redraw()

	func px() -> int:
		return maxi(1, int(round(Spec.size_of(role) * k)))

	## Lines it takes now.
	func lines() -> int:
		return _lines.size()

	## Its height in units: its lines times its role's line height.
	func height_u() -> float:
		return float(maxi(1, _lines.size())) * Spec.line_of(role)

	## Width of its widest line, units.
	func width_u() -> float:
		var f: Font = Spec.font(role)
		var w: float = 0.0
		for ln in _lines:
			w = maxf(w, f.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, px()).x)
		return w / k

	func _wrap() -> void:
		_lines = PackedStringArray()
		overflow = false
		if text.is_empty():
			return
		var f: Font = Spec.font(role)
		var para := TextParagraph.new()
		para.add_string(text, f, px())
		para.width = maxf(1.0, u_size.x * k) if u_size.x > 0.0 else -1.0
		para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
		var n: int = para.get_line_count()
		for i in n:
			var r: Vector2i = para.get_line_range(i)
			var ln: String = text.substr(r.x, r.y - r.x).strip_edges(false, true).replace("\n", "")
			if i >= max_lines:
				overflow = true
				break
			_lines.append(ln)
		if overflow:
			push_warning("Wall panel: \"%s\" needs more than %d line(s) in the %s role; shorten it (it is never shrunk)." % [text.left(48), max_lines, role])

	func place(pos_u: Vector2, size_u: Vector2) -> El:
		super(pos_u, size_u)
		if not text.is_empty():
			_wrap()
		return self

	func _draw() -> void:
		if _lines.is_empty():
			return
		var f: Font = Spec.font(role)
		var p: int = px()
		var lh: float = Spec.line_of(role) * k
		var asc: float = f.get_ascent(p)
		var desc: float = f.get_descent(p)
		var col: Color = Spec.ink(token, alpha)
		for i in _lines.size():
			# Figma's line box: the font's ascent-to-descent block centred in the line height.
			var base: float = float(i) * lh + (lh - (asc + desc)) * 0.5 + asc
			if _lines[i].begins_with("●"):
				# Montserrat has no ●, and a fallback font's differs from machine to machine: the dot is
				# drawn, at the size and advance the Figma's has.
				var rest: String = _lines[i].substr(1)
				var adv: float = 0.85 * float(p)
				var total: float = adv + f.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, p).x
				var x0: float = 0.0
				if align == HORIZONTAL_ALIGNMENT_RIGHT:
					x0 = size.x - total
				elif align == HORIZONTAL_ALIGNMENT_CENTER:
					x0 = (size.x - total) * 0.5
				draw_circle(Vector2(x0 + 0.35 * float(p), base - 0.36 * float(p)), 0.35 * float(p), col, true, -1.0, true)
				draw_string(f, Vector2(x0 + adv, base), rest, HORIZONTAL_ALIGNMENT_LEFT, -1.0, p, col)
				continue
			draw_string(f, Vector2(0.0, base), _lines[i], align, size.x if align != HORIZONTAL_ALIGNMENT_LEFT else -1.0, p, col)
			if underline > 0.0 and i == 0:
				var w: float = f.get_string_size(_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, p).x
				var uy: float = base + maxf(1.0, f.get_underline_position(p))
				var th: float = maxf(1.0, f.get_underline_thickness(p))
				draw_rect(Rect2(0.0, uy, w, th), Spec.ink(underline_token, 0.35 * alpha))
				draw_rect(Rect2(0.0, uy, w * clampf(underline, 0.0, 1.0), th), Spec.ink(underline_token, alpha))


## A hairline or a divider: its whole rect in one token.
class Rule extends El:
	var token: String = "rule"

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Spec.ink(token))


## A rounded card.
class Surface extends El:
	var token: String = "surface"
	var radius: float = Spec.CHART_RADIUS
	var square_bottom: bool = false

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Spec.ink(token)
		sb.set_corner_radius_all(int(round(radius * k)))
		if square_bottom:
			sb.corner_radius_bottom_left = 0
			sb.corner_radius_bottom_right = 0
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(Vector2.ZERO, size))


## A control's icon; `lit` (0..1) turns it to the accent when its control is used.
class Icon extends El:
	var kind: String = "wheel"
	var token: String = "white"
	var lit: float = 0.0:
		set(v):
			if not is_equal_approx(v, lit):
				lit = v
				queue_redraw()

	func _draw() -> void:
		Icons.draw(self, kind, Rect2(Vector2.ZERO, size), Spec.ink(token).lerp(Spec.ink("accent"), clampf(lit, 0.0, 1.0)))


## One part of a story: "01   The Balls   placed by a designer". Done: white. Now: the title in the
## accent, underlined (solid as far as the part has played). Later: the whole row at 65%.
class StoryRow extends El:
	var number_t: Text
	var title_t: Text
	var line_t: Text

	func build() -> StoryRow:
		var cols: Array = Spec.STORY_COLS
		number_t = Text.new("Number", k).setup("micro", "muted")
		title_t = Text.new("Title", k).setup("small", "white")
		line_t = Text.new("Line", k).setup("micro", "muted", 1, HORIZONTAL_ALIGNMENT_RIGHT)
		add_child(number_t)
		add_child(title_t)
		add_child(line_t)
		number_t.place(Vector2(0, 0), Vector2(cols[0], 10))
		title_t.place(Vector2(cols[0] + Spec.STEP, 0), Vector2(cols[1], 14))
		line_t.place(Vector2(cols[0] + cols[1] + Spec.STEP * 2.0, 0), Vector2(cols[2], 10))
		return self

	func set_row(n: int, title: String, line: String, state: String, progress: float = 1.0) -> void:
		number_t.set_text("%02d" % n)
		title_t.set_text(title)
		line_t.set_text(line)
		var a: float = Spec.STORY_LATER_ALPHA if state == "later" else 1.0
		number_t.set_token("muted", a)
		line_t.set_token("muted", a)
		title_t.set_token("accent" if state == "now" else "white", a)
		var ul: float = clampf(progress, 0.0, 1.0) if state == "now" else 0.0
		if not is_equal_approx(ul, title_t.underline):
			title_t.underline = ul
			title_t.queue_redraw()


## A figure and what it measures, as frame 01's "14,240 / tetrahedra in the finished body".
class Metric extends El:
	var value_t: Text
	var label_t: Text

	func build() -> Metric:
		value_t = Text.new("Value", k).setup("value", "white")
		label_t = Text.new("Explanation", k).setup("micro", "muted", 2)
		add_child(value_t)
		add_child(label_t)
		value_t.place(Vector2.ZERO, Vector2(u_size.x, 30))
		label_t.place(Vector2(0, Spec.METRIC_LABEL_DY), Vector2(u_size.x, 20))
		return self

	func set_metric(value: String, label: String, accent: bool, known: bool = true) -> void:
		value_t.set_text(value if known else "measuring")
		value_t.set_token("accent" if accent and known else ("white" if known else "muted"))
		label_t.set_text(label)


## Frame 01's build-step chart: a bar for each step, the step on show in the accent with its count
## over it, the steps numbered under, the axis on the left. `grow` (0..1 each) brings bars in.
class Bars extends El:
	var values: Array = []
	var lit: int = -1
	var grow: Array = []
	var _texts: Array = []

	func set_bars(v: Array, lit_i: int, grow_v: Array) -> void:
		values = v
		lit = lit_i
		grow = grow_v
		_relabel()
		queue_redraw()

	func _top() -> float:
		var top: float = 1.0
		for x in values:
			top = maxf(top, float(x))
		return top

	## The plot's floor and the height of the tallest bar, units.
	func _floor_y() -> float:
		return Spec.PLOT.end.y

	func _max_h() -> float:
		return Spec.PLOT.size.y - Spec.PLOT_PAD

	func _bar_x(i: int, n: int) -> float:
		# Bars from the plot's left padding, BAR_GAP apart; more than seven narrow to fit.
		var w: float = _bar_w(n)
		var gap: float = Spec.BAR_GAP if n <= 7 else (Spec.PLOT.size.x - Spec.PLOT_PAD * 2.0 - w * float(n)) / maxf(1.0, float(n - 1))
		return Spec.PLOT.position.x + Spec.PLOT_PAD + float(i) * (w + gap)

	func _bar_w(n: int) -> float:
		if n <= 7:
			return Spec.BAR_W
		return (Spec.PLOT.size.x - Spec.PLOT_PAD * 2.0) / float(n) * 0.7

	func _relabel() -> void:
		for t in _texts:
			(t as Node).queue_free()
		_texts = []
		var n: int = values.size()
		if n == 0:
			return
		var top: float = _top()
		for i in n:
			var t := Text.new("Step %d" % (i + 1), k).setup("micro", "muted", 1, HORIZONTAL_ALIGNMENT_CENTER)
			add_child(t)
			t.place(Vector2(_bar_x(i, n), Spec.BAR_LABEL_Y), Vector2(_bar_w(n), 10))
			t.set_text(str(i + 1))
			_texts.append(t)
		# The axis: 0, and round steps up to the top, labelled as the Figma's.
		var nice: float = pow(10.0, floor(log(top) / log(10.0)))
		var step_v: float = nice * (1.0 if top / nice < 2.5 else (2.0 if top / nice < 5.0 else 5.0)) * 0.5
		var v: float = 0.0
		while v <= top * 1.001:
			var y: float = _floor_y() - _max_h() * v / top
			var t2 := Text.new("Axis %d" % int(v), k).setup("tiny", "muted")
			add_child(t2)
			t2.place(Vector2(Spec.AXIS_X, clampf(y - 5.0, 0.0, _floor_y() - 9.0)), Vector2(28, 10))
			t2.set_text(_thousands(int(v)))
			_texts.append(t2)
			v += step_v
		# The lit bar's count over it.
		var li: int = lit if lit >= 0 and lit < n else n - 1
		var h: float = _max_h() * float(values[li]) / top
		var t3 := Text.new("Final count", k).setup("micro", "white", 1, HORIZONTAL_ALIGNMENT_CENTER)
		add_child(t3)
		t3.place(Vector2(_bar_x(li, n) - 20.0, _floor_y() - h - 12.0), Vector2(_bar_w(n) + 40.0, 10))
		t3.set_text(_thousands(int(values[li])))
		_texts.append(t3)

	func _draw() -> void:
		var n: int = values.size()
		if n == 0:
			return
		var top: float = _top()
		var li: int = lit if lit >= 0 and lit < n else n - 1
		for i in n:
			var g: float = float(grow[i]) if i < grow.size() else 1.0
			var h: float = _max_h() * float(values[i]) / top * g
			if h <= 0.01:
				continue
			var r := Rect2(Vector2(_bar_x(i, n), _floor_y() - h), Vector2(_bar_w(n), h))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Spec.ink("accent" if i == li else "muted")
			sb.set_corner_radius_all(int(round(Spec.BAR_RADIUS * k)))
			sb.anti_aliasing = true
			draw_style_box(sb, Rect2(r.position * k, r.size * k))
		for t in _texts:
			if String((t as Node).name) == "Final count":
				(t as Text).alpha = 1.0 if (float(grow[li]) if li < grow.size() else 1.0) > 0.99 else 0.0
				(t as Text).queue_redraw()

	static func _thousands(n: int) -> String:
		var s: String = str(absi(n))
		var out: String = ""
		while s.length() > 3:
			out = "," + s.right(3) + out
			s = s.left(s.length() - 3)
		return ("-" if n < 0 else "") + s + out


## Column heads and rows; the current row's first cell gets a ● (frame 01's benchmark).
class Table extends El:
	var widths: Array = Spec.TABLE_COLS
	var _heads: Array = []
	var _rows: Array = []

	func set_table(heads: Array, rows: Array, current: int) -> void:
		var n: int = widths.size()
		while _heads.size() < n:
			var t := Text.new("Head %d" % _heads.size(), k).setup("fine", "muted")
			add_child(t)
			_heads.append(t)
		var x: float = 0.0
		for i in n:
			(_heads[i] as Text).place(Vector2(x, 0), Vector2(widths[i], 10))
			(_heads[i] as Text).set_text(String(heads[i]) if i < heads.size() else "")
			x += float(widths[i])
		var shown: int = mini(rows.size(), Spec.TABLE_ROWS)
		while _rows.size() < shown:
			var cells: Array = []
			for i in n:
				var t := Text.new("Row %d/%d" % [_rows.size() + 1, i], k).setup("micro", "white")
				add_child(t)
				cells.append(t)
			_rows.append(cells)
		for r in _rows.size():
			var x2: float = 0.0
			for i in n:
				var t: Text = _rows[r][i]
				t.visible = r < shown
				if r >= shown:
					continue
				t.place(Vector2(x2, Spec.TABLE_ROW_DY - Spec.TABLE_HEAD_DY + float(r) * Spec.TABLE_ROW_PITCH), Vector2(widths[i], 10))
				var cell: String = String(rows[r][i]) if i < (rows[r] as Array).size() else ""
				t.set_text(("● " + cell) if i == 0 and r == current else cell)
				x2 += float(widths[i])
