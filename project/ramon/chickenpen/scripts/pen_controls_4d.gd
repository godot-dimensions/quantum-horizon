extends Control

## The controls card, top right.
##
## DRAWN RATHER THAN A LABEL, and only for one reason: columns. A key and its verb want
## to line up down the card, and a proportional font cannot be padded into a column with
## spaces - "W" and "CTRL+R" are different widths, so every row lands somewhere else and
## the block reads as a paragraph instead of a list. Two measured columns and a box round
## each key is the whole difference between a reference and a wall of text.
##
## BUILT FROM THE INPUT MAP, not typed out. Every other piece of text in this prototype
## that names a key reads it from `InputMap` - the locator, the tutor, the catch prompt -
## for the same reason: a printed key name is a claim that stops being true the moment
## somebody rebinds, and a card of wrong controls is worse than no card. Rebind anything
## and this card changes with it. The shortcuts below the rule are the exception: they are
## not actions, they are keys owned by single scripts, so each is read from the exported
## property on the node that actually listens for it.
##
## TWO BLOCKS, AND THE SECOND ONE IS DIMMER. The verbs you need in order to play, then a
## rule, then the keys that are not part of the game at all - jump to the cinema, finish
## the round, hide the dial. They are worth having on screen, since a shortcut nobody can
## remember is a shortcut nobody uses, but they should not compete with the controls.
##
## QUIET ON PURPOSE. The old card was white text at full strength over a third of the sky
## and the first thing anyone noticed in a screenshot. Everything here is a fraction of
## white over a panel that is barely there: legible when you look at it, gone when you
## are not.
##
## AND A SLIDER AT THE FOOT for the size of the whole interface (Ramon, 28 Sept: "add a UI
## size percentage slider somewhere"), through pen_ui_scale_4d.gd. ESC frees the cursor to
## use it, as for anything else on the card. It takes effect when it is let go: resizing the
## interface while it is being dragged would move the slider out from under the pointer.

## Font size for the verbs. The keys inside their boxes are drawn a point smaller.
@export_range(9, 28, 1) var text_size: int = 13
## How present the panel behind it is. Zero is text on its own.
@export_range(0.0, 1.0, 0.01) var panel_alpha: float = 0.34
## Gap between the card and the right edge of the screen.
@export_range(0.0, 80.0, 1.0) var right_margin: float = 22.0
@export var toggle_key: Key = KEY_H
## The block under the rule. Off gives you the playing controls alone.
@export var show_shortcuts: bool = true
## The interface scale the slider at the foot sets. Nothing there, no slider.
@export var ui_scale_path: NodePath = NodePath("../../Systems/UiScale")

## Where the keys that are not input actions actually live, so the card can ask them what
## they are bound to instead of repeating it. Each is a node path and the name of an
## exported property on it.
const OWNED: Array = [
	["../../Crossing", "debug_key", "into the cinema, and back"],
	["../../Systems/Celebration", "test_key", "finish the round - again restarts"],
	["../../UI/SlicePlane", "toggle_key", "the dial, on or off"],
]

var _rows: Array = []
var _chip_w: float = 0.0
var _label_x: float = 0.0
var _rule_after: int = -1
var _panel: StyleBoxFlat
var _chip: StyleBoxFlat
## The row the slider sits in, or -1.
var _slider_row: int = -1
var _ui_scale: Node
## THE UI SIZE IS A SMALL VERTICAL SPINNER, not a slider (Ramon, 29 Sept: "ideally a UI hud
## scaler should be small and vertical, with plus on the top, and minus down below, and no
## ability to drag slider"): the size, and beside it a plus over a minus, 10% a press.
var _size_box: Control
var _percent: Label
var _minus: Button
var _plus: Button
const SIZE_STEP := 10.0
const SIZE_MIN := 50.0
const SIZE_MAX := 300.0
const STEP_W := 20.0
const STEP_H := 12.0
## How much taller than the other rows the size row is, for the two buttons stacked in it.
const SIZE_ROW_EXTRA := 6.0
## AND THE DIAL'S OWN SIZE, beside it, while Shift is held with the cursor free (Ramon, 29
## Sept: "with holding shift, we can make a second [control] next to it, that controls the
## bottom right collector hud size"). Only with the cursor free: Shift is also the sprint
## key, and a control that popped in every time you ran would be a flicker, not a feature -
## and only a free cursor can click it anyway. Its room is kept whether it shows or not, so
## the card never changes width; while it is hidden that room says how to get it.
var _dial_percent: Label
var _dial_plus: Button
var _dial_minus: Button
var _dial_hint: Label
const DIAL_STEP := 10.0
const DIAL_GAP := 22.0


