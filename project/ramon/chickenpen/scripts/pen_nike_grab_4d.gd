extends Node

## Picking Nike up, carrying him, and throwing him into the pen - where he carries on
## walking as though it had been his idea, which according to him it was.
##
## HE IS NOT A CAT AND NOT A CHICKEN. The cat's grab exists because a caught cat does not
## stay caught; the catcher's contract is that a caught bird does. Nike is a third thing
## again: he stays caught indefinitely, he is not part of the twelve-bird loop, and he has
## a whole behaviour tree of his own that has to be put to sleep while he is off the
## ground. So he gets his own node rather than being bent into either of the others.
##
## HE HAS HIS OWN KEY, AND THAT IS THE WHOLE FIX. F was the catch key, the throw key and
## the talk key already, and sharing it with the pig went wrong in a way no arbitration
## really solved. Measured directly, with two sibling nodes on one action
## (_diagnose_input_order_runner.gd):
##
##   * _input propagates in REVERSE tree order - the node declared SECOND ran first. So
##     "declare the grab before the driver and it wins" was backwards.
##   * set_input_as_handled() did not stop the other sibling. It stops an event reaching
##     _unhandled_input and the GUI, which is what keeps the chicken catcher out of this,
##     but every _input in the tree still runs.
##
## One press therefore both lifted him and opened a conversation with him. Arbitrating it
## worked, and cost the player the ability to talk to him while standing next to him,
## which is where you would naturally talk to him. G instead: F talks, G lifts and puts
## down, and neither needs to know about the other.
##
## Talking IS still suppressed while he is off the ground, but by choice rather than by
## collision: his panel, his prompt and the carry prompt all on screen at once read as
## clutter. The player's own line on picking him up stays - that is the shared player tag
## the cat grab uses, not the dialogue system, and it is one line that then goes away.
##
## AND IT ONLY WORKS ONCE HE HAS ASKED. The key does nothing until the conversation
## reaches the line where he invites it - "if somebody were to pick me up, I wouldn't
## struggle". Picking up a stranger's pig unprompted is not a mechanic the player has any
## reason to try, and gating it means the prompt appears exactly when the reason does.
##
## HIS BEHAVIOUR IS SUSPENDED, NOT DISABLED. Setting `suspended` on the antics halts the
## gait clock rather than resetting it, and leaves the node processing, so when he lands he
## resumes mid-stride from whatever state he was in instead of snapping to the start of a
## walk cycle. Disabling the node outright also froze the walker's own skinning, which
## left him in whatever pose he happened to be in when lifted.

@export var nike_path: NodePath
@export var antics_path: NodePath
@export var walker_path: NodePath
@export var player_path: NodePath
@export var catcher_path: NodePath
@export var anchor_path: NodePath
@export var gait_path: NodePath
@export var slice_frame_path: NodePath
@export var tag_path: NodePath
## A world-space prompt of its own, floating over him, rather than a row on the control
## card. The card is already eleven lines long and this action only exists some of the
## time - a prompt that appears on the animal it applies to, when it applies, says more
## and costs the card nothing.
@export var prompt_tag_path: NodePath
## Anything else that can have its hands full - the two cat grabs. He cannot be picked up
## while one of those is holding, and the chicken catcher is checked separately because it
## reports through a different property.
@export var busy_paths: Array[NodePath] = []

@export_group("Grabbing")
## Wider than the cat's 1.5: he is a big animal and you have to be able to get hold of
## him without standing inside him.
@export_range(0.5, 5.0, 0.1) var reach: float = 2.3
@export_range(0.05, 1.5, 0.05) var slice_tolerance: float = 0.6
## How much of a load he is, 0 to 1, handed to the gait. He is all of it.
@export_range(0.0, 1.0, 0.05) var load: float = 1.0
## A THOUGHT, NOT AN INSTRUCTION, the same as the cat's line. He has already asked to be
## carried in conversation, so this is the character agreeing rather than a tutorial.
@export var carry_line: String = "He is heavier than he looks, and he looks heavy."
## What the floating prompt says, before and while carrying.
@export var prompt_text: String = "pick up Nike"
@export var holding_prompt_text: String = "put Nike down"

