extends Node4D
## Ramon-only "green spheres" experiment: small, fast, erratically-moving
## targets that show up intermittently rather than being constantly
## present - up to MAX_ACTIVE at once, each on its own random appear/
## despawn timer. "Sphere" here means OrthoplexTetraMesh4D (the roundest
## built-in generator mesh available - there's no true 4D sphere/glome
## generator class in this engine, same conclusion reached earlier when
## picking shapes for the blocker showcase), scaled down small.
##
## Movement is deliberately NOT the blockers' smooth sine-wobble - it picks
## a brand new random direction and speed every ERRATIC_INTERVAL_SEC, which
## reads as darting/skittish rather than floating. Combined with a small
## hitbox and 1 hp, the difficulty here is entirely about aim/tracking, not
## endurance - same reasoning as giving the yellow target only 1 hp.
##
## Also gets a small bouncy squash/stretch "pop" pulse each time it changes
## direction - a uniform scale pulse, not a true velocity-aligned stretch
## (which would need deriving an arbitrary 4D orthonormal basis from a
## constantly-changing direction vector - the same Gram-Schmidt-style
## problem ray_beam_ramon.gd sidesteps by reusing an existing basis; here
## there's no convenient existing basis to reuse since the direction
## changes every fraction of a second). A uniform pulse gets a similar
## "juicy" feel without that complexity.
##
## Spawn/despawn are a smooth grow-in/shrink-out (transition_t, ramped via
## move_toward) rather than an instant appear/disappear - popping fully-
## formed into existence and vanishing outright read as an abrupt glitch
## more than a deliberate "here and gone" moment. try_hit_sphere marks a
## slot as despawning (immediately un-hittable, so it can't register a
## second hit mid-shrink) rather than removing the node on the spot; actual
## queue_free only happens once the shrink-out finishes.

const MAX_ACTIVE := 3
const MIN_APPEAR_DELAY_SEC := 3.0
const MAX_APPEAR_DELAY_SEC := 9.0
const LIFETIME_SEC := 6.0 # Despawns and re-hides itself if never shot.

const SPAWN_X_RANGE := 8.0
const SPAWN_Z_RANGE := 4.0
const SPAWN_W_RANGE := 4.0
const SPAWN_Y_MIN := 1.0
const SPAWN_Y_MAX := 3.5

const SPHERE_SCALE := 0.35
const SPEED := 3.2 # Meters per second - much faster than the blockers' slow patrol.
const ERRATIC_INTERVAL_MIN := 0.15
const ERRATIC_INTERVAL_MAX := 0.4
const WANDER_RADIUS := 3.0 # How far it's allowed to roam from its own spawn point before steering back.

const POP_AMOUNT := 0.35
const POP_DECAY_RATE := 10.0

const GROW_RATE := 3.5 # transition_t units per second - reaches full size in ~0.3s.
const SHRINK_RATE := 4.5 # Slightly faster than growing - shrink-outs should feel snappier, not lingering.

var _slots: Array = [] # Array of Dictionary: {node, mesh_instance, active, despawning, transition_t, spawn_pos, velocity, erratic_timer, life_timer, appear_timer, pop}


func _ready() -> void:
	for i in MAX_ACTIVE:
		_slots.append({
			"node": null,
			"mesh_instance": null,
			"active": false,
			"despawning": false,
			"transition_t": 0.0,
			"spawn_pos": Vector4.ZERO,
			"velocity": Vector4.ZERO,
			"erratic_timer": 0.0,
			"life_timer": 0.0,
			"appear_timer": randf_range(MIN_APPEAR_DELAY_SEC, MAX_APPEAR_DELAY_SEC),
			"pop": 0.0,
		})


func _process(delta: float) -> void:
	for slot in _slots:
		if not slot.active:
			slot.appear_timer -= delta
			if slot.appear_timer <= 0.0:
				_spawn_sphere(slot)
			continue

		if slot.despawning:
			slot.transition_t = move_toward(slot.transition_t, 0.0, SHRINK_RATE * delta)
			if slot.transition_t <= 0.0:
				_finish_despawn(slot)
				continue
		else:
			slot.transition_t = move_toward(slot.transition_t, 1.0, GROW_RATE * delta)
			slot.erratic_timer -= delta
			if slot.erratic_timer <= 0.0:
				_pick_new_direction(slot)
				slot.pop = POP_AMOUNT

			slot.node.position += slot.velocity * delta
			# Steer back if it's wandered too far from its own spawn point, rather
			# than letting it drift off into the void indefinitely.
			if slot.node.position.distance_to(slot.spawn_pos) > WANDER_RADIUS:
				slot.velocity = (slot.spawn_pos - slot.node.position).normalized() * SPEED

			slot.life_timer -= delta
			if slot.life_timer <= 0.0:
				_start_despawn(slot)

		slot.pop *= exp(-POP_DECAY_RATE * delta)
		var base_scale: float = SPHERE_SCALE * (1.0 + slot.pop) * slot.transition_t
		slot.mesh_instance.basis = Basis4D.from_scale_uniform(base_scale)


## Called by hitscan_weapon_ramon.gd. Returns whether the hit body was one of
## the active (not already despawning) spheres.
func try_hit_sphere(hit_body: Object) -> bool:
	for slot in _slots:
		if slot.active and not slot.despawning and slot.node == hit_body:
			_start_despawn(slot)
			return true
	return false


func _spawn_sphere(slot: Dictionary) -> void:
	var area := Area4D.new()
	add_child(area)
	area.position = Vector4(
		randf_range(-SPAWN_X_RANGE, SPAWN_X_RANGE),
		randf_range(SPAWN_Y_MIN, SPAWN_Y_MAX),
		randf_range(-SPAWN_Z_RANGE, SPAWN_Z_RANGE),
		randf_range(-SPAWN_W_RANGE, SPAWN_W_RANGE),
	)

	var collision_shape := CollisionShape4D.new()
	var box_shape := BoxShape4D.new()
	box_shape.size = Vector4.ONE * SPHERE_SCALE * 1.1 # Small hitbox - the erratic movement is the real difficulty, not a tiny target on top of that.
	collision_shape.shape = box_shape
	area.add_child(collision_shape)

	var mesh_instance := MeshInstance4D.new()
	mesh_instance.mesh = OrthoplexTetraMesh4D.new()
	var material := TetraMaterial4D.new()
	material.albedo_color = Color(0.15, 0.9, 0.25, 1.0)
	mesh_instance.material_override = material
	area.add_child(mesh_instance)

	slot.node = area
	slot.mesh_instance = mesh_instance
	slot.active = true
	slot.despawning = false
	slot.transition_t = 0.0
	slot.spawn_pos = area.position
	slot.life_timer = LIFETIME_SEC
	slot.pop = POP_AMOUNT
	_pick_new_direction(slot)


func _pick_new_direction(slot: Dictionary) -> void:
	var direction: Vector4 = Vector4(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	).normalized()
	slot.velocity = direction * SPEED
	slot.erratic_timer = randf_range(ERRATIC_INTERVAL_MIN, ERRATIC_INTERVAL_MAX)


func _start_despawn(slot: Dictionary) -> void:
	slot.despawning = true


func _finish_despawn(slot: Dictionary) -> void:
	slot.node.queue_free()
	slot.node = null
	slot.mesh_instance = null
	slot.active = false
	slot.despawning = false
	slot.appear_timer = randf_range(MIN_APPEAR_DELAY_SEC, MAX_APPEAR_DELAY_SEC)