func _ready() -> void:
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(0.04, 0.05, 0.08, panel_alpha)
	_panel.border_color = Color(1.0, 1.0, 1.0, 0.07)
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(9)
	_chip = StyleBoxFlat.new()
	_chip.bg_color = Color(1.0, 1.0, 1.0, 0.11)
	_chip.border_color = Color(1.0, 1.0, 1.0, 0.20)
	_chip.set_border_width_all(1)
	_chip.set_corner_radius_all(4)
	_ui_scale = get_node_or_null(ui_scale_path)
	if _ui_scale != null:
		_make_spinner()
	_build()
	queue_redraw()
	_make_hint.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == toggle_key:
		visible = not visible
		if _hint != null:
			_hint.visible = not visible
		get_viewport().set_input_as_handled()


## WHERE THE CARD WENT. Hiding it with H left nothing behind, so the one key that brings it
## back was only written on the card it had just hidden - Trym: "After hiding the tooltip
## with H, there should be a small indicator top right (where it used to be) that H will
## bring it back in case you forget the buttons."
##
## A SIBLING, NOT A CHILD. A hidden Control draws none of its children, so a hint hung off
## the card would vanish at exactly the moment it is needed. It sits in the same corner in
## the same chip style as the card's own keys, and is only ever up while the card is down.
var _hint: Label


func _make_hint() -> void:
	var host: Node = get_parent()
	if host == null:
		return
	_hint = Label.new()
	_hint.name = "ControlsHint"
	_hint.text = "%s   controls" % OS.get_keycode_string(toggle_key)
	_hint.add_theme_font_size_override("font_size", text_size)
	_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.82))
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.04, 0.05, 0.08, maxf(panel_alpha, 0.55))
	chip.border_color = Color(1.0, 1.0, 1.0, 0.16)
	chip.set_border_width_all(1)
	chip.set_corner_radius_all(6)
	chip.content_margin_left = 10.0
	chip.content_margin_right = 10.0
	chip.content_margin_top = 4.0
	chip.content_margin_bottom = 4.0
	_hint.add_theme_stylebox_override("normal", chip)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.offset_right = -right_margin
	_hint.offset_top = offset_top
	_hint.visible = not visible
	host.add_child(_hint)


## The verbs in the order you need them: get there, get into its slice, pick it up, put it
## in the pen. Then the rule, then the things that are not the game.
func _build() -> void:
	_rows = [
		[_chip_for(&"move_forward") + _chip_for(&"move_left") + _chip_for(&"move_back")
			+ _chip_for(&"move_right"), "move", false],
		["%s %s" % [_chip_for(&"move_ana"), _chip_for(&"move_kata")],
			"step through the fourth axis", false],
		["T", "lock onto the nearest chicken", false],
		[_chip_for(&"catch_target"), "pick up, and throw", false],
		[_chip_for(&"fire"), "put down where you stand", false],
		[_chip_for(&"rotate_4d"), "hold and drag - turn through W", false],
		[_chip_for(&"move_jump"), "jump", false],
		["R", "back to your starting slice", false],
		[OS.get_keycode_string(toggle_key), "hide this card", false],
		["ESC", "free the cursor, then quit", false],
	]
	if show_shortcuts:
		_rule_after = _rows.size() - 1
		for entry in OWNED:
			var owner_node: Node = get_node_or_null(NodePath(entry[0]))
			if owner_node == null:
				continue
			var code: int = int(owner_node.get(entry[1]))
			if code == 0:
				continue
			_rows.append([OS.get_keycode_string(code), entry[2], true])
		_rows.append(["CTRL+R", "restart the scene", true])
	if _size_box != null:
		_slider_row = _rows.size()
		_rows.append(["UI size", "", false])
	_measure()