## Where he sits relative to the carry anchor. The anchor was placed for a chicken, which
## is small enough to go straight overhead; a pig this size wants to come down into the
## hands rather than float above them.
@export var carry_offset: Vector4 = Vector4(0.0, -0.36, 0.06, 0.0)
## Turned across the body while carried. A pig held nose-forward reads as a battering ram
## and buries his head in the back of the player's own avatar; across the chest is how you
## would actually carry something with a head at one end.
@export_range(-180.0, 180.0, 5.0, "suffix:°") var carry_yaw_degrees: float = 90.0

@export_group("Throwing")
## Gentler than the cat's throw. He is four hundred pounds of contentment; he does not
## sail, he is set down a short way in front of you.
@export_range(0.5, 12.0, 0.5) var throw_distance: float = 3.4

## Whether he has invited it yet. Set from his conversation, through the talk driver, when
## the script announces `wants_carrying`. Exported so the scene can start it unlocked for
## testing without having to sit through the conversation.
@export var unlocked: bool = false

var holding: bool = false

var _nike: Node4D
var _antics: Node
var _walker: Node
var _player: Node4D
var _catcher: Node
var _anchor: Node4D
var _gait: Node
var _frame: Node4D
var _tag: Node
var _prompt: Node
## His own basis, kept across the carry. It holds the instance's SCALE as well as his
## heading, so the carry rotation is composed onto it rather than replacing it - writing a
## bare rotation would drop him back to the size he is authored at.
var _rest_basis: Projection = Projection.IDENTITY
## The height he was standing at when lifted, so he can be put back down at it. Taking
## his CURRENT y at that moment is what left him hanging in the air: by then the carry has
## already moved him up to the anchor, so "keep his own y" kept the carried one.
var _ground_y: float = 0.0
## Which frame this node last acted on. One press must not be able to reach both branches
## of _input - grab and then immediately put down - which is what a double dispatch of the
## same action does, and it reads exactly like the pick-up and the throw fighting.
var _acted_frame: int = -1
var _busy: Array[Node] = []


func _ready() -> void:
	_nike = get_node_or_null(nike_path) as Node4D
	_antics = get_node_or_null(antics_path)
	_walker = get_node_or_null(walker_path)
	_player = get_node_or_null(player_path) as Node4D
	_catcher = get_node_or_null(catcher_path)
	_anchor = get_node_or_null(anchor_path) as Node4D
	_gait = get_node_or_null(gait_path)
	_frame = get_node_or_null(slice_frame_path) as Node4D
	_tag = get_node_or_null(tag_path)
	_prompt = get_node_or_null(prompt_tag_path)
	for path in busy_paths:
		var other: Node = get_node_or_null(path)
		if other != null:
			_busy.append(other)
	if _nike == null or _player == null or _anchor == null:
		push_warning("%s: pig, player or carry anchor missing - Nike cannot be picked up." % name)


## Called when his script announces that he has asked to be carried.
func unlock() -> void:
	unlocked = true


## The key to print in his prompt, read from the InputMap rather than hard-coded - a
## printed key stops being true the moment somebody rebinds it.
func carry_key() -> String:
	if not InputMap.has_action(&"carry_pig"):
		return "?"
	for event in InputMap.action_get_events(&"carry_pig"):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "?"


## Whether the prompt should be offered: he has asked, and he is within reach.
func can_offer() -> bool:
	return unlocked and not holding and _can_grab()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"carry_pig"):
		return
	if Engine.get_process_frames() == _acted_frame:
		return
	if holding:
		_acted_frame = Engine.get_process_frames()
		_put_down()
		get_viewport().set_input_as_handled()
		return
	if not _can_grab():
		return
	_acted_frame = Engine.get_process_frames()
	_grab()
	get_viewport().set_input_as_handled()


