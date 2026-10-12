extends Node
class_name DialogueLayoutProbe4D

## Cycles the dialogue panel through a handful of placements so they can be judged by
## playing rather than by argument. Press P.
##
## A playtest tool, not a feature. Each preset is a plain dictionary of box properties, so
## trying a fifth arrangement means adding four numbers here rather than touching the box;
## and when one of them wins, the winner's numbers get typed into the scene and this node
## comes out. `enabled` off for a clean capture.
##
## The four are chosen to separate the questions that actually differ:
##   1 and 2 differ ONLY in which end the replies hug, which is the question the HUD makes
##   for you - chickenpen keeps its slice radar bottom right.
##   3 asks whether a narrower band reads better than a full-width one.
##   4 is the one worth settling: over his head, comic-balloon style, which is the natural
##   thing to want and the thing most likely to fight the camera.

@export var box_path: NodePath
@export var enabled: bool = true
@export var toggle_key: Key = KEY_P
## Where to put the little "which variant is this" readout, from the top of the screen.
@export_range(0.0, 400.0, 1.0) var readout_top: float = 12.0
@export_range(10, 40, 1) var readout_size: int = 17

const PRESETS: Array = [
	{
		"name": "1. Over his head (default)",
		"props": {
			"layout": 2, "over_head_width": 470.0, "over_head_lift": 10.0,
			"over_head_nudge_x": -450.0, "choice_width": 470.0, "choice_gap": 10.0,
			"text_size": 20, "choice_size": 19, "name_size": 17,
		},
	},
	{
		"name": "2. Wide band, replies right",
		"props": {
			"layout": 0, "side_margin": 70.0, "bottom_margin": 34.0,
			"choice_side": 0, "choice_width": 620.0,
			"band_text_height": 66.0, "text_size": 24, "choice_size": 20, "name_size": 20,
		},
	},
	{
		"name": "3. Wide band, replies left",
		"props": {
			"layout": 0, "side_margin": 70.0, "bottom_margin": 34.0,
			"choice_side": 1, "choice_width": 620.0,
			"band_text_height": 66.0, "text_size": 24, "choice_size": 20, "name_size": 20,
		},
	},
	{
		"name": "4. Narrow centred band",
		"props": {
			"layout": 0, "side_margin": 300.0, "bottom_margin": 56.0,
			"choice_side": 1, "choice_width": 620.0,
			"band_text_height": 82.0, "text_size": 22, "choice_size": 19, "name_size": 18,
		},
	},
]

var _box: Node
var _readout: Label
var _at: int = 0


func _ready() -> void:
	_box = get_node_or_null(box_path)
	if _box == null:
		push_warning("DialogueLayoutProbe4D: no box at '%s' - nothing to cycle." % box_path)
		return
	if not enabled:
		return
	# Its own label rather than borrowing one: this is scaffolding and it should not need
	# a slot in anybody's HUD.
	_readout = Label.new()
	_readout.name = "LayoutReadout"
	_readout.add_theme_font_size_override("font_size", readout_size)
	_readout.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	_readout.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.09, 0.9))
	_readout.add_theme_constant_override("outline_size", 5)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_readout.offset_top = readout_top
	_readout.offset_bottom = readout_top + float(readout_size) + 8.0
	add_child(_readout)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or _box == null:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if (event as InputEventKey).keycode != toggle_key:
		return
	_at = (_at + 1) % PRESETS.size()
	_apply()
	get_viewport().set_input_as_handled()


func _apply() -> void:
	var preset: Dictionary = PRESETS[_at]
	for key in (preset["props"] as Dictionary):
		_box.set(key, preset["props"][key])
	if _readout != null:
		_readout.text = "%s        P for the next" % preset["name"]
