extends PenNpcTalk4D

## Wren's side of a conversation. PenNpcTalk4D owns the reach, the key, the prompt and the
## staging; this builds her script fresh from where the story is, and acts on what is
## agreed: she hands you the camera, and later puts you in the balloon.
##
## SHE NEVER TAKES F WHILE YOU ARE UP THE TOWER. Up there the player is parked at the
## ladder's foot - in her reach - and F means "climb down"; the station has it.
##
## THE BALLOON STARTS AFTER THE CONVERSATION CLOSES, not on the line that agrees to it, for
## the range master's reason: the camera, HUD and movement are handed back first.

const WrenScript := preload("res://ramon/chickenpen/lookout/wren_script.gd")

@export var facing_path: NodePath
@export var lookout_path: NodePath

var _facing: Node
var _lookout: Node
var _boarding := false


func _configure() -> void:
	_facing = get_node_or_null(facing_path)
	_lookout = get_node_or_null(lookout_path)
	_talk.use_script(WrenScript.nodes("", false), WrenScript.START_MEET)


func _can_talk() -> bool:
	if _lookout != null and (bool(_lookout.get("station").call("busy")) or bool(_lookout.call("story_busy"))):
		return false
	return super._can_talk()


func _before_begin() -> void:
	var story: Node = _lookout.get("story") if _lookout != null else null
	var tip: String = String(story.call("tip")) if story != null else "Keep looking."
	var can_ride: bool = story != null and bool(story.call("balloon_open"))
	_talk.use_script(WrenScript.nodes(tip, can_ride), _entry_node())


func _began() -> void:
	if _facing != null and _facing.has_method("face_now"):
		_facing.call("face_now")


func _entry_node() -> String:
	var story: Node = _lookout.get("story") if _lookout != null else null
	if story == null:
		return WrenScript.START_MEET
	return String(story.call("wren_opening"))


func _on_effect(effect_name: String) -> void:
	var story: Node = _lookout.get("story") if _lookout != null else null
	match effect_name:
		"give_camera":
			if story != null:
				story.call("on_camera_given")
		"board":
			_boarding = true


func _ended() -> void:
	var story: Node = _lookout.get("story") if _lookout != null else null
	if story != null:
		story.call("on_wren_spoken")
	if _boarding and story != null:
		_boarding = false
		story.call("board_balloon")


func _tag_text() -> String:
	return "%s  talk to Wren" % _catch_key()
