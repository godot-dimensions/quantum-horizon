extends Node

## Teaches the controls one at a time, each at the moment it first becomes usable (item 68).
##
## NO TUTORIAL PANEL. Item 68 rules one out, and it would be the wrong shape anyway: a
## panel has to explain every verb before the player can perform any of them, so it is
## read once, while none of it means anything, and then never again. Each hint here waits
## for the state that makes it true.
##
## THE CATCH AND THE THROW ARE NOT HERE. The catcher already prompts for both, and it does
## it better than this node could, because it knows whether a catch would actually succeed
## right now. Duplicating them would mean two things competing to explain the same key.
## What is left is what nothing else owns: how to move, what the fourth direction is, and
## what to do with a chicken once you are holding it.
##
## HINTS IN PLACES (6 Oct 2026, the pen's new opening): a marker in the group "tutor_spot"
## teaches the first time you reach it, so a wall or a door can explain itself without this
## node knowing it exists. Its metadata:
##   tutor_key     the hint's name (each still fires once)
##   tutor_text    the words; {ana} and {kata} become those keys, {dir} the way to the
##                 marker's own W (ana or kata) and {key} the key for it
##   tutor_radius  how near, on the ground, in metres
##   tutor_w       how near in W
##   tutor_when    "in": shown within tutor_w of the marker's W; "off": shown further than
##                 that from it (a door that is somewhere else in W)
##
## EACH HINT FIRES ONCE. A hint that reappears is no longer teaching - it is nagging, and
## the player has already demonstrated they understood it by triggering the next one.

@export var player_path: NodePath
@export var catcher_path: NodePath
@export var locator_path: NodePath
@export var label_path: NodePath

## How long a hint stays up. Long enough to read twice, short enough that it is gone before
## it becomes furniture.
@export_range(2.0, 20.0, 0.5) var hint_seconds: float = 7.0
## Seconds spent off the slice you started in before R is named as the way back.
@export_range(2.0, 60.0, 0.5) var home_after: float = 8.0

var _player: Node4D
var _catcher: Node
var _locator: Node
var _label: Label
var _shown: Dictionary = {}
var _showing: String = ""
var _left: float = 0.0
var _start_w: float = 0.0
var _off_for: float = 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_catcher = get_node_or_null(catcher_path)
	_locator = get_node_or_null(locator_path)
	_label = get_node_or_null(label_path) as Label
	if _label == null or _player == null:
		push_warning("PenTutor: label or player missing, so no control will ever be taught (item 82).")
		return
	_label.text = ""
	_start_w = _player.global_position.w
	_show("move", "Move with %s   Look with the mouse" % _movement_keys())


func _process(delta: float) -> void:
	if _label == null or _player == null:
		return
	if _showing != "":
		_left -= delta
		if _left <= 0.0:
			_showing = ""
			_label.text = ""
	if absf(_player.global_position.w - _start_w) > 0.5:
		_off_for += delta
	_check()


func _check() -> void:
	# Holding a chicken: the only thing left to learn is where it goes.
	if _catcher != null and _catcher.get("carried") != null:
		_show("deliver", "Carry it inside the fence, or throw it over.")
		return

	if _spot_hint():
		return

	# The fourth direction, introduced the first time the locator says a chicken is off the
	# current slice. Waiting for that is the point: said at the start it is a riddle, said
	# here it explains something the player is already looking at.
	if _locator != null:
		var readout: Label = _locator.get_node_or_null(_locator.get("readout_path")) as Label
		if readout != null and not readout.text.contains("LOCKED") and readout.text.contains("press "):
			_show("ana", "That chicken is beside your slice, not in it. %s and %s move you through the fourth direction." % [
				_key_for(&"move_ana"), _key_for(&"move_kata")])
			return
		# And once they have actually moved through W, name what just happened. This is the
		# moment the mechanic is understood rather than merely obeyed.
		if absf(_player.global_position.w - _start_w) > 0.5:
			_show("moved", "You are now standing in a different slice of the world.")
	# And a while later, still off it: the way back.
	if _off_for > home_after:
		_show("home", "R takes you back to the farm's slice.")


## The place hints (see the top of the file). True when one was shown.
func _spot_hint() -> bool:
	var me: Vector4 = _player.global_position
	for spot in get_tree().get_nodes_in_group(&"tutor_spot"):
		var marker := spot as Node4D
		if marker == null or not marker.is_visible_in_tree():
			continue
		var key: String = String(marker.get_meta(&"tutor_key", marker.name))
		if _shown.has(key):
			continue
		var at: Vector4 = marker.global_position
		if Vector2(at.x - me.x, at.z - me.z).length() > float(marker.get_meta(&"tutor_radius", 5.0)):
			continue
		var dw: float = at.w - me.w
		var near_w: bool = absf(dw) <= float(marker.get_meta(&"tutor_w", 1.0))
		if near_w != (String(marker.get_meta(&"tutor_when", "in")) == "in"):
			continue
		var text: String = String(marker.get_meta(&"tutor_text", ""))
		text = text.replace("{ana}", _key_for(&"move_ana")).replace("{kata}", _key_for(&"move_kata"))
		text = text.replace("{dir}", "ana" if dw > 0.0 else "kata")
		text = text.replace("{key}", _key_for(&"move_ana") if dw > 0.0 else _key_for(&"move_kata"))
		_show(key, text)
		return _showing == key
	return false


## One hint at a time, and each of them only ever once.
func _show(key: String, message: String) -> void:
	if _shown.has(key) or _showing != "":
		return
	_shown[key] = true
	_showing = key
	_left = hint_seconds
	_label.text = message


func _movement_keys() -> String:
	return "%s%s%s%s" % [
		_key_for(&"move_forward"), _key_for(&"move_left"),
		_key_for(&"move_back"), _key_for(&"move_right")]


## Read from the InputMap for the same reason the locator does: advice that names a key
## nobody has bound is worse than no advice.
func _key_for(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code)
	return "?"


## Item 73: a restart should teach a new player again.
func reset() -> void:
	_shown.clear()
	_showing = ""
	_left = 0.0
	if _label != null:
		_label.text = ""
	if _player != null:
		_start_w = _player.global_position.w
	_off_for = 0.0
	_show("move", "Move with %s   Look with the mouse" % _movement_keys())
