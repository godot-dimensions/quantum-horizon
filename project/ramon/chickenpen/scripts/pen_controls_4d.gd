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
##
## TWO GROUPS SIDE BY SIDE (10 Oct 2026, Ramon's walkthrough items 8 and 9: "too tall and cluttered ... Keep the
## controls from Move through Escape together as one unit ... from C (Cinema) through Ctrl+R (Restart Scene) together
## as a second unit ... alongside each other ... a thin divider line ... roughly inspired by a 16:9 landscape
## proportion"): the playing keys in the left column, the shortcuts in the right, a thin rule between them; the card is
## as tall as the longer column. And the two sizes have their own small bracket now ("Move the UI Size and Dial Size
## controls into their own separate bracket ... next to the third Camera Testing bracket ... Rename Dial Size to Dial
## Size / Locator Gizmo"), drawn by this script beside the camera picker (UI/CameraPicker); + and - still work from
## anywhere.

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
	["../../CaveCrossing", "debug_key", "into the cave, and back"],
	["../../Systems/Celebration", "test_key", "finish the round - again restarts"],
	["../../UI/SlicePlane", "toggle_key", "the dial, on or off"],
	["../../Systems/Paths", "key_type", "paths: as drawn, static, here, follow, reveal"],
	["../../Systems/Paths", "key_found", "paths found as you go, or all shown"],
	["../../Systems/Look", "key", "dev look, or the art"],
	["../../Systems/MinimalHud", "key", "minimal HUD, on or off"],
	["../../Systems/UiLayout", "key", "move and size the cards"],
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
## THE SIZES ARE KEYS, LIKE EVERYTHING ELSE ON THE CARD (Ramon, 29 Sept: "of course you have
## to say press + -, and under it shift + +/- ... might as well remove the plus minus icons"):
## two rows in the card's own grammar, the key in its chip and what it does beside it, with
## the size as it stands written into the words - the interface's, and under it the dial's,
## so the two can be read together. 10% a press. Room is kept for the widest number, so the
## card never changes width as the numbers do.
var _size_box: Control
const SIZE_STEP := 10.0
const SIZE_MIN := 50.0
const SIZE_MAX := 300.0
const DIAL_STEP := 10.0
## The number first, then what it is (Ramon, 29 Sept: "percentage first, then text"): drawn
## as two columns, the number in room for the widest one, so the words stay put.
const SIZE_WORDS := "UI size"
const DIAL_WORDS := "dial size / locator gizmo"
## The two columns: the first row of the second, its chip width and label start; the left column's the same.
var _split: int = -1
var _chip_w2: float = 0.0
var _label_x2: float = 0.0
var _col2_x: float = 0.0
## The sizes' own bracket, beside the camera picker.
var _size_card: Control
var _size_rows: Array = []
const NUMBER_ROOM := "300%"


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
	# Again once everything is up: the hawk is made by the Lookout, after this card is ready.
	_rebuild.call_deferred()


func _rebuild() -> void:
	_build()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# THE + AND - KEYS DO WHAT THE BUTTONS SAY (Ramon, 29 Sept: "plus and minus don't do
	# anything in terms of scaling"): the buttons only answer a free cursor, and the keys
	# they are drawn as answer always - the main row's or the numpad's, and with Shift the
	# dial's size rather than the interface's.
	if event is InputEventKey and event.pressed and _ui_scale != null:
		var code: int = (event as InputEventKey).keycode
		var up: bool = code == KEY_EQUAL or code == KEY_PLUS or code == KEY_KP_ADD
		var down: bool = code == KEY_MINUS or code == KEY_KP_SUBTRACT
		if up or down:
			var by: float = SIZE_STEP if up else -SIZE_STEP
			if (event as InputEventKey).shift_pressed:
				step_dial(by)
			else:
				step_size(by)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == toggle_key:
		visible = not visible
		if _hint != null:
			_hint.visible = not visible
		if _size_card != null:
			_size_card.visible = visible
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
	]
	# Flying as the flock's hawk, a key of the pen's own (Ramon, 3 Oct: "the hawk flight is the
	# only thing i want to have in the main hud on the top right. cool feature"): read off the
	# hawk, which the Lookout makes; no hawk in the scene, no row.
	var hawk: Node = get_node_or_null(^"../../Systems/Lookout/Hawk")
	if hawk != null and int(hawk.get("key")) != 0:
		_rows.append([OS.get_keycode_string(int(hawk.get("key"))), "fly as the hawk", false])
	# And the projection, the pen's own too (Ramon, 3 Oct: "can you also make p for projection
	# in the main scene?"): the cut, and over it a ghost of what is ana and kata of it.
	var lookout: Node = get_node_or_null(^"../../Systems/Lookout")
	if lookout != null and int(lookout.get("projection_key")) != 0:
		_rows.append([OS.get_keycode_string(int(lookout.get("projection_key"))), "projection, a ghost of W", false])
	_rows += [
		["R", "back to your starting slice", false],
		[OS.get_keycode_string(toggle_key), "hide this card", false],
		["ESC", "stop, free the cursor", false],
	]
	# From the menu (11 Oct): M is the way back to it (Menu/scripts/menu_way_home.gd); Esc only stops.
	if is_inside_tree() and get_tree().root.has_node(^"WayHome"):
		_rows.append(["M", "the menu (asks first)", false])
	if show_shortcuts:
		_rule_after = _rows.size() - 1
		_split = _rows.size()
		for entry in OWNED:
			var owner_node: Node = get_node_or_null(NodePath(entry[0]))
			if owner_node == null:
				continue
			var code: int = int(owner_node.get(entry[1]))
			if code == 0:
				continue
			_rows.append([OS.get_keycode_string(code), entry[2], true])
		_rows.append(["CTRL+R", "restart the scene", true])
	_slider_row = -1
	if _size_box != null:
		_size_rows = [["+ / −", SIZE_WORDS, false, "%d%%" % roundi(size_percent())],
			["Shift + / −", DIAL_WORDS, false, "%d%%" % roundi(dial_percent())]]
	if not show_shortcuts:
		_split = -1
	_measure()


