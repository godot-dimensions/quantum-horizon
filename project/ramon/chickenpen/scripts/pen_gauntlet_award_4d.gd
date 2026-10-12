extends Node

## The moment the gauntlet is handed over: it turns above your head, then it is on your arm.
##
## THREE OBJECTS, ONE ITEM. The same gauntlet appears in three places and none of them is
## the same mesh: a DETAILED copy turning overhead at eight times size, a drawn icon in the
## inventory slot, and a BLOCK strapped to the forearm. Each is built for the distance it
## is seen from - see pen_gauntlet_4d.gd - and this node is what makes them read as one
## object, by handing the reveal off to the slot and the slot to the arm in that order.
##
## IT LISTENS FOR THE EFFECT, like the inventory does. The conversation says
## `give_gauntlet` and has no idea any of this exists.
##
## THE SHOWCASE IS NOT PARENTED TO THE PLAYER. It is dropped in the world at head height
## and left there: parented to the player it would inherit the avatar's facing and turn
## with the character, so walking away mid-reveal would drag it along and spinning the
## camera would make it appear to counter-rotate. A thing being presented to you should
## hold still in the world while you look at it.

enum Stage { IDLE, SHOWING, FLYING, WORN }

@export var player_path: NodePath
@export var avatar_path: NodePath
@export var dialogue_path: NodePath
@export var world_path: NodePath
@export var camera_path: NodePath

@export_group("Reveal")
## How big it grows while it turns, as a multiple of the wearable size.
##
## Big enough to be the subject of the shot and no bigger. At 7 it was four units across
## and stood in front of the pen, the keeper and half the fence - a reward that hides the
## thing it is a reward for.
@export_range(1.0, 20.0, 0.5) var showcase_scale: float = 3.2
@export_range(0.5, 12.0, 0.1) var spin_seconds: float = 3.2
@export_range(0.1, 6.0, 0.1) var spin_speed: float = 1.7
## Height above the player's own origin that it hangs at.
@export_range(0.5, 6.0, 0.1) var hover_height: float = 2.7
## How long it takes to shrink away toward the inventory once the turning is done.
@export_range(0.1, 3.0, 0.05) var fly_seconds: float = 0.55

var stage: Stage = Stage.IDLE

var _player: Node4D
var _avatar: Node
var _world: Node4D
var _showcase: Node4D
var _worn: Node4D
var _elapsed: float = 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_avatar = get_node_or_null(avatar_path)
	_world = get_node_or_null(world_path) as Node4D
	var dialogue: Node = get_node_or_null(dialogue_path)
	if _player == null or _world == null or dialogue == null:
		push_warning("PenGauntletAward: player, world or dialogue missing - the gauntlet will never appear (item 82).")
		return
	if not dialogue.is_connected("effect", _on_effect):
		dialogue.connect("effect", _on_effect)


func _on_effect(effect_name: String) -> void:
	if effect_name != "give_gauntlet" or stage != Stage.IDLE:
		return
	_begin()


## Item 73: a restart should take it back off your arm.
func reset() -> void:
	if _showcase != null:
		_showcase.queue_free()
		_showcase = null
	if _worn != null:
		_worn.queue_free()
		_worn = null
	stage = Stage.IDLE
	_elapsed = 0.0


func _begin() -> void:
	var model := preload("res://ramon/chickenpen/scripts/pen_gauntlet_4d.gd").new()
	model.name = "GauntletShowcase"
	model.build = 0  # DETAILED
	# Wide through W while it turns, so fiddling with the slice cannot make the prize
	# vanish mid-presentation.
	model.w_depth = 2.4
	_world.add_child(model)
	# Placed in the WORLD at the player's head, not parented to them - see the header.
	model.position = _player.global_position - _world.global_position \
		+ Vector4(0.0, hover_height, 0.0, 0.0)
	_showcase = model
	stage = Stage.SHOWING
	_elapsed = 0.0


func _process(delta: float) -> void:
	match stage:
		Stage.SHOWING:
			_turn(delta)
		Stage.FLYING:
			_shrink(delta)
		_:
			pass


func _turn(delta: float) -> void:
	_elapsed += delta
	if _showcase == null:
		stage = Stage.IDLE
		return
	# Grows into place over the first third of a second rather than popping at full size.
	var grown: float = clampf(_elapsed / 0.35, 0.0, 1.0)
	var eased: float = grown * grown * (3.0 - 2.0 * grown)
	_showcase.basis = _pose(_elapsed * spin_speed, showcase_scale * eased)
	if _elapsed >= spin_seconds:
		stage = Stage.FLYING
		_elapsed = 0.0


## Away and down toward the slot bar, shrinking as it goes. It is not tracked to the actual
## slot on screen: a world object chasing a 2D rectangle needs the camera's projection and
## looks wrong the moment the camera moves. Down and small is the readable version.
func _shrink(delta: float) -> void:
	_elapsed += delta
	if _showcase == null:
		_wear()
		return
	var t: float = clampf(_elapsed / fly_seconds, 0.0, 1.0)
	var size: float = showcase_scale * (1.0 - t)
	_showcase.basis = _pose(spin_seconds * spin_speed + _elapsed * spin_speed * 2.0, maxf(size, 0.01))
	var start: Vector4 = _player.global_position - _world.global_position \
		+ Vector4(0.0, hover_height, 0.0, 0.0)
	_showcase.position = start.lerp(start - Vector4(0.0, hover_height * 0.7, 0.0, 0.0), t)
	if t >= 1.0:
		_showcase.queue_free()
		_showcase = null
		_wear()


## Turning, at a size. Yaw carries the spin; a small fixed tilt keeps it from looking like
## a flat card turning edge-on twice a revolution.
func _pose(angle: float, size: float) -> Projection:
	var frame: Projection = Basis4D.from_zx(angle) * Basis4D.from_yz(0.32)
	return frame * Projection(
		Vector4(size, 0, 0, 0), Vector4(0, size, 0, 0),
		Vector4(0, 0, size, 0), Vector4(0, 0, 0, size))


## On the arm from here: the BLOCK build, hung off the forearm joint so it swings with it.
func _wear() -> void:
	stage = Stage.WORN
	if _avatar == null:
		return
	var elbow: Node4D = _avatar.get("elbow_left") as Node4D
	if elbow == null:
		push_warning("PenGauntletAward: the avatar has no elbow_left, so there is nothing to strap it to.")
		return
	var model := preload("res://ramon/chickenpen/scripts/pen_gauntlet_4d.gd").new()
	model.name = "GauntletWorn"
	model.build = 1  # BLOCK
	model.width = 0.17
	model.w_depth = 0.45
	elbow.add_child(model)
	# Partway down the forearm, screen outward. The forearm hangs along -Y from the elbow.
	model.position = Vector4(0.0, -0.13, 0.0, 0.0)
	model.basis = Basis4D.from_yz(-PI * 0.5)
	_worn = model
