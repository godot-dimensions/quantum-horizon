extends Node

## Tells the player where the next chicken is, including which way through W.
##
## BUILT ON THE SHOOTING RANGE'S MATHS, NOT BESIDE IT (items 50 and 65). The Range
## already solves "how far off the visible slice is this, and which way do I turn to fix
## it" in bearing_utility_4d.gd, and that file documents a bug worth inheriting the fix
## for: it must read the PLAYER BODY, never the camera, because pitch lives on the head
## and would otherwise fold vertical look into a horizontal answer. Re-deriving any of
## that here would have meant re-finding that bug.
##
## THE TWO-PART CUE (item 52). Ordinary direction is one problem and W is another, so
## they are reported separately: where to walk, and whether the chicken lies toward ana or
## kata. When both are satisfied the readout says so plainly, which is item 63's decisive
## response - the player should never wonder whether the device has succeeded.
##
## IT NAMES THE KEY, AND READS THAT KEY FROM THE INPUT MAP (item 66). An indicator that
## is technically accurate but that nobody can act on is not sufficient, and this readout
## was exactly that: it said "hold slice-rotate", which is how the Shooting Range moves
## through W - the Range puts slice rotation on the player BODY. This scene does not.
## Here the camera rig owns slice rotation (it changes what you SEE) while the body moves
## through W on move_ana / move_kata (it changes where you ARE), and only the second one
## can ever reach an off-slice chicken. A player following the old advice would have
## rotated the view until the bird appeared and then walked at a thing that was not there.
## The label is looked up from the InputMap rather than written out, so rebinding the key
## updates the advice instead of silently invalidating it.
##
## NOT AN AUTOPILOT (item 58). It gives a direction, a W side and a sense of getting
## warmer. It does not give coordinates or draw a marker on the chicken, because the
## search IS the mechanic; a locator that walks you there deletes the thing it exists to
## teach.

const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

@export var manager_path: NodePath
@export var player_path: NodePath
@export var readout_path: NodePath
## The node whose basis defines the currently VISIBLE slice.
##
## Not the player body, in this scene. The Range applies slice-rotation to the body, so
## there the body is both where you are and which slice you see. Here the camera rig owns
## it, which meant slice-rotating changed the view and changed nothing in this readout -
## it read a body basis that never moved. bearing_utility_4d anticipates exactly this and
## provides compute_raw for it: observer POSITION from one node, observer BASIS from
## another. The rig is right and the rig's Pitch CHILD is not - pitch must stay out of it,
## which is the bug that utility's header documents.
@export var slice_frame_path: NodePath

## How much closer a rival chicken must be before the locator switches to it. Without
## this, two chickens at similar range make the readout flicker between them, which item
## 56 asks to prevent.
@export_range(0.0, 0.9, 0.05) var switch_hysteresis: float = 0.25

## Below this angle off the slice the chicken counts as present and catchable (item 63).
@export_range(0.01, 0.6, 0.01) var lock_angle: float = 0.08

## Above this it is simply "far off" - used to scale the strength reading (item 53).
@export_range(0.2, 2.0, 0.05) var wide_angle: float = 0.9

var target: Node = null

var _manager: Node
var _player: Node4D
var _frame: Node4D
var _readout: Label


func _ready() -> void:
	_manager = get_node_or_null(manager_path)
	_player = get_node_or_null(player_path) as Node4D
	_readout = get_node_or_null(readout_path) as Label
	_frame = get_node_or_null(slice_frame_path) as Node4D
	if _manager == null or _player == null:
		push_warning("ChickenLocator: manager or player missing, so it cannot point at anything (item 82).")


func _physics_process(_delta: float) -> void:
	if _manager == null or _player == null:
		return
	target = _choose_target()
	if _readout == null:
		return
	if target == null:
		_readout.text = "Locator: all chickens accounted for."
		return
	_readout.text = _describe(target)
	# The camera rig carries the T lock; the slice frame IS that rig, so no new wiring.
	# "Tracking", not "locked on": this line already says LOCKED, meaning in your slice,
	# and two different meanings of lock side by side is one too many.
	if _frame != null and _frame.has_method("is_locked_on") and bool(_frame.call("is_locked_on")):
		_readout.text = "[T] tracking  -  " + _readout.text


