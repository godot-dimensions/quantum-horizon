extends RefCounted

## THE MENU'S LOOK: everything menu_final draws, built here. Since 9 Oct 2026 the menu is this one
## design, "A" (Ramon: "install final A as the main menu lander ... keep the menu final as the new
## main master and remove the tab variations"). The 41 designs it was picked from are frozen in
## `res://ramon/menu_variations.tscn` for reference; nothing here depends on them.
##
## A started as round 3's design 23 (the Octobergate deck's measured rows, Figma "Octobergate
## presentation", page "Final 2"), then Ramon worked it on 8 and 9 Oct:
##   - each prototype's own logo, grey and light, where the deck had P1, P2; one blue throughout
##     (no hue per group); the group's small Frontier Map mark before its name
##   - the selected row hard edged, its blue bar inside the row; lines stop short of the scrollbar
##   - the world as the big card (it holds every system), the launch button's corners on it and
##     on the video frame; the details panel flat, no stroke, no rounding
##   - a LIST / ROUTE switch and a light / dark square at the foot; the route view cut in half
##     both ways (route above, details below; video left, words right)
##   - the eyebrow just "QUANTUM HORIZON"
##
## The deck's measures, halved for the 1920 x 1080 canvas: eyebrow Montserrat Regular, grey; act
## label SemiBold, tracked, blue; an act tab under the eyebrow; hairline header and footer rules
## with a small footer slug; route rings with a 2.5 px stroke and 4 px links.
##
## The working parts stay in menu_final.gd (rows in `_rows`, the world in `_hero_panel`, the
## details from `_build_detail_column()`, selection, keys, launching, the way home). NO
## class_name: the menu preloads it.

const FONT_DIR := "res://ramon/Demo/fonts/Montserrat/static/"

## The deck's margins at 1920 x 1080 (half the slide's).
const MARGIN := 70.0
const TOP := 84
const BOTTOM := 74
## The foot's controls' height: QUIT's, so LIST / ROUTE in the middle sits on the same line.
const FOOT_ROW := 32

const WORDS: PackedStringArray = ["No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"]

var m: Control
var _fonts: Dictionary = {}
## The list's logos as last built, so the Tab panel's greys can repaint them in place.
var _logos: Array = []


func _init(menu: Control) -> void:
	m = menu


# --------------------------------------------------------------------------------------------
# Tokens
# --------------------------------------------------------------------------------------------

func ink() -> Color:
	return m.style.text


func dim() -> Color:
	return m.style.text_dim


func faint() -> Color:
	return m.style.text_faint


func accent() -> Color:
	return m.style.accent


func hair(strong: bool = false) -> Color:
	return Color(m.style.text, 0.22 if strong else 0.09)


func font(kind: String) -> Font:
	if not _fonts.has(kind):
		_fonts[kind] = load(FONT_DIR + "Montserrat-%s.ttf" % kind)
	return _fonts[kind]


