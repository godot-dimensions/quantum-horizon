class_name TerrainCreature4D
extends Node4D
## Basic "alive and moving" behavior for a creature cube - no pathfinding,
## no boid rules (separation/alignment/cohesion) yet, deliberately: this
## confirms the land-bound wander + continuous ground-tracking piece in
## isolation first, so a later boid-rules pass has a known-good baseline
## to build on rather than debugging both layers at once.
##
## Movement is a simple "walk toward a random nearby point, repeat" wander:
## x/z/w move at a constant speed toward _target_xzw; y is NEVER moved
## directly by the wander step - it's re-derived every frame from a fresh
## downward raycast against the terrain's real ConcaveMeshShape4D
## collision (the same PhysicsServer4D + RaycastParameters4D pattern
## already proven for click-to-edit and initial creature placement in
## terrain4d_voxel_showcase.gd), so the creature stays glued to the actual
## surface height as it crosses slopes and bumps, rather than sliding
## along its original spawn height.

@export var speed: float = 2.0
@export var wander_radius: float = 4.0
@export var arrival_threshold: float = 0.3
@export var half_height: float = 0.3  ## half the creature's own box height, so it rests ON the surface, not through it
@export var ground_probe_height: float = 20.0
@export var ground_max_ray_distance: float = 40.0
## Only the populated footprint has terrain to walk on - wander targets are
## clamped to this box (in the SAME local/generation space `position` is
## in) so a creature doesn't wander into ungenerated space and lose the
## ground entirely. Y components are ignored (height is never targeted
## directly).
@export var wander_min: Vector4 = Vector4(-10, 0, -10, -10)
@export var wander_max: Vector4 = Vector4(10, 0, 10, 10)

var _target_xzw: Vector4

func _ready() -> void:
	_pick_new_target()

func _process(delta: float) -> void:
	_step_toward_target(delta)
	_update_ground_height()

func _step_toward_target(delta: float) -> void:
	var to_target := Vector4(_target_xzw.x - position.x, 0.0, _target_xzw.z - position.z, _target_xzw.w - position.w)
	var dist := to_target.length()
	if dist <= arrival_threshold:
		_pick_new_target()
		return
	var move := to_target.normalized() * minf(speed * delta, dist)
	position.x += move.x
	position.z += move.z
	position.w += move.w

func _pick_new_target() -> void:
	_target_xzw = Vector4(
		clampf(position.x + randf_range(-wander_radius, wander_radius), wander_min.x, wander_max.x),
		0.0,
		clampf(position.z + randf_range(-wander_radius, wander_radius), wander_min.z, wander_max.z),
		clampf(position.w + randf_range(-wander_radius, wander_radius), wander_min.w, wander_max.w)
	)

## Same broadphase raycast pattern proven for click-to-edit and initial
## creature placement - re-derives the hit point from global_distance
## since ConcaveMeshShape4D's own raycast_intersects() never sets a
## "point" key. Uses get_parent()'s transform rather than a separately
## passed rig reference: this node's own `position` is already local to
## whatever parent it's under, and as long as that parent is the same
## un-rotated generation-space node the terrain itself lives under (true
## however this is spawned, since it's what makes `position` meaningful
## as a wander/terrain coordinate at all), this manual conversion and
## Godot's own global_position math agree.
func _update_ground_height() -> void:
	var parent_basis: Projection = get_parent().global_basis
	var parent_pos: Vector4 = get_parent().global_position
	var probe_local := Vector4(position.x, ground_probe_height, position.z, position.w)
	var ray_params := RaycastParameters4D.new()
	ray_params.global_ray_origin = parent_pos + parent_basis * probe_local
	ray_params.global_ray_direction = Vector4(0.0, -1.0, 0.0, 0.0)
	ray_params.max_distance = ground_max_ray_distance
	var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)
	if not result.get("hit", false):
		return  # keep the last known-good height rather than snapping to something wrong
	var world_point: Vector4 = ray_params.global_ray_origin + ray_params.global_ray_direction * float(result.global_distance)
	var inverse_basis: Projection = parent_basis.inverse()
	var local_point: Vector4 = inverse_basis * (world_point - parent_pos)
	position.y = local_point.y + half_height
