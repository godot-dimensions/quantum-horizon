extends PenNpcTalk4D

## The miner in the spacesuit, at the foot of the monolith.
##
## FORTY LINES, LIKE THE PROFESSOR. PenNpcTalk4D owns who can be addressed, when, the key,
## the prompt, freezing the player and staging the shot; this supplies his script, where he
## opens, and turning to face you. The scene he stands in is not the pen, but the talking
## is the pen's own - its player, its belt, its dialogue system - so nothing here needed to
## know that.
##
## HE OPENS ON WHAT YOU HAVE DONE. First meeting, the introduction. After that, once you
## have taken a piece out of the cube, a line that knows it before the topics.

const MinerScript := preload("res://ramon/chickenpen/cave/cave_miner_script.gd")

@export var facing_path: NodePath
@export var pickaxe_path: NodePath

var _facing: Node
var _met := false
var _struck := false
var _remarked := false


func _configure() -> void:
	_facing = get_node_or_null(facing_path)
	_talk.use_script(MinerScript.NODES, MinerScript.START)
	var pick: Node = get_node_or_null(pickaxe_path)
	if pick != null and pick.has_signal("mined") and not pick.is_connected("mined", _note_mined):
		pick.connect("mined", _note_mined)


func _began() -> void:
	if _facing != null and _facing.has_method("face_now"):
		_facing.call("face_now")


func _entry_node() -> String:
	if not _met:
		_met = true
		return MinerScript.START
	if _struck and not _remarked:
		_remarked = true
		return "greet_after_strike"
	return "menu"


func _note_mined(_at: Vector4 = Vector4.ZERO, _radius: float = 0.0) -> void:
	_struck = true
