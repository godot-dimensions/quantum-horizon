@tool
extends Control
class_name FrontierDrawer

## The contextual activity overlay: a temporary right-side drawer over whatever
## map is showing.
##
## NOT A FOURTH SUB-MAP, and the distinction is the whole design. It layers over
## the current map, does not change the current selection, and closing it puts
## you back exactly where you were. That is why it is one Control that shows and
## hides rather than another layout the navigation stack has to remember.
##
## It opens from four places, all of which mean the same thing - "show me what is
## happening at this node":
##
##   - a blue numbered badge on a node
##   - VIEW ACTIVITY in the detail panel
##   - the next-cycle signal pill on a sub-map
##   - a contribution brief action
##
## TWO MODES, ONE DRAWER. Activity aggregates contribution and player signal;
## Next-cycle Signal presents one bounded choice among three. They share a frame
## because they are both "the live human context around this node", and giving
## them separate surfaces would make the second one feel like a separate product.
##
## WHAT IT REFUSES TO BE. Names, pull requests, credits and submitted artefacts
## are explicitly one level DEEPER than this drawer - the actions at the bottom
## lead there. Nothing here expands into permanent map nodes, which is the rule
## that stops a contributor list from becoming a dependency graph.

signal closed()
signal brief_requested(node_id: String)
signal signal_submitted(node_id: String, option_index: int)
## A press that could not do anything - submitting with nothing chosen, or
## submitting twice. Emitted so the map can answer it rather than leaving the
## button looking broken.
signal refused()

enum Tab { ACTIVITY, SIGNAL }

const WIDTH: float = 510.0
## Width kept clear on the right for the scroll bar.
const SCROLLBAR_GUTTER: float = 16.0

var style: FrontierStyle = null

var _dim: ColorRect = null
var _panel: Control = null
var _body: VBoxContainer = null
var _title: Label = null
var _tab_buttons: Array[Button] = []
var _node_id: String = ""
var _activity: FrontierActivity = null
var _tab: Tab = Tab.ACTIVITY
## Which of the three options is currently chosen, or -1. One per drawer opening
## for now; a profile store would hold this instead.
var _chosen: int = -1
var _submitted: bool = false


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func is_open() -> bool:
	return visible


## `initial_tab` exists because the signal pill must land on the signal tab
## directly - arriving on Activity and making someone find the second tab is
## exactly the sort of extra click the overlay was meant to remove.
func open_for(node_id: String, title: String, activity: FrontierActivity,
		initial_tab: Tab = Tab.ACTIVITY) -> void:
	_node_id = node_id
	_activity = activity
	_tab = initial_tab
	if _tab == Tab.SIGNAL and (activity == null or not activity.signal_open):
		_tab = Tab.ACTIVITY
	_chosen = -1
	_submitted = false
	visible = true
	_rebuild(title)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _rebuild(title: String) -> void:
	for child in get_children():
		child.queue_free()
	_tab_buttons.clear()
	if style == null:
		return

	# The map stays visible but subdued underneath, so the drawer reads as a
	# layer over a place rather than as a new place. The dim also swallows clicks
	# so background map controls cannot fire by accident.
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.0, 0.0, 0.0, 0.45)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			close())

	_panel = Control.new()
	# TOP_LEFT, not RIGHT_WIDE. The panel's rect is computed in _layout_panel to
	# line up with the map's reference space; anchors would re-solve it against
	# the WINDOW on the next layout pass and push the content off the edge.
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.clip_contents = true
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_panel.draw.connect(_draw_panel)
	_panel.resized.connect(_panel.queue_redraw)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_bottom", 34)
	_panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)

	_build_header(title)
	if _tab == Tab.ACTIVITY:
		_build_activity()
	else:
		_build_signal()
	_layout_panel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_panel()