## A label at an explicit pixel size, in one of the deck's weights, with tracking in pixels.
func txt(text: String, size_px: int, color: Color, kind: String = "Regular", tracking: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var f: Font = font(kind)
	if tracking != 0:
		var v := FontVariation.new()
		v.base_font = f
		v.set_spacing(TextServer.SPACING_GLYPH, tracking)
		f = v
	label.add_theme_font_override("font", f)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label


## Small caps the deck way: SemiBold, tracked, upper case.
func caps(text: String, size_px: int, color: Color) -> Label:
	return txt(text.to_upper(), size_px, color, "SemiBold", maxi(1, int(round(size_px * 0.06))))


func wrapped(label: Label, min_width: float = 120.0) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = min_width
	return label


func gap(box_node: Container, pixels: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(pixels, pixels)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_node.add_child(g)


func rule(strong: bool = false) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.custom_minimum_size.y = 1
	r.color = hair(strong)
	return r


func box(fill: Color, radius: int = 0, edge: Color = Color(0, 0, 0, 0), edge_width: int = 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	if edge_width > 0:
		b.border_color = edge
		b.set_border_width_all(edge_width)
	b.content_margin_left = 0
	b.content_margin_right = 0
	b.content_margin_top = 0
	b.content_margin_bottom = 0
	return b


func groups() -> Array:
	return m._groups_in_order()


func is_films(group: int) -> bool:
	return group == m.GROUP_FILMS


func entry(index: int) -> Resource:
	return m._entry(index)


func title_of(index: int) -> String:
	return String(entry(index).get("title"))


func gink(group: int) -> Color:
	return m._group_color(group) if group < m._systems.size() else dim()


func word(n: int) -> String:
	return WORDS[n] if n >= 0 and n < WORDS.size() else str(n)


## How many shown prototypes a family holds.
func family_count(group: int) -> int:
	for chunk in groups():
		if int(chunk[0]) == group:
			return (chunk[1] as Array).size()
	return 0


## How many families the shown prototypes fall into.
func group_count() -> int:
	var n: int = 0
	for chunk in groups():
		if int(chunk[0]) < m._systems.size():
			n += 1
	return n


# --------------------------------------------------------------------------------------------
# The frame: running header and footer, the deck's own
# --------------------------------------------------------------------------------------------

func header_height() -> int:
	return TOP


## Full-screen frame (mouse-transparent but for the two switches): the eyebrow and act label with
## the act tab and header rule, and at the foot the footer rule, the slug, and the light / dark and
## LIST / ROUTE switches.
func build_frame() -> Control:
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No "/ OCTOBER GATE" (Ramon, 9 Oct): the menu outlives the gate.
	var eyebrow := txt("QUANTUM HORIZON", 19, faint())
	eyebrow.position = Vector2(MARGIN, 22)
	frame.add_child(eyebrow)
	frame.set_meta(&"eyebrow", eyebrow)
	# What the menu shows (the catalogue's header_subject, "4D PROTOTYPES"); until 9 Oct the deck's
	# "00 / PROTOTYPE HUB", an old page number and the diegetic hub's name.
	var act := caps(String(m.catalogue.header_subject), 20, accent())
	act.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	act.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	act.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	act.offset_right = -MARGIN
	act.offset_top = 22
	frame.add_child(act)
	# The foot is one line (Ramon, 10 Oct: "align and fit in style"): the slug, LIST / ROUTE and the
	# corner row all centred in the same FOOT_ROW strip, in the same caps.
	var slug := caps(_footer_slug(), 12, faint())
	slug.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	slug.offset_left = MARGIN
	slug.offset_right = MARGIN
	slug.offset_top = -10 - FOOT_ROW
	slug.offset_bottom = -10
	slug.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(slug)
	# LIST / ROUTE at the very middle of the foot (Ramon, 10 Oct: "this panel should be at the very
	# middle"), in a strip as tall as the corner row so the two sit on one line.
	var middle := CenterContainer.new()
	middle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	middle.offset_top = -10 - FOOT_ROW
	middle.offset_bottom = -10
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(_view_toggle())
	frame.add_child(middle)
	# A world on hold (left through a laptop or Esc): the way back, solid blue, just right of the
	# pill so the pill stays at the very middle (Ramon, 10 Oct). Absent otherwise.
	if bool(m.call("_world_on_hold")):
		var back := foot_button("RETURN TO THE WORLD", true)
		back.name = "ReturnToWorld"
		back.tooltip_text = "Back to where you left off"
		back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		back.offset_left = 84.0 + 16.0
		back.offset_right = 84.0 + 16.0 + 230.0
		back.offset_top = -10 - FOOT_ROW
		back.offset_bottom = -10
		back.pressed.connect(m._return_to_world)
		frame.add_child(back)
	# The corner: the light / dark switch, then QUIT in the very corner. menu_final's
	# _add_quit_button finds this row by name and puts QUIT at its end.
	var corner := HBoxContainer.new()
	corner.name = "CornerRow"
	corner.add_theme_constant_override("separation", 28)
	corner.custom_minimum_size.y = FOOT_ROW
	corner.add_child(_shade_toggle())
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -MARGIN
	corner.offset_bottom = -10
	frame.add_child(corner)
	frame.draw.connect(_draw_frame.bind(frame))
	frame.resized.connect(frame.queue_redraw)
	return frame


## LIST and ROUTE as one pill: rounded at its two outer ends, square where the halves meet, so it
## reads as one control (Ramon, 10 Oct: "keep a continuation between list and route").
func _view_toggle() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for k in 2:
		var route: bool = k == 1
		var b := foot_button("ROUTE" if route else "LIST", bool(m._route_view) == route, not route, route)
		b.pressed.connect(m._show_route.bind(route))
		row.add_child(b)
	return row


## The foot's caps: SemiBold 12, a pixel of tracking (the slug's, the switches', QUIT's).
func foot_font() -> FontVariation:
	var v := FontVariation.new()
	v.base_font = font("SemiBold")
	v.set_spacing(TextServer.SPACING_GLYPH, 1)
	return v


## A button of the foot (LIST, ROUTE, QUIT; menu_final asks for QUIT): blue caps in a light grey
## edge, the hairlines' strong grey (Ramon, 10 Oct), or white on solid blue when `on`. Corners
## round like the LAUNCH button's; `round_left` / `round_right` square off the side that joins
## another button.
func foot_button(text: String, on: bool = false, round_left: bool = true, round_right: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(84, FOOT_ROW)
	b.add_theme_font_override("font", foot_font())
	b.add_theme_font_size_override("font_size", 12)
	var ink_color: Color = Color(1, 1, 1) if on else accent()
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, ink_color)
	var blue: Color = m.style.launch_fill
	var edge: Color = blue if on else hair(true)
	var fills := {"normal": 0.0, "hover": 0.10, "pressed": 0.18}
	var r: int = m.style.corner_radius
	for state in fills:
		var sb := box(blue if on else Color(blue, float(fills[state])), 0, edge, 1)
		sb.corner_radius_top_left = r if round_left else 0
		sb.corner_radius_bottom_left = r if round_left else 0
		sb.corner_radius_top_right = r if round_right else 0
		sb.corner_radius_bottom_right = r if round_right else 0
		b.add_theme_stylebox_override(state, sb)
	return b


## Light or dark: what a click turns the page to, in words, then the half-filled disc on its own,
## no square round it (Ramon, 10 Oct: "only the ball remains and scale that up a bit").
func _shade_toggle() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.text = "DARK MODE" if bool(m._light) else "LIGHT MODE"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", foot_font())
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", accent())
	b.add_theme_color_override("font_hover_color", accent())
	b.add_theme_color_override("font_pressed_color", accent())
	var r: float = 10.5
	var bare := StyleBoxEmpty.new()
	bare.content_margin_right = r * 2.0 + 12.0
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, bare)
	b.draw.connect(func() -> void:
		var c := Vector2(b.size.x - r - 1.0, b.size.y * 0.5)
		if b.is_hovered():
			b.draw_circle(c, r, Color(accent(), 0.14))
		b.draw_arc(c, r, 0.0, TAU, 40, accent(), 1.5, true)
		var half := PackedVector2Array()
		for s in 17:
			var a: float = -PI * 0.5 + PI * float(s) / 16.0
			half.append(c + Vector2(cos(a), sin(a)) * r)
		b.draw_colored_polygon(half, accent())
	)
	b.pressed.connect(m._toggle_shade)
	return b


func _footer_slug() -> String:
	var parts: PackedStringArray = ["One world"]
	var labs: int = family_count(0)
	var plays: int = family_count(1)
	if labs > 0:
		parts.append("%s %s" % [word(labs).to_lower(), "lab" if labs == 1 else "labs"])
	if plays > 0:
		parts.append("%s %s" % [word(plays).to_lower(), "experiment" if plays == 1 else "experiments"])
	parts.append("click or enter launches, M returns")
	return "  ·  ".join(parts)


func _draw_frame(frame: Control) -> void:
	var w: float = frame.size.x
	var h: float = frame.size.y
	# The blue tab, exactly as wide as the eyebrow above it.
	var tab: float = 230.0
	var eyebrow: Label = frame.get_meta(&"eyebrow", null)
	if is_instance_valid(eyebrow):
		tab = eyebrow.get_minimum_size().x
	frame.draw_rect(Rect2(MARGIN, 58, tab, 4), accent())
	frame.draw_line(Vector2(MARGIN, 62.5), Vector2(w - MARGIN, 62.5), hair(true), 1.0)
	frame.draw_line(Vector2(MARGIN, h - 52.5), Vector2(w - MARGIN, h - 52.5), hair(), 1.0)


# --------------------------------------------------------------------------------------------
# Shared pieces
# --------------------------------------------------------------------------------------------

## The deck's two-line claim, one line per family ("Four labs to explore. Three experiments to
## play.").
func statement(size_px: int) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", int(size_px * 0.32))
	var labs: int = family_count(0)
	var plays: int = family_count(1)
	var line1: String = "%s %s to explore." % [word(labs), "lab" if labs == 1 else "labs"]
	var line2: String = "%s %s to play." % [word(plays), "experiment" if plays == 1 else "experiments"]
	var title := txt("%s\n%s" % [line1, line2], size_px, ink(), "Regular", -int(round(size_px * 0.03)))
	title.add_theme_constant_override("line_spacing", -int(size_px * 0.04))
	block.add_child(title)
	return block


## A family's head on the route: its mark and tracked name, its line under them, centred over the
## family's own stops.
func group_head(group: int, name_px: int) -> VBoxContainer:
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(top)
	if group < m._systems.size():
		var mark: Control = m._system_mark(group, gink(group), name_px + 5)
		top.add_child(mark)
	var name_label := caps(m._group_label(group), name_px, gink(group))
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_label)
	var line: String = m._group_line(group)
	if line != "":
		var line_label := txt(line, name_px + 1, dim())
		line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(line_label)
	return head


## A clickable prototype: it goes into menu_final's `_rows`.
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


## How a row lights up. On the route nothing (the ring shows it); in the list a hard-edged tint
## with the blue bar inside the row (Ramon, 8 Oct: "hard edged, no rounding ... inside the button").
func row_box(_index: int, chosen: bool, hovered: bool) -> StyleBoxFlat:
	if bool(m._route_view):
		return box(Color(0, 0, 0, 0))
	var tint: Color = m.style.surface_raised
	var b := box(tint if chosen else (Color(tint, tint.a * 0.55) if hovered else Color(0, 0, 0, 0)), 0)
	if chosen:
		b.border_color = accent()
		b.border_width_left = 4
	return b


## The world's card (big in the list, a pill at the route's end): the code blue with the launch
## button's corners, a step lighter when selected.
func hero_box(chosen: bool) -> StyleBoxFlat:
	var blue: Color = m.style.launch_fill
	return box(blue.lightened(0.08) if chosen else blue, int(m.style.corner_radius))


## The details: a flat panel, no stroke, no rounding (Ramon, 8 Oct).
func pane_box() -> StyleBoxFlat:
	return box(m.style.surface, 0)


## The detail title in the deck's Regular, tracked tight.
func deck_title(label: Label) -> void:
	var v := FontVariation.new()
	v.base_font = font("Regular")
	v.set_spacing(TextServer.SPACING_GLYPH, -1)
	label.add_theme_font_override("font", v)
	label.add_theme_font_size_override("font_size", 40)


## The list's scrolled rows, in a column; `right_gap` keeps the lines and the selection short of
## the scrollbar while there is one. Today every row fits, so the bar stays hidden and the rows run
## the column's full width, flush with the world's card; one more entry and the bar is back, with
## its gap (Ramon, 10 Oct: keep the scroller for when Trym adds a button).
func scroll_rows(column: VBoxContainer, right_gap: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	m._list_scroll = scroll
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 0)
	var inset := MarginContainer.new()
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(rows)
	scroll.add_child(inset)
	# Narrowing the rows can only make them taller (and widening only shorter), so the bar cannot
	# flicker on and off through this.
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var fit_gap := func() -> void:
		inset.add_theme_constant_override("margin_right", right_gap if bar.visible else 0)
	bar.visibility_changed.connect(fit_gap)
	fit_gap.call()
	return rows


## The films, by name on one line (no heading: Ramon, 8 Oct, "remove cinematic writing").
func films_row(column: Container) -> void:
	for chunk in groups():
		if not is_films(int(chunk[0])):
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		for i in chunk[1]:
			var p := row_panel(int(i))
			var pad := MarginContainer.new()
			m._set_margins(pad, 10, 6)
			p.add_child(pad)
			pad.add_child(txt(title_of(int(i)), 15, ink()))
			line.add_child(p)
		column.add_child(line)


# --------------------------------------------------------------------------------------------
# The two views
# --------------------------------------------------------------------------------------------

func build(host: MarginContainer) -> void:
	host.add_theme_constant_override("margin_left", int(MARGIN))
	host.add_theme_constant_override("margin_right", int(MARGIN))
	host.add_theme_constant_override("margin_bottom", BOTTOM)
	if bool(m._route_view):
		_route_page(host)
	else:
		_list_page(host)


## The list: the claim, the prototypes by group, the films and the world on the left; the details
## on the right.
func _list_page(host: MarginContainer) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	host.add_child(columns)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 620.0
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 22)
	columns.add_child(column)
	_list(column)
	columns.add_child(m._build_detail_column())


