extends Node

## THE W GUIDE (discovery, 9 Oct 2026; follow_up/pen_discovery_plan.md): contextual hints for moving through W,
## along the path, that get quieter as the player learns.
##
## Ramon's brief: "teach 4D intuition through exploration, without constantly interrupting the experience"; hints
## that "trigger naturally based on player proximity, appear briefly and disappear after a few seconds, avoid
## repeatedly triggering once the player has understood or completed the interaction, become progressively more
## subtle as the player advances, guide exploration without explicitly revealing the solution".
##
## THE SPOTS are nodes in the group "w_hint" (markers in the scene, so they move with the editor), each with
## metadata:
##   w_hint_key      a name, unique (default: the node's name)
##   w_hint_skill    "step" (E / Q), "turn_side" (drag side to side), "turn_forward" (drag forward and back), "align"
##   w_hint_radius   ground distance (x, z) from the marker within which it can fire (default 6)
##   w_hint_target   NodePath to what is hidden, from the marker (default: the marker itself)
##   w_hint_offset   Vector4 added to the target's position (default zero): a point inside a big thing
##   w_hint_reach    how far off the slice still counts as "in it", along its normal (default 1)
##   w_hint_done     "in_slice" (the target is in your slice), "moved_w" (you moved 0.4 m through W since arriving),
##                   "aligned" (your slice flat at the target's W), "tilted" (the slice turned past w_hint_tilt
##                   degrees, default 60), "flag" (the target's hint_done() says so)
##   w_hint_line     one short line under the card
##   w_hint_linger   seconds you stay in reach, with the target still hidden, before anything shows (default 3)
##   w_hint_tier_min the quietest a spot may be: 1 means never the card, only the chip (the easter eggs)
##   w_hint_chip_always  show the chip even once the skill is learned (an easter egg's last resort)
##   w_hint_card_always  always the animated card, however well the skill is known (10 Oct: the cave, the pen, the wall)
##   w_hint_acts     the card's own gestures, [[kind, words], ...] (kinds: drag_h, drag_v, look_h, keys), else the skill's
##   w_hint_card_seconds  how long its card plays (default card_seconds)
##
## HOW QUIET (by what the player has done, anywhere, this session; never saved, so the next visitor is taught too):
##   tier 0, never done it:      the animated mouse card (discovery/pen_mouse_card_4d.gd) with the line, 5 s
##   tier 1, done it once or twice: a small chip at the spot (a WorldTag4D), 3.5 s
##   tier 2, done it three times:   nothing on screen; the world's own cues (the path's marks, the glints) do it
## A spot fires once. It is done for good when its condition is met, hint or not.
##
## MANNERS: one hint at a time; it waits while the Tutor shows a line, while you talk to someone (input off), in the
## cinema and the cave (the crossings away), and when the player is hidden. Ctrl+R (reset) teaches from scratch.
##
## NO class_name (engine_gotchas.md).

const WSense := preload("res://ramon/chickenpen/discovery/w_sense_4d.gd")
const MouseCard := preload("res://ramon/chickenpen/discovery/pen_mouse_card_4d.gd")

@export var player_path: NodePath = ^"../../Player"
@export var tutor_path: NodePath = ^"../Tutor"
@export var ui_path: NodePath = ^"../../UI"
@export var crossing_paths: Array[NodePath] = [^"../../Crossing", ^"../../CaveCrossing"]
## Seconds the card is up, and the chip.
@export_range(2.0, 12.0, 0.5) var card_seconds: float = 5.5
@export_range(1.0, 8.0, 0.5) var chip_seconds: float = 3.5
## Uses of a skill before it goes quiet: tier 1 from the first, tier 2 from this many.
@export_range(1, 8, 1) var learned_after: int = 3
## Prints each hint and each use (the runners read it).
@export var verbose: bool = true

