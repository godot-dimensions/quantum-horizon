extends PenNpcTalk4D

## The Dream Shifter's side of a conversation (discovery/dream_shifter/dream_shifter_script.gd), as the balloon crew's
## (discovery/pen_balloon_crew_talk_4d.gd): PenNpcTalk4D owns the reach, F, the prompt and the staging. This gives the
## script, fills its question for the look you are in, keeps the crystal awake while it talks, and when the talk ends on
## "shift" or "explain" hands over to the look guide (discovery/dream_shifter/pen_look_guide_4d.gd), which shifts the
## world in front of you and then explains it. The world shifts after the box has gone, in your own camera.

const ShifterScript := preload("res://ramon/chickenpen/discovery/dream_shifter/dream_shifter_script.gd")
const Look := preload("res://ramon/chickenpen/look/pen_look_4d.gd")

@export var shifter_path: NodePath = ^"../../World/DreamShifter"
@export var guide_path: NodePath = ^"../LookGuide"

var _shifter: Node
var _guide: Node
var _due: String = ""
## The left-hand panel (made at run time, so not in hide_while_talking), put away while it talks.
var _panel_hidden: Control


func _configure() -> void:
	_shifter = get_node_or_null(shifter_path)
	_guide = get_node_or_null(guide_path)
	_talk.use_script(ShifterScript.NODES, ShifterScript.START, _fill)


func _fill(line: String, _returned: int, _total: int) -> String:
	var look: Node = Look.current
	var dev: bool = look != null and is_instance_valid(look) and bool(look.get("dev"))
	return line.replace("{question}", ShifterScript.question(dev))


func _entry_node() -> String:
	if _guide != null and bool(_guide.call("onboarded")):
		return "again"
	return ShifterScript.START


func _tag_text() -> String:
	return "%s  touch the orb" % _catch_key()


func _can_talk() -> bool:
	if _guide != null and bool(_guide.call("busy")):
		return false
	return super()


func _began() -> void:
	_due = ""
	if _shifter != null:
		_shifter.set("hold_awake", true)
	var panel := get_tree().root.find_child("GrassPanel", true, false) as Control
	if panel != null and panel.visible:
		panel.visible = false
		_panel_hidden = panel


func _on_effect(effect_name: String) -> void:
	if effect_name in ["shift", "explain"]:
		_due = effect_name


func _ended() -> void:
	if _panel_hidden != null and is_instance_valid(_panel_hidden):
		_panel_hidden.visible = true
	_panel_hidden = null
	if _shifter != null:
		_shifter.set("hold_awake", false)
	var due: String = _due
	_due = ""
	if due == "" or _guide == null:
		return
	if due == "shift":
		_guide.call("shift_from", _shifter)
	else:
		_guide.call("explain", false)


## Ctrl+R: a new visitor.
func reset() -> void:
	_due = ""
