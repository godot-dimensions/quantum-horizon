extends PenNpcTalk4D

## Trym's half of the conversation. He stands up to talk and sits back down afterwards.
##
## pen_trym_4d.gd was written expecting this: its header says the get-up is exposed and
## not owned, `stand_up()` and `sit_down()` are public, and it watches the talk key
## without consuming it precisely so a conversation could land on him later and drive the
## same animation. Nothing in that file changed to wire this up.

@export var figure_path: NodePath

var _figure: Node
var _met: bool = false


func _configure() -> void:
	_figure = get_node_or_null(figure_path)
	_talk.use_script(TrymScript.NODES, TrymScript.START)


func _began() -> void:
	if _figure != null and _figure.has_method("stand_up"):
		_figure.call("stand_up")


func _ended() -> void:
	if _figure != null and _figure.has_method("sit_down"):
		_figure.call("sit_down")


func _entry_node() -> String:
	if not _met:
		_met = true
		return TrymScript.START
	if _catcher != null and _catcher.get("carried") != null:
		return "greet_carrying"
	return "greet_back"


func reset() -> void:
	_met = false
	if _talk != null:
		_talk.stop()
		_talk.reset()
	if _figure != null and _figure.has_method("sit_down"):
		_figure.call("sit_down")
	_set_player_moving(true)
