extends Control

## Which of the three cameras is on, bottom left, just above the belt.
##
## A STUDY TOOL THAT LOOKS LIKE THE GAME. The point of the three presets is to decide
## between them by playing, and that decision is worth nothing if you cannot tell which
## one you are in - after two Tabs the difference between 55 and 45 degrees is a feeling,
## not a fact. So the active one is named, and the lens and distance are printed under it.
##
## IT READS THE RIG RATHER THAN REPEATING IT. The names and numbers come out of the rig's
## own PRESETS, so adding a fourth camera there gives it a fourth button here and there is
## no second list to keep in step.
##
## DRAWN, AND IN THE SAME HAND AS THE CONTROLS CARD - same panel, same chip corners, same
## fractions of white. Two HUD pieces in two different styles look like an accident.
##
## STACKED, NOT IN A ROW. A row of four buttons is a strip of HUD across the bottom of the
## screen; a column of four is a narrow block in a corner that was empty anyway. The names
## are centred in their boxes so the column reads as buttons rather than as a list.

@export var rig_path: NodePath
## The line over the buttons. Empty draws no heading.
##
## IT SAYS WHAT THIS IS FOR. A stack of four buttons in the corner of a farm reads as a
## game feature somebody has to work out; labelled as a test, it reads as scaffolding,
## and scaffolding is allowed to be temporary.
@export var title: String = "3rd person camera testing"
## The line under it. The key belongs in the heading rather than in the readout below the
## buttons: it is how you work the thing, and that should be the second thing you read,
## not the last.
@export var subtitle: String = "press TAB to toggle"
## Font size for the names in their boxes; the line under them is drawn smaller.
@export_range(9, 24, 1) var text_size: int = 13
@export_range(0.0, 1.0, 0.01) var panel_alpha: float = 0.34
## Optional. A panel to sit underneath, right edges lined up.
##
## UNDER IT, NOT PART OF IT. The controls card is what the game is; this is scaffolding
## for a decision that will be made and then taken away. Sharing a panel with the card
## would say they are the same kind of thing, and would also mean pulling the card apart
## again when the cameras are settled. Its own panel, tucked under the card's corner, says
## "related, and temporary".
##
## It follows the card's ACTUAL rect rather than a number typed here, because the card
## sizes itself to however many rows it ends up with - and it is read whether the card is
## visible or not, so hiding the card with H does not make this jump up the screen.
@export var under_path: NodePath
## Space between the two panels.
@export_range(0.0, 60.0, 1.0) var gap: float = 8.0
## Optional. Something already occupying that corner, to slide left of rather than sit on
## top of.
##
## LEFT UNWIRED ON THE FARM, and the reason is worth keeping. Pointed at the dial, this
## slid the panel left until it cleared it - which looked correct at the window size it
## was tuned at, and at 16:9 put it 470 pixels clear of the card, adrift in the middle of
## the screen. A panel that has visibly left its parent is worse than one that clips a few
## dozen pixels of the emptiest part of a circle. Use it only when the thing to avoid is
## genuinely beside the anchor rather than below it.
@export var avoid_path: NodePath
## Optional. Something underneath the card that the panel must not drop onto. When hanging
## under the card would put it there, it goes beside the card instead - to its left, bottom
## edges flush - which still reads as the card's. Wired to the dial on the farm: with the
## interface scaled up (pen_ui_scale_4d.gd) the card is taller and hanging under it put
## the panel across the top of the dial.
@export var clear_of_path: NodePath
## Used only when there is nothing to sit under: left edge, and height above the belt.
@export_range(0.0, 200.0, 1.0) var side_margin: float = 40.0
@export_range(0.0, 200.0, 1.0) var lift: float = 118.0

var _rig: Node
var _under: Control
var _avoid: Control
var _clear_of: Control
var _panel: StyleBoxFlat
var _chip: StyleBoxFlat
var _chip_on: StyleBoxFlat


func _ready() -> void:
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.04, 0.05, 0.08, panel_alpha)
	_panel.border_color = Color(1.0, 1.0, 1.0, 0.07)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(9)
	_chip = StyleBoxFlat.new()
	_chip.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	_chip.border_color = Color(1.0, 1.0, 1.0, 0.16)
	_chip.set_border_width_all(1)
	_chip.set_corner_radius_all(4)
	# The one you are in is a filled button, not a brighter outline. An outline difference
	# is invisible at a glance over a bright sky.
	_chip_on = StyleBoxFlat.new()
	_chip_on.bg_color = Color(1.0, 1.0, 1.0, 0.26)
	_chip_on.border_color = Color(1.0, 1.0, 1.0, 0.55)
	_chip_on.set_border_width_all(1)
	_chip_on.set_corner_radius_all(4)
	_under = get_node_or_null(under_path) as Control
	_avoid = get_node_or_null(avoid_path) as Control
	_clear_of = get_node_or_null(clear_of_path) as Control
	# Laid out on redraw, so it has to hear when the card it hangs under moves or changes
	# size - the Cinematics card above it places itself every frame, after this one has.
	if _under != null and not _under.item_rect_changed.is_connected(queue_redraw):
		_under.item_rect_changed.connect(queue_redraw)
	_rig = get_node_or_null(rig_path)
	if _rig == null:
		push_warning("%s: no camera rig - nothing to report." % name)
		visible = false
		return
	if _rig.has_signal("preset_changed"):
		_rig.connect("preset_changed", _on_changed)
	_lay_out()
	queue_redraw()


