extends Node

## THE MEADOW THOUGHT (Systems/MeadowThought; 10 Oct 2026, Ramon's walkthrough item 24: "The campsite contains a large,
## relatively empty meadow ... when the player reaches the campsite or looks toward the meadow, we could introduce a
## brief observation. Something like: 'That's a beautiful stretch of grassland... I wonder what's out there?' ... a
## short line of player dialogue ... I don't want a lengthy cinematic").
##
## Once a session: standing near the research camp (any W: the camp is 2.5 m kata, its road slants down to it) and
## looking out east over the meadow (the camera's forward within [member within_degrees] of [member toward]), you
## think it, in the player's own thought box (UI/ThoughtBox, as the crows' line), for a few seconds. Out there are the
## edge-on door and the strange clock. Not while anyone is talking. NO class_name (engine_gotchas.md).

@export var player_path: NodePath = ^"../../Player"
@export var camp_path: NodePath = ^"../../World/EggCamp"
@export var box_path: NodePath = ^"../../UI/ThoughtBox"
## The meadow's direction from the camp (east), and how close to it the view must point.
@export var toward: Vector2 = Vector2(1.0, 0.25)
@export_range(5.0, 90.0, 1.0) var within_degrees: float = 35.0
@export_range(3.0, 30.0, 0.5) var near_m: float = 14.0
@export var line: String = "That's a beautiful stretch of grassland. I wonder what's out there?"
@export_range(1.0, 10.0, 0.5) var hold_seconds: float = 4.0

static var said: bool = false

var _player: Node4D
var _camp: Node4D
var _box: DialogueBox4D
var _showing: bool = false
var _hold: float = -1.0
var _looked: float = 0.0


func _ready() -> void:
	add_to_group(&"discovery_reset")
	_player = get_node_or_null(player_path) as Node4D
	_camp = get_node_or_null(camp_path) as Node4D
	_box = get_node_or_null(box_path) as DialogueBox4D


func _busy() -> bool:
	for talk in get_tree().get_nodes_in_group(&"npc_talk"):
		var player: Variant = talk.get("_talk")
		if player is Node and is_instance_valid(player) and bool((player as Node).call("is_running")):
			return true
	return _player.get("input_enabled") == false


func _process(delta: float) -> void:
	if _box == null or _player == null or _camp == null:
		return
	if _showing:
		if _hold >= 0.0:
			_hold -= delta
			if _hold <= 0.0:
				_showing = false
				_hold = -1.0
				_box.close()
		elif not _box.is_typing():
			_hold = hold_seconds
		return
	if said or _busy():
		return
	var gap: Vector4 = _player.global_position - _camp.global_position
	if Vector2(gap.x, gap.z).length() > near_m:
		_looked = 0.0
		return
	# Where the view points, on the ground: the player's camera's forward (-z).
	var fwd := Vector2.ZERO
	var cam4 := _player.find_child("Camera4D", true, false) as Node4D
	if cam4 != null:
		var f: Vector4 = -cam4.global_basis.z
		fwd = Vector2(f.x, f.z)
	if fwd.length() < 0.1:
		return
	if rad_to_deg(absf(fwd.angle_to(toward))) <= within_degrees:
		_looked += delta
		if _looked >= 0.8:
			said = true
			_showing = true
			_box.say(_box.player_name, line)
	else:
		_looked = 0.0


## Ctrl+R: thought again by the next visitor.
func reset() -> void:
	said = false
	_looked = 0.0
