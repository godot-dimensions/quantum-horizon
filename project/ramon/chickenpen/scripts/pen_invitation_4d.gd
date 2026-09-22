extends Node

## Trym's invitation: the moment he stops answering questions about chickens and offers to
## show you something.
##
## IT COMES OUT OF THE CONVERSATION, not out of a timer. His script has a node that ends
## with `"do": "trym_invite"`, so the offer is something he says, in the first
## conversation, at the point he says it - an earlier version rolled dice when any talk
## with him finished and the result was a man who abruptly stood up and walked into a
## field for no stated reason.
##
## AND IT WAITS FOR THE END OF THE SENTENCE. The effect only arms it; the walk starts on
## `ended`, one beat later, because a character who gets up and leaves while his own
## dialogue box is still open is a bug that looks like rudeness.
##
## ONCE A RUN. An offer that repeats is not an offer, it is a machine, and the whole point
## is that it feels like he decided.
##
## HE WALKS, THE FURNITURE STAYS. His node is the desk, the stool, the laptop and the
## bookshelf; moving it would carry the whole office out onto the grass. So the walk goes
## through pen_trym_4d's own `walk_towards`, which offsets the FIGURE and leaves the room
## where it was built.
##
## THE ROUTE IS WAYPOINTS, NOT A DIRECTION. He is indoors. A straight line to the door is
## a straight line through a wall on the day somebody moves his desk, and a character who
## clips through his own shed undoes every other thing this scene does carefully.
##
## HE GOES FIRST, AND HE GOES AWAY FROM YOU. He stops on YOUR side of the door and puts it
## up behind himself, so when he turns and steps through it he is walking away through the
## field rather than past it - a man who walks alongside his own door and then stops
## existing is a bug, and reads as one. The question the player is left holding is "do I
## follow", which is a better question than "what is this". Nothing forces them through it
## and nothing hurries them.

enum Beat { WAITING, SPEAKING, WALKING, RAISING, CALLING, LEAVING, OPEN, HOME }

@export var dialogue_path: NodePath
@export var trym_path: NodePath
@export var tag_path: NodePath
@export var arch_path: NodePath
@export var crossing_path: NodePath
@export var player_path: NodePath
## His talk driver, so it knows to open with "what did you think" when you get home.
@export var driver_path: NodePath
## The marker the driver slides the player to for a conversation. It lives at the desk; it
## has to come with him, or talking to him by the door teleports you back into the shed.
@export var stand_marker_path: NodePath
## The marker his speech tag hangs from. It lives at the desk, so while he is walking it
## gets carried along behind his head - otherwise he talks from an empty stool.
@export var head_path: NodePath

@export_group("When")
## The node in his script that ends with `"do": "trym_invite"`.
@export var effect_name: String = "trym_invite"

@export_group("The walk")
## Where he goes, in WORLD space: out of the shed door, then clear of it, then to the spot
## he stops on - which is BETWEEN the player and where the door goes up.
@export var route: Array[Vector4] = [Vector4(-10.0, 0.0, -12.1, 0.0),
	Vector4(-9.4, 0.0, -8.0, 0.0), Vector4(-9.0, 0.0, -4.4, 0.0)]
## Where the arch goes up, also world space: a couple of paces BEHIND him, so he is facing
## you across it.
@export var door_at := Vector4(-9.0, 0.0, -6.6, 0.0)
@export_range(-180.0, 180.0, 5.0) var door_yaw_degrees: float = 0.0
## How far past it he gets before he is out of sight.
@export_range(0.5, 6.0, 0.1) var vanish_beyond: float = 2.0
@export_range(0.2, 6.0, 0.1) var walk_speed: float = 1.7
@export_range(0.5, 8.0, 0.5) var speak_seconds: float = 3.6
@export_range(0.5, 8.0, 0.5) var raise_seconds: float = 2.4
## How close you have to get before he goes through. He does NOT go on a timer: he asked
## you to follow him, so he waits until you have, however long that takes.
@export_range(1.0, 12.0, 0.5) var waits_until_within: float = 4.5

