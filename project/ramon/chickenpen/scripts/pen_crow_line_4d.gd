extends Node

## The one thought the player has out loud, when the crows kick off.
##
## WHY THE CROWS ARE WORTH A LINE. They are the only thing in the farm that happens TO you
## rather than because of you - the bed, the clucks and the stone all answer something you
## did, and the crows just arrive. A sound like that with nothing acknowledging it reads as
## an asset playing. One line turns it into somebody standing in a field noticing weather.
##
## THIS IS A BOX, NOT A CONVERSATION. DialogueBox4D draws and types; DialoguePlayer4D is
## the thing that captures input, freezes you and waits to be advanced. Using only the box
## means the line lands while you carry on walking, which is what a thought is. It is also
## why there is no reply: you are not talking to anybody.
##
## AND IT STAYS OUT OF THE WAY OF REAL TALK. If any conversation is running the crows go
## unremarked, rather than typing over the keeper mid-sentence.
##
## NOTHING ABOUT CROWS HAPPENS IN THE THEATRE. The farm is switched off in there - the
## crow clock does not run and pen_crossing_4d disables the whole of `Systems` - so the
## sound cannot start. The line could still be caught out by the crossing, though: it waits
## four seconds between the swell and the sentence, and a box that was already up would
## have hung frozen on the theatre wall while `Systems` slept. So this node runs THROUGH
## the crossing and watches it, cancels anything pending on the way in and takes the box
## down with it. A thought about weather, in a room with no weather and no outside, is the
## one place it would read as a bug rather than a character.

## Where the crows are announced from.
@export var sfx_path: NodePath = NodePath("../Sfx")
## The band it is typed into. Its own box, not a character's: the NPC boxes are anchored
## over a head, and this is nobody's head.
@export var box_path: NodePath = NodePath("../../UI/ThoughtBox")
## The way in and out of the theatre.
@export var crossing_path: NodePath = NodePath("../../Crossing")
## Anyone whose conversation this must not interrupt.
@export var talker_paths: Array[NodePath] = []

@export var line: String = "Damn. These crows sure are ominous."
## Far enough into the swell that the crows are the reason for the line rather than a
## coincidence. pen_sfx_4d fades them up over `crow_fade_seconds`, so this lands at or
## just after the top of it.
@export_range(0.0, 20.0, 0.1) var delay_seconds: float = 4.0
## How long it sits there once it has finished typing.
@export_range(0.5, 20.0, 0.5) var hold_seconds: float = 3.5
## Once a run, by default. The crows come round every minute or so and a thought you have
## had eleven times is a character with a tic, not a character reacting.
@export var once: bool = true

var _box: DialogueBox4D
var _talkers: Array[Node] = []
var _wait: float = -1.0
var _hold: float = -1.0
var _said: bool = false
## The line is up. NOT `_box.visible`, which stays true through the fade-out and would
## have this starting a fresh hold on a box it had just closed.
var _showing: bool = false
var _crossing: Node
var _inside: bool = false


func _ready() -> void:
	_box = get_node_or_null(box_path) as DialogueBox4D
	if _box == null:
		push_warning("PenCrowLine: no box at box_path - the crows will go unremarked.")
		return
	for path in talker_paths:
		var talker: Node = get_node_or_null(path)
		if talker != null:
			_talkers.append(talker)
	_crossing = get_node_or_null(crossing_path)
	var sfx: Node = get_node_or_null(sfx_path)
	if sfx == null or not sfx.has_signal("crows_rising"):
		push_warning("PenCrowLine: nothing announces the crows at sfx_path.")
		return
	sfx.connect("crows_rising", _on_crows_rising)


func _on_crows_rising() -> void:
	if _box == null or (once and _said):
		return
	# Start the clock rather than the line. Whether anybody is talking is a question for
	# four seconds from now, not for now.
	_wait = delay_seconds


func _busy() -> bool:
	for talker in _talkers:
		if talker.has_method("is_running") and bool(talker.call("is_running")):
			return true
	return false


func _process(delta: float) -> void:
	if _crossing != null:
		var away: bool = bool(_crossing.call("is_away"))
		if away != _inside:
			_inside = away
			if away:
				_wait = -1.0
				_hold = -1.0
				if _showing:
					_showing = false
					_box.close()
		if _inside:
			return
	if _wait >= 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_wait = -1.0
			if _busy():
				return
			_said = true
			_showing = true
			_box.say(_box.player_name, line)
	elif _hold >= 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_hold = -1.0
			_showing = false
			_box.close()
	elif _showing and not _box.is_typing():
		# The box does not close itself and there is no key to press, so the hold starts
		# when the typing stops rather than when the line was asked for - a longer line
		# gets read for as long as a short one.
		_hold = hold_seconds
