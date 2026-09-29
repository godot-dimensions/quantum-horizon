extends Node

## "Press 1 to mine" over the Artifact, while you are standing at it with the pickaxe on
## your belt and something else - or nothing - in your hand (Ramon, 29 Sept: "when you're in
## front of the artefact and you dont have the pickaxe active, you should get a prompt that
## says press 1 to mine").
##
## THE NUMBER IS THE PICKAXE'S OWN SLOT, read from the belt every frame, so it stays true
## however the belt has filled - it is "1" only because the pickaxe is usually the first
## thing you are given. No pickaxe on the belt, no prompt: there is nothing to press yet.
## Put away while a conversation holds you still, the way every other prompt is.

@export var tag_path: NodePath = NodePath("../UI/MineTag")
@export var rock_path: NodePath = NodePath("../Monolith")
@export var player_path: NodePath = NodePath("../../Player")
@export var inventory_path: NodePath = NodePath("../../UI/Inventory")
@export var tool_effect: String = "found_pickaxe"
## How close, across the floor and through W, before it is offered.
@export_range(0.5, 10.0, 0.1) var near: float = 4.5
@export_range(0.2, 6.0, 0.1) var near_w: float = 2.0

var _tag: Node
var _rock: Node4D
var _player: Node4D
var _belt: Node
var _shown := ""


func _ready() -> void:
	_tag = get_node_or_null(tag_path)
	_rock = get_node_or_null(rock_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	_belt = get_node_or_null(inventory_path)


func _process(_delta: float) -> void:
	if _tag == null:
		return
	var text: String = prompt()
	if text == _shown:
		return
	_shown = text
	if text == "":
		_tag.call("clear")
	else:
		_tag.call("show_text", text)


## What it would say right now, or "" - for the tests as well.
func prompt() -> String:
	if _rock == null or _player == null or _belt == null or not _player.is_inside_tree():
		return ""
	if _player.get("input_enabled") == false:
		return ""
	var gap: Vector4 = _rock.global_position - _player.global_position
	if Vector2(gap.x, gap.z).length() > near or absf(gap.w) > near_w:
		return ""
	var items: Array = _belt.get("items")
	var slot: int = items.find(tool_effect)
	if slot < 0 or String(_belt.call("selected_effect")) == tool_effect:
		return ""
	return "Press %d to mine" % (slot + 1)