## The session's memory (static: a reload of the pen keeps it, a new launch starts afresh).
static var uses: Dictionary = {"step": 0, "turn_side": 0, "turn_forward": 0, "align": 0}
static var spent: Dictionary = {}
static var done: Dictionary = {}

var _player: CharacterBody4D
var _rig: Node
var _cam: Camera4D
var _tutor: Node
var _card: Control
var _chip_anchor: Node4D
var _chip: Node
var _chip_left: float = 0.0
## The hint on screen now (its key), so doing the thing can take it down.
var _showing_key: String = ""
var _showing_spot: Node4D
var _check: float = 0.0
var _linger: Dictionary = {}
var _arrived_w: Dictionary = {}
# Skill tracking: the drag since the right button went down, the W walked since a step key went down, and the rig's
# trip home (an align when it is to a W other than 0).
var _drag := Vector2.ZERO
var _step_from: float = INF
var _homing_was: float = 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody4D
	_tutor = get_node_or_null(tutor_path)
	if _player == null:
		push_warning("WGuide: no player, so no W hints.")
		return
	_rig = _player.get_node_or_null("CameraRig")
	_cam = WSense.camera_of(_player)
	var ui: Node = get_node_or_null(ui_path)
	_card = MouseCard.new()
	_card.name = "WGuideCard"
	if ui != null:
		ui.add_child(_card)
	else:
		add_child(_card)


func _input(event: InputEvent) -> void:
	# Watching, never taking: the rig and everyone else still get every event.
	if event is InputEventMouseMotion and Input.is_action_pressed(&"rotate_4d") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_drag += (event as InputEventMouseMotion).relative
		# About 0.25 rad of turn at the rig's sensitivity (0.005 per pixel): a turn somebody meant.
		if absf(_drag.x) > 50.0 and absf(_drag.x) >= absf(_drag.y):
			_used("turn_side")
			_drag = Vector2.ZERO
		elif absf(_drag.y) > 50.0 and absf(_drag.y) > absf(_drag.x):
			_used("turn_forward")
			_drag = Vector2.ZERO
	elif event.is_action_released(&"rotate_4d"):
		_drag = Vector2.ZERO


func _process(delta: float) -> void:
	if _player == null:
		return
	_track_steps()
	_track_align()
	if _chip_left > 0.0:
		_chip_left -= delta
		if _chip_left <= 0.0 and _chip != null:
			_chip.call("clear")
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.1
	_think(0.1)


## A step through W: a step key held, and 0.5 m walked through W since it went down.
func _track_steps() -> void:
	var held: bool = Input.is_action_pressed(&"move_ana") or Input.is_action_pressed(&"move_kata")
	if not held:
		_step_from = INF
		return
	if _step_from == INF:
		_step_from = _player.global_position.w
	elif absf(_player.global_position.w - _step_from) > 0.5:
		_used("step")
		_step_from = _player.global_position.w


## V at the camp, the marsh or the balloon sends the rig home to a W other than 0 (rig.align_to): an align.
func _track_align() -> void:
	if _rig == null:
		return
	var homing: float = float(_rig.get("_homing"))
	if homing > 0.0 and _homing_was <= 0.0 and absf(float(_rig.get("_home_w"))) > 0.01:
		_used("align")
	_homing_was = homing


func _used(skill: String) -> void:
	uses[skill] = int(uses.get(skill, 0)) + 1
	if verbose:
		print("WGUIDE used %s (%d)" % [skill, uses[skill]])


func tier_of(skill: String) -> int:
	var n: int = int(uses.get(skill, 0))
	return 0 if n == 0 else (1 if n < learned_after else 2)


func _quiet() -> bool:
	if not _player.is_visible_in_tree() or _player.get("input_enabled") == false:
		return true
	if _tutor != null:
		var showing: Variant = _tutor.get("_showing")
		if showing is String and showing != "":
			return true
	for path in crossing_paths:
		var c: Node = get_node_or_null(path)
		if c != null and c.has_method("is_away") and bool(c.call("is_away")):
			return true
	return false


