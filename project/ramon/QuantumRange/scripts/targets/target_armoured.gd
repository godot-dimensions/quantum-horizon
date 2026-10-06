extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## ARMOURED CORE: a red core inside an amber casing. Two steps, and its construction says so: charge
## to crack the casing, then tap the core it was hiding. The casing's hitbox encloses the core's, so a
## shot meets the casing first while it is there.

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

var radius: float = 0.66


func build() -> void:
	family = "armoured"
	var r: float = radius
	add_part("Core", "core", Shapes.ball(), Vector4(r * 0.9, r * 0.9, r * 0.9, r * 1.0), {"basis": Basis4D.from_scale_uniform(r * 0.45)})
	add_part("Casing", "armour", Shapes.cell24(), Vector4(r * 1.75, r * 1.75, r * 1.75, r * 1.75), {"basis": Basis4D.from_scale_uniform(r)})


func animate(t: float, _dt: float) -> void:
	var casing: Dictionary = parts[1]
	if bool(casing["alive"]) and age > 0.35:
		(casing["mesh"] as MeshInstance4D).basis = Basis4D.from_scale_uniform(radius) * Basis4D.from_zx(t * 0.3)
	var core: Dictionary = parts[0]
	if not bool(casing["alive"]) and bool(core["alive"]) and age > 0.35:
		# Exposed: it pulses.
		var k: float = 1.0 + sin(t * 9.0) * 0.08
		(core["mesh"] as MeshInstance4D).basis = Basis4D.from_scale_uniform(radius * 0.45 * k)
