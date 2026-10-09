extends Node4D

## WATER LAB: the specks hanging in the tank's water (Ramon, 9 Oct: "and make small particles in the
## tank"): a thousand and a half bits of marine snow, written once (life/snow.gdshader drifts and sinks
## them on the GPU), spread through the water's whole 4D box so a turned slice finds others. In the
## water's own frame (life/).
##
## NO class_name (engine_gotchas.md).

const Herd := preload("res://ramon/WaterLab/shared/slice_herd_4d.gd")
const SHADER := preload("res://ramon/WaterLab/life/snow.gdshader")

@export var count: int = 1500
var half_extents: Vector4 = Vector4(9.2, 2.4, 1.6, 3.5)
var floor_y: float = -2.14
var herd: Node4D


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6061
	herd = Node4D.new()
	herd.name = "SnowHerd"
	herd.set_script(Herd)
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	herd.set("mesh", quad)
	herd.set("shader", SHADER)
	herd.set("count", count)
	herd.set("params", {&"half_ext": half_extents, &"w_depth": 24.0})
	add_child(herd)
	var he: Vector4 = half_extents
	for i in count:
		var p := Vector4(rng.randf_range(-he.x + 0.1, he.x - 0.1), rng.randf_range(-he.y, he.y), rng.randf_range(-he.z + 0.05, he.z - 0.05), rng.randf_range(-1.6, 1.6))
		var r: float = rng.randf_range(0.004, 0.011)
		var tint := Color(0.86, 0.90, 0.84).lerp(Color(0.95, 0.88, 0.72), rng.randf())
		herd.call("write", i, p, Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0), tint, Vector4(r, rng.randf_range(0.004, 0.02), rng.randf() * TAU, rng.randf_range(0.3, 1.0)))
	herd.call("upload")


func bench_row() -> Array:
	return ["Specks", str(count), "0 ms", "1", "drift on the GPU"]
