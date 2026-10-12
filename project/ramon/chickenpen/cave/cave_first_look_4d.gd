extends Node

## The first time the corridor opens into the chamber, you say so (Ramon, 28 Sept: "when you
## just enter the cave, and walk towards the main room, you could say, wow, whats this or
## something"). Through the pen's own thought box, the one the crows' line uses.
##
## ONCE, AND NOT OVER ANYBODY. Kept on the pen's root node, so walking out and back in does
## not say it again (a restart of the scene does); and held back while somebody is already
## talking.

@export var box_path: NodePath = NodePath("../../UI/ThoughtBox")
@export var player_path: NodePath = NodePath("../../Player")
@export var talker_paths: Array[NodePath] = [NodePath("../Systems/MinerTalk")]
## How far down the corridor, along the cave's z, before the chamber is in view.
@export var at_z: float = -21.0
@export var line: String = "Wow... what is this place?"
## Or instead, how far out along W - for the far room, which you walk into along W (Ramon,
## 29 Sept: "when you enter the second cave, make him say, wow.. and I sense something").
@export var use_w: bool = false
@export var at_w: float = 25.0
## Where it is remembered as said: the parent's parent, under this name.
@export var said_meta: StringName = &"cave_first_look_said"
@export_range(0.5, 20.0, 0.5) var hold_seconds: float = 3.5

const SAID := &"cave_first_look_said"

var _box: Node
var _player: Node4D
var _showing := false
var _hold := -1.0


func _ready() -> void:
	_box = get_node_or_null(box_path)
	_player = get_node_or_null(player_path) as Node4D


func _busy() -> bool:
	for path in talker_paths:
		var talker: Node = get_node_or_null(path)
		if talker != null and talker.has_method("is_running") and bool(talker.call("is_running")):
			return true
	return false


func _exit_tree() -> void:
	if _showing and _box != null:
		_box.call("close")
	_showing = false
	_hold = -1.0


func _process(delta: float) -> void:
	if _box == null or _player == null:
		return
	if _showing:
		if _hold < 0.0 and not bool(_box.call("is_typing")):
			_hold = hold_seconds
		elif _hold >= 0.0:
			_hold -= delta
			if _hold <= 0.0:
				_showing = false
				_hold = -1.0
				_box.call("close")
		return
	var cave := get_parent() as Node4D
	var root: Node = cave.get_parent()
	if root == null or root.has_meta(said_meta):
		return
	var local: Vector4 = cave.global_basis.inverse() * (_player.global_position - cave.global_position)
	var there: bool = local.w > at_w if use_w else local.z < at_z
	if there and not _busy():
		root.set_meta(said_meta, true)
		_showing = true
		_box.call("say", String(_box.get("player_name")), line)