func _measure() -> void:
	var font: Font = get_theme_default_font()
	var key_size: int = maxi(text_size - 1, 8)
	_chip_w = 0.0
	var widest: float = 0.0
	for row in _rows:
		_chip_w = maxf(_chip_w,
			font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, key_size).x + 14.0)
		widest = maxf(widest,
			font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x)
	if _size_box != null:
		var one: float = font.get_string_size("300%", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + 10.0 + STEP_W
		var dial: float = font.get_string_size("Dial 200%", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + 10.0 + STEP_W
		widest = maxf(widest, one + DIAL_GAP + maxf(dial, font.get_string_size("Shift: dial size", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size - 2).x))
	_label_x = 14.0 + _chip_w + 12.0
	var height: float = 14.0 + float(_rows.size()) * _step() + 8.0
	if _rule_after >= 0:
		height += 11.0
	if _slider_row >= 0:
		height += 11.0
		var y: float = _row_y(_slider_row)
		var chip_h: float = float(text_size) + 7.0
		height += SIZE_ROW_EXTRA
		var mid: float = y + (chip_h + SIZE_ROW_EXTRA) * 0.5
		var digits: float = get_theme_default_font().get_string_size("300%", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		_percent.position = Vector2(_label_x, mid - float(text_size) * 0.72)
		_plus.position = Vector2(_label_x + digits + 10.0, mid - STEP_H - 1.0)
		_plus.size = Vector2(STEP_W, STEP_H)
		_minus.position = Vector2(_label_x + digits + 10.0, mid + 1.0)
		_minus.size = Vector2(STEP_W, STEP_H)
		var x0: float = _plus.position.x + STEP_W + DIAL_GAP
		var dial_w: float = get_theme_default_font().get_string_size("Dial 200%", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		_dial_percent.position = Vector2(x0, _percent.position.y)
		_dial_plus.position = Vector2(x0 + dial_w + 10.0, _plus.position.y)
		_dial_plus.size = _plus.size
		_dial_minus.position = Vector2(x0 + dial_w + 10.0, _minus.position.y)
		_dial_minus.size = _minus.size
		_dial_hint.position = Vector2(x0, mid - float(text_size - 2) * 0.72)
	# Anchored to the right edge in the scene, so the card is grown leftward and downward
	# from the corner it is pinned to rather than being sized by hand - a row added below
	# used to fall off the bottom of a rect somebody had typed a number into.
	offset_right = -right_margin
	offset_left = -right_margin - (_label_x + widest + 16.0)
	offset_bottom = offset_top + height


func _step() -> float:
	return float(text_size) + 9.0


## Where row [param i] starts, down the card - the same sums _draw does.
func _row_y(i: int) -> float:
	var y: float = 14.0 + float(i) * _step()
	if _rule_after >= 0 and i > _rule_after:
		y += 11.0
	if _slider_row >= 0 and i >= _slider_row:
		y += 11.0
	return y


func _make_spinner() -> void:
	# Named as the slider was, so anything looking for the size control still finds it.
	_size_box = Control.new()
	_size_box.name = "UiSize"
	_size_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_size_box)
	_percent = Label.new()
	_percent.add_theme_font_size_override("font_size", text_size)
	_percent.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.72))
	_percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_percent)
	_plus = _step_button("+", SIZE_STEP)
	_minus = _step_button("−", -SIZE_STEP)
	_dial_percent = Label.new()
	_dial_percent.add_theme_font_size_override("font_size", text_size)
	_dial_percent.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.72))
	_dial_percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dial_percent)
	_dial_plus = _step_button("+", DIAL_STEP, true)
	_dial_minus = _step_button("−", -DIAL_STEP, true)
	_dial_hint = Label.new()
	_dial_hint.text = "Shift: dial size"
	_dial_hint.add_theme_font_size_override("font_size", maxi(text_size - 2, 8))
	_dial_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.3))
	_dial_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dial_hint)
	_show_dial(false)
	_show_size()
	# The scale reads what was last chosen in its own _ready, which comes after this one;
	# catch up with it once it has.
	_show_size.call_deferred()


