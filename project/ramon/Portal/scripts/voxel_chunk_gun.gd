extends Node
## Shoot the chunked wall as often as you like; every cut accumulates.

const RANGE := 60.0
## Wide enough that a hole is a doorway rather than a porthole - the player is
## 1.75 m tall and 0.5 m across, and the point of this range is to walk through
## into the room behind.
const CARVE_RADIUS := 1.35

## Only the player is looked up by path, so this node can be dropped into any
## scene that has one - it finds the wall through the raycast rather than
## needing to know the scene's layout.
@onready var _player: CharacterBody4D = $"../Player"
@onready var _player_head: Node4D = $"../Player/PlayerHead"

var last_shot_status: String = "no shots yet"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_shoot()


func _shoot() -> void:
	var ray := RaycastParameters4D.new()
	ray.global_ray_origin = _player_head.global_position
	ray.global_ray_direction = -_player_head.global_basis.z
	ray.set_exclude_nodes([_player])
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray)
	if not result.get("hit", false) or result.get("global_distance", INF) > RANGE:
		last_shot_status = "nothing in range"
		return

	# A chunk's colliders live on its "Voxels" body, whose parent is the chunk and
	# whose grandparent is the wall.
	var body: Object = result.get("body")
	var chunk: Object = body.get_parent() if body != null else null
	var wall: Object = chunk.get_parent() if chunk != null else null
	if wall == null or not wall.has_method("carve_at"):
		last_shot_status = "that surface is not carvable"
		return

	var dirty: int = wall.carve_at(result.get("global_point", Vector4.ZERO), CARVE_RADIUS)
	# last_rebuild_msec, not last_carve_msec: the wall rebuilds chunks for the
	# heal animation too, not only for the shot that started it.
	last_shot_status = "carve %d: %d chunks rebuilt in %.0f ms (%d tetrahedra total)" % [
		wall.carves.size(), dirty, wall.last_rebuild_msec, wall.total_tetra_count()]
	print("[VoxelChunk] ", last_shot_status)
