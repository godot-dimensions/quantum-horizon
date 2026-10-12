extends RefCounted

## THE THIRD ROUND of menu_final's design review (designs 20 to 29, 8 Oct 2026): the language
## of the Octobergate deck's top row (Figma "Octobergate presentation", page "Final 2", the
## C00 to C23 slides; Ramon: "inspired by this style ... this is what inspired the lab/kit
## look, but then with the white and blue tones").
##
## Measured from the deck's own layers (a 3840 x 2160 slide; halved here for the 1920 x 1080
## canvas):
##   - running header: eyebrow "QUANTUM HORIZON / OCTOBER GATE", Montserrat Regular 38, grey,
##     at x 138 y 54; act label right, SemiBold 40 +4% tracking, blue; an act tab 460 x 8 under
##     the eyebrow at y 124; a hairline header rule.
##   - title: Regular 164, line height 170, -3% tracking, at x 139 y 193; standfirst Regular 60
##     grey at y 574.
##   - group names SemiBold 40 +6% tracking in the group's colour; descriptions Regular.
##   - the route: rings 180 across with a 5 px stroke, links 9 px, labels Regular 42.
##   - closer statement Regular 84; footer rule 3 px at y 2040, margins 140; small footer slug.
##   - dividers on a dark ground (32322F) with huge outlined numerals in light blue.
## Here in white and blue (light) or near black and light blue (B), never mixed. The deck's
## warm cream and olive become cool white and the code blue; its category colours a blue ramp.
##
## Every design here keeps menu_final's working parts (rows in `_rows`, the world in
## `_hero_panel`, the details from `_build_detail_column()`), so selection, keys, launching and
## the way home behave as in every other design. NO class_name: the menu preloads it.

const FONT_DIR := "res://ramon/Demo/fonts/Montserrat/static/"

## The deck's measures at 1920 x 1080 (half the slide's).
const MARGIN := 70.0
const TOP := 84
const BOTTOM := 74

var m: Control
var _fonts: Dictionary = {}
## How the world's card is drawn in the current design: "fill", "pill" or "line".
var _hero_kind: String = "fill"


func _init(menu: Control) -> void:
	m = menu


# --------------------------------------------------------------------------------------------
# Tokens
# --------------------------------------------------------------------------------------------

func light() -> bool:
	return bool(m.get("_light"))


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


func design() -> int:
	return int(m.design)


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


func gap(box: Container, pixels: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(pixels, pixels)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(g)


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


const WORDS: PackedStringArray = ["No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve"]


func word(n: int) -> String:
	return WORDS[n] if n >= 0 and n < WORDS.size() else str(n)


## How many system groups (or questions) the shown prototypes fall into.
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


## Full-screen frame (mouse-transparent): eyebrow and act label with the act tab and header
## rule, and at the foot the footer rule, slug and page number.
func build_frame() -> Control:
	var frame := Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# "A" drops the deck's "/ OCTOBER GATE" (Ramon, 9 Oct): the menu outlives the gate.
	var eyebrow := txt("QUANTUM HORIZON" if design() == 40 else "QUANTUM HORIZON  /  OCTOBER GATE", 19, faint())
	eyebrow.position = Vector2(MARGIN, 22)
	frame.add_child(eyebrow)
	frame.set_meta(&"eyebrow", eyebrow)
	var act := caps("00  /  Prototype hub", 20, accent())
	act.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	act.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	act.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	act.offset_right = -MARGIN
	act.offset_top = 22
	frame.add_child(act)
	var slug := caps(_footer_slug(), 12, faint())
	slug.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	slug.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slug.offset_left = MARGIN
	slug.offset_bottom = -22
	frame.add_child(slug)
	if design() == 40:
		# "A": the view switch where the page number was (Ramon, 8 Oct: "start with bottom right
		# and remove 00").
		var toggle := HBoxContainer.new()
		toggle.add_theme_constant_override("separation", 12)
		toggle.add_child(_shade_toggle())
		toggle.add_child(_view_toggle())
		toggle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		toggle.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		toggle.grow_vertical = Control.GROW_DIRECTION_BEGIN
		toggle.offset_right = -MARGIN
		toggle.offset_bottom = -10
		frame.add_child(toggle)
	else:
		var page := caps("00", 12, faint())
		page.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		page.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		page.grow_vertical = Control.GROW_DIRECTION_BEGIN
		page.offset_right = -MARGIN
		page.offset_bottom = -22
		frame.add_child(page)
	frame.draw.connect(_draw_frame.bind(frame))
	frame.resized.connect(frame.queue_redraw)
	return frame


## "A": LIST and ROUTE as two hard-edged segments, the one showing filled blue.
func _view_toggle() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	for k in 2:
		var route: bool = k == 1
		var on: bool = bool(m._a_route) == route
		var b := Button.new()
		b.text = "ROUTE" if route else "LIST"
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = Vector2(84, 30)
		var v := FontVariation.new()
		v.base_font = font("SemiBold")
		v.set_spacing(TextServer.SPACING_GLYPH, 1)
		b.add_theme_font_override("font", v)
		b.add_theme_font_size_override("font_size", 12)
		var ink_on: Color = Color(1, 1, 1)
		b.add_theme_color_override("font_color", ink_on if on else accent())
		b.add_theme_color_override("font_hover_color", ink_on if on else accent())
		b.add_theme_color_override("font_pressed_color", ink_on)
		var normal := box(m.style.launch_fill if on else Color(0, 0, 0, 0), 0, m.style.launch_fill, 1)
		var hover := box(m.style.launch_fill if on else Color(m.style.launch_fill, 0.10), 0, m.style.launch_fill, 1)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", normal)
		b.pressed.connect(m._toggle_a_route.bind(route))
		row.add_child(b)
	return row


## "A": light or dark, one square with the half-filled disc, beside LIST / ROUTE: both are how
## the page is shown, so they sit together at the foot, away from the content.
func _shade_toggle() -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.tooltip_text = "Dark" if bool(m._light) else "Light"
	b.custom_minimum_size = Vector2(30, 30)
	var blue: Color = m.style.launch_fill
	b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), 0, blue, 1))
	b.add_theme_stylebox_override("hover", box(Color(blue, 0.10), 0, blue, 1))
	b.add_theme_stylebox_override("pressed", box(Color(blue, 0.18), 0, blue, 1))
	b.draw.connect(func() -> void:
		var c: Vector2 = b.size * 0.5
		var r: float = 7.5
		b.draw_arc(c, r, 0.0, TAU, 32, accent(), 1.5, true)
		var half := PackedVector2Array()
		for s in 17:
			var a: float = -PI * 0.5 + PI * float(s) / 16.0
			half.append(c + Vector2(cos(a), sin(a)) * r)
		b.draw_colored_polygon(half, accent())
	)
	b.pressed.connect(m._toggle_bright)
	return b


