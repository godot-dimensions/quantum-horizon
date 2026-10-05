extends Node

## Pick a chicken and be told which way to rotate onto it (items 50 and 65).
##
## THE GALLERY DOES NOT MAKE YOU GUESS. Its w_targeting.gd selects a target and re-solves
## the slice orientation continuously, so manual rotation there is for looking around
## rather than for finding. This scene asked the player to do that by hand, and measuring
## it showed the job was not merely fiddly:
##
##   standing 1.1 units from a chicken 0.90 off-slice, rotating xw through 62 degrees
##   moved its offset from 0.894 to 0.424 and never reached it
##
## and worse, xw was the WRONG PLANE - the bird was straight ahead, so its offset lay along
## z and needed zw. Nothing on screen said so. Picking the right plane by feel, from a
## control that is a held right-mouse drag, is not a puzzle anybody solves twice.
##
## IT NAMES THE DRAG; IT DOES NOT PERFORM IT.
##
## An earlier version rotated the slice for you, and it worked - but the rotating WAS the
## mechanic. Six of the twelve chickens exist to teach that things sit off your slice, and
## a button that finds them teaches only that the button exists. What was actually missing
## was never the effort; it was that nothing on screen said whether a given chicken needed
## xw or zw, and picking the wrong one moves the offset almost not at all. So this says
## which way to drag, watches you do it, and tells you when you have arrived.
##
## SOLVED BY MEASUREMENT, NOT BY ALGEBRA. Rather than derive the drag that puts a given
## chicken on the slice, this makes a small sideways drag and a small vertical one on the
## rig's frame - the very operation the mouse makes, GroundBasis4D.sliced - and watches what
## the offset does. Two extra basis multiplies a frame, and it cannot disagree with the rig
## about how the rig works.

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

@export var rig_path: NodePath
@export var player_path: NodePath
@export var locator_path: NodePath
@export var readout_path: NodePath

## Do the rotation instead of guiding it. Off: the solver is correct and kept for when an
## assist is wanted - a demo where nobody should be stuck, say - but it bypasses the lesson.
@export var rotate_for_me: bool = false
## How fast the slice eases onto the target when it does.
@export_range(0.5, 12.0, 0.1) var ease_speed: float = 3.2
## Below this offset the chicken counts as arrived.
##
## MUST NOT BE TIGHTER THAN THE CATCH ALLOWS. At 0.02 against a catch tolerance of 0.35 it
## went on demanding drags long after the bird was catchable, and since a real drag is
## coarse it overshot the band every time: the advice flipped between "drag up" and "drag
## down" forever while the chicken sat there, grabbable, the whole while. Guidance should
## stop when the player can act, not when a number is small.
@export_range(0.01, 1.0, 0.01) var settled: float = 0.30
@export var toggle_key: Key = KEY_T

var tracking: bool = false

var _rig: Node4D
var _player: Node4D
var _locator: Node
var _readout: Label
var _held: Node = null
## The offset when the chicken was selected, so the bar shows progress against the job you
## were actually given rather than against a fixed scale.
var _first_offset: float = 0.0


func _ready() -> void:
	_rig = get_node_or_null(rig_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	_locator = get_node_or_null(locator_path)
	_readout = get_node_or_null(readout_path) as Label
	if _rig == null or _player == null or _locator == null:
		push_warning("PenSliceAssist: rig, player or locator missing - lock-on will do nothing (item 82).")
	_say("")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if (event as InputEventKey).keycode != toggle_key:
		return
	tracking = not tracking
	_held = _locator.get("target") if tracking else null
	if tracking and _held == null:
		tracking = false
	_first_offset = 0.0
	_say("" if not tracking else "Chicken %s selected - see below." % _held.get("chicken_id"))
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not tracking or _rig == null:
		return
	# Let go when the bird is no longer something to catch - caught, penned, or delivered.
	if _held == null or not bool(_held.call("can_be_caught")):
		tracking = false
		_held = null
		_say("")
		return

	var body: Node4D = _held.get_parent() as Node4D
	if body == null:
		return
	if is_zero_approx(_first_offset):
		_first_offset = absf(_ana(body, Vector2.ZERO))
	var offset: float = _ana(body, Vector2.ZERO)
	var name: String = str(_held.get("chicken_id"))
	if absf(offset) <= settled:
		_say("Chicken %s is on your slice now - catch it." % name)
		return

	# Which way of dragging moves this chicken, and how much? Nudge each, look at what the
	# offset does. The bigger gradient is the direction worth dragging in; the other one can
	# be almost useless, which is the whole reason this readout exists.
	var probe: float = 0.01
	var d_x: float = (_ana(body, Vector2(probe, 0.0)) - offset) / probe
	var d_y: float = (_ana(body, Vector2(0.0, probe)) - offset) / probe
	if absf(d_x) < 0.0001 and absf(d_y) < 0.0001:
		_say("Chicken %s cannot be turned onto your slice from here - walk closer." % name)
		return

	if rotate_for_me:
		var scale: float = d_x * d_x + d_y * d_y
		var step: float = clampf(ease_speed * delta, 0.0, 1.0) * -offset / scale
		_rig.call("drag_slice", Vector2(d_x, d_y) * step)
		_say("Locked on chicken %s - turning the slice to it." % name)
		return

	_say("Chicken %s: hold %s and drag %s.   %s" % [
		name, _rotate_key(), _drag_words(offset, d_x, d_y), _closeness(offset)])


## Which way to move the mouse, in the player's words.
##
## The gradients are per unit of mouse motion - positive x rightwards, positive y downwards,
## as the rig hands it to GroundBasis4D.sliced - so the words read straight off their signs,
## and the direction is whichever one actually moves this chicken: the failure being fixed
## here is a player dragging hard in the direction that does nothing.
func _drag_words(offset: float, d_x: float, d_y: float) -> String:
	var sideways: bool = absf(d_x) >= absf(d_y)
	var needed: float = -offset / (d_x if sideways else d_y)
	if sideways:
		return "right" if needed > 0.0 else "left"
	return "down" if needed > 0.0 else "up"


## Feedback while dragging, so the guidance is not a one-shot instruction you follow blind.
func _closeness(offset: float) -> String:
	var span: float = maxf(_first_offset, 0.0001)
	var left: float = clampf(absf(offset) / span, 0.0, 1.0)
	var filled: int = int(round((1.0 - left) * 6.0))
	return "[%s]" % "".lpad(filled, "=").rpad(6, ".")


## The target's offset from the slice, as it WOULD be after [param drag] on the rig's frame.
## Nothing on the rig is touched: the dragged frame is built beside it.
func _ana(body: Node4D, drag: Vector2) -> float:
	var frame: Projection = GroundBasis4D.sliced(_rig.global_basis, drag)
	var bearing: Dictionary = BearingUtility4D.compute_raw(
		_player.global_position, frame, body.global_position)
	return float(bearing["ana_offset"])


## The key that holds slice-rotation, read from the InputMap like every other key named
## on screen in this scene.
func _rotate_key() -> String:
	for event in InputMap.action_get_events(&"rotate_4d"):
		if event is InputEventMouseButton:
			match (event as InputEventMouseButton).button_index:
				MOUSE_BUTTON_RIGHT:
					return "right mouse"
				MOUSE_BUTTON_LEFT:
					return "left mouse"
			return "mouse %d" % (event as InputEventMouseButton).button_index
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "slice-rotate"


func _say(text: String) -> void:
	if _readout != null:
		_readout.text = text
