extends PenNpcTalk4D

## Nike's half of the conversation.
##
## HE IS AN OUTDOOR CHARACTER, so none of the interior staging applies: no stand marker,
## no camera mark, no cutaway. He is talked to where he lies, which is the point of him.
##
## HE ALSO STOPS TALKING WHILE HE IS BEING CARRIED, in the sense that the grab node takes
## the key first at close range - see its header. What this handles is the three states he
## can be found in, because what he says about the pen only makes sense before he is in it.

@export var grab_path: NodePath
## His behaviour, so it can be kept on a short leash while the conversation is open. He is
## deliberately NOT stopped - walking off mid-sentence is half his character - only kept
## within reach.
@export var antics_path: NodePath
## Where the pen is, and how close counts as being in it. He is in the pen when somebody
## has put him there, and there is nothing else in the scene that knows that.
@export var pen_path: NodePath
@export_range(1.0, 20.0, 0.5) var pen_radius: float = 6.0

const _Script = preload("res://ramon/dialogue/nike_script.gd")

var _grab: Node
var _antics: Node
var _pen: Node4D
var _met: bool = false


func _configure() -> void:
	_grab = get_node_or_null(grab_path)
	_antics = get_node_or_null(antics_path)
	_pen = get_node_or_null(pen_path) as Node4D
	# PRELOADED rather than referenced by class_name: a class_name is only a global
	# identifier once the editor has scanned the project, so a freshly added script fails
	# outright from a headless run.
	_talk.use_script(_Script.NODES, _Script.START)


func _began() -> void:
	_leash(true)


func _ended() -> void:
	_leash(false)


func _leash(on: bool) -> void:
	if _antics != null and _antics.has_method("leash"):
		_antics.call("leash", on)


## NO TALKING WHILE HE IS OFF THE GROUND. He has a key of his own now, so the two no
## longer compete - but holding a conversation with an animal in your arms put his panel,
## his prompt and the carry prompt on screen at once and read as clutter rather than as a
## joke. This is narrower than the override it replaces: that one refused whenever the
## grab COULD claim the key, which also stopped him being talked to from arm's length.
func _can_talk() -> bool:
	if _grab != null and bool(_grab.get("holding")):
		return false
	return super()


## His script announces this on the line where he invites being carried, and the carry
## key does nothing until it arrives.
func _on_effect(effect_name: String) -> void:
	if effect_name == "wants_carrying" and _grab != null and _grab.has_method("unlock"):
		_grab.call("unlock")


func _entry_node() -> String:
	if _in_pen():
		return "greet_in_pen"
	if not _met:
		_met = true
		return _Script.START
	return "greet_back"


## Being in the pen is measured on the ground only. He has no business being off-slice
## from the pen and it would only make the test fail for a reason the player cannot see.
func _in_pen() -> bool:
	if _pen == null:
		return false
	var anchor: Node4D = _anchor()
	if anchor == null:
		return false
	var gap: Vector4 = anchor.global_position - _pen.global_position
	return Vector2(gap.x, gap.z).length() <= pen_radius


func _tag_text() -> String:
	return "%s talk to Nike" % _catch_key()


func reset() -> void:
	_met = false
	if _talk != null:
		_talk.stop()
		_talk.reset()
	_set_player_moving(true)
