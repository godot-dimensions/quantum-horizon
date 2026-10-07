extends Control

## The paths' own window (Ramon, 7 Oct: "the path settings should get there own window"): what was the
## Paths row of the grass panel (grass/pen_grass_panel_4d.gd), on its own. The type of every stretch
## (as drawn, or all static, here, follow, reveal; 9 goes round them) and found as you go or all shown
## (Shift+9), each lit as it stands, with a line saying what the lit type does. Made by the Paths node
## (scripts/pen_paths_4d.gd); clicks need the mouse (Esc first), the keys work always.
##
## IN THE GRASS PANEL'S HAND: the same dark glass and chips, so the two read as one set of test tools.
## On top of the grass panel (it keeps the room), else beside it, or wherever the HUD has room (pen_hud_spot_4d.gd).

const SPOT := preload("res://ramon/chickenpen/scripts/pen_hud_spot_4d.gd")

## The Paths node it works (pen_paths_4d.gd).
var paths: Node
## What it sits beside, if it is up (the grass panel).
var beside: Control
## What each type does (pen_paths_4d.gd TYPE_SAYS), handed over by the Paths node.
var says: Dictionary = {}
var text_size: int = 13
var panel_alpha: float = 0.3
var margin: float = 24.0
var gap: float = 10.0

var _type_buttons: Array[Button] = []
var _found_buttons: Array[Button] = []
var _says: Label
var _chip: StyleBoxFlat
var _chip_hover: StyleBoxFlat
var _chip_on: StyleBoxFlat
var _off_farm: bool = false


func _ready() -> void:
	name = "PathsPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip = _style(Color(1.0, 1.0, 1.0, 0.08), Color(1.0, 1.0, 1.0, 0.16), 4)
	_chip_hover = _style(Color(1.0, 1.0, 1.0, 0.15), Color(1.0, 1.0, 1.0, 0.3), 4)
	_chip_on = _style(Color(1.0, 1.0, 1.0, 0.26), Color(1.0, 1.0, 1.0, 0.55), 4)
	var back := PanelContainer.new()
	back.add_theme_stylebox_override("panel", _style(Color(0.04, 0.05, 0.08, panel_alpha), Color(1.0, 1.0, 1.0, 0.07), 9))
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
	var keys: String = ""
	if paths != null:
		keys = "   %s type,  %s" % [OS.get_keycode_string(int(paths.get("key_type"))), OS.get_keycode_string(int(paths.get("key_found")))]
	_label("Paths" + keys, Color(1.0, 1.0, 1.0, 0.58), box)
	for types in [["", "static", "here"], ["follow", "reveal"]]:
		var row := _row(box)
		for t in types:
			var b := _button("Drawn" if t == "" else String(t).capitalize(), row)
			b.set_meta("type", t)
			b.pressed.connect(func() -> void: _call("set_type", t))
			_type_buttons.append(b)
	var found_row := _row(box)
	for on in [true, false]:
		var b := _button("Found" if on else "All", found_row)
		b.set_meta("found", on)
		b.pressed.connect(func() -> void: _call("set_found", on))
		_found_buttons.append(b)
	_says = _label("", Color(1.0, 1.0, 1.0, 0.42), box)
	_says.custom_minimum_size = Vector2(170.0, 0.0)
	_says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if paths != null and paths.has_signal("changed"):
		paths.connect("changed", _on_paths)
	_on_paths()


func _call(method: String, value: Variant) -> void:
	if paths != null and is_instance_valid(paths):
		paths.call(method, value)


func _on_paths() -> void:
	if paths == null or not is_instance_valid(paths):
		return
	var t: String = String(paths.call("type"))
	var found: bool = bool(paths.call("is_found"))
	for b in _type_buttons:
		_paint(b, String(b.get_meta("type")) == t)
	for b in _found_buttons:
		_paint(b, bool(b.get_meta("found")) == found)
	var line: String = String(says.get(t, ""))
	_says.text = line.substr(0, 1).to_upper() + line.substr(1)


func _process(_delta: float) -> void:
	# Only on the farm, as the grass panel: away in the cave or the cinema the paths are asleep.
	var network: Node = paths.get("_network") if paths != null and is_instance_valid(paths) else null
	var on_farm: bool = network != null and network is Node4D and (network as Node4D).is_visible_in_tree()
	# Only its own hiding undone, as the grass panel's (the Lookout's raised camera hides the whole HUD).
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
	var view: Vector2 = get_viewport_rect().size
	var back: Control = get_child(0) as Control
	size = back.get_combined_minimum_size()
	back.size = size
	if beside == null or not is_instance_valid(beside):
		beside = get_parent().get_node_or_null(^"GrassPanel") as Control
	# The grass panel's size (its panel_scale, 60% since 7 Oct), so the two stack as one set.
	scale = beside.scale if beside != null and is_instance_valid(beside) else Vector2.ONE
	var vis: Vector2 = size * scale
	var places: Array = []
	# Under the murmuration card, at its left edge, the look panel beside it (Ramon, 7 Oct: "place them under the
	# murmuration box"); with the card away, under the info card.
	var stats := get_parent().get_node_or_null(^"FlockStats") as Control
	var info := get_parent().get_node_or_null(^"InfoCard") as Control
	if stats != null and stats.is_visible_in_tree():
		var sr: Rect2 = SPOT.rect_of(stats)
		places.append(Vector2(sr.position.x, sr.end.y + gap))
	elif info != null and info.is_visible_in_tree():
		var ir: Rect2 = SPOT.drawn_of(info)
		places.append(Vector2(maxf(ir.position.x, 4.0), ir.end.y + gap))
	if beside != null and is_instance_valid(beside) and beside.is_visible_in_tree():
		var r: Rect2 = SPOT.rect_of(beside)
		# On top of the grass panel, left edges level: it keeps the room (grass/pen_grass_panel_4d.gd; Ramon,
		# 7 Oct: "the paths window can stack neatly above the other").
		places.append(Vector2(r.position.x, r.position.y - vis.y - gap))
		places.append(Vector2(r.end.x + gap, r.position.y))
		places.append(Vector2(r.end.x + gap, r.end.y - vis.y))
	places.append(Vector2(margin, view.y * 0.22))
	places.append(Vector2(margin, view.y * 0.5 - vis.y))
	var ignore: Array = []
	for other in [^"CameraPicker", ^"Journal"]:
		var n: Node = get_parent().get_node_or_null(other)
		if n != null:
			ignore.append(n)
	var taken: Array = SPOT.taken(get_parent(), self, ignore)
	var belt := get_parent().get_node_or_null(^"Inventory") as Control
	if belt != null and belt.is_visible_in_tree() and belt.has_method("belt_rect"):
		taken.append(belt.call("belt_rect"))
	position = SPOT.first(places, vis, taken, view)


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	return row


func _button(text: String, parent: Control) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(52.0, 0.0)
	# No focus: Space is jump, and a focused button would take it.
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", text_size)
	parent.add_child(b)
	return b


func _label(text: String, colour: Color, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", text_size - 2)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _paint(b: Button, mine: bool) -> void:
	b.add_theme_stylebox_override("normal", _chip_on if mine else _chip)
	b.add_theme_stylebox_override("hover", _chip_on if mine else _chip_hover)
	b.add_theme_stylebox_override("pressed", _chip_on)
	b.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95 if mine else 0.55))
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
