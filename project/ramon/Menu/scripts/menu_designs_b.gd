extends RefCounted

## THE SECOND ROUND of menu_final's design review (designs 10 to 19, 8 Oct 2026).
##
## Ramon, 8 Oct: "number 7 was the most intresting"; "all white options, and all near black
## options ... dont mix this black and white together stuff"; "keep the left outline right panel
## system, and also the system from number 7 can be tackled again. but this time, make a better
## relation to how the different protos fit in the menu".
##
## So every design here comes in one palette at a time (B: white, or near black, set into the
## style by menu_final.gd), and each tries to show how the prototypes fit:
##   - which group (or RFP question) each one belongs to,
##   - where its system turns up in the playable world (`MenuEntry.world_link`),
##   - the order to see them in, ending in the world.
##
## 10 to 14 keep the list on the left and the details on the right; 15 to 19 rework number 7's
## board in five ways (a board, a stack, a hub, a matrix, a journey).
##
## Everything is built from menu_final's own pieces (rows go into its `_rows`, the world's card
## is its `_hero_panel`, the details are its `_build_detail_column()`), so selection, the arrow
## keys, launching and the way home work the same as in every other design. NO class_name: the
## menu preloads it, and it goes when the review ends.

var m: Control


func _init(menu: Control) -> void:
	m = menu


# --------------------------------------------------------------------------------------------
# Tokens: one palette at a time, read from the style menu_final has set
# --------------------------------------------------------------------------------------------

func light() -> bool:
	return bool(m.get("_light"))


func ink() -> Color:
	return m.style.text


func dim() -> Color:
	return m.style.text_dim


func faint() -> Color:
	return m.style.text_faint


func panel() -> Color:
	return m.style.surface


func lit() -> Color:
	return m.style.surface_raised


func line(strong: bool = false) -> Color:
	return Color(m.style.text, 0.20 if strong else 0.08)


## The code blue of both rooms.
func blue() -> Color:
	return Color(0.13, 0.40, 0.86)


## Kickers and links: the code blue on white, the lab's UI_ACCENT on black.
func kicker() -> Color:
	return blue() if light() else Color(0.40, 0.76, 1.0)


## A group's colour, darkened on white so its type stays readable.
func gink(group: int) -> Color:
	if group < m._systems.size():
		var c: Color = m._group_color(group)
		return c.darkened(0.38) if light() else c
	return dim()


func lbl(text: String, step: int, color: Color, tracked: bool = false) -> Label:
	return m._label(text, step, color, tracked)


func heavy(label: Label) -> Label:
	m._heavy(label)
	return label


func space(units: float) -> int:
	return m.style.space(units)


func px(pixels: float) -> float:
	return m.style.scaled(pixels)