## Said as he comes out of the shed, not at the door - "follow me" is an instruction, and
## an instruction given after you have already arrived is a caption.
const LINE := "Follow me!"
const AT_THE_DOOR := "There. Built it last week."
const CALL := "Come on, stand with me. It's deeper than it looks."
const HOME_AGAIN := "Right. Back where we started."

var _dialogue: Node
var _trym: Node4D
var _tag: Node
var _arch: Node
var _crossing: Node
var _player: Node4D
var _head: Node4D
var _beat: Beat = Beat.WAITING
var _timer: float = 0.0
var _leg: int = 0
var _armed: bool = false
var _offered: bool = false
var _driver: Node
var _marker: Node4D
var _stood := Vector4.ZERO


func _ready() -> void:
	_dialogue = get_node_or_null(dialogue_path)
	_trym = get_node_or_null(trym_path) as Node4D
	_tag = get_node_or_null(tag_path)
	_arch = get_node_or_null(arch_path)
	_crossing = get_node_or_null(crossing_path)
	_player = get_node_or_null(player_path) as Node4D
	_head = get_node_or_null(head_path) as Node4D
	_driver = get_node_or_null(driver_path)
	_marker = get_node_or_null(stand_marker_path) as Node4D
	if _arch != null:
		_arch.set("armed", false)
		if _arch.has_signal("entered") and not _arch.is_connected("entered", _on_entered):
			_arch.connect("entered", _on_entered)
	if _dialogue == null:
		push_warning("PenInvitation: no dialogue to listen to, so Trym never offers.")
		return
	if not _dialogue.is_connected("effect", _on_effect):
		_dialogue.connect("effect", _on_effect)
	if not _dialogue.is_connected("ended", _on_ended):
		_dialogue.connect("ended", _on_ended)


func _on_effect(name: String) -> void:
	if name == effect_name:
		_armed = true


func _on_ended() -> void:
	if _armed:
		_offer()


## Public so a test - or a line of his script - can stage it on demand.
func offer() -> void:
	_offer()


func has_offered() -> bool:
	return _offered


func _offer() -> void:
	if _offered or _trym == null:
		return
	_offered = true
	_armed = false
	_beat = Beat.SPEAKING
	_timer = speak_seconds
	_leg = 0
	_say(LINE)
	if _trym.has_method("take_over"):
		_trym.call("take_over")
	if _trym.has_method("face_towards") and _player != null:
		_trym.call("face_towards", _player.global_position)


func _process(delta: float) -> void:
	if _beat == Beat.WAITING or _trym == null:
		return
	if _head != null and _trym.has_method("head_position"):
		_head.global_position = _trym.call("head_position")
	if _beat == Beat.OPEN:
		return
	if _beat == Beat.HOME:
		# Home again: he stands where the door was, turned to whoever he came back with,
		# and the one line over his head clears itself so it does not become scenery.
		if _trym.has_method("face_towards") and _player != null:
			_trym.call("face_towards", _player.global_position)
		_timer -= delta
		if _timer <= 0.0 and _timer > -1.0:
			_say("")
			_timer = -99.0
		return
	_timer -= delta
	match _beat:
		Beat.SPEAKING:
			# He finishes the sentence before he moves. The line is the invitation; walking
			# away mid-word would read as him leaving rather than asking.
			if _timer > 0.0:
				return
			_beat = Beat.WALKING
		Beat.WALKING:
			if _leg >= route.size():
				_raise()
				return
			var here: Vector4 = route[_leg]
			if _trym.call("walk_towards", here, walk_speed, delta):
				_leg += 1
			if _leg >= route.size():
				_raise()
		Beat.RAISING:
			# He stands still and lets it come up behind him. Walking while it grows would
			# put the best thing in the scene off to one side of the frame.
			if _trym.has_method("face_towards") and _player != null:
				_trym.call("face_towards", _player.global_position)
			if _timer > 0.0:
				return
			_beat = Beat.CALLING
			_say(CALL)
		Beat.CALLING:
			# He called you over, so he waits until you come. No timer: a man who invites
			# you somewhere and then leaves without you has not invited you anywhere.
			if _trym.has_method("face_towards") and _player != null:
				_trym.call("face_towards", _player.global_position)
			if _player == null:
				_beat = Beat.LEAVING
				return
			var reach: Vector4 = _player.global_position - _trym.call("head_position")
			if Vector2(reach.x, reach.z).length() > waits_until_within:
				return
			_say("")
			_beat = Beat.LEAVING
		Beat.LEAVING:
			# He turns, walks into his own door and is gone - away from the player, through
			# the field, not around it. Hidden rather than freed, because a freed Trym is
			# one his own conversation still holds a reference to, and the desk he was
			# sitting at is the same node.
			var away: Vector4 = Basis4D.from_zx(deg_to_rad(door_yaw_degrees)) * Vector4(0.0, 0.0, -vanish_beyond, 0.0)
			var beyond := Vector4(door_at.x, 0.0, door_at.z, 0.0) + away
			if not _trym.call("walk_towards", beyond, walk_speed, delta):
				return
			if _trym.has_method("set_figure_visible"):
				_trym.call("set_figure_visible", false)
			_say("")
			_beat = Beat.OPEN