## Each prototype's own logo, plain (no ring, no frame), its name large and its line small;
## hairlines between rows, a heavier one over each group.
func _list(column: VBoxContainer) -> void:
	_logos.clear()
	column.add_child(statement(44))
	var rows := scroll_rows(column, 22)
	var first: bool = true
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			continue
		# The rows a little closer (10 Oct) so all seven fit without the scrollbar.
		gap(rows, 4.0 if first else 18.0)
		first = false
		# The family's mark and name, and on the same line what kind of thing it holds (Ramon's 9 Oct
		# brief: "the two categories should be immediately distinguishable").
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		if group < m._systems.size():
			var mark: Control = m._system_mark(group, accent(), 22)
			head.add_child(mark)
		var name_label := caps(m._group_label(group), 14, gink(group))
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(name_label)
		var family_line: String = m._group_line(group)
		if family_line != "":
			var line_label := txt(family_line, 14, dim())
			line_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(line_label)
		rows.add_child(head)
		gap(rows, 6.0)
		for k in (chunk[1] as Array).size():
			var i: int = int(chunk[1][k])
			rows.add_child(rule(k == 0))
			var p := row_panel(i)
			var pad := MarginContainer.new()
			m._set_margins(pad, 12, 7)
			p.add_child(pad)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 20)
			pad.add_child(line)
			# The deck's grey, lighter still, and bigger.
			var logo := TextureRect.new()
			logo.texture = entry(i).get("icon")
			logo.custom_minimum_size = Vector2(76, 56)
			logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Lighter on 10 Oct; tuned behind Tab (menu_final.tuning, "list_logos").
			logo.modulate = Color(ink(), float(m.tuning["list_logos"]))
			_logos.append(logo)
			# The icons are 512 px, drawn at 56: mipmapped, or their strokes shimmer.
			logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(logo)
			var words := VBoxContainer.new()
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			words.add_theme_constant_override("separation", 2)
			line.add_child(words)
			# 4D Ascent tries a step up (Ramon, 8 Oct): one weight up, a little bigger and 20 %
			# brighter. Shooting Range tried the weight too and went back to Light (10 Oct).
			var weight: String = "Regular" if title_of(i) == "4D Ascent" else "Light"
			var ascent: bool = title_of(i) == "4D Ascent"
			words.add_child(txt(title_of(i), 31 if ascent else 28, ink().lightened(0.2) if ascent else ink(), weight, -1))
			words.add_child(wrapped(txt(String(entry(i).get("blurb")), 13, dim()), 200))
			rows.add_child(p)
	films_row(column)
	column.add_child(world_big())