## Nearest eligible loose chicken, with hysteresis (items 56 and 57).
##
## Eligibility comes from the chicken itself - carried, penned and returned birds all
## answer no - so the locator cannot point at something that is already home, and it
## moves on the instant one is delivered.
func _choose_target() -> Node:
	var candidates: Array = _manager.call("locator_candidates")
	if candidates.is_empty():
		return null
	var best: Node = null
	var best_gap: float = INF
	for agent in candidates:
		var body: Node4D = agent.get_parent() as Node4D
		if body == null:
			continue
		var gap: float = body.global_position.distance_to(_player.global_position)
		if gap < best_gap:
			best_gap = gap
			best = agent
	# Keep the current target unless the new one is meaningfully closer.
	if target != null and candidates.has(target) and best != target:
		var current: Node4D = target.get_parent() as Node4D
		if current != null:
			var current_gap: float = current.global_position.distance_to(_player.global_position)
			if best_gap > current_gap * (1.0 - switch_hysteresis):
				return target
	return best


func _describe(agent: Node) -> String:
	var body: Node4D = agent.get_parent() as Node4D
	if body == null:
		return "Locator: ..."
	var bearing: Dictionary = BearingUtility4D.compute_raw(
		_player.global_position, _slice_basis(), body.global_position)
	var rel: Vector4 = bearing["rel"]
	# ABSOLUTE. angle_off_slice is SIGNED - it says which side of the slice the chicken is
	# on, not just how far - so comparing it raw against a threshold called every negative
	# value a lock, however far off it was. It never showed while slice-rotation did
	# nothing, because walking through W only ever approached the slice from one side.
	var angle: float = absf(float(bearing["angle_off_slice"]))
	var ana: float = float(bearing["ana_offset"])
	var flat: float = Vector2(rel.x, rel.z).length()

	var where: String = _heading_word(rel)
	var distance: String = _distance_word(flat)
	# Item 53: signal strength, as words rather than a number - the player needs to know
	# it is improving, not what the angle is.
	var strength: float = clampf(1.0 - angle / wide_angle, 0.0, 1.0)
	var bars: String = "".lpad(int(round(strength * 5.0)), "#").rpad(5, ".")

	if angle <= lock_angle:
		# Item 63: a decisive response, not a slightly better number.
		return "Locator: LOCKED  %s %s  [%s]  in your slice - catchable" % [distance, where, bars]
	var side: String = "ana" if ana > 0.0 else "kata"
	var key: String = _key_for(&"move_ana" if ana > 0.0 else &"move_kata")
	return "Locator: %s %s  [%s]  it is %s of you - press %s" % [distance, where, bars, side, key]


## The frame the visible slice is defined in: the rig if there is one, the body otherwise.
func _slice_basis() -> Projection:
	return _frame.global_basis if _frame != null else _player.global_basis


func _heading_word(rel: Vector4) -> String:
	if _player == null:
		return ""
	var basis: Projection = _slice_basis()
	var forward: float = rel.dot(-basis.z)
	var right: float = rel.dot(basis.x)
	if absf(forward) > absf(right):
		return "ahead" if forward > 0.0 else "behind you"
	return "to your right" if right > 0.0 else "to your left"


func _distance_word(flat: float) -> String:
	if flat < 2.0:
		return "very close,"
	if flat < 6.0:
		return "nearby,"
	if flat < 14.0:
		return "some way off,"
	return "far away,"


## The key currently bound to an action, in words a player can act on (item 66).
##
## Read from the InputMap every time rather than written into the string: the advice and
## the binding then cannot disagree, which is the failure this whole readout exists to
## avoid.
func _key_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return str(action)
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					return "left mouse"
				MOUSE_BUTTON_RIGHT:
					return "right mouse"
				MOUSE_BUTTON_MIDDLE:
					return "middle mouse"
			return "mouse %d" % event.button_index
		if event is InputEventJoypadButton:
			return "pad button %d" % event.button_index
	return str(action)
