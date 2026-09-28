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
@export var locator_path: NodePath
@export var cues_path: NodePath

## Item 67: the opening statement of what the player is meant to do.
@export var objective_text: String = "Nine chickens are loose. Bring them all back to the pen."

@export var completion_text: String = "All nine chickens are home."

## Everybody who walks about and therefore has to be put back. The player first, because
## that is the one the card's promise is really about.
@export var restore_paths: Array[NodePath] = [NodePath("../../Player"),
	NodePath("../../World/Nike"), NodePath("../../Mithra")]
@export var crossing_path: NodePath = NodePath("../../Crossing")
@export var rig_path: NodePath = NodePath("../../Player/CameraRig")
## Things that know how to reset themselves but do NOT live under Systems, so the sweep
## never reached them. The belt is the one that mattered: it hangs off UI, so a restart
## put the flock back and left last round's gold on your wrist - and the trough you had
## already bought with it still standing in the field.
@export var also_reset_paths: Array[NodePath] = [NodePath("../../UI/Inventory"), NodePath("../../UI/Quests")]

var _manager: Node
var _player: Node4D
var _catcher: Node
var _progress: Label
var _objective: Label
var _locator: Node
var _cues: Node
var _finished: bool = false
var _last_returned: int = 0


func _ready() -> void:
	_manager = get_node_or_null(manager_path)
	_player = get_node_or_null(player_path) as Node4D
	_catcher = get_node_or_null(catcher_path)
	_progress = get_node_or_null(progress_label_path) as Label
	_objective = get_node_or_null(objective_label_path) as Label
	_locator = get_node_or_null(locator_path)
	_cues = get_node_or_null(cues_path)
	if _manager == null or _player == null:
		push_warning("ChickenPenGame: manager or player missing, so nothing will be wired up.")
		return
	_manager.call("bind_player", _player)
	if not _manager.is_connected("progress_changed", _on_progress):
		_manager.connect("progress_changed", _on_progress)
	if _objective != null:
		_objective.text = objective_text
	_reset_everyone()
	_on_progress(_manager.call("returned_count"), (_manager.get("agents") as Array).size())

	# Taken at the end of _ready, once the scene has placed everybody.
	_snapshot()

## Where each of them was when the scene loaded.
var _spawns: Dictionary = {}


func _snapshot() -> void:
	for path in restore_paths:
		var who: Node4D = get_node_or_null(path) as Node4D
		if who != null:
			_spawns[path] = [who.position, who.basis]


## Anything that knows how to reset itself, does. The talk drivers hold quest state - who
## has been met, who is carrying whose coin - and item 73's restart is not one if it
## leaves that behind.
##
## ONE FUNCTION, CALLED FROM BOTH ENDS. It used to be written out inside _ready only, so
## the load did the full sweep and Ctrl+R did not, and nothing in the file made that
## visible. Now they are the same call and cannot drift.
func _reset_everyone() -> void:
	for sibling in get_parent().get_children():
		if sibling != self and sibling.has_method("reset"):
			sibling.call("reset")
	for path in also_reset_paths:
		var other: Node = get_node_or_null(path)
		if other != null and other.has_method("reset"):
			other.call("reset")


func _unhandled_input(event: InputEvent) -> void:
	# Item 73: reset without leaving the scene.
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R:
		if Input.is_key_pressed(KEY_CTRL):
			restart()


## Item 69: a restrained, always-visible count.
func _on_progress(returned: int, total: int) -> void:
	if _progress != null:
		_progress.text = "Chickens returned: %d/%d" % [returned, total]
	# Item 70: immediate, and only on an actual gain. Driven off the count rather than off
	# a "chicken landed" event, because the count is the thing the player is watching - if
	# the number moved, the sound plays, and the two can never disagree.
	var gained: bool = returned > _last_returned
	_last_returned = returned
	if returned >= total and total > 0 and not _finished:
		_finished = true
		if _objective != null:
			_objective.text = completion_text
		# Item 72: the locator stops guiding. It has nothing left to point at, and a device
		# still murmuring directions after the job is done reads as unfinished.
		if _locator != null:
			_locator.set_physics_process(false)
			# Resolved against the LOCATOR, whose export it is - a NodePath means nothing
			# without the node it was written relative to.
			var readout: Label = _locator.get_node_or_null(_locator.get("readout_path")) as Label
			if readout != null:
				readout.text = "Locator: nothing left to find."
		if _cues != null:
			_cues.call("quiet")
			_cues.call("celebrate")
		emit_signal("completed")
	elif gained and _cues != null:
		_cues.call("confirm")


## EVERYTHING BACK, INCLUDING YOU. The card has always said "restart the scene" and this
## used to put the flock back and leave the player wherever they were standing - halfway
## across the field, three slices out, possibly inside the theatre. The counter said 0/9
## and nothing else agreed with it.
##
## Snapshotted at load rather than typed in here, so moving anybody in the editor moves
## where they restart to. Only the things that MOVE are listed: scenery does not need
## putting back, and a long list of paths is a long list of paths to get wrong.
func restart() -> void:
	# OUT OF THE THEATRE FIRST. It is a whole second scene added beside this one, with the
	# farm disabled underneath it - restarting into that leaves you in a room that has just
	# been told the presentation never happened.
	var crossing: Node = get_node_or_null(crossing_path)
	if crossing != null and crossing.has_method("is_away") and bool(crossing.call("is_away")):
		crossing.call("come_back")
	for path in restore_paths:
		var who: Node4D = get_node_or_null(path) as Node4D
		if who == null or not _spawns.has(path):
			continue
		var spawn: Array = _spawns[path]
		who.position = spawn[0]
		who.basis = spawn[1]
		# `linear_velocity`, not `velocity` - this is CharacterBody4D, not the 3D one, and
		# the 3D name silently fails as an unknown property rather than erroring at parse
		# time. Put back on the spawn with the old momentum still in you, you slide.
		if "linear_velocity" in who:
			who.set("linear_velocity", Vector4.ZERO)
	# And the slice dial flat again, which plain R does. Restarting on a rotated slice
	# means the pen is somewhere you cannot see and the first thing you do is press R.
	var rig: Node = get_node_or_null(rig_path)
	if rig != null and rig.has_method("go_home"):
		rig.call("go_home")
	_finished = false
	_last_returned = 0
	if _locator != null:
		_locator.set_physics_process(true)
	if _cues != null:
		_cues.call("resume")
	if _catcher != null:
		_catcher.set("carried", null)
	if _manager != null:
		_manager.call("reset")
		_manager.call("bind_player", _player)
	if _objective != null:
		_objective.text = objective_text
	# AND EVERYTHING THAT HOLDS QUEST STATE, which is the half this never did. The comment
	# up in _ready has always said item 73's restart is not one if it leaves that behind -
	# and then the sweep it describes only ever ran at load. Ctrl+R put the chickens back
	# and left Trym having already shown you the cinema, Mithra having already been paid,
	# the keeper having already been met, and the gold still on your wrist.
	_reset_everyone()
