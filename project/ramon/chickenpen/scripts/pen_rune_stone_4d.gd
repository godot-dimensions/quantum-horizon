extends Node4D

## The rune stone at the range: the button to the Quantum Range (6 Oct 2026, PenLayout/
## PLAN_WATCHSTONE.md step 13; Ramon: "the block next to the table will give you a button
## activation to teleport to the shooting range").
##
## Stand by it and "F  To the range" comes up over it; F, and you are at the Quantum Range
## (Systems/RangeTrip, the same trip the range master's "yes" takes, with the pen parked as you
## left it). The stone itself, its runes and its glowing diamond are the yard's
## (pen_rune_range_4d.gd); this node stands where it is and owns only the reach, the prompt and
## the key.
##
## F IS EVERYBODY'S KEY: a chicken in reach or in your arms, or someone to talk to, wins over
## the stone (the same rule as the Lookout's old ladder), so the stone never takes the key from
## them.
##
## NO class_name (engine_gotchas.md).

@export var player_path: NodePath = NodePath("../../../Player")
@export var trip_path: NodePath = NodePath("../../../Systems/RangeTrip")
@export var catcher_path: NodePath = NodePath("../../../Player/Catcher")
## How near, across the ground and through W, before F works.
@export_range(0.5, 4.0, 0.1, "suffix:m") var reach: float = 1.7
@export_range(0.2, 3.0, 0.1, "suffix:m") var reach_w: float = 1.0
@export var prompt: String = "F  To the range"

var _player: Node4D
var _trip: Node
var _catcher: Node
var _tag: WorldTag4D
var _shown: String = ""


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_trip = get_node_or_null(trip_path)
	_catcher = get_node_or_null(catcher_path)
	if _player == null or _trip == null:
		push_warning("RuneStone: player or the range trip missing - the stone will never send you (fail visibly).")
	var anchor := Node4D.new()
	anchor.name = "Over"
	anchor.position = Vector4(0.0, 1.6, 0.0, 0.0)
	add_child(anchor)
	_tag = WorldTag4D.new()
	_tag.name = "Prompt"
	_tag.anchor_path = NodePath("..")
	var cam: Node = _player.get_node_or_null("CameraRig/Pitch/Camera4D") if _player != null else null
	if cam != null:
		_tag.camera_path = cam.get_path()
	_tag.lift = 8.0
	anchor.add_child(_tag)


## Whether F would send you now.
func can_press() -> bool:
	if _player == null or _trip == null or not is_visible_in_tree() or not _player.is_visible_in_tree():
		return false
	if _player.get("input_enabled") == false or bool(_trip.call("is_away")):
		return false
	var gap: Vector4 = global_position - _player.global_position
	if Vector2(gap.x, gap.z).length() > reach or absf(gap.w) > reach_w:
		return false
	if _catcher != null and (_catcher.get("carried") != null or _catcher.get("_candidate") != null):
		return false
	for talker in get_tree().get_nodes_in_group(&"npc_talk"):
		if not talker.is_inside_tree() or not talker.can_process():
			continue
		var talk: Node = talker.get("_talk")
		if talk != null and bool(talk.call("is_running")):
			return false
		if bool(talker.call("_can_talk")):
			return false
	return true


func _process(_delta: float) -> void:
	if _tag == null:
		return
	var text: String = prompt if can_press() else ""
	if text != _shown:
		_shown = text
		if text == "":
			_tag.clear()
		else:
			_tag.show_text(text)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"catch_target") and can_press():
		get_viewport().set_input_as_handled()
		_tag.clear()
		_shown = ""
		_trip.call("go")