func _measure() -> void:
	var font: Font = get_theme_default_font()
	var key_size: int = maxi(text_size - 1, 8)
	var first: int = _split if _split >= 0 else _rows.size()
	_chip_w = 0.0
	_chip_w2 = 0.0
	var widest: float = 0.0
	var widest2: float = 0.0
	for i in _rows.size():
		var row: Array = _rows[i]
		var cw: float = font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, key_size).x + 14.0
		var lw: float = font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		if i < first:
			_chip_w = maxf(_chip_w, cw)
			widest = maxf(widest, lw)
		else:
			_chip_w2 = maxf(_chip_w2, cw)
			widest2 = maxf(widest2, lw)
	_label_x = 14.0 + _chip_w + 12.0
	var left_w: float = _label_x + widest + 12.0
	_col2_x = left_w + 12.0 if _split >= 0 else 0.0
	_label_x2 = _col2_x + _chip_w2 + 12.0
	var total_w: float = (_label_x2 + widest2 + 16.0) if _split >= 0 else (left_w + 4.0)
	var rows_tall: int = maxi(first, _rows.size() - first) if _split >= 0 else _rows.size()
	var height: float = 14.0 + float(rows_tall) * _step() + 8.0
	# Anchored to the right edge in the scene, so the card is grown leftward and downward
	# from the corner it is pinned to rather than being sized by hand - a row added below
	# used to fall off the bottom of a rect somebody had typed a number into.
	offset_right = -right_margin
	offset_left = -right_margin - total_w
	offset_bottom = offset_top + height


func _step() -> float:
	return float(text_size) + 9.0


## Where row [param i] starts, down the card - the same sums _draw does.
func _row_y(i: int) -> float:
	var k: int = i - _split if _split >= 0 and i >= _split else i
	return 14.0 + float(k) * _step()


func _make_spinner() -> void:
	# A marker for the size rows, named as the slider once was, so anything looking for the
	# size control still finds the card has one.
	_size_box = Control.new()
	_size_box.name = "UiSize"
	_size_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_size_box)
	# Their own bracket (10 Oct): top-level, so it is placed on the screen rather than inside this card.
	_size_card = Control.new()
	_size_card.name = "SizeCard"
	_size_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_size_card.top_level = true
	_size_card.draw.connect(_draw_size_card)
	add_child(_size_card)
	# The scale reads what was last chosen in its own _ready, which comes after this one;
	# catch up with it once it has.
	_show_size.call_deferred()


