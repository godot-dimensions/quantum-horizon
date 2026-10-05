extends "res://ramon/QuantumRange/scripts/range_target_4d.gd"

## FLYING CHICKEN (Ramon, 5 Oct: "would be fun to shoot some flying chickens too ... we already have the
## model"): the pen's chicken, a carried copy baked into rigid pieces (range_shapes.gd chicken()), flapping
## both wings, flown on a skeet arc by whoever launched it (its `path`). The whole bird is the target: one
## quick shot, and it bursts into feathers.
##
## THE OTHER WING. The bird is lofted with one wing, on its left. The right one is the same mesh turned
## half a turn in the x/w plane, which sends x to -x and w to -w: for a shape that is the same either side
## of its middle slice through W, as a lofted wing is, that is exactly its mirror image, with no negative
## scale to turn its faces inside out.

const Shapes := preload("res://ramon/QuantumRange/scripts/range_shapes.gd")

var flap_rate: float = 11.0
var _wings: Array = []      # [pivot Node4D, side]
var _last: Vector4 = Vector4.INF


func build() -> void:
	family = "chicken"
	var s: float = Shapes.CHICKEN_SCALE
	# The hitbox: the bird, wings folded; the body is the part, everything else hangs off it.
	var k: float = s / 0.5
	var core: Dictionary = add_part("Bird", "core", null, Vector4(0.55, 0.7, 0.85, 0.45) * k, {"radar": true})
	var body: Node4D = core["node"]
	for piece in Shapes.chicken(get_tree()):
		var nm: String = piece[0]
		var mesh: Mesh4D = piece[1]
		var mat: Material4D = piece[2]
		var pos: Vector4 = piece[3]
		if bool(piece[4]):
			# A wing on its shoulder, twice: the second turned through x/w (see above).
			var shoulder := Vector4(0.33, 1.0, 0.08, 0.0)
			var mid := Vector4(0.0, 1.05, -0.2, 0.0)
			for side in [1.0, -1.0]:
				var pivot := Node4D.new()
				pivot.name = "Shoulder" + ("L" if side > 0.0 else "R")
				pivot.position = Vector4((shoulder.x) * side, shoulder.y - mid.y, shoulder.z - mid.z, 0.0) * s
				body.add_child(pivot)
				var p: Dictionary = add_part("Wing" + ("L" if side > 0.0 else "R"), "cover", mesh, Vector4.ZERO,
					{"parent": pivot, "basis": Basis4D.from_scale_uniform(s), "material": mat, "radar": false})
				(p["mesh"] as MeshInstance4D).position = Vector4(-shoulder.x, -shoulder.y, -shoulder.z, 0.0) * s
				_wings.append([pivot, side])
			continue
		var d: Dictionary = add_part(nm, "cover", mesh, Vector4.ZERO, {"parent": body, "basis": Basis4D.from_scale_uniform(s), "material": mat, "radar": false})
		(d["mesh"] as MeshInstance4D).position = pos


func on_hit(p: Dictionary, outcome: String) -> void:
	if outcome == "pop":
		Fx.burst(get_parent(), (p["node"] as Node4D).global_position, Color(0.97, 0.95, 0.90), 22, 0.07, 3.2)


func animate(t: float, dt: float) -> void:
	# Face the way it flies.
	if _last != Vector4.INF and dt > 0.0:
		var v: Vector4 = (position - _last) / dt
		var flat := Vector2(v.x, v.z)
		if flat.length() > 0.2:
			basis = Basis4D.from_zx(atan2(flat.x, flat.y)) * Basis4D.from_yz(clampf(-v.y * 0.08, -0.5, 0.5))
	_last = position
	var beat: float = sin(t * flap_rate)
	for w in _wings:
		var pivot: Node4D = w[0]
		var side: float = w[1]
		# The same beat for both: the mirror turn after it carries the left wing's lift over to the right.
		var flap: Projection = Basis4D.from_xy(0.15 + 0.75 * beat)
		pivot.basis = flap if side > 0.0 else Basis4D.from_xw(PI) * flap
