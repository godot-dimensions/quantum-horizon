extends Node
## Shooting gallery experiment: projectile-based weapon. Left-click ("fire")
## spawns a world-space Projectile4D (projectile_4d.gd) from the gun's
## muzzle along the camera's aim direction, which then travels on its own
## and resolves - hit or miss - once it actually reaches something or times
## out. This replaces the original instant hitscan raycast, kept below as
## _fire_hitscan() (disconnected from input) in case a side-by-side
## comparison is useful later.
##
## Ammo is still consumed immediately on trigger pull (a real round leaves
## the gun right away), but hits/misses/accuracy (CombatEvents.shot_fired)
## only update once the projectile actually resolves - firing and its
## outcome are no longer the same instant, so anything depending on that
## distinction has to wait for _on_projectile_resolved, not _fire().
##
## Reads Player/PlayerHead from outside rather than adding this to player.gd -
## firing doesn't need to touch movement or the existing rotate_4d raycast
## test, so there's no reason for it to live inside the controller script.

const PoofEffect4D := preload("res://scripts/poof_effect_4d.gd")
const Projectile4D := preload("res://scripts/projectile_4d.gd")

# Units/sec. ~0.6-0.8s to cross a typical engagement distance in this
# gallery (roughly 8-10 units, player to target) - fast enough to feel
# responsive, slow enough that leading a moving target is a real, perceptible
# skill rather than a formality. Tune by feel.
const PROJECTILE_SPEED := 12.0

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var player_head: Node4D = $"../FlatPlane/Player/PlayerHead"
@onready var first_person_camera: Node4D = $"../FlatPlane/Player/PlayerHead/FirstPersonCamera"
@onready var spawner: Node4D = $"../FlatPlane/GalleryTargetSpawner"
@onready var duck_spawner: Node4D = $"../FlatPlane/DuckRowSpawner"
@onready var contest_player: Node4D = $"../FlatPlane/ContestSequencePlayer"
@onready var gun_core: Node4D = $"../FlatPlane/Player/PlayerHead/FirstPersonCamera/GunViewmodel/Core"
@onready var gun_barrel: Node4D = $"../FlatPlane/Player/PlayerHead/FirstPersonCamera/GunViewmodel/Barrel"
@onready var ammo_pips: Node4D = $"../FlatPlane/Player/PlayerHead/FirstPersonCamera/GunViewmodel/AmmoPips"
@onready var projectiles: Node4D = $"../FlatPlane/Projectiles"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_fire()


func _fire() -> void:
	if not ammo_pips.can_fire():
		return
	ammo_pips.consume_round()
	gun_core.pulse()

	var projectile := Node4D.new()
	projectile.set_script(Projectile4D)
	projectile.speed = PROJECTILE_SPEED
	# The gun model's own orientation isn't necessarily co-linear with actual
	# aim (see the Core's independent spin) - use the camera's forward,
	# Aaron's original raycast pattern, not the barrel's basis.
	projectile.direction = (-first_person_camera.global_basis.z).normalized()
	projectile.exclude_nodes = [player]
	projectile.on_resolved = _on_projectile_resolved
	projectiles.add_child(projectile)
	# Muzzle point for visual consistency with the gun model, independent of
	# the aim direction above.
	projectile.global_position = gun_barrel.global_position


func _on_projectile_resolved(hit: bool, hit_body: Object, global_point: Vector4) -> void:
	var caught := false
	if hit and hit_body != null:
		caught = spawner.try_catch_target(hit_body)
		if not caught:
			caught = duck_spawner.try_hit_duck(hit_body)
		if not caught:
			caught = contest_player.try_hit_target(hit_body)
		if caught:
			_spawn_poof(global_point)
	CombatEvents.shot_fired.emit(caught)


func _spawn_poof(at_position: Vector4) -> void:
	var poof := Node4D.new()
	poof.set_script(PoofEffect4D)
	spawner.add_child(poof)
	poof.global_position = at_position


# --- Disconnected - kept intact for reference / side-by-side comparison. ---
# The original instant hitscan raycast. No longer wired to any input; call
# it directly if needed.
func _fire_hitscan() -> void:
	if not ammo_pips.can_fire():
		return
	ammo_pips.consume_round()
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
	var caught := false
	if result.get("hit", false):
		var hit_body: Object = result["body"]
		caught = spawner.try_catch_target(hit_body)
		if not caught:
			caught = duck_spawner.try_hit_duck(hit_body)
		if caught:
			_spawn_poof(result.get("global_point", hit_body.global_position))
	CombatEvents.shot_fired.emit(caught)
