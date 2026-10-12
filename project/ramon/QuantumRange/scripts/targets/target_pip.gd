extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## PIP: a bare red core, bobbing gently. Round and alone: shoot it. One quick shot.
##
## The core is a lofted 4D ball (range_shapes.gd ball()): in any slice through it you see a sphere,
## smaller the further the slice is from its middle, gone past `radius` through W.

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

var radius: float = 0.42
var bob: float = 0.10


func build() -> void:
	family = "pip"
	var r: float = radius
	add_part("Core", "core", Shapes.ball(), Vector4(r * 1.8, r * 1.8, r * 1.8, r * 2.0), {"basis": Basis4D.from_scale_uniform(r)})


func animate(t: float, _dt: float) -> void:
	var core: Node4D = (parts[0]["node"] as Node4D)
	core.position = Vector4(0.0, sin(t * 2.2 + float(get_instance_id() % 7)) * bob, 0.0, 0.0)