func _layout_panel() -> void:
	if _panel == null:
		return
	var scale: float = MenuBanner.reference_scale(size)
	var origin: Vector2 = MenuBanner.reference_origin(size)
	var top: float = origin.y + MenuBanner.HEIGHT * scale

	# Pinned to the WINDOW's right edge, not the reference space's.
	#
	# Aligning it with the reference space read better on a 16:9 window and then
	# hung past the edge on anything else - the project runs CANVAS_ITEMS +
	# EXPAND, so the canvas is wider than 1920 whenever the window is not exactly
	# 16:9, and the drawer's far column went off screen. A panel that is
	# sometimes clipped is worse than one that is sometimes a few pixels out of
	# register with the map behind it.
	# UNSCALED width. The drawer is chrome, not part of the scaled map: its text,
	# buttons and bars are laid out by containers in canvas pixels, so shrinking
	# the panel with the window while its content stayed fixed was what pushed
	# the far column off the edge.
	var width: float = minf(WIDTH, size.x)
	_panel.position = Vector2(size.x - width, top)
	_panel.size = Vector2(width, size.y - top)


func _draw_panel() -> void:
	_panel.draw_rect(Rect2(Vector2.ZERO, _panel.size), style.panel_fill)
	_panel.draw_line(Vector2.ZERO, Vector2(0, _panel.size.y),
		Color(style.selection_ring, 0.7), 1.5, true)


func _build_header(title: String) -> void:
	var top := HBoxContainer.new()
	_body.add_child(top)
	top.add_child(_label("CONTEXTUAL NODE OVERLAY", style.section_size,
		style.selection_ring, style.section_tracking))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)

	var close_button := Button.new()
	close_button.text = "✕"
	close_button.flat = true
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.custom_minimum_size = Vector2(34, 28)
	close_button.add_theme_color_override("font_color", style.text_dim)
	close_button.add_theme_color_override("font_hover_color", style.text_bright)
	close_button.pressed.connect(close)
	top.add_child(close_button)

	if _activity != null and _activity.illustrative:
		# Said on the drawer's face, not in a footnote. Every number below is
		# invented, and a viewer who assumes otherwise would be reading this as
		# a measurement of the project.
		var pill := HBoxContainer.new()
		_body.add_child(pill)
		pill.add_child(_pill("ILLUSTRATIVE FUTURE DATA", style.gate_gold))

	_body.add_child(_gap(8))
	_title = _label(title.to_upper(), style.panel_title_size, style.text_bright, 1)
	_body.add_child(_title)
	_body.add_child(_gap(6))
	_build_tabs()
	_body.add_child(_rule())


func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var signal_available: bool = _activity != null and _activity.signal_open
	for i in 2:
		var button := Button.new()
		button.text = "ACTIVITY" if i == 0 else "NEXT-CYCLE SIGNAL"
		button.focus_mode = Control.FOCUS_ALL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 42
		# Disabled rather than hidden when no signal is running: the interaction
		# should stay discoverable so people learn it exists before it opens.
		button.disabled = i == 1 and not signal_available
		var active: bool = int(_tab) == i
		var tint: Color = style.selection_ring if i == 0 else style.upcoming_stroke
		button.add_theme_font_size_override("font_size", style.small_caps_size + 1)
		button.add_theme_color_override("font_color", tint if active else style.text_dim)
		button.add_theme_color_override("font_disabled_color", style.text_faint)
		var font: Font = style.caps_font(2)
		if font != null:
			button.add_theme_font_override("font", font)
		var fill: Color = style.tab_active_fill if active else style.tab_idle_fill
		var stroke: Color = tint if active else style.tab_idle_stroke
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, _box(fill, stroke))
		if not active and not button.disabled:
			button.pressed.connect(func() -> void:
				_tab = Tab.ACTIVITY if i == 0 else Tab.SIGNAL
				_rebuild(_title.text))
		row.add_child(button)
		_tab_buttons.append(button)


# --------------------------------------------------------------------------
# Activity tab
# --------------------------------------------------------------------------