func gap(box: Container, units: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(space(units), space(units))
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(g)


func hairline(strong: bool = false) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size.y = 2 if strong else 1
	r.color = line(strong)
	return r


func box(fill: Color, radius: int = 10, edge: Color = Color(0, 0, 0, 0), edge_width: int = 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	if edge_width > 0:
		b.border_color = edge
		b.set_border_width_all(edge_width)
	# The content keeps its own margins, so borders never push it about.
	b.content_margin_left = 0
	b.content_margin_right = 0
	b.content_margin_top = 0
	b.content_margin_bottom = 0
	return b


func cap_first(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1) if text != "" else ""


func world_link(index: int) -> String:
	var entry: Resource = m._entry(index)
	if entry == null:
		return ""
	var link = entry.get("world_link")
	return String(link) if link != null else ""


## Where only the idea turns up in the world (no shared code); see MenuEntry.world_idea.
func world_idea(index: int) -> String:
	var entry: Resource = m._entry(index)
	if entry == null:
		return ""
	var idea = entry.get("world_idea")
	return String(idea) if idea != null else ""


## The relation in a few words, and how strongly to set it: the system itself in the world
## (dim ink), only its idea ("idea: ...", faint), or nothing yet.
func relation_text(index: int) -> String:
	# A film's relation is its length, unless it was shot in the world.
	var entry: Resource = m._entry(index)
	if entry != null and String(entry.get("section")) == "Cinematic" and world_link(index) == "":
		var length: String = String(entry.get("duration"))
		return "film  ·  " + length if length != "" else "film"
	if world_link(index) != "":
		return world_link(index)
	if world_idea(index) != "":
		return "idea: " + world_idea(index)
	return "not in the world yet"


func relation_ink(index: int) -> Color:
	return dim() if world_link(index) != "" else faint()


## The ground of the room: in white the Creation Lab's grey mood (a light grid with its little
## crosses), in near black its black mood (a faint grid only).
func draw_ground(node: Control) -> void:
	var step: float = 56.0
	var grid: Color = Color(0.06, 0.09, 0.15, 0.05) if light() else Color(1, 1, 1, 0.035)
	var x: float = 0.0
	while x <= node.size.x:
		node.draw_line(Vector2(x, 0), Vector2(x, node.size.y), grid, 1.0)
		x += step
	var y: float = 0.0
	while y <= node.size.y:
		node.draw_line(Vector2(0, y), Vector2(node.size.x, y), grid, 1.0)
		y += step
	if light():
		var cross: Color = Color(0.06, 0.09, 0.15, 0.13)
		var cx: float = step * 2.0
		while cx < node.size.x:
			var cy: float = step * 2.0
			while cy < node.size.y:
				node.draw_line(Vector2(cx - 5, cy), Vector2(cx + 5, cy), cross, 1.0)
				node.draw_line(Vector2(cx, cy - 5), Vector2(cx, cy + 5), cross, 1.0)
				cy += step * 4.0
			cx += step * 4.0


## The details, in the second round: the palette's own panel, a hairline edge, rounder corners.
func pane_box() -> StyleBoxFlat:
	return box(panel(), 14, line(), 1)


# --------------------------------------------------------------------------------------------
# Rows and the world's card, shared by every design
# --------------------------------------------------------------------------------------------

## A clickable prototype: it goes into menu_final's `_rows`, so the menu selects, hovers,
## launches and walks it like any row.
func row_panel(index: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(m._on_row_input.bind(index))
	p.mouse_entered.connect(m._on_row_hover.bind(index, true))
	p.mouse_exited.connect(m._on_row_hover.bind(index, false))
	m._rows[index] = p
	p.add_theme_stylebox_override("panel", row_box(index, false, false))
	return p


## How a row is drawn per design: flat lines (10, 12, 18), round pills (17), or cards.
func row_box(index: int, chosen: bool, hovered: bool) -> StyleBoxFlat:
	var group: int = m._group_of(m._entry(index))
	var bar: Color = gink(group) if group < m._systems.size() else kicker()
	match int(m.design):
		10, 12, 18:
			var b := box(lit() if chosen else (Color(lit(), lit().a * 0.55) if hovered else Color(0, 0, 0, 0)), 6)
			if chosen:
				b.border_color = bar
				if int(m.design) == 10:
					b.border_width_bottom = 2
				else:
					b.border_width_left = 3
			return b
		17:
			var b := box(Color(bar, 0.16) if chosen else (lit() if hovered else panel()), 999, bar if chosen else line(true), 2 if chosen else 1)
			return b
		_:
			var b := box(lit() if chosen or hovered else panel(), 10, line(), 1)
			if chosen:
				b.border_color = bar
				b.set_border_width_all(2)
				b.border_width_left = 4
			return b


## A row's words: title (ExtraBold), optionally the kicker line, the blurb, and the world link.
func row_words(index: int, title_step: int, with_blurb: bool, with_link: bool, wrap: bool = false) -> VBoxContainer:
	var entry: Resource = m._entry(index)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", space(0.3))
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := heavy(lbl(String(entry.get("title")).to_upper(), title_step, ink()))
	if wrap:
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(title)
	if with_blurb:
		var b := lbl(String(entry.get("blurb")), MenuStyle.CAPTION, dim())
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = px(120)
		words.add_child(b)
	var link: String = world_link(index)
	if with_link and link != "":
		var l := lbl("IN THE WORLD  ·  " + link.to_upper(), MenuStyle.MICRO, kicker(), true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(l)
	elif with_link and world_idea(index) != "":
		var l := lbl("THE IDEA, IN THE WORLD  ·  " + world_idea(index).to_upper(), MenuStyle.MICRO, faint(), true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.add_child(l)
	return words


## A card: words in a padded panel.
func card(index: int, title_step: int = MenuStyle.BODY, with_blurb: bool = true, with_link: bool = true, wrap: bool = false) -> PanelContainer:
	var p := row_panel(index)
	var pad := MarginContainer.new()
	m._set_margins(pad, space(1.6), space(1.1))
	p.add_child(pad)
	pad.add_child(row_words(index, title_step, with_blurb, with_link, wrap))
	return p


## The world's card: code blue in both palettes (the rooms' own blue), white type, the system
## marks. It is menu_final's `_hero_panel`, so clicking it does what the banner does.
func world_card(compact: bool = false, title_text: String = "") -> PanelContainer:
	var card_panel := PanelContainer.new()
	card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	card_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card_panel.gui_input.connect(m._on_hero_input)
	m._hero_panel = card_panel
	card_panel.add_theme_stylebox_override("panel", hero_box(false))
	var pad := MarginContainer.new()
	m._set_margins(pad, space(2.5), space(1.75))
	card_panel.add_child(pad)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", space(0.4))
	pad.add_child(words)
	var heading: String = m.catalogue.hero_heading
	var subtitle: String = ""
	var hero: Resource = m.catalogue.hero
	if hero != null:
		subtitle = String(hero.get("blurb"))
	if m._laptop_trip() != null:
		heading = m.catalogue.hero_return_heading
		subtitle = m.catalogue.hero_return_subtitle
	if title_text != "":
		words.add_child(lbl(title_text, MenuStyle.MICRO, Color(1, 1, 1, 0.72), true))
	var title := heavy(lbl(heading, MenuStyle.SUBTITLE if compact else MenuStyle.TITLE, Color(1, 1, 1)))
	if compact:
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(title)
	var sub := lbl(subtitle, MenuStyle.CAPTION if compact else MenuStyle.BODY, Color(1, 1, 1, 0.86))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(sub)
	var marks := HBoxContainer.new()
	marks.add_theme_constant_override("separation", space(0.6))
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for g in m._systems.size():
		marks.add_child(m._system_mark(g, Color(1, 1, 1, 0.9), px(20)))
	words.add_child(marks)
	return card_panel


## The world as one slim bar: name, line and marks on one row (the question board's foot).
func world_bar(kicker_text: String) -> PanelContainer:
	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bar.gui_input.connect(m._on_hero_input)
	m._hero_panel = bar
	bar.add_theme_stylebox_override("panel", hero_box(false))
	var pad := MarginContainer.new()
	m._set_margins(pad, space(2.5), space(1.1))
	bar.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", space(2))
	pad.add_child(row)
	var heading: String = m.catalogue.hero_heading if m._laptop_trip() == null else m.catalogue.hero_return_heading
	var title := heavy(lbl(heading, MenuStyle.SUBTITLE, Color(1, 1, 1)))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var k := lbl(kicker_text, MenuStyle.MICRO, Color(1, 1, 1, 0.75), true)
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	for g in m._systems.size():
		row.add_child(m._system_mark(g, Color(1, 1, 1, 0.9), px(20)))
	return bar


func hero_box(chosen: bool) -> StyleBoxFlat:
	var b := box(blue().lightened(0.08) if chosen else blue(), 14)
	if chosen:
		b.border_color = Color(1, 1, 1)
		b.border_width_left = 4
	return b


## The list column (620 px, as in the first round) with its scroller; returns the rows box.
func list_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = px(620)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", space(1.75))
	return column


func scroll_rows(column: VBoxContainer, separation: int = 0) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	m._list_scroll = scroll
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", separation)
	scroll.add_child(rows)
	return rows


func hint(column: VBoxContainer) -> void:
	column.add_child(lbl(m.catalogue.hint, MenuStyle.MICRO, dim()))


## A group's head as kicker and question: "LIVE IT" over "Can ordinary players ...?".
func group_head(group: int, question_step: int = MenuStyle.BODY, on_blue: bool = false) -> VBoxContainer:
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", space(0.3))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", space(0.9))
	head.add_child(top)
	var k: Color = Color(1, 1, 1, 0.78) if on_blue else gink(group)
	if group < m._systems.size():
		top.add_child(m._system_mark(group, Color(1, 1, 1) if on_blue else gink(group), px(18)))
	var name_label := lbl(m._group_label(group), MenuStyle.CAPTION, k, true)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_label)
	var question: String = m._group_line(group)
	if question != "":
		var q := heavy(lbl(cap_first(question), question_step, Color(1, 1, 1) if on_blue else ink()))
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.add_child(q)
	return head


func groups() -> Array:
	return m._groups_in_order()


func is_films(group: int) -> bool:
	return group == m.GROUP_FILMS


# --------------------------------------------------------------------------------------------
# The ten designs
# --------------------------------------------------------------------------------------------

func build(host: MarginContainer) -> void:
	_pane_rows.clear()
	_pane_tabs.clear()
	match int(m.design):
		10:
			_list_and_details(host, _research_list)
		11:
			_list_and_details(host, _plaques)
		12:
			_list_and_details(host, _chapters)
		13:
			_three_panes(host)
		14:
			_list_and_details(host, _world_first)
		15:
			_question_board(host)
		16:
			_side_and_details(host, _stack)
		17:
			_side_and_details(host, _hub)
		18:
			_side_and_details(host, _matrix)
		19:
			_journey(host)


func _list_and_details(host: MarginContainer, filler: Callable) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", space(4))
	host.add_child(columns)
	var column := list_column()
	columns.add_child(column)
	filler.call(column)
	columns.add_child(m._build_detail_column())


## The board family's left side wider than the details on the right.
func _side_and_details(host: MarginContainer, filler: Callable) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", space(3))
	host.add_child(columns)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.2
	side.add_theme_constant_override("separation", space(1.5))
	columns.add_child(side)
	filler.call(side)
	var details: Control = m._build_detail_column()
	details.size_flags_stretch_ratio = 1.0
	columns.add_child(details)


## 10 · The research wall's story list (CreationLab research wall: "01 The Balls ... placed by a
## designer"): each group a kicker and its question over a heavy rule, its prototypes numbered,
## where each lives in the world set right like the wall's grey descriptor. The selected one is
## underlined in its group's colour, as the wall underlines the part that is playing.
func _research_list(column: VBoxContainer) -> void:
	column.add_child(world_card())
	var rows := scroll_rows(column)
	var first: bool = true
	for chunk in groups():
		var group: int = int(chunk[0])
		if not first:
			gap(rows, 3.0)
		first = false
		rows.add_child(group_head(group, MenuStyle.SUBTITLE))
		gap(rows, 0.8)
		rows.add_child(hairline(true))
		var ids: Array = chunk[1]
		for k in ids.size():
			if k > 0:
				rows.add_child(hairline())
			var i: int = int(ids[k])
			var p := row_panel(i)
			var pad := MarginContainer.new()
			m._set_margins(pad, space(0.75), space(1.1))
			p.add_child(pad)
			var line_box := HBoxContainer.new()
			line_box.add_theme_constant_override("separation", space(1.5))
			pad.add_child(line_box)
			var number := lbl("%02d" % m._run_number(i) if not is_films(group) else "·", MenuStyle.CAPTION, faint(), true)
			number.custom_minimum_size.x = px(30)
			line_box.add_child(number)
			var title := heavy(lbl(String(m._entry(i).get("title")).to_upper(), MenuStyle.SUBTITLE, ink()))
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_box.add_child(title)
			var note := lbl(relation_text(i), MenuStyle.CAPTION, relation_ink(i))
			note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line_box.add_child(note)
			rows.add_child(p)
	hint(column)


## 11 · Blue plaques: the lab's rule, blue for what teaches. Each group's name and question on a
## code-blue plaque, its prototypes as cards beneath, each saying where it lives in the world.
func _plaques(column: VBoxContainer) -> void:
	column.add_child(world_card())
	var rows := scroll_rows(column, space(0.75))
	var first: bool = true
	for chunk in groups():
		var group: int = int(chunk[0])
		if not first:
			gap(rows, 2.0)
		first = false
		var plaque := PanelContainer.new()
		plaque.add_theme_stylebox_override("panel", box(blue() if not is_films(group) else lit(), 10))
		var pad := MarginContainer.new()
		m._set_margins(pad, space(2), space(1.25))
		plaque.add_child(pad)
		pad.add_child(group_head(group, MenuStyle.SUBTITLE, not is_films(group)))
		rows.add_child(plaque)
		for i in chunk[1]:
			rows.add_child(card(int(i), MenuStyle.SUBTITLE))
	hint(column)


## 12 · Chapters: the run read as a book. A big chapter number by each group, the world as the
## last chapter ("then, all of it together"), the films after as extras.
func _chapters(column: VBoxContainer) -> void:
	var rows := scroll_rows(column)
	var n: int = 0
	var films: Array = []
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			films = chunk
			continue
		n += 1
		rows.add_child(_chapter(n, group_head(group, MenuStyle.SUBTITLE), chunk[1]))
		gap(rows, 2.5)
	var world := VBoxContainer.new()
	world.add_theme_constant_override("separation", space(0.75))
	world.add_child(lbl("THE WORLD", MenuStyle.CAPTION, kicker(), true))
	world.add_child(heavy(lbl("Then, all of it together", MenuStyle.SUBTITLE, ink())))
	world.add_child(world_card())
	rows.add_child(_chapter(n + 1, world, []))
	if not films.is_empty():
		gap(rows, 2.5)
		var extras := VBoxContainer.new()
		extras.add_child(lbl(m._group_label(m.GROUP_FILMS), MenuStyle.CAPTION, dim(), true))
		rows.add_child(_chapter(-1, extras, films[1]))
	hint(column)


func _chapter(n: int, head: Control, ids: Array) -> HBoxContainer:
	var chapter := HBoxContainer.new()
	chapter.add_theme_constant_override("separation", space(2))
	var numeral := lbl("%02d" % n if n > 0 else "", 5, faint())
	numeral.custom_minimum_size.x = px(78)
	numeral.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chapter.add_child(numeral)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	chapter.add_child(body)
	body.add_child(head)
	if not ids.is_empty():
		gap(body, 0.75)
	for k in ids.size():
		if k > 0:
			body.add_child(hairline())
		var i: int = int(ids[k])
		var p := row_panel(i)
		var pad := MarginContainer.new()
		m._set_margins(pad, space(1), space(0.9))
		p.add_child(pad)
		pad.add_child(row_words(i, MenuStyle.BODY, true, true))
		body.add_child(p)
	return chapter


## 13 · Three panes, left to right: the groups (with the world over them), one group's
## prototypes as big cards, then the details. The relation is the hierarchy itself.
var _pane_rows: Dictionary = {}
var _pane_tabs: Dictionary = {}
var _pane_title: Label = null


func _three_panes(host: MarginContainer) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", space(3))
	host.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = px(250)
	left.add_theme_constant_override("separation", space(1))
	columns.add_child(left)
	left.add_child(world_card(true))
	gap(left, 1.0)
	for chunk in groups():
		var group: int = int(chunk[0])
		var tab := PanelContainer.new()
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.gui_input.connect(_on_pane_tab.bind(group))
		var pad := MarginContainer.new()
		m._set_margins(pad, space(1.5), space(1.1))
		tab.add_child(pad)
		var head := group_head(group, MenuStyle.CAPTION)
		var count: int = (chunk[1] as Array).size()
		var noun: String = ("FILM" if is_films(group) else "PROTOTYPE") + ("" if count == 1 else "S")
		head.add_child(lbl("%d %s" % [count, noun], MenuStyle.MICRO, faint(), true))
		pad.add_child(head)
		left.add_child(tab)
		_pane_tabs[group] = tab
	var middle := VBoxContainer.new()
	middle.custom_minimum_size.x = px(430)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", space(1.25))
	columns.add_child(middle)
	_pane_title = heavy(lbl("", MenuStyle.SUBTITLE, ink()))
	_pane_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	middle.add_child(_pane_title)
	var rows := scroll_rows(middle, space(1))
	for chunk in groups():
		for i in chunk[1]:
			var c := card(int(i), MenuStyle.SUBTITLE)
			rows.add_child(c)
			_pane_rows[int(i)] = int(chunk[0])
	hint(middle)
	columns.add_child(m._build_detail_column())
	var entry: Resource = m._selected_entry()
	var start: int = m._group_of(entry) if entry != null and int(m._selected) != m.HERO else int(groups()[0][0])
	open_pane(start, false)


func _on_pane_tab(event: InputEvent, group: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		open_pane(group, true)


func open_pane(group: int, select_first: bool) -> void:
	for g in _pane_tabs:
		var open: bool = int(g) == group
		var b := box(lit() if open else Color(0, 0, 0, 0), 10, gink(int(g)), 0)
		if open:
			b.border_color = gink(int(g))
			b.border_width_left = 4
		(_pane_tabs[g] as Control).add_theme_stylebox_override("panel", b)
	var first_row: int = -1
	for i in _pane_rows:
		var here: bool = int(_pane_rows[i]) == group
		var row: Control = m._rows[int(i)]
		if row != null:
			row.visible = here
		if here and first_row < 0:
			first_row = int(i)
	if _pane_title != null:
		var q: String = m._group_line(group)
		_pane_title.text = cap_first(q) if q != "" else String(m._group_label(group))
	if select_first and first_row >= 0:
		m._select(first_row)


## Called by the menu whenever the selection moves, so a pane follows it.
func follow_selection(group: int) -> void:
	if int(m.design) == 13 and _pane_tabs.has(group):
		open_pane(group, false)


## 14 · World first: the world on top, and under it what it is built from. Every prototype
## whose system lives in the world is a chip naming where (click it to open that prototype's
## details); then all the prototypes, grouped, with their place in the world set right.
func _world_first(column: VBoxContainer) -> void:
	column.add_child(world_card())
	var built := PanelContainer.new()
	built.add_theme_stylebox_override("panel", box(panel(), 12, line(), 1))
	var pad := MarginContainer.new()
	m._set_margins(pad, space(2), space(1.5))
	built.add_child(pad)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", space(1))
	pad.add_child(inside)
	inside.add_child(lbl("IN THE WORLD, FROM THE PROTOTYPES", MenuStyle.MICRO, kicker(), true))
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", space(0.75))
	chips.add_theme_constant_override("v_separation", space(0.75))
	inside.add_child(chips)
	var any: bool = false
	for i in m._order:
		var link: String = world_link(int(i))
		if link == "":
			continue
		any = true
		var chip := Button.new()
		chip.text = "%s  ·  %s" % [cap_first(link), String(m._entry(int(i)).get("title"))]
		chip.focus_mode = Control.FOCUS_NONE
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.add_theme_font_override("font", m.style.font)
		chip.add_theme_font_size_override("font_size", m.style.size_for(MenuStyle.CAPTION))
		var group: int = m._group_of(m._entry(int(i)))
		chip.add_theme_color_override("font_color", ink())
		chip.add_theme_color_override("font_hover_color", ink())
		var idle := box(Color(gink(group), 0.10), 999, Color(gink(group), 0.55), 1)
		idle.content_margin_left = space(1.25)
		idle.content_margin_right = space(1.25)
		idle.content_margin_top = space(0.5)
		idle.content_margin_bottom = space(0.5)
		var hover := idle.duplicate() as StyleBoxFlat
		hover.bg_color = Color(gink(group), 0.20)
		chip.add_theme_stylebox_override("normal", idle)
		chip.add_theme_stylebox_override("hover", hover)
		chip.add_theme_stylebox_override("pressed", hover)
		chip.pressed.connect(m._select.bind(int(i)))
		chips.add_child(chip)
	if not any:
		inside.add_child(lbl("Not linked yet.", MenuStyle.CAPTION, dim()))
	column.add_child(built)
	var rows := scroll_rows(column)
	var first: bool = true
	for chunk in groups():
		var group: int = int(chunk[0])
		gap(rows, 0.5 if first else 2.0)
		first = false
		rows.add_child(group_head(group, MenuStyle.CAPTION))
		gap(rows, 0.5)
		for i in chunk[1]:
			var p := row_panel(int(i))
			var row_pad := MarginContainer.new()
			m._set_margins(row_pad, space(1), space(0.8))
			p.add_child(row_pad)
			var line_box := HBoxContainer.new()
			line_box.add_theme_constant_override("separation", space(1.5))
			row_pad.add_child(line_box)
			var title := heavy(lbl(String(m._entry(int(i)).get("title")).to_upper(), MenuStyle.BODY, ink()))
			title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_box.add_child(title)
			var note := lbl(relation_text(int(i)), MenuStyle.CAPTION, relation_ink(int(i)))
			line_box.add_child(note)
			rows.add_child(p)
	hint(column)


## 15 · Number 7 again. A column per group, each headed by its question, its prototypes as cards
## saying where they live in the world; lines from every column run down into the world's bar
## beneath them all ("where all of it runs together"). The details lie sideways below.
func _question_board(host: MarginContainer) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	host.add_child(stack)
	var board := HBoxContainer.new()
	board.add_theme_constant_override("separation", space(2))
	stack.add_child(board)
	for chunk in groups():
		var group: int = int(chunk[0])
		var column := PanelContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_stretch_ratio = 0.62 if is_films(group) else 1.0
		var b := box(panel(), 12, line(), 1)
		b.border_color = gink(group) if not is_films(group) else line(true)
		b.border_width_top = 4
		column.add_theme_stylebox_override("panel", b)
		board.add_child(column)
		var pad := MarginContainer.new()
		m._set_margins(pad, space(1.5), space(1.5))
		column.add_child(pad)
		var inside := VBoxContainer.new()
		inside.add_theme_constant_override("separation", space(1))
		pad.add_child(inside)
		inside.add_child(group_head(group, MenuStyle.BODY))
		inside.add_child(hairline())
		for i in chunk[1]:
			inside.add_child(card(int(i), MenuStyle.BODY, false, true, true))
	var funnel := Control.new()
	funnel.custom_minimum_size.y = px(34)
	funnel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	funnel.draw.connect(_draw_funnel.bind(funnel, board))
	board.resized.connect(funnel.queue_redraw)
	board.sort_children.connect(funnel.queue_redraw)
	stack.add_child(funnel)
	stack.add_child(world_bar("WHERE ALL OF IT RUNS TOGETHER"))
	gap(stack, 2.5)
	var details: Control = m._build_detail_column(true)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(details)


func _draw_funnel(funnel: Control, board: HBoxContainer) -> void:
	var target := Vector2(funnel.size.x * 0.5, funnel.size.y)
	var k: int = 0
	var chunks: Array = groups()
	for child in board.get_children():
		var c := child as Control
		if c == null or k >= chunks.size():
			continue
		var group: int = int(chunks[k][0])
		k += 1
		if is_films(group):
			continue
		var from := Vector2(c.position.x + c.size.x * 0.5, 0.0)
		var mid := Vector2(from.x, funnel.size.y * 0.5)
		var ink_c := Color(gink(group), 0.7)
		funnel.draw_line(from, mid, ink_c, 2.0, true)
		funnel.draw_line(mid, Vector2(lerpf(mid.x, target.x, 0.85), target.y), ink_c, 2.0, true)


## 16 · The stack: the engine at the base, the content made on it, what players read on top,
## and the world as the roof (the RFP's own order: an engine that runs well and that players can
## read is still not a platform if small teams cannot fill it). Each layer holds its prototypes.
func _stack(side: VBoxContainer) -> void:
	side.add_child(world_card(false, "THE ROOF  ·  ALL OF IT TOGETHER"))
	var films: Array = []
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			films = chunk
			continue
		side.add_child(_layer(group, chunk[1]))
	if int(m._taxonomy) == 1:
		var read := lbl("Read from the bottom: the engine, the content made on it, the players reading it, the world on top.", MenuStyle.CAPTION, dim())
		read.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(read)
	if not films.is_empty():
		side.add_child(_layer(m.GROUP_FILMS, films[1]))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(filler)
	hint(side)


func _layer(group: int, ids: Array) -> PanelContainer:
	var layer := PanelContainer.new()
	var b := box(panel(), 12, line(), 1)
	b.border_color = gink(group) if not is_films(group) else line(true)
	b.border_width_left = 5
	layer.add_theme_stylebox_override("panel", b)
	var pad := MarginContainer.new()
	m._set_margins(pad, space(2), space(1.5))
	layer.add_child(pad)
	var line_box := HBoxContainer.new()
	line_box.add_theme_constant_override("separation", space(2))
	pad.add_child(line_box)
	var head := group_head(group, MenuStyle.CAPTION)
	head.custom_minimum_size.x = px(230)
	line_box.add_child(head)
	var tiles := HBoxContainer.new()
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_theme_constant_override("separation", space(1))
	line_box.add_child(tiles)
	for i in ids:
		var c := card(int(i), MenuStyle.BODY, false, true, true)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tiles.add_child(c)
	return layer


## 17 · The hub: the world at the centre, every prototype a spoke around it in its group's
## sector, the spoke solid where its system lives in the world (and labelled where), dashed where
## it does not yet. The relation drawn as a diagram.
func _hub(side: VBoxContainer) -> void:
	var hub := Control.new()
	hub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub.clip_contents = true
	side.add_child(hub)
	var disc := world_card(true)
	disc.custom_minimum_size = Vector2(px(280), 0)
	hub.add_child(disc)
	var nodes: Dictionary = {}
	var labels: Dictionary = {}
	var films: Array = []
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			films = chunk[1]
			continue
		var head := group_head(group, MenuStyle.CAPTION)
		head.custom_minimum_size.x = px(230)
		hub.add_child(head)
		labels[group] = head
		for i in chunk[1]:
			var p := row_panel(int(i))
			var pad := MarginContainer.new()
			m._set_margins(pad, space(1.75), space(0.8))
			p.add_child(pad)
			var words := VBoxContainer.new()
			words.add_theme_constant_override("separation", 0)
			pad.add_child(words)
			words.add_child(heavy(lbl(String(m._entry(int(i)).get("title")).to_upper(), MenuStyle.BODY, ink())))
			words.add_child(lbl(relation_text(int(i)), MenuStyle.MICRO, relation_ink(int(i)), world_link(int(i)) != ""))
			hub.add_child(p)
			nodes[int(i)] = p
	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", space(1))
	if not films.is_empty():
		extras.add_child(lbl(m._group_label(m.GROUP_FILMS), MenuStyle.MICRO, dim(), true))
		for i in films:
			extras.add_child(card(int(i), MenuStyle.CAPTION, false, false))
	side.add_child(extras)
	hint(side)
	hub.set_meta(&"layout", {"disc": disc, "nodes": nodes, "labels": labels})
	hub.resized.connect(_layout_hub.bind(hub))
	hub.draw.connect(_draw_hub.bind(hub))
	_layout_hub.call_deferred(hub)


func _hub_angles() -> Dictionary:
	var out: Dictionary = {}
	var chunks: Array = []
	for chunk in groups():
		if not is_films(int(chunk[0])):
			chunks.append(chunk)
	# Each group's sector is as wide as its share of the prototypes, so a group of four is not
	# squeezed into the same arc as a group of one.
	var total: int = 0
	for chunk in chunks:
		total += (chunk[1] as Array).size()
	var start: float = -PI * 0.5 - PI * float((chunks[0][1] as Array).size()) / float(maxi(1, total)) if not chunks.is_empty() else 0.0
	for k in chunks.size():
		var ids: Array = chunks[k][1]
		var span: float = TAU * float(ids.size()) / float(maxi(1, total))
		out[int(chunks[k][0])] = start + span * 0.5
		for j in ids.size():
			out[-1 - int(ids[j])] = start + span * (float(j) + 0.5) / float(ids.size())
		start += span
	return out


func _layout_hub(hub: Control) -> void:
	if not is_instance_valid(hub) or not hub.has_meta(&"layout"):
		return
	var layout: Dictionary = hub.get_meta(&"layout")
	var centre: Vector2 = hub.size * 0.5
	var disc: Control = layout["disc"]
	disc.size = disc.get_combined_minimum_size()
	disc.position = centre - disc.size * 0.5
	var angles: Dictionary = _hub_angles()
	var radius := Vector2(hub.size.x * 0.37, hub.size.y * 0.36)
	var nodes: Dictionary = layout["nodes"]
	for i in nodes:
		var p: Control = nodes[i]
		p.size = p.get_combined_minimum_size()
		var a: float = float(angles.get(-1 - int(i), 0.0))
		p.position = centre + Vector2(cos(a), sin(a)) * radius - p.size * 0.5
	var labels: Dictionary = layout["labels"]
	for g in labels:
		var head: Control = labels[g]
		head.size = head.get_combined_minimum_size()
		var a: float = float(angles.get(int(g), 0.0))
		var outward := Vector2(cos(a), sin(a))
		var at: Vector2 = centre + outward * radius + outward * Vector2(head.size.x * 0.5 + px(140), head.size.y * 0.5 + px(56)) - head.size * 0.5
		head.position = Vector2(clampf(at.x, 0.0, hub.size.x - head.size.x), clampf(at.y, 0.0, hub.size.y - head.size.y))
	hub.queue_redraw()


func _draw_hub(hub: Control) -> void:
	if not hub.has_meta(&"layout"):
		return
	var layout: Dictionary = hub.get_meta(&"layout")
	var disc: Control = layout["disc"]
	var centre: Vector2 = disc.position + disc.size * 0.5
	var nodes: Dictionary = layout["nodes"]
	for i in nodes:
		var p: Control = nodes[i]
		var at: Vector2 = p.position + p.size * 0.5
		var group: int = m._group_of(m._entry(int(i)))
		var c := Color(gink(group), 0.65)
		# Solid where the prototype itself is in the world, dashed where only its idea is.
		if world_link(int(i)) != "":
			hub.draw_line(at, centre, c, 2.5, true)
		else:
			hub.draw_dashed_line(at, centre, Color(c, 0.55), 2.0, 7.0)


## 18 · The evidence matrix: a row per prototype, a column per RFP question; a filled dot where
## it answers that question, a ring where it also gives evidence for one; and where it lives in
## the world. The world's own row has every dot.
func _matrix(side: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", space(1))
	var name_head := lbl("PROTOTYPE", MenuStyle.MICRO, faint(), true)
	name_head.custom_minimum_size.x = px(300)
	header.add_child(name_head)
	for t in m.THRUSTS.size():
		var head := VBoxContainer.new()
		head.custom_minimum_size.x = px(96)
		head.add_child(lbl(m.THRUST_LABELS[t], MenuStyle.MICRO, _thrust_ink(t), true))
		header.add_child(head)
	header.add_child(lbl("IN THE WORLD", MenuStyle.MICRO, faint(), true))
	side.add_child(header)
	side.add_child(hairline(true))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	side.add_child(rows)
	var first: bool = true
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			continue
		if not first:
			rows.add_child(hairline())
		first = false
		for i in chunk[1]:
			var p := row_panel(int(i))
			var pad := MarginContainer.new()
			m._set_margins(pad, space(0.75), space(0.9))
			p.add_child(pad)
			var line_box := HBoxContainer.new()
			line_box.add_theme_constant_override("separation", space(1))
			pad.add_child(line_box)
			var words := VBoxContainer.new()
			words.custom_minimum_size.x = px(300) - space(0.75)
			words.add_theme_constant_override("separation", 0)
			words.add_child(heavy(lbl(String(m._entry(int(i)).get("title")).to_upper(), MenuStyle.BODY, ink())))
			words.add_child(lbl(String(m._entry(int(i)).get("maturity")).to_upper(), MenuStyle.MICRO, faint(), true))
			line_box.add_child(words)
			for t in m.THRUSTS.size():
				line_box.add_child(_dot_cell(int(i), t))
			var note := lbl(relation_text(int(i)), MenuStyle.CAPTION, relation_ink(int(i)))
			note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_box.add_child(note)
			rows.add_child(p)
	rows.add_child(hairline(true))
	gap(rows, 1.0)
	var world := world_card(false, "THE WORLD  ·  EVERY QUESTION, TOGETHER")
	rows.add_child(world)
	gap(rows, 1.0)
	rows.add_child(lbl("●  answers it      ○  also shows it", MenuStyle.CAPTION, dim()))
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(filler)
	hint(side)


func _thrust_ink(t: int) -> Color:
	var c: Color = m.THRUST_COLORS[t]
	return c.darkened(0.38) if light() else c


func _dot_cell(index: int, t: int) -> Control:
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(px(96), px(30))
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var entry: Resource = m._entry(index)
	var primary: bool = String(entry.get("thrust")) == m.THRUSTS[t]
	var also = entry.get("also_answers")
	var secondary: bool = also != null and (also as PackedStringArray).has(m.THRUSTS[t])
	cell.draw.connect(func() -> void:
		var at := Vector2(px(12), cell.size.y * 0.5)
		var c := _thrust_ink(t)
		if primary:
			cell.draw_circle(at, px(7), c)
		elif secondary:
			cell.draw_arc(at, px(6), 0.0, TAU, 24, c, 2.0, true)
		else:
			cell.draw_circle(at, px(2), line(true))
	)
	return cell


## 19 · The journey: a route left to right, START to THE WORLD, the prototypes as numbered stops
## in the order to see them, each group a band of the route; the films beside it as extras. The
## details lie sideways below.
func _journey(host: MarginContainer) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", space(1.5))
	host.add_child(stack)
	var route := HBoxContainer.new()
	route.add_theme_constant_override("separation", space(1))
	route.custom_minimum_size.y = px(250)
	stack.add_child(route)
	var start := VBoxContainer.new()
	start.alignment = BoxContainer.ALIGNMENT_CENTER
	start.custom_minimum_size.x = px(70)
	start.add_child(lbl("START", MenuStyle.CAPTION, kicker(), true))
	route.add_child(start)
	var films: Array = []
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			films = chunk[1]
			continue
		var band := PanelContainer.new()
		band.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		band.size_flags_stretch_ratio = float((chunk[1] as Array).size())
		var b := box(Color(gink(group), 0.08), 14, Color(gink(group), 0.35), 1)
		band.add_theme_stylebox_override("panel", b)
		route.add_child(band)
		var pad := MarginContainer.new()
		m._set_margins(pad, space(1.25), space(1.25))
		band.add_child(pad)
		var inside := VBoxContainer.new()
		inside.add_theme_constant_override("separation", space(1))
		pad.add_child(inside)
		inside.add_child(group_head(group, MenuStyle.CAPTION))
		var stops := HBoxContainer.new()
		stops.add_theme_constant_override("separation", space(1))
		stops.size_flags_vertical = Control.SIZE_EXPAND_FILL
		inside.add_child(stops)
		for i in chunk[1]:
			var p := row_panel(int(i))
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var stop_pad := MarginContainer.new()
			m._set_margins(stop_pad, space(1.25), space(1))
			p.add_child(stop_pad)
			var words := VBoxContainer.new()
			words.add_theme_constant_override("separation", space(0.3))
			stop_pad.add_child(words)
			words.add_child(lbl("%02d" % m._run_number(int(i)), MenuStyle.SUBTITLE, gink(group)))
			var title := heavy(lbl(String(m._entry(int(i)).get("title")).to_upper(), MenuStyle.CAPTION, ink()))
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			words.add_child(title)
			var l := lbl(relation_text(int(i)), MenuStyle.MICRO, relation_ink(int(i)))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			words.add_child(l)
			stops.add_child(p)
	var world := world_card(true, "THE END OF THE ROUTE")
	world.custom_minimum_size.x = px(260)
	route.add_child(world)
	if not films.is_empty():
		var extras := HBoxContainer.new()
		extras.add_theme_constant_override("separation", space(1))
		extras.add_child(lbl(m._group_label(m.GROUP_FILMS), MenuStyle.MICRO, dim(), true))
		for i in films:
			extras.add_child(card(int(i), MenuStyle.CAPTION, false, false))
		stack.add_child(extras)
	var details: Control = m._build_detail_column(true)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(details)
