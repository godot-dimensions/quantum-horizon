extends Node

## Picking the cat up, and the three seconds you have before it objects.
##
## THE CAT IS NOT A CHICKEN, deliberately. It would have been less code to register it with
## the chicken manager and let the existing catcher handle it, and it would have been
## wrong: the catcher's whole contract is that a caught bird stays caught until you put it
## somewhere, and the entire point of the cat is that it does not. Keeping it separate also
## means the chicken loop - twelve birds, a counter, a pen - cannot be broken by an animal
## that is not part of it.
##
## IT SHARES THE CATCH KEY AND YIELDS TO THE CHICKENS. This listens in _input, which runs
## before the catcher's _unhandled_input, and takes the key ONLY when the cat is the
## unambiguous target: in reach, on your slice, and no chicken already in your hands. Every
## other press falls through untouched. That is the same rule pen_talk_4d uses for talking,
## and the reason the control card does not need a fourth line.
##
## THREE SECONDS IS THE WHOLE MECHANIC. Long enough to turn and throw if you already knew
## where the pen was, short enough that you cannot wander over and think about it. Running
## out is not a failure state with a penalty screen - you sit down, it goes, and you can go
## and get it again.

@export var cat_path: NodePath
@export var player_path: NodePath
@export var catcher_path: NodePath
@export var anchor_path: NodePath
@export var slice_frame_path: NodePath
## Picked up, and had enough of being picked up. Announced rather than acted on, the way
## the chicken catcher announces a catch: sound and anything else that wants to know is
## then somebody else's file, and this one stays about the cat.
signal grabbed
signal scratched

@export var tag_path: NodePath

@export_group("Grabbing")
@export_range(0.5, 4.0, 0.1) var reach: float = 1.5
@export_range(0.05, 1.0, 0.05) var slice_tolerance: float = 0.4
## How long it tolerates being held.
@export_range(0.5, 15.0, 0.5) var patience: float = 3.0
## And how long you spend on the ground afterwards.
@export_range(0.5, 8.0, 0.5) var knocked_down_seconds: float = 2.2
## Whether this one objects to being carried. The black one does and always has; a
## friendlier animal can be carried about indefinitely and simply gets put down.
@export var scratches: bool = true
@export var scratch_line: String = "It scratched me, damn.."
## A THOUGHT, NOT AN INSTRUCTION. "Throw it in the pen!" is the game telling you what
## to do next. Phrased as an urge the character is having, the same words become a
## joke about the player, and it stops reading as a tutorial prompt.
@export var carry_line: String = "I feel an urge to throw the cat in the pen.."

@export_group("Throwing")
@export_range(0.5, 12.0, 0.5) var throw_speed: float = 5.0
@export_range(0.5, 12.0, 0.5) var throw_rise: float = 2.4

var holding: bool = false

var _cat: Node4D
var _player: Node4D
var _catcher: Node
var _anchor: Node4D
var _frame: Node4D
var _tag: Node
var _left: float = 0.0


func _ready() -> void:
	_cat = get_node_or_null(cat_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	_catcher = get_node_or_null(catcher_path)
	_anchor = get_node_or_null(anchor_path) as Node4D
	_frame = get_node_or_null(slice_frame_path) as Node4D
	_tag = get_node_or_null(tag_path)
	if _cat == null or _player == null or _anchor == null:
		push_warning("PenCatGrab: cat, player or carry anchor missing - the cat cannot be picked up (item 82).")


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"catch_target"):
		return
	if holding:
		_throw()
		get_viewport().set_input_as_handled()
		return
	if not _can_grab():
		return
	_grab()
	get_viewport().set_input_as_handled()


## In reach, on your slice, and your hands are empty. The chicken check is what keeps this
## from stealing the key in the middle of the actual game.
func _can_grab() -> bool:
	if _cat == null or _player == null:
		return false
	if _catcher != null and _catcher.get("carried") != null:
		return false
	# THE CAT DECIDES. This used to test its mood against a handful of literal numbers,
	# which is fine until somebody adds a mood in the middle of the enum and every number
	# below it quietly means something else. It answers for itself now.
	if not bool(_cat.call("can_be_picked_up")):
		return false
	var slice: Projection = _frame.global_basis if _frame != null else _player.global_basis
	var gap: Vector4 = _cat.global_position - _player.global_position
	if absf(gap.dot(slice.w)) > slice_tolerance:
		return false
	return Vector2(gap.dot(slice.x), gap.dot(slice.z)).length() <= reach \
		and absf(gap.dot(slice.y)) <= 2.0


func _grab() -> void:
	holding = true
	_left = patience
	_cat.call("grab")
	_say(carry_line)
	emit_signal("grabbed")


func _process(delta: float) -> void:
	if not holding or _cat == null:
		return
	if not scratches:
		# A friendly one is simply carried. It still has to be put somewhere, which is
		# what the throw is for.
		var host_calm: Node4D = _cat.get_parent() as Node4D
		_cat.position = _anchor.global_position \
			- (host_calm.global_position if host_calm != null else Vector4.ZERO)
		return
	# Held overhead, written as a LOCAL position: assigning global_position on a Node4D
	# goes through the parent's transform and silently does nothing, which is a trap this
	# project has already fallen into twice.
	var host: Node4D = _cat.get_parent() as Node4D
	var origin: Vector4 = host.global_position if host != null else Vector4.ZERO
	_cat.position = _anchor.global_position - origin
	_left -= delta
	if _left <= 0.0:
		_scratch()


## Out of time. It goes, you sit down, and the screen says why.
func _scratch() -> void:
	emit_signal("scratched")
	holding = false
	_cat.call("drop_and_flee")
	_say(scratch_line, knocked_down_seconds)
	if _player != null and _player.has_method("knock_down"):
		_player.call("knock_down", knocked_down_seconds)


## In time. It arcs where you were facing and then makes its own way to the coop.
func _throw() -> void:
	holding = false
	var facing: Node4D = _player.get_node_or_null("Avatar") as Node4D
	var frame: Projection = facing.global_basis if facing != null else _player.global_basis
	var forward: Vector4 = (frame * Vector4(0.0, 0.0, 1.0, 0.0)).normalized()
	var landing: Vector4 = _cat.global_position + forward * throw_speed * 0.7 \
		+ Vector4(0.0, throw_rise * 0.1, 0.0, 0.0)
	var host: Node4D = _cat.get_parent() as Node4D
	var origin: Vector4 = host.global_position if host != null else Vector4.ZERO
	_cat.call("thrown_to", landing - origin)
	_say("")


func _say(text: String, seconds: float = 2.0) -> void:
	if _tag == null:
		return
	if text == "":
		_tag.call("clear")
		return
	_tag.call("show_text", text)
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
		# Only clear it if nothing else has since taken the tag over.
		if _tag != null and not holding:
			_tag.call("clear")