func _think(dt: float) -> void:
	# Walked away from the spot whose hint is up: it goes (it was about that place).
	if _showing_key != "" and is_instance_valid(_showing_spot):
		var away: Vector4 = _showing_spot.global_position - _player.global_position
		if Vector2(away.x, away.z).length() > float(_showing_spot.get_meta(&"w_hint_radius", 6.0)) * 1.5 + 2.0:
			_take_down()
	var busy: bool = (_card != null and bool(_card.call("is_playing"))) or _chip_left > 0.0 or _quiet()
	for spot in get_tree().get_nodes_in_group(&"w_hint"):
		var s := spot as Node4D
		if s == null or not s.is_visible_in_tree():
			continue
		var key: String = String(s.get_meta(&"w_hint_key", s.name))
		if done.has(key):
			continue
		var gap: Vector4 = s.global_position - _player.global_position
		var near: bool = Vector2(gap.x, gap.z).length() <= float(s.get_meta(&"w_hint_radius", 6.0))
		if not near:
			_linger.erase(key)
			_arrived_w.erase(key)
			continue
		if not _arrived_w.has(key):
			_arrived_w[key] = _player.global_position.w
		if _is_done(s, key):
			done[key] = true
			_linger.erase(key)
			# Done while its own hint is up: the hint goes (end a hint when the player does the thing).
			if key == _showing_key:
				_take_down()
			if verbose:
				print("WGUIDE done %s" % key)
			continue
		if spent.has(key) or busy:
			continue
		_linger[key] = float(_linger.get(key, 0.0)) + dt
		if float(_linger[key]) >= float(s.get_meta(&"w_hint_linger", 3.0)):
			_show(s, key)
			busy = true


func _target_point(s: Node4D) -> Vector4:
	var path: NodePath = s.get_meta(&"w_hint_target", NodePath(""))
	var t := s.get_node_or_null(path) as Node4D if not path.is_empty() else s
	if t == null:
		t = s
	return t.global_position + (s.get_meta(&"w_hint_offset", Vector4.ZERO) as Vector4)


func _is_done(s: Node4D, key: String) -> bool:
	var how: String = String(s.get_meta(&"w_hint_done", "in_slice"))
	var p: Vector4 = _target_point(s)
	match how:
		"moved_w":
			return absf(_player.global_position.w - float(_arrived_w.get(key, _player.global_position.w))) >= 0.4
		"aligned":
			return _rig != null and _rig.has_method("is_aligned_to") and bool(_rig.call("is_aligned_to", p.w))
		"tilted":
			return WSense.tilt(_cam) >= deg_to_rad(float(s.get_meta(&"w_hint_tilt", 60.0)))
		"flag":
			var path: NodePath = s.get_meta(&"w_hint_target", NodePath(""))
			var t: Node = s.get_node_or_null(path) if not path.is_empty() else s
			return t != null and t.has_method("hint_done") and bool(t.call("hint_done"))
		_:
			return absf(WSense.off_slice(_cam, p)) <= float(s.get_meta(&"w_hint_reach", 1.0))