func _footer_slug() -> String:
	var parts: PackedStringArray = ["One world", "%s prototypes" % word(m._run_total()).to_lower()]
	if group_count() > 0:
		parts.append(("%s questions" if int(m._taxonomy) == 1 else "%s areas of research") % word(group_count()).to_lower())
	parts.append("click or enter launches, esc returns")
	return "  ·  ".join(parts)


func _draw_frame(frame: Control) -> void:
	var w: float = frame.size.x
	var h: float = frame.size.y
	# The blue tab; in "A" exactly as wide as the shorter eyebrow above it.
	var tab: float = 230.0
	var eyebrow: Label = frame.get_meta(&"eyebrow", null)
	if design() == 40 and is_instance_valid(eyebrow):
		tab = eyebrow.get_minimum_size().x
	frame.draw_rect(Rect2(MARGIN, 58, tab, 4), accent())
	frame.draw_line(Vector2(MARGIN, 62.5), Vector2(w - MARGIN, 62.5), hair(true), 1.0)
	frame.draw_line(Vector2(MARGIN, h - 52.5), Vector2(w - MARGIN, h - 52.5), hair(), 1.0)


# --------------------------------------------------------------------------------------------
# Shared pieces
# --------------------------------------------------------------------------------------------

## The deck's title and standfirst ("Nine experiments. Four areas of research.").
func statement(size_px: int = 52, with_standfirst: bool = true) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", int(size_px * 0.32))
	var line1: String = "%s experiments." % word(m._run_total())
	var line2: String
	if int(m._taxonomy) == 1:
		line2 = "%s questions to answer." % word(group_count())
	else:
		line2 = "%s areas of research." % word(group_count())
	var title := txt("%s\n%s" % [line1, line2], size_px, ink(), "Regular", -int(round(size_px * 0.03)))
	title.add_theme_constant_override("line_spacing", -int(size_px * 0.04))
	block.add_child(title)
	if with_standfirst:
		block.add_child(wrapped(txt("Each one tests a single capability. The world puts them all together.", int(round(size_px * 0.4)), dim()), 300))
	return block


## A group's head the deck way: mark and tracked name in the group's colour, the question or
## description under it in Regular.
func group_head(group: int, name_px: int = 15, desc_px: int = 15, with_desc: bool = true) -> VBoxContainer:
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	head.add_child(top)
	if group < m._systems.size():
		var mark: Control = m._system_mark(group, gink(group), name_px + 5)
		top.add_child(mark)
	var name_label := caps(m._group_label(group), name_px, gink(group))
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(name_label)
	var desc: String = m._group_line(group)
	if with_desc and desc != "":
		head.add_child(wrapped(txt(desc.substr(0, 1).to_upper() + desc.substr(1), desc_px, dim()), 120))
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