func _on_changed(_index: int) -> void:
	queue_redraw()


func _presets() -> Array:
	if _rig == null or not _rig.has_method("presets"):
		return []
	return _rig.call("presets") as Array


## The column's measurements, in one place because the draw needs all of them too.
func _metrics() -> Dictionary:
	var font: Font = get_theme_default_font()
	var rows: Array = _presets()
	var widest: float = 0.0
	for row in rows:
		widest = maxf(widest,
			font.get_string_size(str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x)
	var small: int = maxi(text_size - 2, 8)
	var note: String = _note()
	var note_w: float = font.get_string_size(
		note, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
	var head_w: float = 0.0
	var head_h: float = 0.0
	if not title.is_empty():
		head_w = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x
		head_h = float(small) + 3.0
	if not subtitle.is_empty():
		head_w = maxf(head_w,
			font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, small).x)
		head_h += float(small) + 7.0
	var chip_w: float = widest + 16.0
	var chip_h: float = float(text_size) + 7.0
	var step: float = chip_h + 4.0
	return {
		"chip_w": chip_w,
		"chip_h": chip_h,
		"step": step,
		"note": note,
		"small": small,
		"head_h": head_h,
		"width": 10.0 + maxf(maxf(chip_w, note_w), head_w) + 10.0,
		"height": 10.0 + head_h + float(rows.size()) * step + 3.0 + float(small) + 10.0,
	}


## Short on purpose: the line sets the column's width, so a long one would widen every
## button to match it.
func _note() -> String:
	var rows: Array = _presets()
	if rows.is_empty() or _rig == null:
		return "TAB"
	var p: Array = rows[posmod(int(_rig.get("preset")), rows.size())]
	return "%.0f deg lens   %.1f m back" % [float(p[1]), float(p[2])]


func _lay_out() -> void:
	var m: Dictionary = _metrics()
	var w: float = float(m["width"])
	var h: float = float(m["height"])
	if _under != null:
		# Right edges flush, which is what makes two separate panels read as a pair
		# rather than as two things that happen to be in the same corner - unless
		# something else is already sitting there.
		var right: float = _under.position.x + _under.size.x
		if _avoid != null:
			right = minf(right, _avoid.position.x - gap)
		position = Vector2(right - w, _under.position.y + _under.size.y + gap)
		if _clear_of != null and _clear_of.visible and position.y + h > _clear_of.position.y:
			position = Vector2(_under.position.x - gap - w, _under.position.y + _under.size.y - h)
	else:
		position = Vector2(side_margin, get_viewport_rect().size.y - lift - h)
	size = Vector2(w, h)


func _draw() -> void:
	var rows: Array = _presets()
	if rows.is_empty():
		return
	# Re-measured every draw, because the belt is placed against the viewport and this has
	# to stay above it when the window is resized.
	_lay_out()
	var font: Font = get_theme_default_font()
	var on: int = posmod(int(_rig.get("preset")), rows.size())
	var m: Dictionary = _metrics()
	var chip_w: float = float(m["chip_w"])
	var chip_h: float = float(m["chip_h"])
	if panel_alpha > 0.0:
		draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var small: int = int(m["small"])
	var y: float = 10.0
	if not title.is_empty():
		draw_string(font, Vector2(10.0, y + font.get_ascent(small)), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1.0, 1.0, 1.0, 0.58))
		y += float(small) + 3.0
	if not subtitle.is_empty():
		# Dimmer than the heading: it is an instruction, not a label.
		draw_string(font, Vector2(10.0, y + font.get_ascent(small)), subtitle,
			HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1.0, 1.0, 1.0, 0.38))
		y += float(small) + 7.0
	for i in rows.size():
		var label: String = str(rows[i][0])
		draw_style_box(_chip_on if i == on else _chip, Rect2(10.0, y, chip_w, chip_h))
		var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		draw_string(font, Vector2(10.0 + (chip_w - w) * 0.5,
			y + font.get_ascent(text_size) + 3.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			text_size, Color(1.0, 1.0, 1.0, 0.95 if i == on else 0.50))
		y += float(m["step"])
	# What you are actually looking through, so the comparison is a comparison.
	draw_string(font, Vector2(10.0, y + 3.0 + font.get_ascent(small)), str(m["note"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(1.0, 1.0, 1.0, 0.44))
