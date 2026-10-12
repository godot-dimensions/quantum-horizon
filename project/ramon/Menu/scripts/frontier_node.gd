@tool
extends Control
class_name FrontierNode

## One circular node on the Frontier Map, in every state it can be in.
##
## A SCRIPT WITH A class_name, NOT A .tscn. The brief asked for a reusable
## `FrontierNode.tscn`; this is that reusability without the scene file, and the
## reason is the trap CLAUDE.md documents - a hand-written .tscn that Godot has
## not normalised needs the resave script, and the resave script rewrites all 130
## scenes in the project. `menu2.gd`, `hub_gate_ring_4d.gd` and
## `ascent_builder_4d.gd` all already build their children in code for exactly
## this reason, so this follows the house pattern rather than introducing a
## second one.
##
## Everything is drawn in a single `_draw()` rather than assembled from a Panel,
## a TextureRect and three Labels. Ten nodes would otherwise be sixty-odd
## Controls, all needing their own theme overrides, and the ring/dash/glow
## treatment the reference art uses is not expressible as a StyleBox anyway.
##
## HIT AREA IS THE CIRCLE. The control's rect is a square around the circle, at
## least `style.min_hit_size` on a side, and the labels are drawn BELOW that rect
## deliberately - overflowing a Control's rect draws fine, and it keeps the label
## from stealing clicks meant for the node above it.

signal focused(entry_title: String)
signal activated(entry_title: String)
## Drag lifecycle. The map listens so it can pull this node's route neighbours
## along and keep the edges following while anything is moving.
signal drag_started(entry_title: String)
signal dragged(entry_title: String)
signal drag_released(entry_title: String)
## The blue numbered badge was pressed. A SEPARATE intention from selecting or
## activating the node - "show me what is happening here", not "open this".
signal activity_requested(entry_title: String)

const CHECK_RADIUS: float = 11.0
## The gate badge is a BOOKMARK, not a disc: a rectangle whose bottom corners
## converge to a point. A circle read as one more status dot among the checks and
## the activity badges; a bookmark reads as "flagged for something", which is
## exactly what a gate cross-reference is.
## Sized to sit in the same weight class as the blue activity badges
## (BADGE_RADIUS * 2 = 28 across). A flag that out-measures them would claim to
## be the more important of the two markers, which it is not - they are peers.
const GATE_WIDTH: float = 23.0
const GATE_HEIGHT: float = 29.0
## How far the point drops below the rectangle's shoulders.
const GATE_POINT: float = 8.0
const BADGE_RADIUS: float = 14.0

var placement: FrontierEntry = null
var style: FrontierStyle = null
var title_text: String = ""
var sub_text: String = ""

## The catalogue entry's own icon, so `catalogue.tres` stays the single place an
## icon is chosen and changing it there changes it on BOTH screens. Falls back to
## the placement's glyph for a standalone node, which has no catalogue entry.
var icon: Texture2D = null

## Where this node belongs. `position` is `home + drag_offset`, so the node can
## be pulled around without ever losing the authored placement.
var home: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO

## Where this node is being pulled to right now. Set by itself while it is the
## one under the cursor, and by the map for its neighbours, so a drag moves a
## small connected piece of the graph rather than one lonely circle.
var drag_target: Vector2 = Vector2.ZERO

## True only for the node actually under the cursor with the button held.
var dragging: bool = false

## How far a node can be pulled from home, in reference pixels. A hard cap
## rather than a rubber band that keeps giving: the map is a composed layout and
## a node dragged across it would be lying about where it belongs.
const MAX_PULL: float = 26.0
## Fraction of the mouse's travel the node actually follows. Under one, so the
## node feels attached to something rather than stuck to the cursor.
const PULL_RATIO: float = 0.55

## Set by the map, not by this node. Selection is a property of the SCREEN - only
## one node is selected - so the node draws it but does not decide it.
var selected: bool = false:
	set(value):
		if selected == value:
			return
		selected = value
		# The living ring only ticks on the selected node, so processing follows
		# selection rather than running on all ten.
		set_process(value)
		queue_redraw()

var _hovered: bool = false
var _press_at: Vector2 = Vector2.ZERO
## Drives the selection ring's wobble. Only advanced while this node is the
## selected one, so an idle screen animates exactly one ring.
var _pulse_time: float = 0.0
var _badge: Button = null
var _gate: Button = null
## Whether the gold G is currently explaining itself. Off by default: the badge
## is a cross-reference, and a permanent caption beside every gate-essential node
## would compete with the node's own label.
var _gate_open: bool = false