## How a row lights up: flat, a tint and a 3 px bar in the group's blue when selected; a hairline
## card in the grid design; nothing at all on the route, whose ring shows it.
func row_box(index: int, chosen: bool, hovered: bool) -> StyleBoxFlat:
	var group: int = m._group_of(entry(index))
	var bar: Color = gink(group) if group < m._systems.size() else accent()
	if design() == 40:
		# "A": on the route the ring shows it; in the list a hard-edged tint with the blue bar
		# inside the row (Ramon, 8 Oct: "hard edged, no rounding ... inside the button").
		if bool(m._a_route):
			return box(Color(0, 0, 0, 0))
		var tint: Color = m.style.surface_raised
		var a := box(tint if chosen else (Color(tint, tint.a * 0.55) if hovered else Color(0, 0, 0, 0)), 0)
		if chosen:
			a.border_color = accent()
			a.border_width_left = 4
		return a
	match design():
		21, 29:
			return box(Color(0, 0, 0, 0))
		24:
			var b := box(m.style.surface_raised if chosen else (Color(m.style.surface_raised, 0.5) if hovered else m.style.surface), 6, hair(), 1)
			if chosen:
				b.border_color = bar
				b.set_border_width_all(2)
			return b
		_:
			var lit: Color = m.style.surface_raised
			var b := box(lit if chosen else (Color(lit, lit.a * 0.55) if hovered else Color(0, 0, 0, 0)), 2)
			if chosen:
				b.border_color = bar
				b.border_width_left = 3
			return b


## The world's card: the deck's code blue (white type) as a panel, a pill, or a hairline line.
func hero_box(chosen: bool) -> StyleBoxFlat:
	var blue: Color = m.style.launch_fill
	# "A": the world takes the launch button's corners.
	if design() == 40:
		return box(blue.lightened(0.08) if chosen else blue, int(m.style.corner_radius))
	match _hero_kind:
		"pill":
			return box(blue.lightened(0.1) if chosen else blue, 999)
		"line":
			var b := box(m.style.surface_raised if chosen else Color(0, 0, 0, 0), 4, accent(), 1)
			if chosen:
				b.set_border_width_all(2)
			return b
		_:
			var b := box(blue.lightened(0.08) if chosen else blue, 4)
			if chosen:
				b.border_color = Color(1, 1, 1)
				b.border_width_left = 4
			return b


## The world, as `_hero_panel`: a kicker, its name and its line.
func world(kind: String, kicker_text: String = "The world  ·  all of it together", compact: bool = false) -> PanelContainer:
	_hero_kind = kind
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(m._on_hero_input)
	m._hero_panel = card
	card.add_theme_stylebox_override("panel", hero_box(false))
	var on_blue: bool = kind != "line"
	var ink_c: Color = Color(1, 1, 1) if on_blue else ink()
	var dim_c: Color = Color(1, 1, 1, 0.8) if on_blue else dim()
	var pad := MarginContainer.new()
	m._set_margins(pad, 26 if kind == "pill" else 22, 12 if kind == "pill" else 18)
	card.add_child(pad)
	var heading: String = m.catalogue.hero_heading if m._laptop_trip() == null else m.catalogue.hero_return_heading
	if kind == "pill":
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		pad.add_child(line)
		line.add_child(caps(heading, 15, ink_c))
		line.add_child(txt("→", 18, ink_c, "SemiBold"))
		return card
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 6)
	pad.add_child(words)
	if kicker_text != "":
		words.add_child(caps(kicker_text, 11, dim_c))
	words.add_child(txt(heading.substr(0, 1) + heading.substr(1).to_lower(), 22 if compact else 30, ink_c, "Regular", -1))
	var hero: Resource = m.catalogue.hero
	if hero != null and m._laptop_trip() == null:
		words.add_child(wrapped(txt(String(hero.get("blurb")), 14, dim_c), 160))
	return card


## The details, the deck way: the palette's panel with a hairline edge and square corners (a
## framed screen in design 25).
func pane_box() -> StyleBoxFlat:
	# "A": a flat white panel, no stroke, no rounding (Ramon, 8 Oct).
	if design() == 40:
		return box(m.style.surface, 0)
	if design() == 25:
		return box(m.style.surface, 12, hair(true), 1)
	return box(m.style.surface, 2, hair(), 1)


## The detail title in the deck's Regular, tracked tight, a step bigger.
func deck_title(label: Label) -> void:
	var v := FontVariation.new()
	v.base_font = font("Regular")
	v.set_spacing(TextServer.SPACING_GLYPH, -1)
	label.add_theme_font_override("font", v)
	label.add_theme_font_size_override("font_size", 40)


func follow_selection(_group: int) -> void:
	pass


## The usual scrolled rows box in a column.
func scroll_rows(column: VBoxContainer, separation: int = 0, right_gap: int = 0) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	m._list_scroll = scroll
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", separation)
	if right_gap > 0:
		# Lines and the selection stop short of the scrollbar, with white space between.
		var inset := MarginContainer.new()
		inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inset.add_theme_constant_override("margin_right", right_gap)
		inset.add_child(rows)
		scroll.add_child(inset)
	else:
		scroll.add_child(rows)
	return rows


func left_column(width: float = 620.0) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = width
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 22)
	return column


