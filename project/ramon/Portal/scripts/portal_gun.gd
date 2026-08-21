extends Node
## Ranged carve tool: the same raycast-then-dispatch shape as VoxelMining's
## mining_axe.gd, at portal range rather than melee range, and reporting why a
## shot did nothing rather than silently ignoring it.
##
## That last part is Valve's rule, not decoration: an invalid surface has to
## answer visibly ("the projectile splashes, no density edit") or the player
## reads a refusal as a bug. This is the text-readout version of that, which is
## all the feedback milestone A needs.

## Metres. Long enough to cross the chamber, so panels can be hit from the far
## side - which is the point of a ranged tool over the mining axe.
const RANGE := 60.0
## Metres of rock removed per shot. Roughly VoxelMining's bite scaled to this
## panel's coarser cells: a person-sized opening should take a handful of shots,
## not dozens, and not one.
const CARVE_RADIUS := 0.6

@onready var _player: CharacterBody4D = $"../Player"
@onready var _player_head: Node4D = $"../Player/PlayerHead"

var last_shot_status: String = "no shots yet"
var carve_count: int = 0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_fire()


func _fire() -> void:
	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = _player_head.global_position
	ray_params.global_ray_direction = -_player_head.global_basis.z
	ray_params.set_exclude_nodes([_player])
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)

	if not result.get("hit", false):
		last_shot_status = "missed - nothing in range"
		return
	var distance: float = result.get("global_distance", INF)
	if distance > RANGE:
		last_shot_status = "out of range (%.1f m)" % distance
		return

	# The hit shape's owner is a panel's "Voxels" StaticBody4D, so the panel
	# itself is its parent - same relationship mining_axe.gd relies on.
	var hit_body: Object = result.get("body")
	if hit_body == null:
		last_shot_status = "hit nothing solid"
		return
	var panel: Object = hit_body.get_parent()
	if panel == null or not panel.has_method("carve_at_shape"):
		last_shot_status = "surface refuses portals (%.1f m)" % distance
		return

	if not panel.carve_at_shape(result.get("shape"), CARVE_RADIUS):
		last_shot_status = "panel hit, but that voxel was already gone"
		return

	carve_count += 1
	last_shot_status = "carved %s at %.1f m (%.0f ms)" % [panel.name, distance, panel.last_carve_msec]