func _show(s: Node4D, key: String) -> void:
	var skill: String = String(s.get_meta(&"w_hint_skill", "step"))
	var tier: int = maxi(tier_of(skill), int(s.get_meta(&"w_hint_tier_min", 0)))
	if tier >= 2 and bool(s.get_meta(&"w_hint_chip_always", false)):
		tier = 1
	# A spot that always teaches with the animated card, however well the skill is known (Ramon, 10 Oct: the cave, the
	# pen, the wall: "Reuse the animated mouse tutorial from Aquatic Lab at this location").
	if bool(s.get_meta(&"w_hint_card_always", false)):
		tier = 0
	spent[key] = true
	if tier >= 2:
		if verbose:
			print("WGUIDE quiet %s (%s learned)" % [key, skill])
		return
	var line: String = String(s.get_meta(&"w_hint_line", ""))
	_showing_key = key
	_showing_spot = s
	if tier == 0 and _card != null:
		# Its own gestures if the spot has them (w_hint_acts: [[kind, words], ...]), else the skill's.
		var acts: Array = s.get_meta(&"w_hint_acts", []) if s.has_meta(&"w_hint_acts") else _acts(skill)
		_card.call("play", acts, line, float(s.get_meta(&"w_hint_card_seconds", card_seconds)))
		if verbose:
			print("WGUIDE card %s: %s" % [key, line])
		return
	_show_chip(s, _chip_text(skill))
	if verbose:
		print("WGUIDE chip %s: %s" % [key, _chip_text(skill)])


## The card, played by someone else's moment (the wall's pivot after its camera move: discovery/pen_wall_pivot_4d.gd):
## [param acts] [[kind, words], ...], [param line] under them, for [param seconds].
func teach(acts: Array, line: String, seconds: float = 6.0) -> void:
	if _card != null:
		_card.call("play", acts, line, seconds)


func _take_down() -> void:
	_showing_key = ""
	_showing_spot = null
	if _card != null and bool(_card.call("is_playing")):
		_card.call("stop")
	if _chip_left > 0.0:
		_chip_left = 0.01


func _acts(skill: String) -> Array:
	match skill:
		"step":
			return [["keys", "STEP THROUGH W"]]
		"turn_side":
			return [["drag_h", "TURN THE SLICE SIDEWAYS"]]
		"turn_forward":
			return [["drag_v", "TURN THE SLICE FORWARD"]]
		_:
			return [["drag_h", "TURN THE SLICE"], ["drag_v", "OR FORWARD"]]


func _chip_text(skill: String) -> String:
	match skill:
		"step":
			return "%s / %s  step through W" % [_key_for(&"move_kata"), _key_for(&"move_ana")]
		"turn_side":
			return "Right mouse  drag sideways"
		"turn_forward":
			return "Right mouse  drag forward"
		_:
			return "Turn the slice, then V"


## The chip: a small tag over the spot, hung at the W where your slice crosses it so it is in your slice.
func _show_chip(s: Node4D, text: String) -> void:
	if _chip_anchor == null:
		_chip_anchor = Node4D.new()
		_chip_anchor.name = "WGuideChipAnchor"
		var world: Node = _player.get_parent().get_node_or_null("World")
		(world if world != null else _player.get_parent()).add_child(_chip_anchor)
		_chip = WorldTag4D.new()
		_chip.name = "WGuideChip"
		_chip.set("anchor_path", NodePath(".."))
		if _cam != null:
			_chip.set("camera_path", _cam.get_path())
		_chip.set("lift", 6.0)
		_chip.set("w_range", 12.0)
		_chip_anchor.add_child(_chip)
	var at: Vector4 = s.global_position + Vector4(0, 1.6, 0, 0)
	var w: float = WSense.slice_w_at(_cam, at.x, at.y, at.z)
	at.w = w if w != INF else _player.global_position.w
	_chip_anchor.global_position = at
	_chip.call("show_text", text)
	_chip_left = chip_seconds


func _key_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "?"


## Ctrl+R (Systems/Game resets every Systems node that has this): a new visitor, taught from scratch.
func reset() -> void:
	uses = {"step": 0, "turn_side": 0, "turn_forward": 0, "align": 0}
	spent.clear()
	done.clear()
	_linger.clear()
	_arrived_w.clear()
	if _card != null:
		_card.call("stop")
	if _chip != null:
		_chip.call("clear")
	_chip_left = 0.0
	# The easter eggs live under World, which Ctrl+R does not reset: hidden again for the next visitor.
	for node in get_tree().get_nodes_in_group(&"discovery_reset"):
		if node != self and node.has_method("reset"):
			node.call("reset")