## A prototype as an editorial line: number, name, and a note set right.
func line_row(index: int, name_px: int = 24, note: String = "") -> PanelContainer:
	var p := row_panel(index)
	var pad := MarginContainer.new()
	m._set_margins(pad, 12, 11)
	p.add_child(pad)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	pad.add_child(line)
	var group: int = m._group_of(entry(index))
	var number := caps("%02d" % m._run_number(index) if not is_films(group) else "·", 13, gink(group) if group < m._systems.size() else faint())
	number.custom_minimum_size.x = 26
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(number)
	var name_label := txt(title_of(index), name_px, ink(), "Regular", -1)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(name_label)
	if note != "":
		var right := txt(note, 13, faint())
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(right)
	return p


func maturity_note(index: int) -> String:
	var bits: PackedStringArray = []
	var mat: String = String(entry(index).get("maturity"))
	if mat != "":
		bits.append(mat.to_lower())
	var dur: String = String(entry(index).get("duration"))
	if dur != "":
		bits.append(dur)
	return "  ·  ".join(bits)


func films_row(column: Container, with_heading: bool = true) -> void:
	for chunk in groups():
		if not is_films(int(chunk[0])):
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		if with_heading:
			var head := caps(m._group_label(m.GROUP_FILMS), 12, faint())
			head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(head)
		for i in chunk[1]:
			var p := row_panel(int(i))
			var pad := MarginContainer.new()
			m._set_margins(pad, 10, 6)
			p.add_child(pad)
			pad.add_child(txt(title_of(int(i)), 15, ink()))
			line.add_child(p)
		column.add_child(line)


# --------------------------------------------------------------------------------------------
# The ten designs
# --------------------------------------------------------------------------------------------

func build(host: MarginContainer) -> void:
	host.add_theme_constant_override("margin_left", int(MARGIN))
	host.add_theme_constant_override("margin_right", int(MARGIN))
	host.add_theme_constant_override("margin_bottom", BOTTOM)
	_hero_kind = "fill"
	match design():
		20:
			_list_and_details(host, _slide)
		21:
			_route_page(host, false)
		22:
			_list_and_details(host, _numerals)
		23:
			_list_and_details(host, _metric_rows)
		24:
			_list_and_details(host, _cover, 700.0)
		25:
			_two_views(host)
		26:
			_index_columns(host)
		27:
			_list_and_details(host, _tesseract)
		28:
			_list_and_details(host, _quiet)
		29:
			_route_page(host, true)
		40:
			if bool(m._a_route):
				_route_page(host, false, true)
			else:
				_list_and_details(host, _design_a)


func _list_and_details(host: MarginContainer, filler: Callable, width: float = 620.0) -> void:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 56)
	host.add_child(columns)
	var column := left_column(width)
	columns.add_child(column)
	filler.call(column)
	columns.add_child(m._build_detail_column())


## 20 · The slide: the deck's title and standfirst over an editorial list, groups as tracked
## heads over hairline rows, maturity and length set right; the world as a blue panel last.
func _slide(column: VBoxContainer) -> void:
	column.add_child(statement(50))
	var rows := scroll_rows(column)
	var first: bool = true
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			continue
		gap(rows, 6.0 if first else 22.0)
		first = false
		rows.add_child(group_head(group, 13, 14, false))
		gap(rows, 6.0)
		rows.add_child(rule(true))
		for k in (chunk[1] as Array).size():
			var i: int = int(chunk[1][k])
			if k > 0:
				rows.add_child(rule())
			rows.add_child(line_row(i, 24, maturity_note(i)))
	films_row(column)
	column.add_child(world("fill"))


## 22 · Dividers in the list: each group opens with a huge outlined numeral, the deck's divider
## slides in miniature; its prototypes as plain lines beside it.
func _numerals(column: VBoxContainer) -> void:
	column.add_child(statement(44, false))
	var rows := scroll_rows(column)
	var n: int = 0
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			continue
		n += 1
		gap(rows, 10.0 if n == 1 else 18.0)
		rows.add_child(rule(true))
		gap(rows, 8.0)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 22)
		rows.add_child(line)
		var numeral := txt("%02d" % n, 84, Color(0, 0, 0, 0), "ExtraLight", -2)
		numeral.add_theme_color_override("font_outline_color", gink(group))
		numeral.add_theme_constant_override("outline_size", 3)
		numeral.custom_minimum_size.x = 120
		numeral.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(numeral)
		var right := VBoxContainer.new()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_theme_constant_override("separation", 0)
		line.add_child(right)
		right.add_child(group_head(group, 13, 15, true))
		gap(right, 6.0)
		for i in chunk[1]:
			right.add_child(line_row(int(i), 22))
	films_row(column)
	column.add_child(world("line"))


