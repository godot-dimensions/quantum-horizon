extends Control

## THE WALKING CARD: how you move and face through W, as a card of its own on the pen's HUD, each choice two buttons
## side by side with the one in use lit (Ramon, 7 Oct: "create a seperate UI with clear toggle between default stepping
## and andrew's stepping ... just so you see which button is selected. it should be integrated seperately cause i tnink
## its important", then of the facing: "add it in the seperate ui with the stepping, i actually thought the stepping
## was the gturning thing" - so each row says what it changes).
##
## STEPPING, where E and Q take you (the player's andrew_stepping, block_walker_character_4d.gd):
##   DEFAULT, WORLD W: along the world's own W, the axis the dial and the places count in (the cave's door at 4 ana,
##   the marsh at +8). With the slice tilted, part of that step lies inside the slice you see, so the picture slides
##   sideways while it changes.
##   ANDREW'S, VIEW W (4Denthusiast, b20b6c6): straight out of the slice you see, its normal, so the picture changes
##   without sliding; with the slice tilted it moves you across the ground too.
## FACING, which way your character's body turns (andrew_turning):
##   DEFAULT, ON THE GROUND: to where you walk across the floor you see; E and Q do not turn you.
##   ANDREW'S, THROUGH W: to wherever you move, W included, so a step ana turns you to face into W (you see another
##   cross-section of the model), and the catch and the throw aim that way (chicken_catcher_4d.gd).
## With the slice level and no E or Q, both rows' choices are the same.
##
## Both are the player's, for the run only: every run starts on the defaults. Made by the Grass node beside the grass
## panel (pen_grass_4d.gd _add_panel), so the pen's scene does not have to carry it; shown on the farm only, as the
## grass panel; placed after the other panels and never in their way (pen_hud_spot_4d.gd spot_follower).

const SPOT := preload("res://ramon/chickenpen/scripts/pen_hud_spot_4d.gd")

## [the player's switch, the row's title, default's button, Andrew's button, what default does, what Andrew's does]
const ROWS := [
	["andrew_stepping", "Stepping   where E / Q take you", "Default: world W", "Andrew's: view W",
		"Along the world's W, as the dial counts", "Straight out of the slice you see"],
	["andrew_turning", "Facing   which way you turn", "Default: on the ground", "Andrew's: through W",
		"Where you walk; E / Q do not turn you", "Into W too; the catch aims that way"],
]

## The player whose walking it switches, and the grass, whose being on the farm says whether to show.
var player: Node
var grass: Node
var text_size: int = 13
var gap: float = 10.0
var margin: float = 24.0

## Per row: [default's button, Andrew's button, its note, what it shows now (-1 not yet)].
var _rows: Array = []
var _chip: StyleBoxFlat
var _chip_hover: StyleBoxFlat
var _chip_on: StyleBoxFlat
var _off_farm: bool = false


