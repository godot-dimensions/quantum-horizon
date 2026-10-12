extends Node
## First test of a "hack away the rock" tool. Raycasts on the existing "fire"
## action and, if it hits a VoxelMiningBlock's per-voxel collider within melee
## range, tells that block to carve out the hit voxel.
##
## Follows the same raycast-then-dispatch shape as
## project/sandbox/shooting_gallery/scripts_ramon/hitscan_weapon_ramon.gd, cut
## down to the minimum needed for this first destructible-voxel test - there
## is no equip/switch-tool system anywhere in the project yet (this is the
## first second tool), so this is deliberately its own always-on Node rather
## than slotting into an existing weapon-switch pattern that doesn't exist.

## Meters. Melee range, not a hitscan weapon's reach.
const MINING_RANGE := 3.0

@onready var _player: CharacterBody4D = $"../Player"
@onready var _player_head: Node4D = $"../Player/PlayerHead"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_swing()


func _swing() -> void:
	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = _player_head.global_position
	ray_params.global_ray_direction = -_player_head.global_basis.z
	ray_params.set_exclude_nodes([_player])
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)
	if not result.get("hit", false):
		return
	if result.get("global_distance", INF) > MINING_RANGE:
		return

	# The raycast's "body" is the CollisionObject4D that owns the hit shape -
	# here that is always a VoxelMiningBlock's "Voxels" StaticBody4D child, so
	# its parent is the block itself.
	var hit_body: Object = result.get("body")
	if hit_body == null:
		return
	var block: Object = hit_body.get_parent()
	if block == null or not block.has_method("mine_at_shape"):
		return
	block.mine_at_shape(result.get("shape"))