## 23 · The deck's measured rows (P1 / P2 / P3): a number in blue, the name large, its one line
## small under it, its icon as a quiet drawing on the right; hairlines between.
func _metric_rows(column: VBoxContainer) -> void:
	column.add_child(statement(44, false))
	var rows := scroll_rows(column)
	var first: bool = true
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			continue
		gap(rows, 4.0 if first else 16.0)
		first = false
		rows.add_child(caps(m._group_label(group), 12, gink(group)))
		gap(rows, 4.0)
		for k in (chunk[1] as Array).size():
			var i: int = int(chunk[1][k])
			rows.add_child(rule(k == 0))
			var p := row_panel(i)
			var pad := MarginContainer.new()
			m._set_margins(pad, 12, 10)
			p.add_child(pad)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 20)
			pad.add_child(line)
			var number := caps("P%d" % m._run_number(i), 13, gink(group))
			number.custom_minimum_size.x = 30
			number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(number)
			var words := VBoxContainer.new()
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			words.add_theme_constant_override("separation", 2)
			line.add_child(words)
			words.add_child(txt(title_of(i), 28, ink(), "Light", -1))
			words.add_child(wrapped(txt(String(entry(i).get("blurb")), 13, dim()), 200))
			var icon := TextureRect.new()
			icon.texture = entry(i).get("icon")
			icon.custom_minimum_size = Vector2(54, 40)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.modulate = Color(ink(), 0.55)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(icon)
			rows.add_child(p)
	films_row(column)
	column.add_child(world("fill"))


## A · Ramon's pick, 23, worked (8 Oct): each prototype's own logo where P1, P2 stood, plain
## (no ring, no rounded frame), so the drawing on the right goes; one blue for every group (no
## hue shifts, menu_final._group_color); the world and the video frame take the launch button's
## corners; the details panel flat. The Shooting Range's name one weight up, to compare.
func _design_a(column: VBoxContainer) -> void:
	column.add_child(statement(44, false))
	var rows := scroll_rows(column, 0, 22)
	var first: bool = true
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			continue
		gap(rows, 4.0 if first else 16.0)
		first = false
		# The group's own small icon before its name (the Frontier Map's marks).
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		if group < m._systems.size():
			var mark: Control = m._system_mark(group, accent(), 18)
			head.add_child(mark)
		var name_label := caps(m._group_label(group), 12, gink(group))
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(name_label)
		rows.add_child(head)
		gap(rows, 4.0)
		for k in (chunk[1] as Array).size():
			var i: int = int(chunk[1][k])
			rows.add_child(rule(k == 0))
			var p := row_panel(i)
			var pad := MarginContainer.new()
			m._set_margins(pad, 12, 10)
			p.add_child(pad)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 20)
			pad.add_child(line)
			# 23's grey, lighter still, and bigger.
			var logo := TextureRect.new()
			logo.texture = entry(i).get("icon")
			logo.custom_minimum_size = Vector2(76, 56)
			logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			logo.modulate = Color(ink(), 0.38)
			logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(logo)
			var words := VBoxContainer.new()
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			words.add_theme_constant_override("separation", 2)
			line.add_child(words)
			# Two of the rows try a step up, to compare (Ramon, 8 Oct): the Shooting Range one
			# weight up; 4D Ascent one weight up, a little bigger and 20 % brighter.
			var weight: String = "Regular" if title_of(i) in ["Shooting Range", "4D Ascent"] else "Light"
			var ascent: bool = title_of(i) == "4D Ascent"
			words.add_child(txt(title_of(i), 31 if ascent else 28, ink().lightened(0.2) if ascent else ink(), weight, -1))
			words.add_child(wrapped(txt(String(entry(i).get("blurb")), 13, dim()), 200))
			rows.add_child(p)
	films_row(column, false)
	column.add_child(world_big())


## "A": the world as the big deal it is (Ramon, 8 Oct: "don't downplay it. it's got everything
## integrated and is the big bang"): the code blue, the launch button's corners, a larger title,
## and what is in it.
func world_big() -> PanelContainer:
	_hero_kind = "fill"
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
	var returning: bool = m._laptop_trip() != null
	var heading: String = m.catalogue.hero_return_heading if returning else m.catalogue.hero_heading
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
	if not returning:
		var hero: Resource = m.catalogue.hero
		if hero != null:
			words.add_child(wrapped(txt(String(hero.get("blurb")) + ".", 17, Color(1, 1, 1, 0.92)), 300))
		words.add_child(wrapped(txt("Researchers at work, a cave whose far room lies out along W, the range, a camera for 4D photographs, 5,000 starlings overhead.", 13, Color(1, 1, 1, 0.74)), 300))
	return card


## 24 · The cover: the deck's opening slide as the menu's left half. Its big two-line claim,
## the programme's three verbs under a blue kicker, the world as the call to action, and the
## prototypes as a compact grid of cards.
func _cover(column: VBoxContainer) -> void:
	column.add_child(txt("A fourth dimension.\nSeven ways in.", 52, ink(), "Regular", -2))
	var verbs := VBoxContainer.new()
	verbs.add_theme_constant_override("separation", 2)
	verbs.add_child(caps("Working foundation", 12, accent()))
	verbs.add_child(txt("Build it. Fill it. Live it.", 24, ink(), "Light"))
	column.add_child(verbs)
	column.add_child(world("fill", "Play the world  ·  about 10 min"))
	column.add_child(caps("Or open one experiment", 12, faint()))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			continue
		for i in chunk[1]:
			var p := row_panel(int(i))
			p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pad := MarginContainer.new()
			m._set_margins(pad, 14, 10)
			p.add_child(pad)
			var words := VBoxContainer.new()
			words.add_theme_constant_override("separation", 3)
			pad.add_child(words)
			words.add_child(caps("%02d  ·  %s" % [m._run_number(int(i)), m._group_label(group)], 10, gink(group)))
			words.add_child(txt(title_of(int(i)), 20, ink()))
			grid.add_child(p)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)
	films_row(column)


