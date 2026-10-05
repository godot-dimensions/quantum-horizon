extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## DRONE: a core with three fins, flying a lane towards the firing line (Incoming). It moves, so lead it.
## Three kinds, told apart by colour and build:
##   red        a bare red core: a quick shot
##   heavy      the core inside an amber casing: charge it
##   friendly   green, with a cross in place of a core: do not shoot
## The fins are decoration (no hitbox); they spin about the line of flight.

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

## "red", "heavy" or "friendly".
var kind: String = "red"
var core_r: float = 0.36

var _fins: Node4D


func build() -> void:
	family = "drone_" + kind
	match kind:
		"friendly":
			_cross()
		"heavy":
			add_part("Core", "core", Shapes.ball(), Vector4(core_r * 1.6, core_r * 1.6, core_r * 1.6, core_r * 1.8),
				{"basis": Basis4D.from_scale_uniform(core_r * 0.8)})
			add_part("Casing", "armour", Shapes.cell24(), Vector4(core_r * 3.0, core_r * 3.0, core_r * 3.0, core_r * 3.0),
				{"basis": Basis4D.from_scale_uniform(core_r * 1.7)})
		_:
			add_part("Core", "core", Shapes.ball(), Vector4(core_r * 1.8, core_r * 1.8, core_r * 1.8, core_r * 2.0),
				{"basis": Basis4D.from_scale_uniform(core_r)})
	_fins = Node4D.new()
	_fins.name = "Fins"
	add_child(_fins)
	for i in 3:
		var a: float = TAU * float(i) / 3.0
		var fin := MeshInstance4D.new()
		fin.mesh = Shapes.fin()
		fin.material_override = Mats.lit(Color(0.92, 0.93, 0.95) if kind != "friendly" else Color(0.80, 0.95, 0.84))
		fin.basis = Basis4D.from_xy(a) * Basis4D.from_scale(Vector4(0.7, 0.62, 0.7, 0.7))
		_fins.add_child(fin)


## The friendly's cross: four bars, one along each axis, x, y, z and w (range_shapes.gd cross()); in any
## slice it reads as a plus.
func _cross() -> void:
	add_part("Cross", "friend", Shapes.cross(0.85, 0.2), Vector4(0.85, 0.85, 0.85, 0.85), {"vital": true})


func animate(t: float, _dt: float) -> void:
	if _fins != null and alive:
		_fins.basis = Basis4D.from_xy(t * 3.0)
