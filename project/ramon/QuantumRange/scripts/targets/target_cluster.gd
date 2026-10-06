extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## CLUSTER: a red core guarded by eight white satellites, one at each vertex of the 16-cell (the 4D
## cross-polytope): one out along each of the eight axis directions, +x -x +y -y +z -z +w -w. The core
## stays dark and locked until all eight are gone.
##
## From your slice you see six of them, the ones along x, y and z. The other two are a whole satellite's
## distance ana and kata of the core: the radar shows them as diamonds with stems, one up, one down.
## Clear the six, step ana for one, kata for the other, and the core lights.

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

var reach: float = 1.35
var sat_r: float = 0.27
var core_r: float = 0.38

var _left: int = 8


func build() -> void:
	family = "cluster"
	add_part("Core", "core", Shapes.ball(), Vector4(core_r * 1.8, core_r * 1.8, core_r * 1.8, core_r * 2.0),
		{"basis": Basis4D.from_scale_uniform(core_r), "locked": true})
	var dirs: Array = [["XP", Vector4(1, 0, 0, 0)], ["XN", Vector4(-1, 0, 0, 0)], ["YP", Vector4(0, 1, 0, 0)], ["YN", Vector4(0, -1, 0, 0)],
		["ZP", Vector4(0, 0, 1, 0)], ["ZN", Vector4(0, 0, -1, 0)], ["WP", Vector4(0, 0, 0, 1)], ["WN", Vector4(0, 0, 0, -1)]]
	for d in dirs:
		var b: float = sat_r * 1.9
		add_part("Sat" + String(d[0]), "cover", Shapes.diamond(), Vector4(b, b, b, b),
			{"at": (d[1] as Vector4) * reach, "basis": Basis4D.from_scale_uniform(sat_r), "radar": true, "hp": 1})


func on_hit(p: Dictionary, outcome: String) -> void:
	if String(p["role"]) == "cover" and outcome == "break":
		_left -= 1
		if _left <= 0:
			unlock("Core")


func animate(t: float, _dt: float) -> void:
	# The satellites turn slowly round the core in its own x/z, so the cluster reads as one thing; the two
	# along W stay where they are (a turn in x/z does not move them).
	var turn: Projection = Basis4D.from_zx(t * 0.35)
	for p in parts:
		var nm: String = String(p["name"])
		if not nm.begins_with("Sat"):
			continue
		var base: Vector4 = {"XP": Vector4(1, 0, 0, 0), "XN": Vector4(-1, 0, 0, 0), "YP": Vector4(0, 1, 0, 0), "YN": Vector4(0, -1, 0, 0),
			"ZP": Vector4(0, 0, 1, 0), "ZN": Vector4(0, 0, -1, 0), "WP": Vector4(0, 0, 0, 1), "WN": Vector4(0, 0, 0, -1)}[nm.substr(3)]
		(p["node"] as Node4D).position = (turn * base) * reach
	var core: Dictionary = parts[0]
	if not bool(core["locked"]) and bool(core["alive"]) and age > 0.35:
		(core["mesh"] as MeshInstance4D).basis = Basis4D.from_scale_uniform(core_r * (1.0 + sin(t * 9.0) * 0.08))