## 25 · Two views, as the deck's menu slide shows them: the list in one framed screen, the
## details in another, a caption under each.
func _two_views(host: MarginContainer) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 20)
	host.add_child(stack)
	stack.add_child(txt("One menu. Seven experiments.", 44, ink(), "Regular", -1))
	var views := HBoxContainer.new()
	views.add_theme_constant_override("separation", 40)
	views.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(views)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 600
	left.add_theme_constant_override("separation", 12)
	views.add_child(left)
	var frame := PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", box(m.style.surface, 12, hair(true), 1))
	left.add_child(frame)
	var pad := MarginContainer.new()
	m._set_margins(pad, 18, 16)
	frame.add_child(pad)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 12)
	pad.add_child(inside)
	inside.add_child(world("fill", ""))
	var rows := scroll_rows(inside)
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			continue
		gap(rows, 10.0)
		rows.add_child(caps(m._group_label(group), 11, gink(group)))
		for i in chunk[1]:
			var p := row_panel(int(i))
			var row_pad := MarginContainer.new()
			m._set_margins(row_pad, 10, 7)
			p.add_child(row_pad)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 14)
			row_pad.add_child(line)
			var icon := TextureRect.new()
			icon.texture = entry(int(i)).get("icon")
			icon.custom_minimum_size = Vector2(34, 24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.modulate = Color(ink(), 0.6)
			line.add_child(icon)
			var name_label := txt(title_of(int(i)), 18, ink())
			name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(name_label)
			rows.add_child(p)
	films_row(inside)
	left.add_child(_caption("Find and launch a prototype."))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	views.add_child(right)
	var details: Control = m._build_detail_column()
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(details)
	right.add_child(_caption("Understand what it tests, and what it found."))


func _caption(text: String) -> Label:
	var c := txt(text, 17, dim())
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return c


## 26 · The index: a column per group under its outlined numeral and question, the prototypes as
## plain numbered lines; the world as a hairline card; the details lie sideways below.
func _index_columns(host: MarginContainer) -> void:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	host.add_child(stack)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 40)
	stack.add_child(top)
	var title := statement(40, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var w := world("line", "The world")
	w.custom_minimum_size.x = 360
	w.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(w)
	stack.add_child(rule(true))
	var board := HBoxContainer.new()
	board.add_theme_constant_override("separation", 36)
	stack.add_child(board)
	var n: int = 0
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			continue
		n += 1
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 4)
		board.add_child(column)
		var numeral := txt("%02d" % n, 56, Color(0, 0, 0, 0), "ExtraLight", -1)
		numeral.add_theme_color_override("font_outline_color", gink(group))
		numeral.add_theme_constant_override("outline_size", 2)
		column.add_child(numeral)
		column.add_child(group_head(group, 12, 14, true))
		gap(column, 6.0)
		for i in chunk[1]:
			column.add_child(rule())
			column.add_child(line_row(int(i), 20))
	var films := VBoxContainer.new()
	films.custom_minimum_size.x = 220
	board.add_child(films)
	films_row(films)
	var details: Control = m._build_detail_column(true)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(details)


## 27 · The tesseract: the deck cover's line drawing of a 4D cube, here turning live in the
## menu (its slice and W rotations, in the palette's blue), over the claim and the world; the
## list in plain lines under it.
func _tesseract(column: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 10)
	top.add_child(words)
	words.add_child(txt("A fourth dimension.\nA world to test it in.", 40, ink(), "Regular", -1))
	words.add_child(caps("Build it  ·  Fill it  ·  Live it", 12, accent()))
	var cube := Tesseract.new()
	cube.custom_minimum_size = Vector2(200, 170)
	cube.ink = accent()
	top.add_child(cube)
	column.add_child(world("fill"))
	var rows := scroll_rows(column)
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			continue
		gap(rows, 10.0)
		rows.add_child(caps(m._group_label(group), 12, gink(group)))
		gap(rows, 2.0)
		for k in (chunk[1] as Array).size():
			if k > 0:
				rows.add_child(rule())
			rows.add_child(line_row(int(chunk[1][k]), 22, maturity_note(int(chunk[1][k]))))
	films_row(column)


