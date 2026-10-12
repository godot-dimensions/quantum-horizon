extends PenNpcTalk4D

const ProfessorScript := preload("res://ramon/chickenpen/scripts/professor_script.gd")

## The mining professor's side of a conversation.
##
## FORTY LINES, AS ADVERTISED. PenNpcTalk4D already owns who can be addressed, when, the
## key, the prompt over the head and freezing the player - so a third talkable character
## supplies only what makes them themselves: which script they speak from, which node they
## open on, and what to do while they are talking.
##
## HE OPENS ON WHAT YOU HAVE DONE, NOT ON A COUNTER. First meeting gets the introduction.
## After that, if the rock is still whole he assumes you have not started and says so; once
## you have dug he hands you the topic list, which is where the interesting answers are.
## The alternative - a flag counting visits - tells you what you have SEEN rather than what
## you have DONE, and gets it wrong the moment somebody talks to him twice before mining.

@export var rock_path: NodePath
@export var gold_path: NodePath
@export var facing_path: NodePath
@export var pickaxe_path: NodePath

var _rock: Node4D
var _gold: Node
var _facing: Node
var _met: bool = false
var _carved: bool = false


func _configure() -> void:
	_rock = get_node_or_null(rock_path) as Node4D
	_gold = get_node_or_null(gold_path)
	_facing = get_node_or_null(facing_path)
	_talk.use_script(ProfessorScript.NODES, ProfessorScript.START)
	var pick: Node = get_node_or_null(pickaxe_path)
	if pick != null and pick.has_signal("mined") and not pick.is_connected("mined", note_mined):
		pick.connect("mined", note_mined)


func _began() -> void:
	# He turns to whoever is addressing him, the way the keeper does.
	if _facing != null and _facing.has_method("face_now"):
		_facing.call("face_now")


func _entry_node() -> String:
	if not _met:
		_met = true
		return ProfessorScript.START
	# Has the rock been touched at all? Its collider count changes the moment it has.
	if not _has_been_mined():
		return "how_to_mine"
	return "menu"


## Whether anybody has taken a bite out of the rock yet.
##
## TOLD, NOT INSPECTED. The obvious test is the rock's collider count, and it does not
## work: a carve removes surface voxels and exposes exactly the ones behind them, so the
## count can come out identical on both sides of a hole - measured at 544 either way. The
## pickaxe already announces every blow, so this listens.
func _has_been_mined() -> bool:
	if _carved:
		return true
	return _gold != null and _gold.has_method("dug_out") and int(_gold.call("dug_out")) > 0


## Hooked to the pickaxe's `mined` signal by the scene.
func note_mined(_at: Vector4 = Vector4.ZERO, _radius: float = 0.0) -> void:
	_carved = true