## The world as the big deal it is (Ramon, 8 Oct: "don't downplay it. it's got everything
## integrated and is the big bang"): the code blue, the launch button's corners, a larger title,
## and what is in it. Always a new world: with one on hold the way back is the blue RETURN TO
## THE WORLD button at the foot (10 Oct; until then a laptop trip turned this card into it).
func world_big() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(m._on_hero_input)
	m._hero_panel = card
	card.add_theme_stylebox_override("panel", hero_box(false))
	var pad := MarginContainer.new()
	m._set_margins(pad, 26, 22)
	card.add_child(pad)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 8)
	pad.add_child(words)
	var heading: String = m.catalogue.hero_heading
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	words.add_child(top)
	var kicker := caps("The world  ·  where it all comes together", 12, Color(1, 1, 1, 0.78))
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(kicker)
	for g in m._systems.size():
		top.add_child(m._system_mark(g, Color(1, 1, 1, 0.9), 18))
	var title_line := HBoxContainer.new()
	title_line.add_theme_constant_override("separation", 14)
	words.add_child(title_line)
	title_line.add_child(txt(heading.substr(0, 1) + heading.substr(1).to_lower(), 40, Color(1, 1, 1), "Regular", -1))
	var arrow := txt("→", 34, Color(1, 1, 1), "Light")
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_line.add_child(arrow)
	var hero: Resource = m.catalogue.hero
	if hero != null:
		words.add_child(wrapped(txt(String(hero.get("blurb")) + ".", 17, Color(1, 1, 1, 0.92)), 300))
	words.add_child(wrapped(txt("Researchers at work, a cave whose far room lies out along W, the range, a camera for 4D photographs, 5,000 starlings overhead.", 13, Color(1, 1, 1, 0.74)), 300))
	return card


