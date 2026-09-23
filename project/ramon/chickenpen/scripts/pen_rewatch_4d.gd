extends Node

## The ticket Trym hands over on the third conversation: select it on the belt, answer
## yes, and you are back in the theatre without him.
##
## WHY AN ITEM AND NOT A SECOND INVITATION. His invitation is written to happen once - its
## own header says an offer that repeats is not an offer, it is a machine. But the whole
## argument he makes in the post-show conversation is that you should be able to check a
## number rather than take his word for it, and that argument is worthless if checking it
## means walking back across the field to ask him. So the third time you speak to him he
## stops being the gate: the projector does not care whether he is standing next to it.
##
## IT ASKS FIRST. The belt is four other things you press by accident, and a key that
## teleports you out of the field with no confirmation is a key you learn to be afraid of.
## Y or N, on the player's own tag, where every other one-line prompt in this scene lands.
##
## IT REUSES THE DOOR RATHER THAN A SCENE CHANGE. pen_crossing_4d puts the theatre beside
## the field and switches the field off, so the chickens you have carried in and the gold
## on your belt are all still there when you come back. Calling go() is the same path the
## door uses; nothing here knows how the trip works.

@export var inventory_path: NodePath
@export var crossing_path: NodePath
@export var tag_path: NodePath
## Conversations that must not be interrupted by the prompt appearing over them.
@export var dialogue_paths: Array[NodePath] = []

@export var item_effect: String = "rewatch_ticket"
@export var question: String = "Watch it again?     Y  yes      N  no"

var _inventory: Node
var _crossing: Node
var _tag: Node
var _talks: Array[Node] = []
var _asking: bool = false


func _ready() -> void:
	_inventory = get_node_or_null(inventory_path)
	_crossing = get_node_or_null(crossing_path)
	_tag = get_node_or_null(tag_path)
	for path in dialogue_paths:
		var talk: Node = get_node_or_null(path)
		if talk != null:
			_talks.append(talk)
	if _inventory == null or _crossing == null:
		push_warning("%s: inventory or crossing missing - the ticket will do nothing." % name)


func _process(_delta: float) -> void:
	var want: bool = _should_ask()
	if want == _asking:
		return
	_asking = want
	if _tag == null:
		return
	if want:
		_tag.call("show_text", question)
	else:
		_tag.call("clear")


## Holding the ticket, on the farm, and not mid-conversation.
func _should_ask() -> bool:
	if _inventory == null or _crossing == null:
		return false
	if String(_inventory.call("selected_effect")) != item_effect:
		return false
	if bool(_crossing.call("is_away")):
		return false
	for talk in _talks:
		if is_instance_valid(talk) and bool(talk.call("is_running")):
			return false
	return true


func _input(event: InputEvent) -> void:
	if not _asking or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = (event as InputEventKey).keycode
	if key != KEY_Y and key != KEY_N:
		return
	get_viewport().set_input_as_handled()
	# Put the ticket away either way. Left in hand, the question would still be on screen
	# when you came home, and pressing Y on the far side would do nothing visible.
	_put_away()
	if key == KEY_Y:
		_crossing.call("go")


func _put_away() -> void:
	_asking = false
	if _tag != null:
		_tag.call("clear")
	if _inventory != null:
		_inventory.set("selected", -1)
