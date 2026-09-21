extends Node
class_name PenNpcTalk4D

## Everything two talkable characters in chickenpen have in common: who can be addressed,
## when, the key they share with catching, the prompt over their head, and freezing the
## player while a conversation is open.
##
## A subclass supplies only what makes the character themselves - which script they speak
## from, which node of it they open on given the state of the world, and what their
## effects mean. The keeper is one of those subclasses and the girl is another; a third
## costs about forty lines.
##
## THE CATCH KEY IS THE TALK KEY, AND THAT NEEDS A RULE. chickenpen already spends F on
## catching and throwing, and a second Talk key on a control card that is already eleven
## rows long is worse than sharing one. So this listens in _input, which runs ahead of the
## catcher's _unhandled_input, and takes the key only when talking is unambiguous: this
## character in reach, no chicken in reach, and nothing in your arms. Every other press
## falls through to the catcher untouched. Two of these in the same scene do not fight,
## because each one only ever claims the key when it is the one you are standing next to.

@export var player_path: NodePath
@export var character_path: NodePath
@export var catcher_path: NodePath
@export var dialogue_path: NodePath
@export var tag_path: NodePath

@export_group("Reach")
## How close on the ground before they are worth talking to.
@export_range(1.0, 12.0, 0.5) var talk_range: float = 3.0
## And how far through W. They should still be addressable from a slice or so away,
## because someone who goes silent when you step sideways reads as a bug.
@export_range(0.5, 8.0, 0.5) var talk_range_w: float = 2.0

@export_group("Rules")
## Freeze the player while a conversation is open. Cheaper and far less buggy than letting
## somebody wander off mid-sentence.
@export var lock_movement: bool = true

var _player: Node4D
var _character: Node
var _catcher: Node
var _talk: DialoguePlayer4D
var _tag: WorldTag4D


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_character = get_node_or_null(character_path)
	_catcher = get_node_or_null(catcher_path)
	_talk = get_node_or_null(dialogue_path) as DialoguePlayer4D
	_tag = get_node_or_null(tag_path) as WorldTag4D
	if _player == null or _talk == null or _tag == null:
		push_warning("%s: player, dialogue or tag missing - this character will never speak (item 82)." % name)
		return
	_talk.effect.connect(_on_effect)
	_talk.started.connect(_on_started)
	_talk.ended.connect(_on_ended)
	_configure()


func _process(_delta: float) -> void:
	if _tag == null:
		return
	if _talk != null and _talk.is_running():
		_tag.clear()
		return
	_tag.show_text(_tag_text()) if _can_talk() else _tag.clear()


func _input(event: InputEvent) -> void:
	if _talk == null or _talk.is_running():
		return
	if not event.is_action_pressed(&"catch_target"):
		return
	if not _can_talk():
		return
	_before_begin()
	_talk.begin(_entry_node())
	get_viewport().set_input_as_handled()


## In reach of them, out of reach of a chicken, and empty-handed. Anything else and the
## key still means catch.
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
	var anchor: Node4D = _anchor()
	if anchor == null:
		return false
	var gap: Vector4 = anchor.global_position - _player.global_position
	return Vector2(gap.x, gap.z).length() <= talk_range and absf(gap.w) <= talk_range_w


## Distance is measured to whatever the tag hangs off, so the prompt and the reach can
## never disagree about where the character is.
func _anchor() -> Node4D:
	if _tag == null:
		return null
	return _tag.get_node_or_null(_tag.anchor_path) as Node4D


func _on_started() -> void:
	_set_player_moving(false)
	_began()


func _on_ended() -> void:
	_set_player_moving(true)
	_ended()


func _set_player_moving(on: bool) -> void:
	if lock_movement and _character != null:
		_character.set("input_enabled", on)


## Read from the InputMap for the same reason every other prompt in this prototype does: a
## printed key stops being true the moment somebody rebinds.
func _catch_key() -> String:
	if not InputMap.has_action(&"catch_target"):
		return "?"
	for event in InputMap.action_get_events(&"catch_target"):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "?"


# ------------------------------------------------------------------ for subclasses

## Hand the dialogue player its script. Called once, after everything is resolved.
func _configure() -> void:
	pass


## Which node of the script to open on, given the state of the world right now.
func _entry_node() -> String:
	return ""


## What one of the script's announced effects means in this game.
func _on_effect(_name: String) -> void:
	pass


## Ways in for a subclass around the conversation itself.
func _before_begin() -> void:
	pass


func _began() -> void:
	pass


func _ended() -> void:
	pass


func _tag_text() -> String:
	return "%s talk" % _catch_key()
