extends Node
## Rail mode's dedicated weapon - fork of the shared hitscan_weapon.gd (fires
## Projectile4D the same way, same PROJECTILE_SPEED), but two deliberate
## differences: unlimited ammo (this mode is about aim/slice precision, not
## resource management - no AmmoPips instanced in this scene), and a
## resolution path that scores two independent numbers per hit (see
## bullseye_target.gd) instead of a hit/miss counter. Reported through a
## dedicated shot_resolved signal rather than CombatEvents.shot_fired - that
## signal's payload is a single bool, which can't carry two independent
## scores.
##
## Resolution just forwards hit_body/global_point to whichever spawner is
## wired in and reports back exactly what it returns - it doesn't reach into
## the spawner's own internals (no "_current_target" lookup), so this script
## works unchanged against any spawner that implements try_hit_target(body,
## global_point) -> {"hit", "ring_score", "slice_score_percent"}, whether
## that's a single always-one-active-target spawner or rail_target_
## spawner.gd's fixed multi-target lineup.

const PoofEffect4D := preload("res://scripts/poof_effect_4d.gd")
const Projectile4D := preload("res://scripts/projectile_4d.gd")

const PROJECTILE_SPEED := 12.0 # Same as the shared weapon - already proven "responsive but leadable" feel.

## slice_score_percent and ring_score are only meaningful when hit is true -
## both are 0 on a miss (no target struck at all, as opposed to striking the
## target but scoring 0 rings, which is a real, distinct outcome reported as
## hit=true, ring_score=0).
signal shot_resolved(hit: bool, ring_score: int, slice_score_percent: int)

@onready var player: CharacterBody4D = $"../FlatPlane/Player"
@onready var first_person_camera: Node4D = $"../FlatPlane/Player/PlayerHead/FirstPersonCamera"
@onready var gun_core: Node4D = $"../FlatPlane/Player/PlayerHead/FirstPersonCamera/GunViewmodel/Core"
@onready var gun_barrel: Node4D = $"../FlatPlane/Player/PlayerHead/FirstPersonCamera/GunViewmodel/Barrel"
@onready var spawner: Node4D = $"../FlatPlane/RailTargetSpawner"
@onready var projectiles: Node4D = $"../FlatPlane/Projectiles"


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"fire"):
		_fire()


func _fire() -> void:
	gun_core.pulse()
	var projectile := Node4D.new()
	projectile.set_script(Projectile4D)
	projectile.speed = PROJECTILE_SPEED
	projectile.direction = (-first_person_camera.global_basis.z).normalized()
	projectile.exclude_nodes = [player]
	projectile.on_resolved = _on_projectile_resolved
	projectiles.add_child(projectile)
	projectile.global_position = gun_barrel.global_position


func _on_projectile_resolved(hit: bool, hit_body: Object, global_point: Vector4) -> void:
	if not hit or hit_body == null:
		shot_resolved.emit(false, 0, 0)
		return
	var result: Dictionary = spawner.try_hit_target(hit_body, global_point)
	if not result.hit:
		shot_resolved.emit(false, 0, 0)
		return
	_spawn_poof(global_point)
	shot_resolved.emit(true, result.ring_score, result.slice_score_percent)


func _spawn_poof(at_position: Vector4) -> void:
	var poof := Node4D.new()
	poof.set_script(PoofEffect4D)
	spawner.add_child(poof)
	poof.global_position = at_position
