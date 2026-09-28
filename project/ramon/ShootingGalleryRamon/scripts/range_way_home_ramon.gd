extends Node

## The way back to the chicken pen, when that is where you came from.
##
## Only in the ramon copy of the gallery (CLAUDE.md: shooting_gallery.tscn itself is never
## edited). It does nothing at all unless the pen left a way home on the tree root
## (pen_range_trip_4d.gd). Launched from the menu there is none, and the gallery's return
## prompt goes to the menu exactly as before.
##
## When there is one, the return prompt is relabelled and its key is taken here first -
## in _input, ahead of the prompt's own _unhandled_input - so the same key, in the same
## corner, says and does "back to the pen" instead of "back to the menu".

const WAY_HOME := "chickenpen_way_home"
const WAY_HOME_LABEL := "chickenpen_way_home_label"

@export var return_button_path: NodePath = NodePath("../ReturnButton")

var _home: Callable
var _key: Key = KEY_H


func _ready() -> void:
	var root: Window = get_tree().root
	if not root.has_meta(WAY_HOME):
		set_process_input(false)
		return
	_home = root.get_meta(WAY_HOME)
	var button: Node = get_node_or_null(return_button_path)
	if button != null:
		_key = button.get("return_key")
		if root.has_meta(WAY_HOME_LABEL):
			button.set("label_format", String(root.get_meta(WAY_HOME_LABEL)))


func _input(event: InputEvent) -> void:
	if not _home.is_valid():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != _key:
		return
	get_viewport().set_input_as_handled()
	_home.call()