## The size as it stands, from the scale itself.
func size_percent() -> float:
	return float(_ui_scale.get("percent")) if _ui_scale != null else 100.0


func _show_size() -> void:
	_percent.text = "%d%%" % roundi(size_percent())
	if _dial_percent != null:
		_dial_percent.text = "Dial %d%%" % roundi(dial_percent())


## The dial's own size, from the scale.
func dial_percent() -> float:
	return float(_ui_scale.get("dial_percent")) if _ui_scale != null else 100.0


func _show_dial(on: bool) -> void:
	_dial_percent.visible = on
	_dial_plus.visible = on
	_dial_minus.visible = on
	_dial_hint.visible = not on


func _process(_delta: float) -> void:
	if _dial_plus == null:
		return
	var on: bool = Input.is_key_pressed(KEY_SHIFT) and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	if on != _dial_plus.visible:
		_show_dial(on)


## A small button in the card's own quiet style that moves the size - or, with [param dial],
## the dial's size - by [param by].
func _step_button(text: String, by: float, dial: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", maxi(text_size - 2, 8))
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1.0, 1.0, 1.0, 0.08 if state == "normal" else (0.16 if state == "hover" else 0.24))
		box.set_corner_radius_all(3)
		box.content_margin_top = 0.0
		box.content_margin_bottom = 0.0
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
	b.pressed.connect(func() -> void:
		if dial:
			step_dial(by)
		else:
			step_size(by))
	add_child(b)
	return b


## The dial's size up or down by [param by], within the scale's limits.
func step_dial(by: float) -> void:
	if _ui_scale == null:
		return
	_ui_scale.call("set_dial_percent", dial_percent() + by)
	_show_size()


## Up or down by [param by], within 50% to 300%. For the buttons and the tests.
func step_size(by: float) -> void:
	if _ui_scale == null:
		return
	_ui_scale.call("set_percent", clampf(size_percent() + by, SIZE_MIN, SIZE_MAX))
	_show_size()


func _draw() -> void:
	if _rows.is_empty():
		return
	var font: Font = get_theme_default_font()
	var key_size: int = maxi(text_size - 1, 8)
	if panel_alpha > 0.0:
		draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var y: float = 14.0
	for i in _rows.size():
		if i == _slider_row:
			y += 5.0
			draw_line(Vector2(14.0, y), Vector2(size.x - 14.0, y), Color(1.0, 1.0, 1.0, 0.09), 1.0)
			# Level with the spinner beside it, which is taller than a row.
			y += 6.0 + SIZE_ROW_EXTRA * 0.5
		var row: Array = _rows[i]
		var chip_h: float = float(text_size) + 7.0
		var box := Rect2(14.0, y, _chip_w, chip_h)
		draw_style_box(_chip, box)
		# Centred in its own box, because a key is a picture of a key. Only the column of
		# verbs beside it is left-aligned, which is what makes them scannable.
		var kw: float = font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, key_size).x
		draw_string(font, Vector2(box.position.x + (_chip_w - kw) * 0.5,
			y + font.get_ascent(key_size) + 3.5), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1,
			key_size, Color(1.0, 1.0, 1.0, 0.90 if not row[2] else 0.55))
		draw_string(font, Vector2(_label_x, y + font.get_ascent(text_size) + 3.5), row[1],
			HORIZONTAL_ALIGNMENT_LEFT, -1, text_size,
			Color(1.0, 1.0, 1.0, 0.44 if row[2] else 0.72))
		y += _step()
		if i == _rule_after:
			y += 5.0
			draw_line(Vector2(14.0, y), Vector2(size.x - 14.0, y),
				Color(1.0, 1.0, 1.0, 0.09), 1.0)
			y += 6.0


## The key bound to an action, short enough to sit in a box.
func _chip_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
		if event is InputEventMouseButton:
			match (event as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT:
					return "LMB"
				MOUSE_BUTTON_RIGHT:
					return "RMB"
				MOUSE_BUTTON_MIDDLE:
					return "MMB"
			return "M%d" % (event as InputEventMouseButton).button_index
	return "?"
