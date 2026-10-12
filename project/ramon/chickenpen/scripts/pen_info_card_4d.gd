extends Control

## The card behind the readouts in the top left.
##
## WHY THERE IS A NODE FOR THIS AT ALL. The left column is seven separate Labels, written
## to by seven different systems - the objective, the count, the locator, the catch prompt,
## the hint, the debug line and whatever the keeper and Mithra are saying. Each one was
## bare white text straight onto the world, which is fine over grass and unreadable over a
## pale sky or a yellow trough, and it looked nothing like the controls card in the other
## corner. This gives them the same panel without taking the Labels away from the systems
## that own them: nothing else changes, they just get something to sit on.
##
## THE SAME PANEL, DELIBERATELY THE SAME NUMBERS. Colour, alpha, border and corner radius
## are copied from pen_controls_4d rather than eyeballed, so the two corners cannot drift
## apart when one is adjusted. What it does NOT copy is the key chips - there are no keys
## to press over here, and a chip with nothing in it is a button that does nothing.
##
## IT PACKS THE ROWS, and that is the difference between a readout and a twitch.
##
## Eleven Labels sit at eleven fixed heights in the scene, and most of them are empty most
## of the time - the catch prompt only exists when a bird is in reach, the keeper only
## speaks when you are near him, the hint comes and goes. Sized to whatever happened to
## have text in it, the panel punched holes through its own middle and changed height
## several times a second. So this node owns the layout now: it walks its list in order,
## stacks only the rows that have something to say, and the panel is exactly as tall as
## the number of them. Nothing blinks a gap into the middle of it any more.
##
## AND NOW IT DOES NOT MOVE AT ALL. Packed to fit, the card still grew a row every time a
## prompt came up - the catch prompt, a hint, the keeper - and shrank again when it went,
## and a panel changing size in the corner of your eye is a thing you look at (Ramon,
## 28 Sept: "the top left UI window should be fixed and not sometimes extend downward ...
## it is distracting"). So it is a fixed size: room for [member rows] rows at
## [member card_width], the rows packed from the top as before and the space under them
## simply left empty. Should more want to be up at once than there is room for, the ones in
## [member give_way_paths] - the debug readouts - make room first, then the last in order;
## and a line too long for the card is cut short with an ellipsis instead of widening it.

## The readouts to sit behind, in the order they are stacked. Anything empty or hidden is
## skipped, so the card ends where the text does.
@export var label_paths: Array[NodePath] = []
@export_range(0.0, 40.0, 1.0) var pad_x: float = 12.0
@export_range(0.0, 40.0, 1.0) var pad_y: float = 9.0
## Where the column starts and how far apart the rows sit. Taken from here rather than
## from each Label's authored offset, because the whole point is that they move.
@export_range(0.0, 400.0, 1.0) var top: float = 14.0
@export_range(0.0, 200.0, 1.0) var left: float = 16.0
@export_range(12.0, 60.0, 1.0) var row_height: float = 25.0
## The first row is the frame counter, which is set larger than the rest.
@export_range(12.0, 80.0, 1.0) var first_row_height: float = 30.0
## How many rows the card always has room for, and how wide it always is.
@export_range(1, 20, 1) var rows: int = 8
@export_range(100.0, 2000.0, 10.0) var card_width: float = 820.0
## Rows that make way first when more want to be up than there is room for.
@export var give_way_paths: Array[NodePath] = [NodePath("../Debug"), NodePath("../../Player/StateLabel")]
## Matching pen_controls_4d, on purpose.
@export_range(0.0, 1.0, 0.01) var panel_alpha: float = 0.34
@export var panel_color: Color = Color(0.04, 0.05, 0.08)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.07)
@export_range(0, 24, 1) var corner_radius: int = 9
## Applied to the Labels themselves, so the text matches the other card too. The right one
## draws its verbs at 13 and white at 0.72; the objective is the one line here that is
## worth a touch more weight, so it is not forced down with the rest.
@export var restyle_labels: bool = true
@export_range(9, 28, 1) var text_size: int = 14
@export var text_color: Color = Color(1.0, 1.0, 1.0, 0.78)

var _labels: Array[Label] = []
var _give_way: Array[Label] = []
var _panel: StyleBoxFlat
var _box: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = StyleBoxFlat.new()
	_panel.bg_color = Color(panel_color, panel_alpha)
	_panel.border_color = border_color
	_panel.set_border_width_all(1)
	_panel.set_corner_radius_all(corner_radius)
	for path in label_paths:
		var label: Label = get_node_or_null(path) as Label
		if label == null:
			continue
		_labels.append(label)
		if restyle_labels:
			label.add_theme_font_size_override("font_size", text_size)
			label.add_theme_color_override("font_color", text_color)
			# A shadow as well as a panel. The panel handles a busy background; the shadow
			# handles the case where the card is off and this is still readable.
			label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
			label.add_theme_constant_override("shadow_offset_y", 1)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
	for path in give_way_paths:
		var label: Label = get_node_or_null(path) as Label
		if label != null:
			_give_way.append(label)


## Stack the rows that have something in them, as many as there is room for, and hide the
## rest until there is. The box is always the same.
func _measure() -> Rect2:
	var up: Array[Label] = []
	for label in _labels:
		if is_instance_valid(label) and label.visible and label.text.strip_edges() != "":
			up.append(label)
	# Over the limit: the debug readouts first, then from the bottom of the order.
	var dropped: Array[Label] = []
	for label in _give_way:
		if up.size() <= rows:
			break
		if up.has(label):
			up.erase(label)
			dropped.append(label)
	while up.size() > rows:
		dropped.append(up.pop_back())
	for label in dropped:
		label.position.y = -1000.0
	var y: float = top
	for label in up:
		label.position = Vector2(left, y)
		label.size.x = card_width
		y += first_row_height if label == _labels[0] else row_height
	var tall: float = first_row_height + float(rows - 1) * row_height
	return Rect2(Vector2(left, top), Vector2(card_width, tall))


func _process(_delta: float) -> void:
	var box: Rect2 = _measure()
	if box == _box:
		return
	_box = box
	queue_redraw()


## Where the panel is actually drawn, in the parent's coordinates. The Control's own rect
## is a fixed 1200 by 300 and the panel is drawn inside it at its own fixed size, so
## anything that wants to sit below the card has to ask for this, not for `size`.
func drawn_rect() -> Rect2:
	return Rect2(position + _box.position - Vector2(pad_x, pad_y), _box.size + Vector2(pad_x, pad_y) * 2.0)


func _draw() -> void:
	if _box.size.x <= 0.0 or _box.size.y <= 0.0 or panel_alpha <= 0.0:
		return
	draw_style_box(_panel, Rect2(_box.position - Vector2(pad_x, pad_y),
		_box.size + Vector2(pad_x, pad_y) * 2.0))
