extends PenNpcTalk4D

## The camp guide's side of a conversation (pen_camp_guide_4d.gd, camp_guide_script.gd). PenNpcTalk4D owns the
## reach, the key, the prompt and the staging; this gives his script, turns him to you, and says it shorter the
## second time.

const GuideScript := preload("res://ramon/chickenpen/scripts/camp_guide_script.gd")

@export var facing_path: NodePath

var _facing: Node
var _met := false


func _configure() -> void:
	_facing = get_node_or_null(facing_path)
	_talk.use_script(GuideScript.NODES, GuideScript.START)


func _began() -> void:
	if _facing != null and _facing.has_method("face_now"):
		_facing.call("face_now")


func _entry_node() -> String:
	if not _met:
		_met = true
		return GuideScript.START
	return "greet_again"
