extends Node4D

## The chicken keeper: the placeholder item 67 asks for, given something to say.
##
## WHY HE EXISTS AT ALL. Item 67 wants the start state to explain itself with "a short
## objective message, sign or lightweight chicken-keeper placeholder". The message and the
## sign were there; he was the third, and until now he was scenery - a figure standing by
## the gate with no reason to be looked at. A person standing where the chickens go is a
## better landmark than a sign, but only if approaching him does something.
##
## HE ANSWERS THE STATE, NOT A SCRIPT. What he says is chosen from how many chickens are
## home, so he is a second readout of the same fact the counter shows - useful when you
## have wandered off and forgotten where you were. No dialogue tree, no input: walk near
## him and he talks, walk away and he stops.

@export var player_path: NodePath
@export var manager_path: NodePath
@export var readout_path: NodePath
## The keeper himself, turned to face whoever walks up to him.
@export var figure_path: NodePath
@export_range(0.5, 20.0, 0.5) var turn_speed: float = 6.0
## How close you have to be before he says anything.
@export_range(1.0, 12.0, 0.5) var speak_within: float = 4.0
## And how far off your slice he can still be heard - generous, because a keeper who goes
## silent because you stepped through W would read as a bug rather than as a rule.
@export_range(0.5, 8.0, 0.5) var speak_within_w: float = 3.0

var _player: Node4D
var _manager: Node
var _readout: Label
var _figure: Node4D
var _facing: float = 0.0
var _last: String = ""


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_manager = get_node_or_null(manager_path)
	_readout = get_node_or_null(readout_path) as Label
	_figure = get_node_or_null(figure_path) as Node4D
	if _player == null or _readout == null:
		push_warning("PenKeeper: player or readout missing - he will never say anything (item 82).")
		return
	_readout.text = ""


func _process(_delta: float) -> void:
	if _player == null or _readout == null:
		return
	var gap: Vector4 = _player.global_position - global_position
	var near: bool = Vector2(gap.x, gap.z).length() <= speak_within and absf(gap.w) <= speak_within_w
	# Turn to whoever came to talk. The same convention the player and the girl use -
	# atan2(x, z) into Basis4D.from_zx, so +Z is the way he faces - because a character
	# that delivers his lines to a fence post while you stand beside him reads as broken.
	if near and _figure != null:
		var want: float = atan2(gap.x, gap.z)
		_facing = rotate_toward(_facing, want, turn_speed * _delta)
		_figure.basis = Basis4D.from_zx(_facing)
	var line: String = _line() if near else ""
	if line != _last:
		_last = line
		_readout.text = line


func _line() -> String:
	if _manager == null:
		return "Keeper: \"Mind the fence.\""
	var home: int = int(_manager.call("returned_count"))
	var total: int = (_manager.get("agents") as Array).size()
	if home >= total and total > 0:
		return "Keeper: \"That's the lot of them. Thank you kindly.\""
	if home == 0:
		return "Keeper: \"All twelve got out. Some of them aren't where you can see them - mind the fourth way.\""
	if home < total / 3:
		return "Keeper: \"%d down, %d to go. The ones left are the awkward ones.\"" % [home, total - home]
	if home < total - 2:
		return "Keeper: \"%d home. You're getting the hang of it.\"" % home
	return "Keeper: \"Nearly there - just %d still out.\"" % (total - home)