## The world as the route's end: a pill with its heading and an arrow.
func world_pill() -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(m._on_hero_input)
	m._hero_panel = card
	card.add_theme_stylebox_override("panel", hero_box(false))
	var pad := MarginContainer.new()
	m._set_margins(pad, 26, 12)
	card.add_child(pad)
	var heading: String = m.catalogue.hero_heading
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	pad.add_child(line)
	line.add_child(caps(heading, 15, Color(1, 1, 1)))
	line.add_child(txt("→", 18, Color(1, 1, 1), "SemiBold"))
	return card


## The route (the deck's route slide): the group heads across the top, a curve through every
## prototype's ring, ending in the world. Cut in half both ways (Ramon, 8 Oct: "video left 50%,
## text page 50% ... and also half vertical"): the route in the top half, the details below.
func _route_page(host: MarginContainer) -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	host.add_child(page)
	# 442 : 466 of the 922 px between header and footer puts the cut at 540, the screen's middle.
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.size_flags_stretch_ratio = 0.95
	page.add_child(stack)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 30)
	stack.add_child(top)
	var title := statement(40)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var air := Control.new()
	air.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(air)
	# Family heads, each centred over its own stops with a bracket under them (the same stretch ratios
	# as the stops, and the world's column mirrored at the end, so they line up).
	var heads := HBoxContainer.new()
	heads.add_theme_constant_override("separation", 0)
	stack.add_child(heads)
	var route := HBoxContainer.new()
	route.add_theme_constant_override("separation", 0)
	route.custom_minimum_size.y = 176
	stack.add_child(route)
	var rings: Array = []
	var colours: Array = []
	var ring_groups: Array = []
	var films: Array = []
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			films = chunk[1]
			continue
		var count: int = (chunk[1] as Array).size()
		var head_box := VBoxContainer.new()
		head_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head_box.size_flags_stretch_ratio = float(count)
		head_box.add_theme_constant_override("separation", 2)
		head_box.add_child(group_head(group, 12))
		var bracket := Control.new()
		bracket.custom_minimum_size.y = 12
		bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bracket.draw.connect(_draw_bracket.bind(bracket, count))
		head_box.add_child(bracket)
		heads.add_child(head_box)
		for k in count:
			var i: int = int(chunk[1][k])
			var node := VBoxContainer.new()
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			node.add_theme_constant_override("separation", 6)
			route.add_child(node)
			# The deck's route weaves: every other ring sits a little lower.
			gap(node, 40.0 if (rings.size() % 2 == 1) else 8.0)
			var p := row_panel(i)
			p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			node.add_child(p)
			var ring := Control.new()
			ring.custom_minimum_size = Vector2(88, 88)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			ring.draw.connect(_draw_ring.bind(ring, i))
			p.add_child(ring)
			m._tracks[i] = ring
			rings.append(ring)
			colours.append(gink(group))
			ring_groups.append(group)
			var label := txt(title_of(i), 17, ink())
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			node.add_child(label)
	var heads_end := Control.new()
	heads_end.custom_minimum_size.x = 230
	heads.add_child(heads_end)
	# The world, the route's end.
	var end := VBoxContainer.new()
	end.add_theme_constant_override("separation", 6)
	end.custom_minimum_size.x = 230
	route.add_child(end)
	gap(end, 28.0)
	var w := world_pill()
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	end.add_child(w)
	var end_label := txt("Where all of it runs together", 13, dim())
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end.add_child(end_label)
	route.set_meta(&"rings", rings)
	route.set_meta(&"colours", colours)
	route.set_meta(&"groups", ring_groups)
	route.set_meta(&"end", w)
	route.draw.connect(_draw_route.bind(route))
	route.sort_children.connect(route.queue_redraw)
	route.resized.connect(route.queue_redraw)
	var note := HBoxContainer.new()
	note.add_theme_constant_override("separation", 28)
	stack.add_child(note)
	# What the line is, without contradicting it (menu_review_9oct.md §3; until 9 Oct "A capability
	# map, not a required order.").
	var hint := txt("Our suggested route. Every stop can be launched on its own.", 13, faint())
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_child(hint)
	if not films.is_empty():
		films_row(note)
	# The spare height split above and below the route (3 : 2), so it sits in its half rather
	# than hanging off the headline.
	var air_below := Control.new()
	air_below.size_flags_vertical = Control.SIZE_EXPAND_FILL
	air_below.size_flags_stretch_ratio = 0.67
	stack.add_child(air_below)
	# One height for every entry (the longest needs 539 px since the 9 Oct write-ups), so the route
	# above never moves when the selection changes.
	var details: Control = m._build_detail_column(true)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.size_flags_stretch_ratio = 1.0
	details.custom_minimum_size.y = 540.0
	page.add_child(details)


