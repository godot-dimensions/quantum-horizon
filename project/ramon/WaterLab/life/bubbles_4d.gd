extends Node4D

## WATER LAB: an air stone at the back of the tank and its stream of bubbles: rising faster as they go
## up, wobbling, squashing, gone at the surface and let go again at the stone. Drawn the starlings'
## way (life/blob.gdshader, a bright rim), each a 4D ball. In the water's own frame (life/).
##
## NO class_name (engine_gotchas.md).

const Herd := preload("res://ramon/WaterLab/shared/slice_herd_4d.gd")
const BLOB := preload("res://ramon/WaterLab/life/blob.gdshader")

@export var count: int = 36
var half_extents: Vector4 = Vector4(9.2, 2.4, 1.6, 3.5)
var floor_y: float = -2.14
var stone_at: Vector4 = Vector4(-8.3, -2.1, -1.15, 0.0)
var herd: Node4D
var _b: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 211
	stone_at = Vector4(-half_extents.x + 0.9, floor_y + 0.04, -half_extents.z + 0.45, 0.0)
	herd = Node4D.new()
	herd.name = "BubbleHerd"
	herd.set_script(Herd)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 8
	herd.set("mesh", ball)
	herd.set("shader", BLOB)
	herd.set("w_radius", 1.0)
	herd.set("count", count)
	add_child(herd)
	for i in count:
		_b.append(_new_bubble(_rng.randf() * (half_extents.y * 2.0)))


func _new_bubble(rise: float) -> Dictionary:
	return {"p": stone_at + Vector4(_rng.randf_range(-0.06, 0.06), rise, _rng.randf_range(-0.06, 0.06), _rng.randf_range(-0.02, 0.02)),
		"r": _rng.randf_range(0.008, 0.026), "v": _rng.randf_range(0.25, 0.35), "ph": _rng.randf() * TAU}


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	var top: float = half_extents.y - 0.02
	for i in _b.size():
		var b: Dictionary = _b[i]
		var p: Vector4 = b["p"]
		b["v"] = minf(float(b["v"]) + dt * 0.12, 0.5)
		p.y += float(b["v"]) * dt
		b["ph"] = float(b["ph"]) + dt * 6.0
		p.x += sin(float(b["ph"])) * 0.06 * dt
		p.z += cos(float(b["ph"]) * 1.3) * 0.05 * dt
		if p.y > top:
			b = _new_bubble(0.0)
			p = b["p"]
		b["p"] = p
		_b[i] = b
		herd.call("write", i, p, Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0), Color(0.75, 0.88, 0.95, 1.0), Vector4(float(b["r"]), 1.0, 1.0, 0.0))
	herd.call("upload")
