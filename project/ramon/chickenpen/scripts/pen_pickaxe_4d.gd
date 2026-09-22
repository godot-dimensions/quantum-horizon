extends Node

## Swinging the pickaxe at a voxel rock.
##
## IT REUSES VoxelMining WHOLE, and does not fork any of it. project/ramon/VoxelMining/
## already has the rock, the per-voxel colliders and the carve - `mine_at_shape()` takes
## the CollisionShape4D a raycast handed back and removes that voxel. What was missing was
## only the part that belongs to THIS scene: which tool is in your hand, and where the
## swing comes from. Its own mining_axe.gd could not be used as-is because it reaches for
## `$"../Player/PlayerHead"` - a node this scene does not have, the camera living on an
## orbit rig instead - and because it is always on, which is wrong the moment the belt has
## more than one thing in it.
##
## THE SWING COMES FROM THE CHARACTER, NOT THE CAMERA. The camera sits five metres behind
## you on its arm, so a ray cast from there would spend its whole melee range crossing the
## gap before it reached anything you could plausibly hit. The ray starts at chest height
## on the body and travels along the way the camera looks, which is also the way a press
## of forward would send you.
##
## IT TAKES THE KEY ONLY WHEN IT IS UNAMBIGUOUS. `fire` is the same button that puts down
## a carried chicken, so this listens in `_input` - ahead of the catcher's
## `_unhandled_input` - and claims the press only with the pickaxe in hand, empty arms,
## the mouse captured, and rock actually in reach. Every other press falls through
## untouched. That is the rule the talk driver and the cat grab already follow.

@export var player_path: NodePath
@export var camera_path: NodePath
@export var inventory_path: NodePath
@export var catcher_path: NodePath
## Which belt entry is a pickaxe. Named rather than assumed, so a second tool is a second
## node with a different name in it.
@export var tool_effect: String = "found_pickaxe"

@export_group("Reach")
## Metres. Melee, not a hitscan weapon's reach.
@export_range(0.5, 8.0, 0.1) var reach: float = 3.0
## How far up the body the swing starts.
@export_range(0.0, 2.5, 0.05) var chest_height: float = 1.0

var _player: Node4D
var _camera: Node4D
var _inventory: Node
var _catcher: Node


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node4D
	_camera = get_node_or_null(camera_path) as Node4D
	_inventory = get_node_or_null(inventory_path)
	_catcher = get_node_or_null(catcher_path)
	if _player == null or _camera == null or _inventory == null:
		push_warning("PenPickaxe: player, camera or inventory missing - nothing can be mined.")


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"fire"):
		return
	if not _armed():
		return
	if _swing():
		get_viewport().set_input_as_handled()


## Pickaxe in hand, hands otherwise empty, and a pointer that is not being used to click
## about the interface.
func _armed() -> bool:
	if _player == null or _camera == null or _inventory == null:
		return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if _catcher != null and _catcher.get("carried") != null:
		return false
	return String(_inventory.call("selected_effect")) == tool_effect


## Returns whether anything was actually hit, because only a real hit should swallow the
## button - a swing at thin air has to fall through to whatever else wanted the press.
func _swing() -> bool:
	var from: Vector4 = _player.global_position + Vector4(0.0, chest_height, 0.0, 0.0)
	# The camera looks along its own -Z, the same axis a press of forward moves you along.
	var along: Vector4 = (_camera.global_basis * Vector4(0.0, 0.0, -1.0, 0.0)).normalized()
	var params := RaycastParameters4D.new()
	params.global_ray_origin = from
	params.global_ray_direction = along
	params.set_exclude_nodes([_player])
	var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
	if not bool(hit.get("hit", false)):
		return false
	if float(hit.get("global_distance", INF)) > reach:
		return false
	# The body that owns the hit shape is the rock's "Voxels" StaticBody4D, so the rock
	# itself is its parent - the same hop VoxelMining's own axe makes.
	var body: Object = hit.get("body")
	if body == null:
		return false
	var rock: Object = (body as Node).get_parent()
	if rock == null or not rock.has_method("mine_at_shape"):
		return false
	rock.call("mine_at_shape", hit.get("shape"))
	return true