## A ring of the route: the prototype's icon in an 88 px ring, filled blue when selected, a halo
## round it; a dot when played.
func _draw_ring(ring: Control, index: int) -> void:
	var c: Vector2 = ring.size * 0.5
	var r: float = minf(ring.size.x, ring.size.y) * 0.5 - 6.0
	var chosen: bool = int(m._selected) == index
	ring.draw_circle(c, r, m.style.launch_fill if chosen else m.style.background)
	# A light grey hairline ring and a darker grey logo (Ramon, 10 Oct), both tuned behind Tab
	# (menu_final.tuning, "route_rings" and "route_logos").
	var ring_ink := Color(ink(), float(m.tuning["route_rings"]))
	ring.draw_arc(c, r, 0.0, TAU, 64, m.style.launch_fill if chosen else ring_ink, 1.0, true)
	if chosen:
		ring.draw_arc(c, r + 5.0, 0.0, TAU, 48, Color(m.style.launch_fill, 0.45), 1.5, true)
	var icon: Texture2D = entry(index).get("icon")
	if icon != null:
		var s: float = r * 1.15
		var aspect: float = float(icon.get_width()) / maxf(1.0, float(icon.get_height()))
		var size := Vector2(s, s / aspect) if aspect >= 1.0 else Vector2(s * aspect, s)
		ring.draw_texture_rect(icon, Rect2(c - size * 0.5, size), false, Color(1, 1, 1) if chosen else Color(ink(), float(m.tuning["route_logos"])))
	var played: Array = m._played
	if index < played.size() and bool(played[index]):
		ring.draw_circle(c + Vector2(r * 0.72, -r * 0.72), 5.0, m.style.positive)


