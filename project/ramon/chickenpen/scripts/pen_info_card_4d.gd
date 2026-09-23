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
## AND THE WIDTH NEVER SNAPS IN. It grows the instant a longer line arrives and shrinks
## back slowly, because the widest line on the card is the frame counter, whose last
## number changes every half second - a panel that tracked it exactly would breathe in and
## out for as long as you looked at it.

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
## Pixels a second the panel is allowed to narrow by. Slow on purpose - see the header.
@export_range(10.0, 2000.0, 10.0) var shrink_rate: float = 90.0
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


## Stack the rows that have something in them, and report the box they fill.
func _measure() -> Rect2:
	var y: float = top
	var widest: float = 0.0
	var packed := 0
	for i in _labels.size():
		var label: Label = _labels[i]
		if not is_instance_valid(label):
			continue
		if not label.visible or label.text.strip_edges() == "":
			continue
		label.position.y = y
		label.position.x = left
		y += first_row_height if i == 0 else row_height
		packed += 1
		# The Label's own rect is as wide as it was authored, which is most of the screen
		# for the long ones. The card follows the TEXT, so it ends where the sentence does.
		var font: Font = label.get_theme_font("font")
		if font != null:
			widest = maxf(widest, font.get_string_size(label.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x)
		else:
			widest = maxf(widest, label.size.x)
	if packed == 0:
		return Rect2()
	return Rect2(Vector2(left, top), Vector2(widest, y - top))


func _process(delta: float) -> void:
	var box: Rect2 = _measure()
	if box.size.x <= 0.0:
		if _box.size.x > 0.0:
			_box = box
			queue_redraw()
		return
	# Out at once, in slowly. Every frame the counter's last digit changes the panel would
	# otherwise step in and out by a few pixels, which is the twitch you see rather than
	# the numbers themselves.
	if box.size.x < _box.size.x:
		box.size.x = maxf(box.size.x, _box.size.x - shrink_rate * delta)
	if box == _box:
		return
	_box = box
	queue_redraw()


func _draw() -> void:
	if _box.size.x <= 0.0 or _box.size.y <= 0.0 or panel_alpha <= 0.0:
		return
	draw_style_box(_panel, Rect2(_box.position - Vector2(pad_x, pad_y),
		_box.size + Vector2(pad_x, pad_y) * 2.0))
