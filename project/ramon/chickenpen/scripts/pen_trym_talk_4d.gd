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
var _owes_an_opinion: bool = false
var _shown_it: bool = false
## NOTHING HE SAYS IS SAID TWICE. The introduction happens once, the conversation after
## the showing happens once, and the third time you come to him he hands over the ticket
## and stops being a gate on the theatre. Before this, once the post-show conversation
## was spent, `_entry_node` fell through to greet_back - which returns to the original
## topic list, so talking to him a third time rewound the whole thing to the beginning.
var _heard_opinion: bool = false
var _gave_ticket: bool = false


func _configure() -> void:
	_figure = get_node_or_null(figure_path)
	_talk.use_script(TrymScript.NODES, TrymScript.START)


func _began() -> void:
	if _figure != null and _figure.has_method("stand_up"):
		_figure.call("stand_up")


func _ended() -> void:
	if _figure != null and _figure.has_method("sit_down"):
		_figure.call("sit_down")


## He asks again until you say yes. Declining an invitation should not delete it, and the
## alternative - a fifth entry on the hub - breaks this script's own rule about four.
func _on_effect(name: String) -> void:
	if name == "trym_invite":
		_shown_it = true


## Set by the invitation when the two of you come home from the theatre. The next thing
## he says is about the thing you just watched, once - after that he is back to chickens.
func ask_what_you_thought() -> void:
	_owes_an_opinion = true


func _entry_node() -> String:
	if _owes_an_opinion:
		_owes_an_opinion = false
		_heard_opinion = true
		return "what_did_you_think"
	if not _met:
		_met = true
		return TrymScript.START
	# He keeps offering until you accept. Declining should not delete the invitation.
	if not _shown_it:
		return "offer"
	if _catcher != null and _catcher.get("carried") != null:
		return "greet_carrying"
	if _heard_opinion and not _gave_ticket:
		_gave_ticket = true
		return "greet_ticket"
	if _gave_ticket:
		return "greet_after"
	return "greet_back"


func reset() -> void:
	_met = false
	_owes_an_opinion = false
	_shown_it = false
	_heard_opinion = false
	_gave_ticket = false
	if _talk != null:
		_talk.stop()
		_talk.reset()
	if _figure != null and _figure.has_method("sit_down"):
		_figure.call("sit_down")
	_set_player_moving(true)