## 28 · Quiet: the original menu's own layout (the world on top, then the list under one
## heading) in the deck's type: Regular names, hairlines, nothing boxed.
func _quiet(column: VBoxContainer) -> void:
	column.add_child(world("line", "Play the world"))
	column.add_child(caps(m.catalogue.list_heading, 12, faint()))
	var rows := scroll_rows(column)
	var first: bool = true
	for chunk in groups():
		var group: int = int(chunk[0])
		if not first:
			gap(rows, 16.0)
		first = false
		rows.add_child(caps(m._group_label(group) if not is_films(group) else m._cinematics_heading(), 12, gink(group) if group < m._systems.size() else faint()))
		gap(rows, 4.0)
		for k in (chunk[1] as Array).size():
			var i: int = int(chunk[1][k])
			rows.add_child(rule(k == 0))
			var p := row_panel(i)
			var pad := MarginContainer.new()
			m._set_margins(pad, 12, 10)
			p.add_child(pad)
			var words := VBoxContainer.new()
			words.add_theme_constant_override("separation", 2)
			pad.add_child(words)
			var head := HBoxContainer.new()
			head.add_theme_constant_override("separation", 12)
			words.add_child(head)
			head.add_child(txt(title_of(i), 22, ink(), "Regular", -1))
			var note := txt(maturity_note(i), 12, faint())
			note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(note)
			words.add_child(wrapped(txt(String(entry(i).get("blurb")), 13, dim()), 200))
			rows.add_child(p)


## 21 and 29 · The route slide ("Nine experiments. Four areas of research."), in the menu:
## the group heads across the top, a curve through every prototype's ring, and the world as the
## route's end; the details lie sideways below. 29 adds the tesseract and outlined numerals.
func _route_page(host: MarginContainer, full: bool, compact: bool = false) -> void:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	host.add_child(page)
	# "A" (compact): the route fills the top half and the details the bottom half, cut in the
	# middle both ways (Ramon, 8 Oct: "video left 50%, text page 50% ... and also half vertical").
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10 if compact else 14)
	page.add_child(stack)
	if compact:
		# 442 : 466 of the 922 px between header and footer puts the cut at 540, the screen's middle.
		stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stack.size_flags_stretch_ratio = 0.95
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 30)
	stack.add_child(top)
	var title := statement(40, not compact)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	if compact:
		var air := Control.new()
		air.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stack.add_child(air)
	if full:
		var cube := Tesseract.new()
		cube.custom_minimum_size = Vector2(170, 130)
		cube.ink = accent()
		top.add_child(cube)
	# Group heads, each over its own stretch of the route (same stretch ratios as the nodes).
	var heads := HBoxContainer.new()
	heads.add_theme_constant_override("separation", 0)
	stack.add_child(heads)
	var route := HBoxContainer.new()
	route.add_theme_constant_override("separation", 0)
	route.custom_minimum_size.y = 176 if compact else 168
	var ring_px: float = 88.0 if compact else 76.0
	stack.add_child(route)
	var rings: Array = []
	var colours: Array = []
	var n: int = 0
	var films: Array = []
	for chunk in groups():
		var group: int = int(chunk[0])
		if is_films(group):
			films = chunk[1]
			continue
		n += 1
		var count: int = (chunk[1] as Array).size()
		var head_box := VBoxContainer.new()
		head_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head_box.size_flags_stretch_ratio = float(count)
		head_box.add_theme_constant_override("separation", 2)
		if full:
			var numeral := txt("%02d" % n, 34, Color(0, 0, 0, 0), "ExtraLight")
			numeral.add_theme_color_override("font_outline_color", gink(group))
			numeral.add_theme_constant_override("outline_size", 2)
			head_box.add_child(numeral)
		head_box.add_child(group_head(group, 12, 13, not compact))
		heads.add_child(head_box)
		for k in count:
			var i: int = int(chunk[1][k])
			var node := VBoxContainer.new()
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			node.add_theme_constant_override("separation", 6)
			route.add_child(node)
			# The deck's route weaves: every other ring sits a little lower.
			gap(node, (40.0 if compact else 30.0) if (rings.size() % 2 == 1) else 8.0)
			var p := row_panel(i)
			p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			node.add_child(p)
			var ring := Control.new()
			ring.custom_minimum_size = Vector2(ring_px, ring_px)
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.draw.connect(_draw_ring.bind(ring, i))
			p.add_child(ring)
			m._tracks[i] = ring
			rings.append(ring)
			colours.append(gink(group))
			var label := txt(title_of(i), 17 if compact else 16, ink())
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			node.add_child(label)
	# The world, the route's end.
	var end := VBoxContainer.new()
	end.add_theme_constant_override("separation", 6)
	end.custom_minimum_size.x = 230
	route.add_child(end)
	gap(end, 28.0 if compact else 22.0)
	var w := world("pill")
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	end.add_child(w)
	var end_label := txt("Where all of it runs together", 13, dim())
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end.add_child(end_label)
	route.set_meta(&"rings", rings)
	route.set_meta(&"colours", colours)
	route.set_meta(&"end", w)
	route.draw.connect(_draw_route.bind(route))
	route.sort_children.connect(route.queue_redraw)
	route.resized.connect(route.queue_redraw)
	var note := HBoxContainer.new()
	note.add_theme_constant_override("separation", 28)
	stack.add_child(note)
	var hint := txt("A capability map, not a required order.", 13, faint())
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.add_child(hint)
	if not films.is_empty():
		films_row(note, not compact)
	if compact:
		# The spare height split above and below the route (3 : 2), so it sits in its half
		# rather than hanging off the headline.
		var air_below := Control.new()
		air_below.size_flags_vertical = Control.SIZE_EXPAND_FILL
		air_below.size_flags_stretch_ratio = 0.67
		stack.add_child(air_below)
	var details: Control = m._build_detail_column(true, compact)
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if compact:
		# One height for every entry (the longest, the Creation Lab, needs 489 px), so the route
		# above never moves when the selection changes; its top lands just above the middle.
		details.size_flags_stretch_ratio = 1.0
		details.custom_minimum_size.y = 492.0
		page.add_child(details)
	else:
		stack.add_child(details)


