extends Node4D

## Turns a standing figure to face whoever walks up to it.
##
## A NODE OF ITS OWN, not a line inside the dialogue driver. The keeper's conversation is
## owned by another part of this scene and is still being written; turning to face someone
## is a separate, smaller idea that any figure might want - the keeper today, a shopkeeper
## or a guard later - so it lives where it can be dropped onto any of them without going
## near the talking.
##
## It is also why this is not folded into the avatar builder: block_avatar_4d BUILDS a
## figure and a Node4D holds one script, so the figure cannot also carry behaviour.
##
## THE FACING CONVENTION IS THE PLAYER'S: atan2(x, z) into Basis4D.from_zx, so +Z is the
## way the figure faces. Copied rather than re-derived, because this project has had that
## backwards twice and both times it was a silent failure - a character that looks right
## until you stand in front of it.

@export var figure_path: NodePath
@export var player_path: NodePath
## How close before it notices you, and how far through W it can still see you.
@export_range(0.5, 16.0, 0.5) var notice_within: float = 4.5
@export_range(0.5, 10.0, 0.5) var notice_within_w: float = 2.5
@export_range(0.5, 20.0, 0.5) var turn_speed: float = 6.0
## Where it looks when nobody is there. Its authored facing, kept so it returns to it.
@export var settle_back: bool = true

var _figure: Node4D
var _player: Node4D
var _facing: float = 0.0
var _rest: float = 0.0


func _ready() -> void:
	_figure = get_node_or_null(figure_path) as Node4D
	_player = get_node_or_null(player_path) as Node4D
	if _figure == null or _player == null:
		push_warning("PenFacePlayer: figure or player missing - nobody will turn (item 82).")
		return
	# Read its authored basis back into an angle, so turning away and settling again both
	# start from where the scene actually put it.
	_rest = atan2(_figure.basis.z.x, _figure.basis.z.z)
	_facing = _rest


func _process(delta: float) -> void:
	if _figure == null or _player == null:
		return
	var gap: Vector4 = _player.global_position - _figure.global_position
	var near: bool = Vector2(gap.x, gap.z).length() <= notice_within \
		and absf(gap.w) <= notice_within_w
	var want: float = _rest
	if near:
		want = atan2(gap.x, gap.z)
	elif not settle_back:
		return
	_facing = rotate_toward(_facing, want, turn_speed * delta)
	_figure.basis = Basis4D.from_zx(_facing)