func _build_activity() -> void:
	if _activity == null:
		_body.add_child(_copy("No recorded activity for this node yet."))
		return

	_body.add_child(_head("CONTRIBUTION ACTIVITY"))
	_body.add_child(_stat_row([
		"%d contributors" % _activity.contributors,
		"%d merged" % _activity.merged,
		"%d open briefs" % _activity.open_briefs,
	]))

	if _activity.member_initials.size() > 0:
		_body.add_child(_gap(6))
		_body.add_child(_members())

	_body.add_child(_rule())
	_body.add_child(_head("CONTRIBUTION LANES"))
	for i in _activity.lane_count():
		_body.add_child(_lane(_activity.lane_names[i], _activity.lane_counts[i],
			_activity.lane_fills[i], _lane_tint(i)))

	_body.add_child(_rule())
	_body.add_child(_head("PLAYER SIGNAL"))
	_body.add_child(_stat_row([
		"%d played" % _activity.played,
		"%d completed" % _activity.completed,
		"%d shared" % _activity.shared,
	]))
	_body.add_child(_copy("Signals accumulate here without becoming map nodes."))

	_body.add_child(_rule())
	_body.add_child(_head("WHY THIS SCALES"))
	_body.add_child(_copy("The map shows aggregate activity. Names, PRs, credits and artefacts live one level deeper."))
	_body.add_child(_gap(10))
	_body.add_child(_action("VIEW CONTRIBUTION BRIEF", style.button_fill,
		func() -> void: brief_requested.emit(_node_id)))


func _lane_tint(index: int) -> Color:
	var tints: Array[Color] = [style.selection_ring, style.upcoming_stroke, style.research_stroke]
	return tints[index % tints.size()]


func _members() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for i in _activity.member_initials.size():
		row.add_child(_chip(_activity.member_initials[i], _lane_tint(i)))
	if _activity.member_overflow > 0:
		row.add_child(_chip("+%d" % _activity.member_overflow, style.text_faint))
	return row


## A stand-in for an avatar. Deliberately initials on a tinted disc rather than
## an image: identity is a backend concern, and this shows that a count is made
## of people without inventing a directory the project does not have.
func _chip(text: String, tint: Color) -> Control:
	var chip := Control.new()
	chip.custom_minimum_size = Vector2(40, 40)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.draw.connect(func() -> void:
		var mid: Vector2 = chip.size * 0.5
		chip.draw_circle(mid, 19.0, Color(tint, 0.16))
		chip.draw_arc(mid, 19.0, 0.0, TAU, 32, tint, 1.4, true)
		if style.font == null:
			return
		var width: float = style.font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		chip.draw_string(style.font, mid + Vector2(-width * 0.5, 4.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, style.text_bright))
	return chip


func _lane(name: String, count: int, fill: float, tint: Color) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	# `_label`, not `_copy`. `_copy` carries a 380px minimum width so paragraphs
	# wrap sensibly - two of those in one row demanded 760px and dragged the whole
	# drawer's content wider than the panel, which is what was clipping the far
	# column. Short inline text has no business setting a minimum.
	var row := HBoxContainer.new()
	row.add_child(_label(name, style.body_size - 1, style.text_dim, 0))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_label(str(count), style.body_size - 1, style.text_dim, 0))
	# The scrollbar is drawn INSIDE the ScrollContainer's rect, on top of its
	# content, so a right margin on the container does not move out from under
	# it. Reserving the width in the row itself does.
	var gutter := Control.new()
	gutter.custom_minimum_size = Vector2(SCROLLBAR_GUTTER, 0)
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gutter)
	column.add_child(row)

	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 5)
	bar.size_flags_stretch_ratio = 1.0
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), style.tab_idle_stroke)
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * clampf(fill, 0.0, 1.0),
			bar.size.y)), tint))
	column.add_child(bar)
	column.add_child(_gap(8))
	return column


# --------------------------------------------------------------------------
# Next-cycle signal tab
# --------------------------------------------------------------------------

func _build_signal() -> void:
	_body.add_child(_head("ONE BOUNDED CHOICE · NEXT 1–2 SPRINTS"))
	_body.add_child(_copy("The team publishes three feasible options. Choose one."))
	_body.add_child(_gap(8))

	for i in _activity.option_count():
		_body.add_child(_option(i))

	_body.add_child(_gap(6))
	_body.add_child(_copy("ONE SIGNAL PER PROFILE · CLOSES AFTER THE CURRENT CYCLE"))
	_body.add_child(_gap(8))
	var label: String = "SIGNAL SUBMITTED" if _submitted else "SUBMIT SIGNAL"
	var submit := _action(label, style.upcoming_stroke.darkened(0.55), func() -> void:
		if _chosen < 0 or _submitted:
			refused.emit()
			return
		_submitted = true
		signal_submitted.emit(_node_id, _chosen)
		_rebuild(_title.text))
	_body.add_child(submit)

	_body.add_child(_rule())
	_body.add_child(_head("WHAT THIS INPUT DOES"))
	# The most important sentence in the drawer. Without it the interaction
	# looks like roadmap editing, which is exactly what it must not be.
	_body.add_child(_copy("It informs one near-term priority. It does not edit dependencies, create nodes, or override gate evidence."))