## Repaints the list's logos and the route's rings with menu_final's current greys (the Tab
## panel, live while a slider moves).
func apply_greys() -> void:
	for logo in _logos:
		if is_instance_valid(logo):
			(logo as TextureRect).modulate = Color(ink(), float(m.tuning["list_logos"]))
	for ring in m._tracks.values():
		if is_instance_valid(ring):
			(ring as CanvasItem).queue_redraw()


## A family's bracket under its name: a thin line from its first stop's centre to its last, with a
## tick down at each end.
func _draw_bracket(bracket: Control, count: int) -> void:
	var w: float = bracket.size.x
	var inset: float = w / float(maxi(1, count)) * 0.5
	var y: float = 4.0
	var c: Color = Color(accent(), 0.45)
	bracket.draw_line(Vector2(inset, y), Vector2(w - inset, y), c, 1.5, true)
	bracket.draw_line(Vector2(inset, y), Vector2(inset, y + 6.0), c, 1.5, true)
	bracket.draw_line(Vector2(w - inset, y), Vector2(w - inset, y + 6.0), c, 1.5, true)


## The route's curve through every ring's centre, then on to the world; between the families the
## line turns to dots, a gate between the two stages rather than a break in the route.
func _draw_route(route: Control) -> void:
	var rings: Array = route.get_meta(&"rings", [])
	var colours: Array = route.get_meta(&"colours", [])
	var ring_groups: Array = route.get_meta(&"groups", [])
	var points: PackedVector2Array = []
	for ring in rings:
		var rc: Control = ring
		if not is_instance_valid(rc):
			return
		points.append(rc.get_global_rect().get_center() - route.get_global_position())
	var end: Control = route.get_meta(&"end", null)
	if is_instance_valid(end):
		var e: Rect2 = end.get_global_rect()
		points.append(Vector2(e.position.x, e.get_center().y) - route.get_global_position())
	for k in range(points.size() - 1):
		var a: Vector2 = points[k]
		var b: Vector2 = points[k + 1]
		var colour: Color = colours[mini(k + 1, colours.size() - 1)]
		var curve := PackedVector2Array()
		for s in 13:
			var t: float = float(s) / 12.0
			# A smooth S between the two centres (ease in and out on y).
			var y: float = lerpf(a.y, b.y, t * t * (3.0 - 2.0 * t))
			curve.append(Vector2(lerpf(a.x, b.x, t), y))
		if k + 1 < ring_groups.size() and int(ring_groups[k]) != int(ring_groups[k + 1]):
			# The gate: dots along the same curve.
			for s in range(1, 12, 2):
				route.draw_circle(curve[s], 2.6, Color(colour, 0.6))
			continue
		route.draw_polyline(curve, Color(colour, 0.85), 4.0, true)
