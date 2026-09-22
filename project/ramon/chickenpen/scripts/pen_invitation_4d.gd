extends Node

## Trym's invitation: the moment he stops answering questions about chickens and offers to
## show you something.
##
## IT HOOKS HIS CONVERSATION WITHOUT EDITING IT. DialoguePlayer4D emits `effect`, `started`
## and `ended`, so this listens rather than being written into his script - which matters
## because that script belongs to another pass of work that is still going on. Add
## `"do": "trym_invite"` to any node of his and the invitation fires exactly there; until
## somebody does, it fires on a random roll when a conversation with him finishes, which
## is the same beat one turn later.
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

enum Beat { WAITING, SPEAKING, WALKING, RAISING, BECKONING, LEAVING, OPEN }

@export var dialogue_path: NodePath
@export var trym_path: NodePath
@export var tag_path: NodePath
@export var arch_path: NodePath
@export var crossing_path: NodePath
@export var player_path: NodePath
## The marker his speech tag hangs from. It lives at the desk, so while he is walking it
## gets carried along behind his head - otherwise he talks from an empty stool.
@export var head_path: NodePath

@export_group("When")
## The effect that triggers it outright, for when his script has a line for it.
@export var effect_name: String = "trym_invite"
## Otherwise: the chance, per finished conversation, that he offers.
@export_range(0.0, 1.0, 0.05) var chance_per_talk: float = 0.5
## And a floor on it, so somebody who talks to him once still sees it eventually.
@export_range(1, 8, 1) var certain_after: int = 2

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
@export_range(0.5, 8.0, 0.5) var raise_seconds: float = 2.2
@export_range(0.5, 8.0, 0.5) var beckon_seconds: float = 3.4

const LINE := "Right - enough chickens. Want to see something cool? Follow me outside."
const AT_THE_DOOR := "Built this last week. Mind the threshold, it's deeper than it looks."
const BECKON := "Come on. It won't bite. Much."

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
var _talks: int = 0
var _offered: bool = false


func _ready() -> void:
	_dialogue = get_node_or_null(dialogue_path)
	_trym = get_node_or_null(trym_path) as Node4D
	_tag = get_node_or_null(tag_path)
	_arch = get_node_or_null(arch_path)
	_crossing = get_node_or_null(crossing_path)
	_player = get_node_or_null(player_path) as Node4D
	_head = get_node_or_null(head_path) as Node4D
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
		_offer()


func _on_ended() -> void:
	_talks += 1
	if _offered:
		return
	if _talks >= certain_after or randf() < chance_per_talk:
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
			_beat = Beat.BECKONING
			_timer = beckon_seconds
			_say(BECKON)
		Beat.BECKONING:
			if _timer > 0.0:
				return
			_beat = Beat.LEAVING
			_timer = 1.4
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
## He walked off through his own door; coming back and finding his stool empty for the
## rest of the run would cost the farm a character for the sake of continuity nobody asked
## for. He is simply at his desk again. What does NOT reset is the offer - it happens once
## - and the door stays standing, so going back is a walk rather than a second audition.
func rearm() -> void:
	if _beat != Beat.OPEN or _trym == null:
		return
	if _trym.has_method("return_to_desk"):
		_trym.call("return_to_desk")


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
