extends PenNpcTalk4D

## The range master's side of a conversation. PenNpcTalk4D owns the reach, the key, the
## prompt and staging; this supplies his script and what "yes" means: once the
## conversation has closed, the trip to the gallery starts.
##
## AFTER IT CLOSES, NOT WHEN IT IS AGREED. The yes is an effect on a line, and swapping the
## whole scene out from under a dialogue that is still being torn down leaves its box and
## the player's frozen movement for the pen to wake up to. So the effect only notes the
## answer, and _ended - which runs after the camera, the HUD and the player's movement have
## all been handed back - is where it goes.

const RangeScript := preload("res://ramon/chickenpen/scripts/range_master_script.gd")

@export var facing_path: NodePath
@export var trip_path: NodePath

var _facing: Node
var _trip: Node
var _met := false
var _going := false


func _configure() -> void:
	_facing = get_node_or_null(facing_path)
	_trip = get_node_or_null(trip_path)
	_talk.use_script(RangeScript.NODES, RangeScript.START)


func _began() -> void:
	if _facing != null and _facing.has_method("face_now"):
		_facing.call("face_now")


func _entry_node() -> String:
	if not _met:
		_met = true
		return RangeScript.START
	return "greet_again"


func _on_effect(effect_name: String) -> void:
	if effect_name == "go_range":
		_going = true


func _ended() -> void:
	if _going and _trip != null and _trip.has_method("go"):
		_going = false
		_trip.call("go")