func _process(delta: float) -> void:
	if not selected:
		set_process(false)
		return
	_pulse_time += delta
	queue_redraw()


func setup(p_placement: FrontierEntry, p_style: FrontierStyle, p_title: String,
		p_sub: String, p_icon: Texture2D = null) -> void:
	placement = p_placement
	style = p_style
	title_text = p_title
	sub_text = p_sub
	icon = p_icon

	var radius: float = _outer_radius()
	var side: float = maxf(radius * 2.0, style.min_hit_size)
	custom_minimum_size = Vector2(side, side)
	size = Vector2(side, side)
	pivot_offset = size * 0.5

	# The icons are 512px and drawn at roughly 27. Without mipmaps that
	# downscale samples one texel in twenty and aliases into a pixelated mess -
	# which is what it did. The .import files now generate mipmaps; this is the
	# other half, telling the canvas to actually sample them.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	# Fog nodes are atmosphere, not choices. No focus, no mouse, per the brief's
	# "Fog nodes cannot receive focus or clicks" acceptance criterion.
	if placement.is_focusable():
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		focus_entered.connect(_on_focus_entered)
		focus_exited.connect(queue_redraw)
	_build_activity_badge()
	_build_gate_badge()
	queue_redraw()


## The blue numbered badge, as a real child Button with its own focus.
##
## A CHILD CONTROL, not a hit-test inside `_gui_input`, because the brief is
## specific: the badge must be reachable without a mouse and its click must not
## propagate to the parent. A Button gives both for free - it consumes the press
## before the node sees it, and it takes its own place in the focus order.
##
## Generous hit area on purpose. The visible disc is 14px in reference space,
## which is far below the 44px floor, so the button is sized to the floor and the
## disc is drawn centred inside it.
func _build_activity_badge() -> void:
	if _badge != null and is_instance_valid(_badge):
		_badge.queue_free()
		_badge = null
	if placement == null or not placement.has_activity():
		return

	var radius: float = base_radius()
	# Up and to the right, unless the gold G is already there - two badges on one
	# diagonal would overlap, and the G is the one that cannot move without
	# breaking its meaning as a fixed cross-reference.
	var direction := Vector2(1, -1) if not placement.has_flag() else Vector2(-1, -1)
	var side: float = maxf(style.min_hit_size, BADGE_RADIUS * 2.0)
	_badge = Button.new()
	_badge.flat = true
	_badge.focus_mode = Control.FOCUS_ALL
	_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	_badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_badge.size = Vector2(side, side)
	_badge.position = size * 0.5 + direction.normalized() * radius * 1.02 - Vector2(side, side) * 0.5
	_badge.tooltip_text = "Open activity for %s" % title_text.replace("\n", " ")
	for state in ["normal", "hover", "pressed", "disabled"]:
		_badge.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_badge.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_badge.pressed.connect(func() -> void: activity_requested.emit(placement.entry_title))
	_badge.draw.connect(_draw_badge)
	add_child(_badge)