func _ready() -> void:
	name = "SteppingCard"
	# Placed after the other panels, and never in their way (pen_hud_spot_4d.gd taken).
	set_meta(&"spot_follower", true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip = _style(Color(1.0, 1.0, 1.0, 0.08), Color(1.0, 1.0, 1.0, 0.16), 4)
	_chip_hover = _style(Color(1.0, 1.0, 1.0, 0.15), Color(1.0, 1.0, 1.0, 0.3), 4)
	_chip_on = _style(Color(1.0, 1.0, 1.0, 0.26), Color(1.0, 1.0, 1.0, 0.55), 4)
	var back := PanelContainer.new()
	back.add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.08, 0.3), Color(1.0, 1.0, 1.0, 0.07), 9))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(box)
	for i in ROWS.size():
		var spec: Array = ROWS[i]
		if i > 0:
			var space := Control.new()
			space.custom_minimum_size = Vector2(0.0, 4.0)
			space.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(space)
		_label(String(spec[1]), Color(1.0, 1.0, 1.0, 0.58), box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(row)
		var own := _button(String(spec[2]), row)
		own.pressed.connect(_pick.bind(i, false))
		var his := _button(String(spec[3]), row)
		his.pressed.connect(_pick.bind(i, true))
		var note := _label("", Color(1.0, 1.0, 1.0, 0.45), box)
		_rows.append([own, his, note, -1])
		_show(i, _on(i))


## Row [param i]'s switch on the player, on or off now.
func _on(i: int) -> bool:
	return player != null and is_instance_valid(player) and bool(player.get(String(ROWS[i][0])))


func _pick(i: int, his: bool) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set(String(ROWS[i][0]), his)
	_show(i, his)


## Row [param i]: the choice in use lit, the other plain, and a line on what it does.
func _show(i: int, his: bool) -> void:
	var row: Array = _rows[i]
	row[3] = 1 if his else 0
	_paint(row[0], not his)
	_paint(row[1], his)
	(row[2] as Label).text = String(ROWS[i][5] if his else ROWS[i][4])


func _process(_delta: float) -> void:
	# Only on the farm, and only its own hiding undone (as the grass panel, pen_grass_panel_4d.gd).
	var on_farm: bool = grass != null and is_instance_valid(grass) and (grass as Node4D).is_visible_in_tree()
	if not on_farm:
		if visible:
			visible = false
			_off_farm = true
		return
	if _off_farm:
		_off_farm = false
		visible = true
	if not visible:
		return
	# Whatever set them, the buttons say what is on.
	for i in _rows.size():
		var now: int = 1 if _on(i) else 0
		if now != int(_rows[i][3]):
			_show(i, now == 1)
	var back: Control = get_child(0) as Control
	size = back.get_combined_minimum_size()
	back.size = size
	# FIRST FREE SPOT (pen_hud_spot_4d.gd): under the grass panel, left edges level; else beside it; else under the
	# info card; else bottom left.
	var view: Vector2 = get_viewport_rect().size
	var places: Array = []
	var panel := get_parent().get_node_or_null(^"GrassPanel") as Control
	if panel != null and panel.is_visible_in_tree():
		var r: Rect2 = SPOT.rect_of(panel)
		places.append(Vector2(r.position.x, r.end.y + gap))
		places.append(Vector2(r.end.x + gap, r.position.y))
	var info := get_parent().get_node_or_null(^"InfoCard") as Control
	if info != null and info.is_visible_in_tree():
		var ir: Rect2 = SPOT.drawn_of(info)
		places.append(Vector2(maxf(ir.position.x, 4.0), ir.end.y + gap))
	var ignore: Array = []
	for other in [^"CameraPicker", ^"Journal"]:
		var n: Node = get_parent().get_node_or_null(other)
		if n != null:
			ignore.append(n)
	var taken: Array = SPOT.taken(get_parent(), self, ignore)
	# THE BELT: its layer is the whole screen, so taken() leaves it out; its slots are what to keep off (7 Oct, the 4K
	# grab: with the grass panel open the card's corner lay over the belt's last slot). Right of it is the last resort.
	var belt := get_parent().get_node_or_null(^"Inventory") as Control
	if belt != null and belt.is_visible_in_tree() and belt.has_method("belt_rect"):
		var belt_r: Rect2 = belt.call("belt_rect")
		taken.append(belt_r)
		places.append(Vector2(belt_r.end.x + gap, view.y - size.y - margin))
	else:
		places.append(Vector2(margin, view.y - size.y - margin))
	position = SPOT.first(places, size, taken, view)


func _label(text: String, colour: Color, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", text_size - 2)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(150.0, 0.0)
	# No focus: Space is jump, and a focused button would take it.
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", text_size)
	parent.add_child(b)
	return b


func _paint(b: Button, on: bool) -> void:
	b.add_theme_stylebox_override("normal", _chip_on if on else _chip)
	b.add_theme_stylebox_override("hover", _chip_on if on else _chip_hover)
	b.add_theme_stylebox_override("pressed", _chip_on)
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95 if on else 0.55))
	b.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 0.95))


func _style(fill: Color, border: Color, corner: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(corner)
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 3.0
	s.content_margin_bottom = 3.0
	return s