## A ring of the route: the prototype's icon in a 76 px ring (the deck's 180 px at its scale,
## 5 px stroke), filled blue when selected, a halo round it; a dot when played.
func _draw_ring(ring: Control, index: int) -> void:
	var c: Vector2 = ring.size * 0.5
	var r: float = minf(ring.size.x, ring.size.y) * 0.5 - 6.0
	var chosen: bool = int(m._selected) == index
	var group: int = m._group_of(entry(index))
	var ink_c: Color = gink(group) if group < m._systems.size() else ink()
	ring.draw_circle(c, r, m.style.launch_fill if chosen else m.style.background)
	ring.draw_arc(c, r, 0.0, TAU, 48, m.style.launch_fill if chosen else ink(), 2.5, true)
	if chosen:
		ring.draw_arc(c, r + 5.0, 0.0, TAU, 48, Color(m.style.launch_fill, 0.45), 1.5, true)
	var icon: Texture2D = entry(index).get("icon")
	if icon != null:
		var s: float = r * 1.15
		var aspect: float = float(icon.get_width()) / maxf(1.0, float(icon.get_height()))
		var size := Vector2(s, s / aspect) if aspect >= 1.0 else Vector2(s * aspect, s)
		ring.draw_texture_rect(icon, Rect2(c - size * 0.5, size), false, Color(1, 1, 1) if chosen else Color(ink(), 0.85))
	var played: Array = m._played
	if index < played.size() and bool(played[index]):
		ring.draw_circle(c + Vector2(r * 0.72, -r * 0.72), 5.0, m.style.positive)


## The route's curve through every ring's centre, each stretch in the colour of the group it
## arrives in, then on to the world.
func _draw_route(route: Control) -> void:
	var rings: Array = route.get_meta(&"rings", [])
	var colours: Array = route.get_meta(&"colours", [])
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
		route.draw_polyline(curve, Color(colour, 0.85), 4.0, true)


## The deck cover's 4D cube as a live line drawing: sixteen corners turned in the XW and ZW
## planes (the slice turning), projected from four dimensions to three by W and to the screen
## by a fixed three-quarter view. Edges fade with depth.
class Tesseract extends Control:
	var ink: Color = Color(0.13, 0.4, 0.86)
	var _t: float = 0.0
	var _verts: Array[Vector4] = []
	var _edges: Array[Vector2i] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 16:
			_verts.append(Vector4(
				1.0 if (i & 1) != 0 else -1.0, 1.0 if (i & 2) != 0 else -1.0,
				1.0 if (i & 4) != 0 else -1.0, 1.0 if (i & 8) != 0 else -1.0))
		for a in 16:
			for bit in 4:
				var b: int = a ^ (1 << bit)
				if a < b:
					_edges.append(Vector2i(a, b))

	func _process(delta: float) -> void:
		_t += delta * 0.35
		queue_redraw()

	func _draw() -> void:
		var pts: Array[Vector3] = []
		var c1: float = cos(_t)
		var s1: float = sin(_t)
		var c2: float = cos(_t * 0.7)
		var s2: float = sin(_t * 0.7)
		for v in _verts:
			# XW then ZW.
			var x: float = v.x * c1 - v.w * s1
			var w: float = v.x * s1 + v.w * c1
			var z: float = v.z * c2 - w * s2
			w = v.z * s2 + w * c2
			var k: float = 2.4 / (3.4 - w)
			pts.append(Vector3(x * k, v.y * k, z * k))
		var centre: Vector2 = size * 0.5
		var scale_px: float = minf(size.x, size.y) * 0.24
		var yaw: float = 0.62
		var pitch: float = 0.42
		var screen: Array[Vector2] = []
		var depth: Array[float] = []
		for p in pts:
			var x1: float = p.x * cos(yaw) - p.z * sin(yaw)
			var z1: float = p.x * sin(yaw) + p.z * cos(yaw)
			var y1: float = p.y * cos(pitch) - z1 * sin(pitch)
			var z2: float = p.y * sin(pitch) + z1 * cos(pitch)
			screen.append(centre + Vector2(x1, -y1) * scale_px)
			depth.append(z2)
		for e in _edges:
			var d: float = (depth[e.x] + depth[e.y]) * 0.5
			var a: float = clampf(0.55 + d * 0.18, 0.18, 1.0)
			draw_line(screen[e.x], screen[e.y], Color(ink, a), 1.4, true)
