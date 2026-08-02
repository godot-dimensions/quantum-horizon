extends Node
## Shooting gallery experiment: hitscan replacement for the F-key/proximity
## catch check. Left-click ("fire") raycasts from the player's head along its
## forward direction - Aaron's confirmed-working pattern (see player.gd's own
## rotate_4d raycast test) - and, if it hits the spawner's current target,
## triggers the same despawn+respawn/timer logic already built.
##
## Reads Player/PlayerHead from outside rather than adding this to player.gd -
## firing doesn't need to touch movement or the existing rotate_4d raycast
## test, so there's no reason for it to live inside the controller script.

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var player_head: Node4D = $"../FlatPlane/Player/PlayerHead"
@onready var spawner: Node4D = $"../FlatPlane/GalleryTargetSpawner"
@onready var duck_spawner: Node4D = $"../FlatPlane/DuckRowSpawner"
@onready var gun_core: Node4D = $"../FlatPlane/Player/PlayerHead/FirstPersonCamera/GunViewmodel/Core"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_fire()

func _fire() -> void:
	gun_core.pulse()
	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = player_head.global_position
	ray_params.global_ray_direction = -player_head.global_basis.z
	# Targets are Area4D (non-solid, detection-only) - raycasts don't collide
	# with areas by default, so this must be opted into explicitly.
	ray_params.collide_with_areas = true
	# inside_is_skip (default true) already keeps the ray from hitting the
	# player's own capsule since the ray origin sits inside it, but exclude
	# the player explicitly too, per Aaron's own comment on set_exclude_nodes -
	# robust against the ray origin ever moving outside the capsule later.
	ray_params.set_exclude_nodes([player])
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)
	if not result.get("hit", false):
		return
	var hit_body: Object = result["body"]
	if spawner.try_catch_target(hit_body):
		return
	duck_spawner.try_hit_duck(hit_body)
