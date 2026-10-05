extends Node

## The way back to the chicken pen, when that is where you came from: the range's own copy of
## ShootingGalleryRamon/scripts/range_way_home_ramon.gd (that range is not changed, CLAUDE.md).
##
## It does nothing unless the pen left a way home on the tree root (chickenpen/scripts/
## pen_range_trip_4d.gd; today the pen still sends you to the old range, and only Ramon decides when
## this one goes live). Launched from the menu there is none, and the return prompt goes to the menu.
## When there is one, the prompt is relabelled and its key taken here first (in _input, ahead of the
## prompt's own _unhandled_input), so the same key in the same corner goes back to the pen. Escape does
## the same: the shared player.gd sends Escape to the old team menu, which lost the parked pen
## (follow_up/quantum_range.md, finding 4); this range never does.

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


func is_set() -> bool:
	return _home.is_valid()


func _input(event: InputEvent) -> void:
	if not _home.is_valid():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != _key:
		return
	get_viewport().set_input_as_handled()
	_home.call()


func go_home() -> void:
	if _home.is_valid():
		_home.call()
