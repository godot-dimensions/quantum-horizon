extends Node

## The pen's paths, the player's side of them (6 Oct 2026, PenLayout/PLAN_A.md phase 5): three
## switches on the network (CreationLab/PathCreator/graph/path_network_4d.gd), each on its own key
## and listed on the controls card (H).
##   F5  reveal or static: paths found as you go (a stretch shows once you have been near it), or
##       every path shown all the time
##   F6  the icons (the sheet's chevrons, balls and W dots) on or off
##   F7  the sand on or off
## Remembered between runs in user://pen_settings.cfg, next to the interface size. A first run is
## static, with icons and sand both on. A full restart (Ctrl+R) forgets what reveal has found.

@export var network_path: NodePath = NodePath("../../World/Paths")
@export var key_reveal: Key = KEY_F5
@export var key_icons: Key = KEY_F6
@export var key_sand: Key = KEY_F7
@export_range(0.5, 6.0, 0.1) var message_seconds: float = 2.2
@export_range(10, 40, 1) var text_size: int = 18

const SETTINGS := "user://pen_settings.cfg"

var _network: Node
var _label: Label
var _left: float = 0.0


func _ready() -> void:
	_network = get_node_or_null(network_path)
	if _network == null:
		push_warning("PenPaths: no path network at %s, so F5, F6 and F7 do nothing." % network_path)
		return
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	_network.set("reveal", bool(cfg.get_value("paths", "reveal", false)))
	_network.set("show_marks", bool(cfg.get_value("paths", "icons", true)))
	_network.set("show_sand", bool(cfg.get_value("paths", "sand", true)))
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", text_size)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
	_label.add_theme_constant_override("outline_size", 5)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.position.y = 64.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	layer.add_child(_label)


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0 and _label != null:
			_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _network == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = (event as InputEventKey).keycode
	if key == key_reveal:
		_network.set("reveal", not bool(_network.get("reveal")))
		_say("Paths: found as you go" if bool(_network.get("reveal")) else "Paths: all shown")
	elif key == key_icons:
		_network.set("show_marks", not bool(_network.get("show_marks")))
		_say("Path icons: on" if bool(_network.get("show_marks")) else "Path icons: off")
	elif key == key_sand:
		_network.set("show_sand", not bool(_network.get("show_sand")))
		_say("Sand paths: on" if bool(_network.get("show_sand")) else "Sand paths: off")
	else:
		return
	get_viewport().set_input_as_handled()
	_save()


func _say(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_label.visible = true
	_label.reset_size()
	_label.position.x = (_label.get_viewport_rect().size.x - _label.size.x) * 0.5
	_left = message_seconds


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("paths", "reveal", bool(_network.get("reveal")))
	cfg.set_value("paths", "icons", bool(_network.get("show_marks")))
	cfg.set_value("paths", "sand", bool(_network.get("show_sand")))
	cfg.save(SETTINGS)


## Part of the full restart (chickenpen_game_4d.gd calls every sibling's reset).
func reset() -> void:
	if _network != null and _network.has_method("reset_reveal"):
		_network.call("reset_reveal")
