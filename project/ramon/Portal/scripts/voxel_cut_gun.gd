extends Node
## Shoot a wall, get a voxel patch with a round hole in it.

const RANGE := 60.0

@onready var _player: CharacterBody4D = $"../Player"
@onready var _player_head: Node4D = $"../Player/PlayerHead"

var last_shot_status: String = "no shots yet"
var last_cut_msec: float = 0.0
var last_collider_count: int = 0
var last_tetra_count: int = 0


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_shoot()


func _shoot() -> void:
	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = _player_head.global_position
	ray_params.global_ray_direction = -_player_head.global_basis.z
	ray_params.set_exclude_nodes([_player])
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)

	if not result.get("hit", false) or result.get("global_distance", INF) > RANGE:
		last_shot_status = "nothing in range"
		return
	var hit_body: Object = result.get("body")
	if hit_body == null:
		last_shot_status = "nothing solid"
		return
	# A cuttable wall owns a "Solid" StaticBody4D, so the wall is its parent. A
	# patch's own "Voxels" body resolves to the patch, which has no cut_at.
	var wall: Object = hit_body.get_parent()
	if wall == null or not wall.has_method("cut_at"):
		last_shot_status = "that surface cannot be cut"
		return

	var hit_point: Vector4 = result.get("global_point", Vector4.ZERO)
	if not wall.cut_at(hit_point):
		last_shot_status = "no room on that wall for a patch"
		return

	var patch: Node4D = wall.patch
	last_cut_msec = patch.build_msec
	last_collider_count = patch.collider_count
	last_tetra_count = patch.tetra_count
	last_shot_status = "cut %s in %.0f ms (%d tetrahedra, %d colliders)" % [
		wall.name, last_cut_msec, last_tetra_count, last_collider_count]
	print("[VoxelCut] ", last_shot_status)
