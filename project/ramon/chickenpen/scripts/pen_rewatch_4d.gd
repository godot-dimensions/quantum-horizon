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
## on your belt are all still there when you come back.
##
## AND NOW IT REUSES THE DOOR LITERALLY. Pressing Y used to call go() and you were simply
## somewhere else - which threw away the best thing in the sequence. The arch is already
## built, already animates open, already lights the grass, already has its own sound, and
## already tells the crossing when somebody walks through it. So the ticket raises it in
## front of wherever you happen to be standing, facing you, and you walk into it. Not one
## line of the arch, the sound or the crossing had to change for that; the ticket just
## stopped skipping them.
##
## IT PUTS ITS OWN DOOR AWAY. The invitation's rearm() deliberately refuses to touch the
## arch once the story is finished with it - see its header - so a door raised after that
## would stand in the field for the rest of the run. This one watches for the trip ending
## and folds it.

@export var inventory_path: NodePath
@export var crossing_path: NodePath
@export var tag_path: NodePath
## Conversations that must not be interrupted by the prompt appearing over them.
@export var dialogue_paths: Array[NodePath] = []

## The door itself. The same one Trym raises; there is only ever one.
@export var arch_path: NodePath = NodePath("../../World/TrymDoor")
@export var player_path: NodePath = NodePath("../../Player")
## How far in front of you it goes up. Far enough to see it whole as it opens, near enough
## that walking into it is obviously the next thing to do.
@export_range(1.5, 8.0, 0.1) var door_ahead: float = 3.4
@export var item_effect: String = "rewatch_ticket"
@export var question: String = "Watch it again?     Y  yes      N  no"

var _inventory: Node
var _crossing: Node
var _tag: Node
var _talks: Array[Node] = []
var _asking: bool = false
var _arch: Node4D
var _player: Node4D
## This door is ours, and has to be folded away again when the trip ends.
var _own_door: bool = false
var _went: bool = false


func _ready() -> void:
	_inventory = get_node_or_null(inventory_path)
	_crossing = get_node_or_null(crossing_path)
	_tag = get_node_or_null(tag_path)
	for path in dialogue_paths:
		var talk: Node = get_node_or_null(path)
		if talk != null:
			_talks.append(talk)
	_arch = get_node_or_null(arch_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	if _inventory == null or _crossing == null:
		push_warning("%s: inventory or crossing missing - the ticket will do nothing." % name)


func _process(_delta: float) -> void:
	# THE DOOR WE RAISED, FOLDED AGAIN. Nothing else will: the invitation refuses to touch
	# the arch once its own sequence is over, which is right for its purposes and leaves
	# ours standing in a field.
	if _own_door:
		if bool(_crossing.call("is_away")):
			_went = true
		elif _went:
			_own_door = false
			_went = false
			if _arch != null:
				_arch.set("armed", false)

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
		_raise_the_door()


## In front of you, facing you, and opening. The crossing is NOT called here - the arch
## announces `entered` when somebody walks through it and the invitation already turns
## that into a trip, so pressing Y buys you a door rather than a teleport.
func _raise_the_door() -> void:
	if _arch == null or _player == null:
		if _crossing != null:
			_crossing.call("go")
		return
	var yaw: float = atan2(_player.global_basis.z.x, _player.global_basis.z.z)
	var ahead := Vector4(sin(yaw), 0.0, cos(yaw), 0.0)
	# Your own W, so it opens in the slice you are standing in rather than one you would
	# have to rotate to reach.
	var at: Vector4 = _player.global_position + ahead * door_ahead
	_arch.position = Vector4(at.x, 0.0, at.z, _player.global_position.w)
	# Square to you, so you walk into its face rather than its edge.
	_arch.basis = Basis4D.from_zx(yaw)
	_arch.visible = true
	_own_door = true
	_went = false
	_arch.set("armed", true)


func _put_away() -> void:
	_asking = false
	if _tag != null:
		_tag.call("clear")
	if _inventory != null:
		_inventory.set("selected", -1)
