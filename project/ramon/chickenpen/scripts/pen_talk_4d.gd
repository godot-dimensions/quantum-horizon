extends Node

## Puts the keeper's conversation into chickenpen: who can talk, when, with which opening
## line, and what his gauntlet actually switches on.
##
## The dialogue itself knows none of this. `ramon/dialogue/` holds a panel, a script walker
## and a page of writing, none of which have heard of a chicken; this file is the whole of
## the join. That is the point - the next character who needs to talk needs a script file
## and a few lines here, not a second dialogue system.
##
## THE CATCH KEY IS THE TALK KEY, AND THAT NEEDS A RULE. chickenpen already spends F on
## catching and throwing, and adding a second Talk key to a control card that is already
## eleven rows long is worse than sharing one. So this listens in _input, which runs ahead
## of the catcher's _unhandled_input, and takes the key only when talking is unambiguously
## what was meant: the keeper in reach, no chicken in reach, and nothing in your arms.
## Every other press falls straight through to the catcher untouched.
##
## THE LOCATOR IS OFF UNTIL HE HANDS IT OVER. It is a gauntlet he gives you, so the game
## should not open with it already on your wrist. Turn `gate_locator` off to get the old
## behaviour back if this gets in the way of testing.

@export var player_path: NodePath
@export var character_path: NodePath
@export var catcher_path: NodePath
@export var manager_path: NodePath
@export var dialogue_path: NodePath
@export var tag_path: NodePath
## What the gauntlet switches on. Hidden at the start, shown when he hands it over.
@export var locator_ui_paths: Array[NodePath] = []

@export_group("Reach")
## How close on the ground before he is worth talking to.
@export_range(1.0, 12.0, 0.5) var talk_range: float = 3.0
## And how far through W. He should still be addressable from a slice or so away, because
## a keeper who goes silent because you stepped sideways reads as a bug.
@export_range(0.5, 8.0, 0.5) var talk_range_w: float = 2.0

@export_group("Rules")
@export var gate_locator: bool = true
## Freeze the player while a conversation is open. Cheaper and far less buggy than letting
## someone wander off mid-sentence.
@export var lock_movement: bool = true

var _player: Node4D
var _character: Node
var _catcher: Node
var _manager: Node
var _talk: DialoguePlayer4D
var _tag: WorldTag4D
var _has_gauntlet: bool = false
var _met: bool = false


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_character = get_node_or_null(character_path)
	_catcher = get_node_or_null(catcher_path)
	_manager = get_node_or_null(manager_path)
	_talk = get_node_or_null(dialogue_path) as DialoguePlayer4D
	_tag = get_node_or_null(tag_path) as WorldTag4D
	if _player == null or _talk == null or _tag == null:
		push_warning("PenTalk: player, dialogue or tag missing - the keeper will never speak (item 82).")
		return
	_talk.use_script(KeeperScript.NODES, KeeperScript.START, Callable(KeeperScript, "fill"))
	_talk.effect.connect(_on_effect)
	_talk.started.connect(_on_started)
	_talk.ended.connect(_on_ended)
	_show_locator(not gate_locator)


func _process(_delta: float) -> void:
	if _tag == null:
		return
	if _talk != null and _talk.is_running():
		_tag.clear()
		return
	_tag.show_text("%s talk" % _catch_key()) if _can_talk() else _tag.clear()


## Ahead of the catcher, and only greedy when the answer is unambiguous.
func _input(event: InputEvent) -> void:
	if _talk == null or _talk.is_running():
		return
	if not event.is_action_pressed(&"catch_target"):
		return
	if not _can_talk():
		return
	_talk.returned = _returned()
	_talk.total = _total()
	_talk.begin(_entry())
	get_viewport().set_input_as_handled()


## In reach of him, out of reach of a chicken, and empty-handed. Anything else and F still
## means catch.
func _can_talk() -> bool:
	if _player == null:
		return false
	if _catcher != null:
		if _catcher.get("carried") != null:
			return false
		if _catcher.get("_candidate") != null:
			return false
	return _in_reach()


func _in_reach() -> bool:
	if _tag == null:
		return false
	var anchor: Node4D = _tag.get_node_or_null(_tag.anchor_path) as Node4D
	if anchor == null:
		return false
	var gap: Vector4 = anchor.global_position - _player.global_position
	return Vector2(gap.x, gap.z).length() <= talk_range and absf(gap.w) <= talk_range_w


## Which greeting he opens with. The scripted meeting once, then whatever state you turn
## up in - which is what makes him a second readout of the count as well as a character.
func _entry() -> String:
	if not _met:
		_met = true
		return KeeperScript.START
	if _catcher != null and _catcher.get("carried") != null:
		return "greet_carrying"
	if gate_locator and not _has_gauntlet:
		return "greet_no_gauntlet"
	var home: int = _returned()
	var all: int = _total()
	if all > 0 and home >= all:
		return "greet_done"
	if home == 0:
		return "greet_none"
	if home >= all - 2:
		return "greet_nearly"
	return "greet_some"


func _on_effect(name: String) -> void:
	match name:
		"give_gauntlet":
			_has_gauntlet = true
		"withhold_gauntlet":
			_has_gauntlet = false
	_talk.set_flag("gauntlet", _has_gauntlet)
	if gate_locator:
		_show_locator(_has_gauntlet)


func _on_started() -> void:
	_set_movement(false)


func _on_ended() -> void:
	_set_movement(true)


func _set_movement(on: bool) -> void:
	if lock_movement and _character != null:
		_character.set("input_enabled", on)


func _show_locator(on: bool) -> void:
	for path in locator_ui_paths:
		var node: CanvasItem = get_node_or_null(path) as CanvasItem
		if node != null:
			node.visible = on


func _returned() -> int:
	return int(_manager.call("returned_count")) if _manager != null else 0


func _total() -> int:
	if _manager == null:
		return 12
	var agents: Array = _manager.get("agents") as Array
	return agents.size() if agents != null else 12


## Read from the InputMap for the same reason every other prompt in this prototype does:
## a printed key stops being true the moment somebody rebinds.
func _catch_key() -> String:
	if not InputMap.has_action(&"catch_target"):
		return "?"
	for event in InputMap.action_get_events(&"catch_target"):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "?"


## Item 73: a restart should give you the first meeting again.
func reset() -> void:
	_met = false
	_has_gauntlet = false
	if _talk != null:
		_talk.stop()
		_talk.reset()
	_show_locator(not gate_locator)
	_set_movement(true)