func _draw_badge() -> void:
	var mid: Vector2 = _badge.size * 0.5
	_badge.draw_circle(mid, BADGE_RADIUS, style.badge_fill)
	_badge.draw_arc(mid, BADGE_RADIUS, 0.0, TAU, 32, style.badge_stroke, 1.2, true)
	if _badge.has_focus():
		_badge.draw_arc(mid, BADGE_RADIUS + 5.0, 0.0, TAU, 32, style.text_bright, 1.4, true)
	if style.font == null:
		return
	var text: String = placement.activity_glyph if placement.activity_glyph != "" \
		else str(placement.activity_count)
	var width: float = style.font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	_badge.draw_string(style.font, mid + Vector2(-width * 0.5, 4.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, style.text_bright)


## Places the node so its CENTRE lands on the reference position, since the
## reference art measures circle centres rather than control corners.
func place_at(at: Vector2) -> void:
	home = at - size * 0.5
	position = home + drag_offset


## Moves the node one step and reports whether it still needs another.
##
## Two regimes, deliberately different in feel:
##
##   HELD - the node chases `drag_target` quickly but never instantly, which is
##   what reads as tension rather than as the node being welded to the cursor.
##   The target is already clamped to MAX_PULL, so the pull has a limit.
##
##   RELEASED - it eases home SLOWLY. No spring, no overshoot, no bounce: a
##   released node drifting back is calm, whereas one that springs past its
##   position and wobbles reads as a physics toy and pulls the eye away from the
##   thing the screen is actually saying.
func advance_drag(delta: float) -> bool:
	var chasing: bool = drag_target != Vector2.ZERO
	var rate: float = 14.0 if chasing else 3.4
	drag_offset = drag_offset.lerp(drag_target, clampf(rate * delta, 0.0, 1.0))
	if not chasing and drag_offset.length() < 0.08:
		drag_offset = Vector2.ZERO
		position = home
		return false
	position = home + drag_offset
	return true


## Clamped pull from the point the press started, in this node's own space.
func set_pull(from_press: Vector2) -> void:
	drag_target = (from_press * PULL_RATIO).limit_length(MAX_PULL)


func centre() -> Vector2:
	return position + size * 0.5


func base_radius() -> float:
	return style.node_radius * (1.0 if placement == null else placement.radius_scale)


func _outer_radius() -> float:
	return base_radius() + style.node_radius_selected_bonus + style.selection_ring_gap


## HOVER DOES NOT SELECT. It only lights the ring.
##
## Selecting on hover meant the detail panel changed every time the cursor
## crossed the map on its way somewhere else, so the panel you were reading
## could be replaced by one you never asked for. Selection is now a deliberate
## act - click, arrow keys, or controller focus - and hover is just the cursor
## saying which node it is over.
func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _on_focus_entered() -> void:
	queue_redraw()
	if placement != null:
		focused.emit(placement.entry_title)


func _gui_input(event: InputEvent) -> void:
	if placement == null or not placement.is_focusable():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		accept_event()
		if button.pressed:
			grab_focus()
			focused.emit(placement.entry_title)
			# SELECT ON PRESS, LAUNCH ON DOUBLE CLICK. A press never launches, so
			# grabbing a node to move it can never start a two-minute prototype
			# by accident.
			if button.double_click:
				activated.emit(placement.entry_title)
				return
			dragging = true
			_press_at = button.position
			drag_started.emit(placement.entry_title)
		else:
			dragging = false
			drag_target = Vector2.ZERO
			drag_released.emit(placement.entry_title)
	elif event is InputEventMouseMotion and dragging:
		accept_event()
		# Measured from the press point in this node's own space, so the pull
		# direction is exactly the direction the mouse has travelled.
		set_pull((event as InputEventMouseMotion).position - _press_at)
		dragged.emit(placement.entry_title)
	elif event.is_action_pressed("ui_accept"):
		accept_event()
		activated.emit(placement.entry_title)


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
	if placement == null or style == null:
		return

	var mid: Vector2 = size * 0.5
	var radius: float = base_radius()
	if selected:
		radius += style.node_radius_selected_bonus

	var fill: Color = _fill_color()
	var stroke: Color = _stroke_color()
	var dashes: int = _dash_count()

	# THE SELECTION RING IS THE LIVING ONE. Selected is the state worth animating
	# - it is where you are - so the wobble marks the current node rather than
	# decorating whatever the cursor happens to be over. Drawn first, so it sits
	# UNDER the node as a halo instead of competing with the state's own stroke.
	if selected:
		_draw_living_ring(mid, radius + style.selection_ring_gap,
			Color(style.selection_ring, 0.9), style.node_stroke_width)
	elif _hovered:
		# Hover is a plain ring at low weight: a quieter version of the same
		# idea, so hovering reads as "this one next" and not as a second
		# selection competing with the real one.
		draw_arc(mid, radius + style.selection_ring_gap * 0.6, 0.0, TAU, 48,
			Color(stroke, 0.4), 1.4, true)

	if placement.haloed:
		draw_arc(mid, radius + 8.0, 0.0, TAU, 64, Color(stroke, 0.55), 1.4, true)

	draw_circle(mid, radius, fill)
	if dashes > 0:
		_draw_dashed_arc(mid, radius, stroke, style.node_stroke_width, dashes)
	else:
		draw_arc(mid, radius, 0.0, TAU, 64, stroke, style.node_stroke_width, true)

	_draw_glyph(mid, radius)
	_draw_labels(mid, radius)

	if placement.state == FrontierEntry.State.PLAYED:
		_draw_check(mid, radius)



func _fill_color() -> Color:
	match placement.state:
		FrontierEntry.State.PLAYED: return style.played_fill
		FrontierEntry.State.RESEARCH: return style.research_fill
		FrontierEntry.State.UPCOMING: return style.upcoming_fill
		FrontierEntry.State.FOG: return style.fog_fill
		_: return style.available_fill


func _stroke_color() -> Color:
	match placement.state:
		FrontierEntry.State.PLAYED: return style.played_stroke
		FrontierEntry.State.RESEARCH: return style.research_stroke
		FrontierEntry.State.UPCOMING: return style.upcoming_stroke
		FrontierEntry.State.FOG: return style.fog_stroke
		_: return style.available_stroke


## Dashed outlines carry meaning here: solid is built, dashed is not yet real.
## Returning a dash COUNT rather than a length keeps the gaps even all the way
## round the circle whatever the radius.
func _dash_count() -> int:
	match placement.state:
		FrontierEntry.State.RESEARCH: return 22
		FrontierEntry.State.FOG: return 18
		_: return 0


## A hover ring that breathes, so a node answers the cursor instead of just
## lighting up.
##
## Same width and colour as the plain ring it replaces - the wobble is the only
## difference, and it is deliberately small (about two pixels of radius on a
## thirty-eight pixel circle). Two harmonics at incommensurate speeds, so the
## shape never visibly repeats and never reads as a spinning object.
## Few, broad bumps moving quickly - harmonics 3 and 5 at full amplitude, driven
## at roughly double the original rate.
##
## The frequencies are what the shape looks like; the time multipliers are what
## it feels like. Raising the speed rather than the frequency keeps the ring
## reading as one soft thing breathing, where more bumps had started to read as
## a texture. The two rates stay incommensurate so the waves never line up and
## the shape never settles into a repeat.
func _draw_living_ring(mid: Vector2, radius: float, color: Color, width: float) -> void:
	const AMPLITUDE: float = 2.1
	const SEGMENTS: int = 96
	var points := PackedVector2Array()
	for i in SEGMENTS + 1:
		# The last point is forced back onto the first, because a wobble that
		# does not close leaves a visible notch at angle zero.
		var t: float = float(i % SEGMENTS) / float(SEGMENTS)
		var angle: float = t * TAU
		var wobble: float = sin(angle * 3.0 + _pulse_time * 3.6) * 0.65 \
			+ sin(angle * 5.0 - _pulse_time * 2.3) * 0.35
		points.append(mid + Vector2(cos(angle), sin(angle)) * (radius + wobble * AMPLITUDE))
	draw_polyline(points, color, width, true)


func _draw_glyph(mid: Vector2, radius: float) -> void:
	var glyph_color: Color = style.available_glyph
	match placement.state:
		FrontierEntry.State.PLAYED: glyph_color = style.played_glyph
		FrontierEntry.State.RESEARCH: glyph_color = style.research_stroke
		FrontierEntry.State.UPCOMING: glyph_color = style.played_glyph
		FrontierEntry.State.FOG: glyph_color = style.fog_stroke

	# The catalogue's icon wins when there is one, so `catalogue.tres` stays the
	# single place an icon is chosen and both screens follow it. Drawn at
	# `node_icon_scale` of the radius rather than filling the circle - the ring
	# carries the state, and a full-bleed picture would drown it.
	if icon != null:
		var box: float = radius * style.node_icon_scale
		draw_texture_rect(icon, Rect2(mid - Vector2(box, box) * 0.5, Vector2(box, box)),
			false, glyph_color)
		return

	if placement.glyph == "" or style.font == null:
		return
	var glyph_size: int = int(round(radius * 0.68))
	var width: float = style.font.get_string_size(
		placement.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size).x
	# Optical centring: the font's ascent puts a glyph's visual middle above the
	# baseline, so the baseline goes BELOW centre by roughly a third of the size.
	draw_string(style.font, mid + Vector2(-width * 0.5, glyph_size * 0.36),
		placement.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, glyph_size, glyph_color)


func _draw_labels(mid: Vector2, radius: float) -> void:
	if style.font == null:
		return
	var caps: Font = style.caps_font(1)
	var label_y: float = mid.y + radius + 30.0
	var label_color: Color = style.text if placement.state != FrontierEntry.State.FOG else style.fog_stroke
	# Titles may carry a newline: the sub-maps name things like "MATERIALS +
	# SCATTER", which will not fit on one line beside its neighbours.
	for line in title_text.split("
"):
		var width: float = caps.get_string_size(
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, style.node_label_size).x
		draw_string(caps, Vector2(mid.x - width * 0.5, label_y), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, style.node_label_size, label_color)
		label_y += 20.0

	if sub_text == "":
		return
	var sub_caps: Font = style.caps_font(2)
	var sub_width: float = sub_caps.get_string_size(
		sub_text, HORIZONTAL_ALIGNMENT_LEFT, -1, style.node_sub_size).x
	draw_string(sub_caps, Vector2(mid.x - sub_width * 0.5, label_y + 16.0), sub_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, style.node_sub_size, style.text_faint)


func _draw_check(mid: Vector2, radius: float) -> void:
	# Up and to the right, on the 45 degree diagonal, so it never collides with
	# the label below or the route edges entering from left and right.
	var at: Vector2 = mid + Vector2(radius, -radius) * 0.72
	draw_circle(at, CHECK_RADIUS, style.check_fill)
	var tick := PackedVector2Array([
		at + Vector2(-5.0, 0.0), at + Vector2(-1.0, 4.0), at + Vector2(6.0, -5.0),
	])
	draw_polyline(tick, Color.WHITE, 2.0, true)


## The gold G, as a pressable badge that names what it refers to.
##
## It used to be inert - the badge language says selecting the NODE explains the
## relationship - but an inert thing that looks like a button reads as broken.
## Pressing it now reveals "OCTOBER GATE" beside it, which is the whole content
## of the cross-reference, without turning the badge into navigation.
func _build_gate_badge() -> void:
	if _gate != null and is_instance_valid(_gate):
		_gate.queue_free()
		_gate = null
	if placement == null or not placement.has_flag():
		return

	var side: float = maxf(style.min_hit_size, maxf(GATE_WIDTH, GATE_HEIGHT))
	_gate = Button.new()
	_gate.flat = true
	_gate.focus_mode = Control.FOCUS_ALL
	_gate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_gate.size = Vector2(side, side)
	_gate.position = size * 0.5 + Vector2(1, -1).normalized() * base_radius() * 1.02 		- Vector2(side, side) * 0.5
	_gate.tooltip_text = placement.flag_caption_text()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		_gate.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_gate.pressed.connect(func() -> void:
		_gate_open = not _gate_open
		_gate.queue_redraw())
	_gate.draw.connect(_draw_gate_badge)
	add_child(_gate)


func _draw_gate_badge() -> void:
	var mid: Vector2 = _gate.size * 0.5
	var half := Vector2(GATE_WIDTH, GATE_HEIGHT) * 0.5
	# Rectangle with the bottom corners pulled into a point - a bookmark tail.
	var shape := PackedVector2Array([
		mid + Vector2(-half.x, -half.y),
		mid + Vector2(half.x, -half.y),
		mid + Vector2(half.x, half.y - GATE_POINT),
		mid + Vector2(0.0, half.y),
		mid + Vector2(-half.x, half.y - GATE_POINT),
	])
	var tint: Color = style.gate_gold if placement.gate_essential else style.upcoming_stroke
	var edge: Color = style.gate_gold_bright if placement.gate_essential else style.text_bright
	_gate.draw_colored_polygon(shape, tint)

	# No focus RING - a circle around a bookmark is the shape this was changed
	# away from. Focus brightens and thickens the outline instead.
	var outline := shape.duplicate()
	outline.append(shape[0])
	var focused: bool = _gate.has_focus()
	_gate.draw_polyline(outline, edge, 2.2 if focused else 1.4, true)

	if style.font == null:
		return

	var letter: String = placement.flag_text()
	var letter_size: int = 12
	var width: float = style.font.get_string_size(
		letter, HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size).x
	# Sits in the rectangular body, above the point, rather than in the centre of
	# the whole silhouette - otherwise it reads as sliding off the bottom.
	var at: Vector2 = mid + Vector2(-width * 0.5, letter_size * 0.36 - GATE_POINT * 0.42)
	# Faked bold: the family only ships one weight here, so the glyph is drawn
	# three times a fraction of a pixel apart. Cheaper than importing a second
	# face for one letter.
	for offset in [Vector2.ZERO, Vector2(0.6, 0), Vector2(0.3, 0.3)]:
		_gate.draw_string(style.font, at + offset, letter,
			HORIZONTAL_ALIGNMENT_LEFT, -1, letter_size, style.gate_gold_ink)

	if not _gate_open:
		return
	# Drawn OUTSIDE the button's rect, which is fine - Controls do not clip by
	# default - so the caption can be as wide as it needs without inflating the
	# badge's hit area.
	var caps: Font = style.caps_font(2)
	_gate.draw_string(caps, Vector2(mid.x + half.x + 10.0, mid.y + 4.0),
		placement.flag_caption_text(), HORIZONTAL_ALIGNMENT_LEFT, -1,
		style.small_caps_size, tint)


## Even dashes around a circle. Godot's draw_arc has no dash support, so the
## circle is walked in `dashes` equal wedges and every other wedge is drawn.
func _draw_dashed_arc(at: Vector2, radius: float, color: Color, width: float, dashes: int) -> void:
	var step: float = TAU / float(dashes)
	for i in dashes:
		if i % 2 == 1:
			continue
		var from: float = float(i) * step
		draw_arc(at, radius, from, from + step * 0.6, 4, color, width, true)