## In reach, on your slice, and your hands are empty. The chicken check is what keeps this
## from stealing the key in the middle of the actual game.
func _can_grab() -> bool:
	if not unlocked:
		return false
	if _nike == null or _player == null:
		return false
	if _catcher != null and _catcher.get("carried") != null:
		return false
	for other in _busy:
		if is_instance_valid(other) and bool(other.get("holding")):
			return false
	var slice: Projection = _frame.global_basis if _frame != null else _player.global_basis
	var gap: Vector4 = _nike.global_position - _player.global_position
	if absf(gap.dot(slice.w)) > slice_tolerance:
		return false
	return Vector2(gap.dot(slice.x), gap.dot(slice.z)).length() <= reach \
		and absf(gap.dot(slice.y)) <= 2.5


func _grab() -> void:
	holding = true
	_rest_basis = _nike.basis
	_ground_y = _nike.position.y
	if _antics != null:
		_antics.set("suspended", true)
	if _walker != null:
		_walker.set("halted", true)
	_tell_gait(true)
	_say(carry_line)


func _process(_delta: float) -> void:
	_update_prompt()
	if not holding or _nike == null or _anchor == null:
		return
	# Written as a LOCAL position. Assigning global_position on a Node4D goes through the
	# parent's transform and silently does nothing useful - a trap this project has fallen
	# into more than once, most expensively with a camera that ended up nineteen metres
	# from where it was told to stand.
	var host: Node4D = _nike.get_parent() as Node4D
	var origin: Vector4 = host.global_position if host != null else Vector4.ZERO
	_nike.position = _anchor.global_position - origin + carry_offset
	_nike.basis = Basis4D.from_zx(deg_to_rad(carry_yaw_degrees)) * _rest_basis


## Offered over his head while it is worth offering, and it stays up while carrying so the
## player knows which key puts him down again.
func _update_prompt() -> void:
	if _prompt == null:
		return
	if holding:
		_prompt.call("show_text", "%s  %s" % [carry_key(), holding_prompt_text])
	elif can_offer():
		_prompt.call("show_text", "%s  %s" % [carry_key(), prompt_text])
	else:
		_prompt.call("clear")


## Set down ahead of you, facing the way you were, and back to his own devices.
func _put_down() -> void:
	holding = false
	_tell_gait(false)
	var facing: Node4D = _player.get_node_or_null("Avatar") as Node4D
	var frame: Projection = facing.global_basis if facing != null else _player.global_basis
	var forward: Vector4 = (frame * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
	var host: Node4D = _nike.get_parent() as Node4D
	var origin: Vector4 = host.global_position if host != null else Vector4.ZERO
	var landing: Vector4 = _player.global_position + forward * throw_distance
	# The height he was STANDING at, not the one he is currently at - he is up at the
	# carry anchor by now, and reusing that left him floating where the player's hands had
	# been. Not the player's y either: the player may be mid-step or mid-jump.
	_nike.position = Vector4(landing.x - origin.x, _ground_y,
		landing.z - origin.z, landing.w - origin.w)
	# He carries on from where he is put, so this becomes the middle of his new patch -
	# otherwise he would immediately set off back to the field he was lifted out of.
	if _antics != null:
		_antics.set("suspended", false)
		_antics.set("_home", _nike.position)
	# Put back the way he was, which also restores the scale the carry rotation was
	# composed onto. His behaviour only rewrites this basis while he is stopped, so
	# without it he would walk off sideways until his next pause.
	_nike.basis = _rest_basis
	if _walker != null:
		_walker.set("halted", false)
	_say("")


func _tell_gait(carrying: bool) -> void:
	if _gait != null and _gait.has_method("set_carrying"):
		_gait.call("set_carrying", carrying, load if carrying else 0.0)


func _say(text: String, seconds: float = 2.4) -> void:
	if _tag == null:
		return
	if text == "":
		_tag.call("clear")
		return
	_tag.call("show_text", text)
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
		if _tag != null and holding:
			_tag.call("clear")