func _raise() -> void:
	if _arch != null and _arch is Node4D:
		(_arch as Node4D).position = Vector4(door_at.x, 0.0, door_at.z, 0.0)
		(_arch as Node4D).basis = Basis4D.from_zx(deg_to_rad(door_yaw_degrees))
		_arch.set("armed", true)
	_say(AT_THE_DOOR)
	_beat = Beat.RAISING
	_timer = raise_seconds


## Called on the way home, by the crossing's sweep for anything that wants resetting.
##
## THE DOOR GOES. Disarming it folds it up into the air and takes it away, which is the
## right ending for a thing that was put up for one trip - a glowing arch left standing in
## a chicken field forever is set dressing nobody chose.
##
## AND HE IS STANDING RIGHT THERE, not back at his desk. You came out of that door
## together; finding him already seated forty metres away, as though none of it happened,
## throws away the whole beat. He stays where the door was, and the marker his talk driver
## slides the player to comes with him - otherwise saying hello teleports you into the
## shed he is not in.
func rearm() -> void:
	if _beat != Beat.OPEN or _trym == null:
		return
	_beat = Beat.HOME
	if _arch != null:
		_arch.set("armed", false)
	# Back on YOUR side of the door, a pace to one side of where the crossing puts you
	# down. He walked through it ahead of you; coming out behind you would be a third
	# thing happening that nobody saw.
	var spot := Vector4(door_at.x + 1.5, 0.0, door_at.z + 2.6, 0.0)
	if _trym.has_method("place_at"):
		_trym.call("place_at", spot)
	if _trym.has_method("set_figure_visible"):
		_trym.call("set_figure_visible", true)
	if _trym.has_method("face_towards") and _player != null:
		_trym.call("face_towards", _player.global_position)
	# From the TARGET, not from him. place_at only moves the offset the figure is drawn
	# at; his global position does not catch up until the next frame, and reading it here
	# puts the marker where he used to be.
	_stood = spot
	if _marker != null:
		# A pace to one side, so the conversation is side by side rather than nose to nose.
		_marker.global_position = Vector4(spot.x + 1.1, 0.0, spot.z + 0.9, 0.0)
	if _driver != null and _driver.has_method("ask_what_you_thought"):
		_driver.call("ask_what_you_thought")
	_say(HOME_AGAIN)
	_timer = 3.5


func _on_entered() -> void:
	if _crossing != null and _crossing.has_method("go"):
		_crossing.call("go")


func _say(text: String) -> void:
	if _tag == null:
		return
	if text == "":
		_tag.call("clear")
	else:
		_tag.call("show_text", text)
