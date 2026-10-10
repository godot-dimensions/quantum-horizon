extends CanvasLayer

## The menu's secret tuning panel, on Tab (Ramon, 10 Oct: "build me a secret hud by letting me press
## tab, where i can change the logo grey and save in settings").
##
## One slider per grey in menu_final's `tuning` (the list's logos, the route's logos, the route's
## rings), each the ink's strength: the menu repaints as the slider moves, SAVE writes them to
## menu_final.TUNING_PATH, REVERT reads that file back. Made and toggled by menu_final
## (_toggle_tuning), only while the menu is up; it hides when a prototype launches.
##
## NO class_name: menu_final preloads it.

const ROWS := [
	["list_logos", "List logos"],
	["route_logos", "Route logos"],
	["route_rings", "Route rings"],
	["music", "Music"],
]
const PANEL := Color(0.04, 0.05, 0.07)
const WHITE := Color(1, 1, 1)
const SOFT := Color(1, 1, 1, 0.55)

var menu: Control
var saved_in: String = ""
var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _status: Label


func _init(owner_menu: Control, path: String) -> void:
	menu = owner_menu
	saved_in = path
	layer = 40
	name = "TuningHud"


func _ready() -> void:
	var look: RefCounted = menu.call("_a")
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_right = -70.0
	panel.offset_top = 84.0
	panel.custom_minimum_size.x = 400.0
	var bg: StyleBoxFlat = look.call("box", PANEL, 8)
	bg.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var head := HBoxContainer.new()
	var title: Label = look.call("caps", "Menu tuning", 13, WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(look.call("caps", "Tab closes", 11, SOFT))
	column.add_child(head)
	column.add_child(look.call("txt", "Grey of the logos and rings, as ink strength: higher is darker on white, lighter on dark. Music: the menu's background bed.", 12, SOFT))
	(column.get_child(1) as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for row in ROWS:
		var key: String = row[0]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var label: Label = look.call("txt", String(row[1]), 14, WHITE)
		label.custom_minimum_size.x = 110.0
		line.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE
		slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		line.add_child(slider)
		var value: Label = look.call("txt", "", 14, WHITE)
		value.custom_minimum_size.x = 48.0
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(value)
		column.add_child(line)
		_sliders[key] = slider
		_values[key] = value
		slider.value_changed.connect(_on_slider.bind(key))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var save: Button = look.call("foot_button", "SAVE", true)
	save.pressed.connect(_on_save)
	buttons.add_child(save)
	var revert: Button = look.call("foot_button", "REVERT")
	# The foot's light grey edge is the page's ink, invisible on this black: a white one here.
	for state in ["normal", "hover", "pressed"]:
		(revert.get_theme_stylebox(state) as StyleBoxFlat).border_color = Color(1, 1, 1, 0.35)
	revert.pressed.connect(_on_revert)
	buttons.add_child(revert)
	column.add_child(buttons)
	_status = look.call("txt", "", 12, SOFT)
	column.add_child(_status)
	refresh()


## Puts the menu's current greys on the sliders (when the panel opens, and after REVERT).
func refresh() -> void:
	if _sliders.is_empty():
		return
	var tuning: Dictionary = menu.get("tuning")
	for key in _sliders:
		(_sliders[key] as HSlider).set_value_no_signal(float(tuning[key]))
		_show_value(key)
	_status.text = "Saved values in %s" % saved_in.get_file()


func _show_value(key: String) -> void:
	(_values[key] as Label).text = "%d %%" % roundi(float((_sliders[key] as HSlider).value) * 100.0)


func _on_slider(value: float, key: String) -> void:
	menu.call("set_tuning", key, value)
	_show_value(key)
	_status.text = "Changed, not saved yet"


func _on_save() -> void:
	var error: int = int(menu.call("save_tuning"))
	_status.text = ("Saved to %s" % saved_in) if error == OK else ("Could not save (error %d)" % error)


func _on_revert() -> void:
	menu.call("load_tuning")
	menu.call("_a").call("apply_greys")
	refresh()
