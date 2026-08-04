extends Node4D
## Ramon-only fork of poof_effect_4d.gd - identical "fling particles outward
## in random 4D directions, shrink and fade, self-destruct" shape and same
## single flat particle color; the only change is a bigger PARTICLE_SIZE.
## An earlier version of this fork also added a separate expanding "flash"
## mesh at the impact center, but that read as a pointless little white
## blob and added nothing, so it's gone - back to the original's particles-
## only look, just a bit bigger.

const PARTICLE_COUNT := 10
const LIFETIME_SEC := 0.4
const BURST_SPEED := 4.0
const PARTICLE_SIZE := 0.1 # Original was 0.06 - "a little bigger."
const PARTICLE_COLOR := Color(1.0, 0.9, 0.3, 1.0)

var _particles: Array = [] # Each: {"node": MeshInstance4D, "velocity": Vector4}.
var _shared_material: TetraMaterial4D
var _age_sec: float = 0.0


func _ready() -> void:
	var particle_mesh := BoxTetraMesh4D.new()
	particle_mesh.size = Vector4(PARTICLE_SIZE, PARTICLE_SIZE, PARTICLE_SIZE, PARTICLE_SIZE)
	_shared_material = TetraMaterial4D.new()
	_shared_material.albedo_color = PARTICLE_COLOR

	for i in PARTICLE_COUNT:
		var particle := MeshInstance4D.new()
		particle.mesh = particle_mesh
		particle.material_override = _shared_material
		add_child(particle)
		var direction: Vector4 = Vector4(
			randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
		).normalized()
		_particles.append({"node": particle, "velocity": direction * BURST_SPEED})


func _process(delta: float) -> void:
	_age_sec += delta
	var t: float = clampf(_age_sec / LIFETIME_SEC, 0.0, 1.0)
	var base_scale: float = lerpf(1.0, 0.0, t)
	var scale_basis: Projection = Basis4D.from_scale_uniform(base_scale)
	for entry in _particles:
		var particle: MeshInstance4D = entry["node"]
		particle.position += entry["velocity"] * delta
		particle.basis = scale_basis
	_shared_material.albedo_color.a = 1.0 - t

	if _age_sec >= LIFETIME_SEC:
		queue_free()
