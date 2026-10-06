extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## RING GATE: a cyan ring that marks a red core far off in another slice. The ring itself is deep through
## W (a spheritorus stretched along W), so it stays in view while you turn your slice; the core is a small
## ball beyond it, further through W than you can step. Turn your slice (hold the right mouse button) until
## the core shows inside the ring: the ring lights when your slice cuts the core. The ring is a guide,
## cyan, and has no hitbox: shots pass through it.
##
## The target stands where the core is; the ring hangs `ring_at` from it (towards you).

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

var core_r: float = 0.4
var ring_r: float = 0.85
## Where the ring hangs relative to the core.
var ring_at: Vector4 = Vector4(0, 0, 6, 0)
## How deep through W the ring reaches either side.
var ring_w: float = 3.5
## The camera whose slice lights the ring (set by whoever spawns it).
var camera: Camera4D
var lit: bool = false

var _dim: TetraMaterial4D
var _bright: TetraMaterial4D


func build() -> void:
	family = "ring"
	add_part("Core", "core", Shapes.ball(), Vector4(core_r * 1.8, core_r * 1.8, core_r * 1.8, core_r * 2.0),
		{"basis": Basis4D.from_scale_uniform(core_r)})
	# The primitive (models/primitives/spheritorus) is a circle of radius 2 in its x/z, thickened by 0.25 in
	# y and w (measured, _probe_primitives_runner.gd): a quarter turn in y/z stands the circle up in x/y,
	# facing you, then it is scaled, and stretched along W so it stays in view as your slice turns.
	var k: float = ring_r / 2.0
	add_part("Ring", "w", Shapes.spheritorus(), Vector4.ZERO,
		{"at": ring_at, "basis": Basis4D.from_scale(Vector4(k, k, k * 0.6, ring_w / 0.25)) * Basis4D.from_yz(PI * 0.5), "glow": true, "radar": true})
	_dim = Mats.glow(Color(0.05, 0.62, 0.95))
	_bright = Mats.glow(Color(0.65, 1.0, 1.0))


func animate(_t: float, _dt: float) -> void:
	var ring: Dictionary = parts[1]
	if age < 0.35 or camera == null or not camera.is_inside_tree():
		return
	var core: Node4D = parts[0]["node"]
	var off: float = absf((core.global_position - camera.global_position).dot(camera.global_basis.w))
	lit = off <= core_r * 0.9 and bool(parts[0]["alive"])
	(ring["mesh"] as MeshInstance4D).material_override = _bright if lit else _dim
