extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## AMBER BLOCK: a solid of amber armour, faceted (the 24-cell, the 4D solid with no 3D counterpart, its
## 24 octahedral cells reading as facets in any slice). Heavy: only a charged shot breaks it; a quick shot
## scuffs it and does nothing else. It turns slowly so its facets catch the light.

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

var radius: float = 0.6


func build() -> void:
	family = "block"
	var r: float = radius
	add_part("Armour", "armour", Shapes.cell24(), Vector4(r * 1.7, r * 1.7, r * 1.7, r * 1.7), {"basis": Basis4D.from_scale_uniform(r), "vital": true})


func animate(t: float, _dt: float) -> void:
	var mi: MeshInstance4D = parts[0]["mesh"]
	if float(parts[0]["dying"]) < 0.0 and _appear_done():
		mi.basis = Basis4D.from_scale_uniform(radius) * Basis4D.from_zx(t * 0.35)


func _appear_done() -> bool:
	return age > 0.35
