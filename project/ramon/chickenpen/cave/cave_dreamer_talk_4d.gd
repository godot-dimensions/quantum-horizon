extends PenNpcTalk4D

## The dreamer's side of a conversation (cave_dreamer_script.gd). PenNpcTalk4D does the rest,
## as for Hale and the professor.
##
## WHAT IT REMEMBERS IS KEPT ON THE CAVE. The far room is let go whenever you are back on
## the flat slice (cave_far_stream_4d.gd), and this node with it, so having met you and
## having been told about the cube are put on the cave node, which stays. Whether the cube
## has been struck is Hale's to know - his driver hears every blow, even ones made while
## this room was not loaded.
##
## ITS MOOD IS THE SCRIPT'S. Lines carrying "do": "warn" turn the core red and "calm" turns
## it back (cave_dreamer_4d.gd, set_mood); it goes back to calm when you leave.

const DreamerScript := preload("res://ramon/chickenpen/cave/cave_dreamer_script.gd")

@export var dreamer_path: NodePath = NodePath("../../Dreamer")
## The cave, where what it remembers is kept, and Hale's driver on it.
@export var cave_path: NodePath = NodePath("../../..")
@export var miner_driver_path: NodePath = NodePath("../../../Systems/MinerDriver")

var _dreamer: Node
var _cave: Node


func _configure() -> void:
	_dreamer = get_node_or_null(dreamer_path)
	_cave = get_node_or_null(cave_path)
	_talk.use_script(DreamerScript.NODES, DreamerScript.START)


func _entry_node() -> String:
	if _cave != null and not _cave.has_meta(&"dreamer_met"):
		_cave.set_meta(&"dreamer_met", true)
		return DreamerScript.START
	var miner: Node = get_node_or_null(miner_driver_path)
	var struck: bool = miner != null and bool(miner.get("_struck"))
	if struck and _cave != null and not _cave.has_meta(&"dreamer_told_strike"):
		_cave.set_meta(&"dreamer_told_strike", true)
		return "greet_after_strike"
	return "menu"


func _on_effect(name: String) -> void:
	if _dreamer != null and (name == "warn" or name == "calm"):
		_dreamer.call("set_mood", name)


func _ended() -> void:
	if _dreamer != null:
		_dreamer.call("set_mood", "calm")
