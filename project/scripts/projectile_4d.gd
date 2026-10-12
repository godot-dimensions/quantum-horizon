extends Node4D
## Shooting gallery experiment: fire-and-forget world-space projectile,
## replacing the instant hitscan raycast (see hitscan_weapon.gd's own
## _fire_hitscan(), kept intact but disconnected). Not parented to the
## camera/gun - once fired this is a fully independent world object. If the
## player rotates away and it leaves their visible slice mid-flight, that's
## correct behavior for an independent object, not a bug.
##
## Entirely self-contained (builds its own mesh in _ready(), matching
## poof_effect_4d.gd's convention) - instantiate via
## preload("res://scripts/projectile_4d.gd"), set_script() onto a fresh
## Node4D, set direction/speed/exclude_nodes/on_resolved, add it as a child
## of any Node4D, then set its global_position.
##
## Hit detection avoids tunneling through fast-moving/thin targets by
## raycasting the actual travel segment each tick (pre-tick position to
## post-tick position, bounded by RaycastParameters4D.max_distance), rather
## than only checking overlap at the new position.

const PROJECTILE_SIZE := 0.05
const PROJECTILE_COLOR := Color(1.0, 0.95, 0.3, 1.0)
const MAX_LIFETIME_SEC := 3.0
const MAX_TRAVEL_DISTANCE := 40.0

var speed: float = 12.0
var direction: Vector4 = Vector4(0, 0, -1, 0)
var exclude_nodes: Array = []
## Called exactly once when the projectile resolves, as
## on_resolved.call(hit: bool, hit_body: Object, global_point: Vector4).
var on_resolved: Callable = Callable()

var _age_sec: float = 0.0
var _traveled_distance: float = 0.0
var _resolved: bool = false


func _ready() -> void:
	var mesh_instance := MeshInstance4D.new()
	var projectile_mesh := BoxTetraMesh4D.new()
	projectile_mesh.size = Vector4(PROJECTILE_SIZE, PROJECTILE_SIZE, PROJECTILE_SIZE, PROJECTILE_SIZE)
	mesh_instance.mesh = projectile_mesh
	var material := TetraMaterial4D.new()
	material.albedo_color = PROJECTILE_COLOR
	mesh_instance.material_override = material
	add_child(mesh_instance)


func _physics_process(delta: float) -> void:
	var pre_pos: Vector4 = global_position
	var step: Vector4 = direction * speed * delta
	var step_length: float = step.length()
	global_position = pre_pos + step
	_age_sec += delta
	_traveled_distance += step_length

	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = pre_pos
	ray_params.global_ray_direction = direction
	ray_params.max_distance = maxf(step_length, 0.001)
	ray_params.collide_with_areas = true
	ray_params.set_exclude_nodes(exclude_nodes)
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)
	if result.get("hit", false):
		_resolve(true, result.get("body"), result.get("global_point", global_position))
		return

	if _age_sec >= MAX_LIFETIME_SEC or _traveled_distance >= MAX_TRAVEL_DISTANCE:
		_resolve(false, null, global_position)


func _resolve(hit: bool, hit_body: Object, global_point: Vector4) -> void:
	if _resolved:
		return
	_resolved = true
	if on_resolved.is_valid():
		on_resolved.call(hit, hit_body, global_point)
	queue_free()
