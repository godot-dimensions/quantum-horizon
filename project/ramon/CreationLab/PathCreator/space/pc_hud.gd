extends Control

## PathCreator: the dev space's HUD, in the kit's black glass (kit_style.gd: screens and overlays
## are black). Where you are in W, how far the slice is tilted into W, the look and the symbol set,
## the view, what the keys do, and the validator's notes when there are any.
##
## NO class_name (engine_gotchas.md).

const Style := preload("res://ramon/CreationLab/kit/kit_style.gd")

var root_node: Node
var _label: Label
var _text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.glass_box(12.0))
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_override("font", Style.ui_font("body"))
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Style.UI_INK_SOFT)
	panel.add_child(_label)


func _process(_dt: float) -> void:
	if root_node == null or not visible:
		return
	var t: String = String(root_node.call("hud_text"))
	if t != _text:
		_text = t
		_label.text = t
