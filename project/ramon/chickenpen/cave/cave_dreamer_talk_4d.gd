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
##
## A SCENE, NOT A CHAT. F stands you on a mark before it (stand_marker_path, set in the
## scene, with the step made a cut) and hands the camera to cave_dreamer_cinema_4d.gd,
## which directs the conversation shot by shot. All of the HUD is put away for it, not only
## what the other characters hide - the dial above all, since the slice is locked while it
## plays.
##
## LEAVING IS WAKING. Its goodbye carries "do": "leave_dream"; when the conversation has
## closed, the pen's DreamWake (pen_dream_wake_4d.gd) flashes you home to the grass in
## front of the cave - the same way the range master's "go_range" waits for the end.

const DreamerScript := preload("res://ramon/chickenpen/cave/cave_dreamer_script.gd")

@export var dreamer_path: NodePath = NodePath("../../Dreamer")
## The cave, where what it remembers is kept, and Hale's driver on it.
@export var cave_path: NodePath = NodePath("../../..")
@export var miner_driver_path: NodePath = NodePath("../../../Systems/MinerDriver")
## The pen's waking, which outlives the cave.
@export var wake_path: NodePath = NodePath("../../../../Systems/DreamWake")
@export var cinema_path: NodePath = NodePath("../DreamerCinema")
## Everything drawn under these is put away while it talks, as well as hide_while_talking.
@export var hide_all_under: Array[NodePath] = [NodePath("../../../../UI")]
@export var hide_also: Array[NodePath] = [NodePath("../../../../Player/StateLabel")]

var _dreamer: Node
var _cave: Node
var _waking := false
var _cinema: Node


func _configure() -> void:
	_dreamer = get_node_or_null(dreamer_path)
	_cave = get_node_or_null(cave_path)
	_cinema = get_node_or_null(cinema_path)
	_talk.use_script(DreamerScript.NODES, DreamerScript.START, _fill_line)
	for path in hide_all_under:
		var under: Node = get_node_or_null(path)
		if under == null:
			continue
		for child in under.get_children():
			if child is CanvasItem and not _hide.has(child):
				_hide.append(child)
	for path in hide_also:
		var item := get_node_or_null(path) as CanvasItem
		if item != null and not _hide.has(item):
			_hide.append(item)


## Its words about the player at the desk: the key they pressed to skip it, and the time on
## their own clock.
func _fill_line(line: String, _returned: int, _total: int) -> String:
	if not line.contains("{"):
		return line
	var now: Dictionary = Time.get_time_dict_from_system()
	return line.format({"key": "Escape", "time": "%d:%02d" % [int(now["hour"]), int(now["minute"])]})


## IN REACH ACROSS THE FLOOR AND THROUGH W TOGETHER. The others measure the floor and W
## separately, and W tightly, which is right for people standing on your slice; you walk to
## the dreamer along W, so its twenty-odd metres of approach are all W, and with a tight W
## limit F only came on right underneath it (Ramon, 29 Sept: "it should work in further
## distance"). One distance, in (x, z, w), up to talk_range.
func _in_reach() -> bool:
	var anchor: Node4D = _anchor()
	if anchor == null or _player == null:
		return false
	var gap: Vector4 = anchor.global_position - _player.global_position
	return Vector3(gap.x, gap.z, gap.w).length() <= talk_range


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
	elif name == "leave_dream":
		_waking = true


func _began() -> void:
	if _cinema != null:
		_cinema.call("begin")


func _ended() -> void:
	if _dreamer != null:
		_dreamer.call("set_mood", "calm")
	var wake: Node = get_node_or_null(wake_path) if _waking else null
	if _cinema != null:
		_cinema.call("end", wake != null)
	if wake != null:
		_waking = false
		# Held on the mark and on the last shot until the flash has you: no stepping back
		# to where you stood, no cut to your own camera for the moment before it.
		_slide = -1.0
		wake.call("hold_hud", _hide)
		wake.call_deferred("wake")