## The size as it stands, from the scale itself.
## The column the size rows' numbers take, words starting after it.
func _number_w() -> float:
	return get_theme_default_font().get_string_size(NUMBER_ROOM, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + 12.0


func size_percent() -> float:
	return float(_ui_scale.get("percent")) if _ui_scale != null else 100.0


func _show_size() -> void:
	if _size_rows.size() < 2:
		return
	_size_rows[0][3] = "%d%%" % roundi(size_percent())
	_size_rows[1][3] = "%d%%" % roundi(dial_percent())
	if _size_card != null:
		_size_card.queue_redraw()


## The dial's own size, from the scale.
func dial_percent() -> float:
	return float(_ui_scale.get("dial_percent")) if _ui_scale != null else 100.0


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
	if panel_alpha > 0.0:
		draw_style_box(_panel, Rect2(Vector2.ZERO, size))
	var first: int = _split if _split >= 0 else _rows.size()
	for i in _rows.size():
		var second: bool = i >= first
		var x0: float = _col2_x if second else 0.0
		_draw_row(self, _rows[i], x0, _row_y(i), _chip_w2 if second else _chip_w, _label_x2 if second else _label_x)
	if _split >= 0:
		# The thin rule between the two groups.
		var rx: float = _col2_x - 6.0
		draw_line(Vector2(rx, 12.0), Vector2(rx, size.y - 10.0), Color(1.0, 1.0, 1.0, 0.12), 1.0)


func _process(_delta: float) -> void:
	_keep_clear_of_todo()
	_place_size_card()


## Wider since 10 Oct, the card can reach over the to-do list (top left, beside the info card) on a narrow screen or at a
## big UI size: then it sits just under the list instead of at the top.
var _top_wanted: float = -1.0


func _keep_clear_of_todo() -> void:
	if _top_wanted < 0.0:
		_top_wanted = offset_top
	var h: float = offset_bottom - offset_top
	var top: float = _top_wanted
	var todo := get_node_or_null(^"../Quests") as Control
	if todo != null and todo.is_visible_in_tree():
		var t: Rect2 = todo.get_global_rect()
		var me := Rect2(Vector2(get_global_rect().position.x, _top_wanted), Vector2(size.x, h))
		if me.intersects(t):
			top = t.end.y + 10.0
	if not is_equal_approx(offset_top, top):
		offset_top = top
		offset_bottom = top + h


## One row: the key in its chip at [param x0] + 14, its words at [param label_x] (and a size row's number first).
func _draw_row(on: Control, row: Array, x0: float, y: float, chip_w: float, label_x: float) -> void:
	var font: Font = get_theme_default_font()
	var key_size: int = maxi(text_size - 1, 8)
	var chip_h: float = float(text_size) + 7.0
	var box := Rect2(x0 + 14.0, y, chip_w, chip_h)
	on.draw_style_box(_chip, box)
	# Centred in its own box, because a key is a picture of a key. Only the column of
	# verbs beside it is left-aligned, which is what makes them scannable.
	var kw: float = font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, key_size).x
	on.draw_string(font, Vector2(box.position.x + (chip_w - kw) * 0.5, y + font.get_ascent(key_size) + 3.5), row[0],
		HORIZONTAL_ALIGNMENT_LEFT, -1, key_size, Color(1.0, 1.0, 1.0, 0.90 if not row[2] else 0.55))
	var words_x: float = label_x
	if row.size() > 3:
		on.draw_string(font, Vector2(label_x, y + font.get_ascent(text_size) + 3.5), row[3],
			HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 1.0, 1.0, 0.9))
		words_x += _number_w()
	on.draw_string(font, Vector2(words_x, y + font.get_ascent(text_size) + 3.5), row[1],
		HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(1.0, 1.0, 1.0, 0.44 if row[2] else 0.72))


## The sizes' bracket: beside the camera picker (to its right, tops level), or under this card without one.
func _place_size_card() -> void:
	if _size_card == null or _size_rows.is_empty():
		return
	var font: Font = get_theme_default_font()
	var key_size: int = maxi(text_size - 1, 8)
	var chip_w: float = 0.0
	var widest: float = 0.0
	for row in _size_rows:
		chip_w = maxf(chip_w, font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, key_size).x + 14.0)
		widest = maxf(widest, _number_w() + font.get_string_size(row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x)
	var w: float = 14.0 + chip_w + 12.0 + widest + 16.0
	var h: float = 14.0 + 2.0 * _step() + 8.0
	var at := Vector2(get_global_rect().position.x, get_global_rect().end.y + 8.0)
	var picker := get_node_or_null(^"../CameraPicker") as Control
	if picker != null and picker.is_visible_in_tree():
		# To the picker's right (its left is the to-do list), tops level; if that runs into this card, to its left.
		var r: Rect2 = picker.get_global_rect()
		at = Vector2(r.end.x + 8.0, r.position.y)
		if Rect2(at, Vector2(w, h)).intersects(get_global_rect().grow(4.0)):
			at = Vector2(r.position.x - w - 8.0, r.position.y)
	_size_card.visible = visible
	_size_card.global_position = at
	_size_card.size = Vector2(w, h)
	_size_card.set_meta(&"chip_w", chip_w)
	_size_card.queue_redraw()


func _draw_size_card() -> void:
	if _size_rows.is_empty():
		return
	if panel_alpha > 0.0:
		_size_card.draw_style_box(_panel, Rect2(Vector2.ZERO, _size_card.size))
	var chip_w: float = float(_size_card.get_meta(&"chip_w", 60.0))
	for i in _size_rows.size():
		_draw_row(_size_card, _size_rows[i], 0.0, 14.0 + float(i) * _step(), chip_w, 14.0 + chip_w + 12.0)


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