func _option(index: int) -> Control:
	var chosen: bool = _chosen == index
	var tint: Color = _lane_tint(index)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 94)
	button.disabled = _submitted and not chosen
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state,
			_box(style.tab_active_fill if chosen else style.tab_idle_fill,
				tint if chosen else style.tab_idle_stroke))
	button.pressed.connect(func() -> void:
		_chosen = index
		_rebuild(_title.text))
	button.draw.connect(func() -> void:
		var mid_y: float = 27.0
		button.draw_arc(Vector2(24, mid_y), 9.0, 0.0, TAU, 24, tint, 1.5, true)
		if chosen:
			button.draw_circle(Vector2(24, mid_y), 5.0, tint)
		if style.font == null:
			return
		var caps: Font = style.caps_font(1)
		button.draw_string(caps, Vector2(45, mid_y + 5.0), _activity.option_titles[index],
			HORIZONTAL_ALIGNMENT_LEFT, -1, style.node_label_size, style.text_bright)
		button.draw_string(style.caps_font(2), Vector2(45, mid_y + 30.0),
			_activity.option_subtitles[index], HORIZONTAL_ALIGNMENT_LEFT, -1,
			style.small_caps_size, style.text_faint)
		if _activity.show_option_counts and index < _activity.option_counts.size():
			var text := "%d signals" % _activity.option_counts[index]
			var width: float = style.font.get_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.body_size - 1).x
			button.draw_string(style.font, Vector2(button.size.x - 20.0 - width, mid_y + 5.0),
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.body_size - 1, style.text_dim)
			var fill: float = float(_activity.option_counts[index]) / 30.0
			var track := Rect2(Vector2(45, mid_y + 45.0), Vector2(button.size.x - 90.0, 5))
			button.draw_rect(track, style.tab_idle_stroke)
			button.draw_rect(Rect2(track.position,
				Vector2(track.size.x * clampf(fill, 0.0, 1.0), track.size.y)), tint))
	return button


# --------------------------------------------------------------------------
# Small parts
# --------------------------------------------------------------------------

func _label(text: String, font_size: int, color: Color, tracking: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	var font: Font = style.caps_font(tracking)
	if font != null:
		label.add_theme_font_override("font", font)
	return label


func _head(text: String) -> Label:
	return _label(text, style.small_caps_size, style.panel_head, 2)


func _copy(text: String) -> Label:
	var label := _label(text, style.body_size - 1, style.text_dim, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# No minimum width. An autowrapping label reports its longest word as its
	# minimum and wraps to whatever it is given; asking for 380 on top of that
	# only ever pushes the container wider.
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _stat_row(values: PackedStringArray) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	for value in values:
		row.add_child(_label(value, style.node_label_size, style.text, 0))
	return row


func _rule() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 22)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.draw.connect(func() -> void:
		holder.draw_line(Vector2(0, 12), Vector2(holder.size.x, 12), style.divider, 1.0))
	return holder


func _gap(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _pill(text: String, tint: Color) -> Control:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(tint, 0.12)
	box.border_color = Color(tint, 0.75)
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(_label(text, style.small_caps_size - 1, tint, 1))
	return panel


func _action(text: String, fill: Color, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", style.small_caps_size + 1)
	button.add_theme_color_override("font_color", style.text_bright)
	var font: Font = style.caps_font(2)
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_stylebox_override("normal", _box(fill, style.button_stroke))
	button.add_theme_stylebox_override("hover", _box(fill.lightened(0.12), style.button_stroke))
	button.add_theme_stylebox_override("pressed", _box(fill.darkened(0.2), style.button_stroke))
	button.add_theme_stylebox_override("focus", _box(fill, style.text_bright))
	button.pressed.connect(on_pressed)
	return button


func _box(fill: Color, stroke: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = stroke
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	return box
