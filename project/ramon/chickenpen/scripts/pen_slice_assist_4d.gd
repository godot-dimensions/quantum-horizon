extends Node

## Lock onto a chicken and let the slice come to you (items 50 and 65).
##
## THE GALLERY DOES NOT MAKE YOU HUNT BY HAND. Its w_targeting.gd selects a target and then
## CONTINUOUSLY re-solves the player's slice orientation so that target stays on the visible
## slice - re-solved every frame, not once, because a target that moves would otherwise
## drift back out. Manual rotation is for looking around; landing on something is done for
## you. Without that, this scene asked the player to do by hand what the Range does for
## them, and it was as hard as it sounds:
##
##   standing 1.1 units from a chicken 0.90 off-slice, rotating xw through 62 degrees
##   moved its offset from 0.894 to 0.424 and never reached it
##
## and worse, xw was the WRONG PLANE - the bird was straight ahead, so its offset lay along
## z and needed zw. Nothing on screen said so. Picking the right plane by feel, from a
## control that is a held right-mouse drag, is not a puzzle anybody solves twice.
##
## SOLVED BY MEASUREMENT, NOT BY ALGEBRA. Rather than derive which xw and zw put a given
## chicken on the slice - which depends on the exact order the rig composes its rotations,
## and would silently rot if that order ever changed - this nudges each angle and watches
## what the offset does. Two extra basis multiplies a frame, and it cannot disagree with
## the rig about how the rig works.

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

@export var rig_path: NodePath
@export var player_path: NodePath
@export var locator_path: NodePath
@export var readout_path: NodePath

## How fast the slice eases onto the target. Fast enough to feel like help, slow enough
## that you can see which way it went - the whole point is to teach what rotating does.
@export_range(0.5, 12.0, 0.1) var ease_speed: float = 3.2
## Below this offset it stops nudging, so a locked slice sits still instead of humming.
@export_range(0.001, 0.2, 0.001) var settled: float = 0.02
@export var toggle_key: Key = KEY_T

var tracking: bool = false

var _rig: Node4D
var _player: Node4D
var _locator: Node
var _readout: Label
var _held: Node = null


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
	_say("" if not tracking else "Locked on chicken %s - the slice is turning to it." % _held.get("chicken_id"))
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
	var offset: float = _ana(body, 0.0, 0.0)
	if absf(offset) <= settled:
		_say("Locked on chicken %s - it is on your slice." % _held.get("chicken_id"))
		return

	# Which way does each plane move the offset? Nudge, look, and step downhill.
	var probe: float = 0.01
	var d_xw: float = (_ana(body, probe, 0.0) - offset) / probe
	var d_zw: float = (_ana(body, 0.0, probe) - offset) / probe
	var scale: float = d_xw * d_xw + d_zw * d_zw
	if scale < 0.000001:
		return
	# The step that would zero the offset outright, taken a fraction at a time.
	var step: float = clampf(ease_speed * delta, 0.0, 1.0) * -offset / scale
	_rig.set("_slice_xw", float(_rig.get("_slice_xw")) + d_xw * step)
	_rig.set("_slice_zw", float(_rig.get("_slice_zw")) + d_zw * step)
	_rig.call("_apply")
	_say("Locked on chicken %s - the slice is turning to it." % _held.get("chicken_id"))


## The target's offset from the slice, as it WOULD be with the rig nudged by these amounts.
##
## Applied through the rig itself and then put back, so this asks the rig how it composes
## its own rotations rather than assuming. The rig is restored before anything renders.
func _ana(body: Node4D, add_xw: float, add_zw: float) -> float:
	var xw: float = float(_rig.get("_slice_xw"))
	var zw: float = float(_rig.get("_slice_zw"))
	if not is_zero_approx(add_xw) or not is_zero_approx(add_zw):
		_rig.set("_slice_xw", xw + add_xw)
		_rig.set("_slice_zw", zw + add_zw)
		_rig.call("_apply")
	var bearing: Dictionary = BearingUtility4D.compute_raw(
		_player.global_position, _rig.global_basis, body.global_position)
	if not is_zero_approx(add_xw) or not is_zero_approx(add_zw):
		_rig.set("_slice_xw", xw)
		_rig.set("_slice_zw", zw)
		_rig.call("_apply")
	return float(bearing["ana_offset"])


func _say(text: String) -> void:
	if _readout != null:
		_readout.text = text
