extends Node

## Holds the minigame together: binds the parts, counts progress, restarts.
##
## Deliberately thin. The chickens know how to be chickens, the catcher knows how to
## catch and the pen knows what is inside it; this only wires them to each other and
## owns the one thing none of them can own alone, which is the score.
##
## Item 73 wants a restart that needs no editor restart, so nothing here caches state
## that a respawn would invalidate - the count is always derived from the chickens
## themselves rather than incremented and hoped over.

signal completed()

@export var manager_path: NodePath
@export var player_path: NodePath
@export var catcher_path: NodePath
@export var progress_label_path: NodePath
@export var objective_label_path: NodePath

## Item 67: the opening statement of what the player is meant to do.
@export var objective_text: String = "Twelve chickens are loose. Bring them all back to the pen."

@export var completion_text: String = "All twelve chickens are home."

var _manager: Node
var _player: Node4D
var _catcher: Node
var _progress: Label
var _objective: Label
var _finished: bool = false


func _ready() -> void:
	_manager = get_node_or_null(manager_path)
	_player = get_node_or_null(player_path) as Node4D
	_catcher = get_node_or_null(catcher_path)
	_progress = get_node_or_null(progress_label_path) as Label
	_objective = get_node_or_null(objective_label_path) as Label
	if _manager == null or _player == null:
		push_warning("ChickenPenGame: manager or player missing, so nothing will be wired up.")
		return
	_manager.call("bind_player", _player)
	if not _manager.is_connected("progress_changed", _on_progress):
		_manager.connect("progress_changed", _on_progress)
	if _objective != null:
		_objective.text = objective_text
	_on_progress(_manager.call("returned_count"), (_manager.get("agents") as Array).size())


func _unhandled_input(event: InputEvent) -> void:
	# Item 73: reset without leaving the scene.
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R:
		if Input.is_key_pressed(KEY_CTRL):
			restart()


## Item 69: a restrained, always-visible count.
func _on_progress(returned: int, total: int) -> void:
	if _progress != null:
		_progress.text = "Chickens returned: %d/%d" % [returned, total]
	if returned >= total and total > 0 and not _finished:
		_finished = true
		if _objective != null:
			_objective.text = completion_text
		emit_signal("completed")


func restart() -> void:
	_finished = false
	if _catcher != null:
		_catcher.set("carried", null)
	if _manager != null:
		_manager.call("reset")
		_manager.call("bind_player", _player)
	if _objective != null:
		_objective.text = objective_text
