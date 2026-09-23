extends PenNpcTalk4D

## Trym's half of the conversation. He stands up to talk and sits back down afterwards.
##
## pen_trym_4d.gd was written expecting this: its header says the get-up is exposed and
## not owned, `stand_up()` and `sit_down()` are public, and it watches the talk key
## without consuming it precisely so a conversation could land on him later and drive the
## same animation. Nothing in that file changed to wire this up.

@export var figure_path: NodePath
## The errand. F is not offered on him for the whole of it - see _can_talk.
@export var invitation_path: NodePath = NodePath("../../Invitation")

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


## He has shown you the thing, however you got there.
##
## Normally this is set by his own dialogue: the `show_you` node ends with
## `"do": "trym_invite"` and _on_effect below picks it up. The C shortcut never runs that
## conversation - it stages the trip and drops you in the cinema - so nothing set it, and
## `_entry_node` fell through to `offer` for the rest of the run. You came home, told him
## what you thought, and then he asked whether you would like to see it, forever. No
## ticket, and the opening conversation apparently starting over.
func mark_shown() -> void:
	# MET, TOO. You cannot have walked the invitation without having talked to him - he
	# offers it halfway through the first conversation. Leaving `_met` false meant the
	# second thing he said after the cinema was his own introduction: you came home, gave
	# him your opinion of the presentation, and then he said hello and explained that his
	# legs had developed opinions. Which is only reachable by pressing C without ever
	# having spoken to him, and C is how this gets played.
	_met = true
	_shown_it = true


## Set by the invitation when the two of you come home from the theatre. The next thing
## he says is about the thing you just watched, once - after that he is back to chickens.
func ask_what_you_thought() -> void:
	# ONCE. Every homecoming calls this, and going back a second time is easy - the C key
	# is two presses and the ticket is one. Without the guard each trip put the opinion
	# conversation back at the front of the queue, so you were asked what you thought of
	# it over and over and never got as far as the ticket.
	#
	# He asks because he has not heard your answer, not because you were just in the room.
	if _heard_opinion:
		return
	_owes_an_opinion = true


## NOT WHILE HE IS TAKING YOU SOMEWHERE. From "let me show you" until the two of you are
## back on the farm, F is simply not offered on him.
##
## Talking stages a shot and slides the player onto `stand_marker_path` - a fixed node
## beside his desk - so pressing F while he was out in the field dragged you back into the
## shed and left him walking away from you. Making it work properly would mean pausing his
## walk, re-siting the marker on him every frame and giving him something to say mid-
## errand; letting the prompt go dark for the eight seconds he is on the move is what
## Ramon asked for and is the honest version - he is busy.
func _can_talk() -> bool:
	var invite: Node = get_node_or_null(invitation_path)
	if invite != null and invite.has_method("is_leading") and bool(invite.call("is_leading")):
		return false
	# Belt and braces: any other walk of his - there is only the homecoming, and he is
	# placed rather than walked for that now, but a future one should not need to know
	# about this rule.
	if _figure != null and _figure.has_method("is_walking") and bool(_figure.call("is_walking")):
		return false
	return super()


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
