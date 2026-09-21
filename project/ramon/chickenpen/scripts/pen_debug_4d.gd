extends Node

## Development tools: teleport, reset, reveal, resize, force (item 81).
##
## ONE SWITCH TURNS THE WHOLE THING OFF, because item 81 asks for that explicitly and
## because a demo is exactly when someone leans on a keyboard. With `enabled` false this
## node does not read input, does not draw its line and cannot be triggered by accident -
## it is not merely hidden.
##
## THE KEYS ARE ALL ON THE NUMBER ROW, away from WASD, E, Q, F and the mouse. Nothing here
## shares a key with anything a player uses, so no debug action can fire during normal
## play even while it is switched on.
##
## IT CHANGES THE GAME THROUGH THE GAME'S OWN FUNCTIONS - recover(), on_caught(), the
## fence's exported extents - rather than reaching past them. A debug tool that writes
## state directly can put the scene into a position the real code cannot reach, and then
## the bug you chase is the tool's.

@export var enabled: bool = true: set = _set_enabled
@export var manager_path: NodePath
@export var player_path: NodePath
@export var catcher_path: NodePath
@export var fence_path: NodePath
@export var cues_path: NodePath
@export var game_path: NodePath
@export var readout_path: NodePath

var _manager: Node
var _player: Node4D
var _catcher: Node
var _fence: Node
var _cues: Node
var _game: Node
var _readout: Label
var _revealing: bool = false
var _message: String = ""
var _left: float = 0.0


func _ready() -> void:
	_manager = get_node_or_null(manager_path)
	_player = get_node_or_null(player_path) as Node4D
	_catcher = get_node_or_null(catcher_path)
	_fence = get_node_or_null(fence_path)
	_cues = get_node_or_null(cues_path)
	_game = get_node_or_null(game_path)
	_readout = get_node_or_null(readout_path) as Label
	_set_enabled(enabled)
	if enabled:
		_say("Debug on: 1 bring chicken  2 teleport to it  3 reveal all  4/5 pen size  6 scatter  7 finish  0 off")


## One place decides what "off" means, so switching it off in the Inspector, in code and
## with the 0 key all leave the node in the same state - not reading input, not ticking,
## and not showing a line. An earlier version only set the flag when 0 was pressed, so the
## node went on processing and only LOOKED disabled.
func _set_enabled(value: bool) -> void:
	enabled = value
	if not is_node_ready():
		return
	set_process(value)
	set_process_unhandled_input(value)
	if not value and _readout != null:
		_readout.text = ""


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0 and _readout != null:
		_readout.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			_bring_target()
		KEY_2:
			_go_to_target()
		KEY_3:
			_toggle_reveal()
		KEY_4:
			_resize(-1.0)
		KEY_5:
			_resize(1.0)
		KEY_6:
			_scatter()
		KEY_7:
			_finish()
		KEY_0:
			_say("Debug off.")
			_left = 2.0
			enabled = false
		_:
			return
	get_viewport().set_input_as_handled()


## 1: bring the chicken the locator is pointing at to the player, in the player's slice.
func _bring_target() -> void:
	var agent: Node = _first_loose()
	if agent == null:
		_say("Nothing loose to bring.")
		return
	var body: Node4D = agent.get_parent() as Node4D
	var host: Node4D = body.get_parent() as Node4D
	var at: Vector4 = _player.global_position + Vector4(0.0, 0.0, -1.2, 0.0)
	at.w = _player.global_position.w
	body.position = at - (host.global_position if host != null else Vector4.ZERO)
	agent.set("home_position", body.position)
	_say("Brought chicken %s to you, in your slice." % agent.get("chicken_id"))


## 2: the other direction - go to the chicken rather than making it come to you. Useful
## for checking a placement without walking there.
func _go_to_target() -> void:
	var agent: Node = _first_loose()
	if agent == null:
		_say("Nothing loose to go to.")
		return
	var body: Node4D = agent.get_parent() as Node4D
	var here: Vector4 = body.global_position
	_player.position = Vector4(here.x, _player.position.y, here.z + 1.2, here.w)
	_say("Teleported to chicken %s at w %.2f." % [agent.get("chicken_id"), here.w])


## 3: item 81's "mark all W targets" - every chicken's marker, from any slice.
##
## Done by widening the reveal band rather than by adding a second kind of marker, so what
## is being shown is the same thing the player sees, just without the limit.
func _toggle_reveal() -> void:
	if _cues == null:
		return
	_revealing = not _revealing
	_cues.set("reveal_band", 40.0 if _revealing else 0.55)
	_cues.set("reveal_distance", 200.0 if _revealing else 11.0)
	_cues.set("present_band", 0.0 if _revealing else 0.12)
	_say("All W targets %s." % ("marked" if _revealing else "hidden again"))


## 4 and 5: resize the pen, to check the fence really is modular (items 36 and 49).
func _resize(step: float) -> void:
	if _fence == null:
		return
	for field in ["extend_x_positive", "extend_x_negative", "extend_z_positive", "extend_z_negative"]:
		_fence.set(field, clampf(float(_fence.get(field)) + step, 2.0, 20.0))
	_say("Pen is now %.0f x %.0f." % [
		float(_fence.get("extend_x_positive")) + float(_fence.get("extend_x_negative")),
		float(_fence.get("extend_z_positive")) + float(_fence.get("extend_z_negative"))])


## 6: force every chicken back to a loose, wandering state at its authored spot.
func _scatter() -> void:
	if _game != null:
		_game.call("restart")
	_say("Scattered: every chicken loose at its authored spot again.")


## 7: jump to the end, to check the completion behaviour without playing the whole thing.
func _finish() -> void:
	var loose: Array = _manager.call("locator_candidates")
	for agent in loose:
		var body: Node4D = agent.get_parent() as Node4D
		agent.call("on_caught")
		agent.call("on_released")
		var spot: Vector4 = _fence.call("random_interior_point", RandomNumberGenerator.new())
		var host: Node4D = body.get_parent() as Node4D
		body.position = spot - (host.global_position if host != null else Vector4.ZERO)
	_say("Delivered %d chickens straight to the pen." % loose.size())


func _first_loose() -> Node:
	var candidates: Array = _manager.call("locator_candidates")
	return null if candidates.is_empty() else candidates[0]


func _say(text: String) -> void:
	_message = text
	_left = 4.0
	if _readout != null:
		_readout.text = text
