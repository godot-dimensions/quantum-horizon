extends Node4D
## Shooting gallery experiment: simple 4D "poof" burst on a target hit - a
## handful of tiny cubes flung outward in random 4D directions (not just
## random 3D directions - genuinely sampled across all four axes, so the
## burst has real ana/kata spread too, not just a flat 3D puff), shrinking
## and fading out over a short lifetime, then self-destructing.
##
## Entirely self-contained (builds its own mesh/material in _ready(),
## rather than needing a companion .tscn) - instantiate via
## preload("res://scripts/poof_effect_4d.gd"), set_script() onto a fresh
## Node4D, add it as a child of any Node4D, then set its global_position.

const PARTICLE_COUNT := 10
const LIFETIME_SEC := 0.4
const BURST_SPEED := 4.0
const PARTICLE_SIZE := 0.06
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
	var scale: float = lerpf(1.0, 0.0, t)
	var scale_basis := Projection(
		Vector4(scale, 0, 0, 0), Vector4(0, scale, 0, 0), Vector4(0, 0, scale, 0), Vector4(0, 0, 0, scale)
	)
	for entry in _particles:
		var particle: MeshInstance4D = entry["node"]
		particle.position += entry["velocity"] * delta
		particle.basis = scale_basis
	_shared_material.albedo_color.a = 1.0 - t

	if _age_sec >= LIFETIME_SEC:
		queue_free()
