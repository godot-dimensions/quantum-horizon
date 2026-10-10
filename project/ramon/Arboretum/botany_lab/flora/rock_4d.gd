extends RefCounted

## BOTANY LAB, round 4 (section 10, step 39; Ramon: "small rock groupings ... environmental elements that help
## frame the spaces"): a rock lofted in 4D. A ball of sections up its height, each of its own size and a
## little off the middle, each squashed its own way across x, z and W, so the stone is lumpy in every
## direction and faceted (the cut is flat-shaded); wider than it is tall, as a field stone is. Baked under
## flora/baked/ (rock_<seed>_v1.res); a stone material of a few greys, warm and cool.
##
## Every loop is capped (section 8). NO class_name (engine_gotchas.md).

const Kit := preload("res://ramon/Arboretum/botany_lab/flora/flora_kit.gd")
const Flower := preload("res://ramon/Arboretum/botany_lab/flora/flower_4d.gd")
const BAKED := "res://ramon/Arboretum/botany_lab/flora/baked/"
const BAKE_VERSION := "v1"
const STONES := [Color(0.52, 0.5, 0.47), Color(0.44, 0.43, 0.42), Color(0.58, 0.55, 0.5), Color(0.4, 0.41, 0.43)]

static var _mats: Dictionary = {}


## A rock about a metre across, its foot at y 0 (scale it to size).
static func mesh(seed_value: int) -> ArrayTetraMesh4D:
	return Kit.cached(BAKED + "rock_%d_%s.res" % [seed_value, BAKE_VERSION], func() -> ArrayTetraMesh4D: return build(seed_value))


static func build(seed_value: int) -> ArrayTetraMesh4D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 977 + 13
	var n: int = 6
	var sections: Array = []
	var height: float = rng.randf_range(0.42, 0.62)
	for i in n:
		var t: float = float(i) / float(n - 1)
		# A dome's profile: widest low down, rounding over the top.
		var r: float = 0.5 * pow(maxf(sin(lerpf(0.12, 1.0, t) * PI * 0.5 + 0.2), 0.05), 0.6) * (1.0 - 0.75 * t * t)
		var off := Vector4(rng.randf_range(-0.06, 0.06), 0.0, rng.randf_range(-0.06, 0.06), rng.randf_range(-0.05, 0.05))
		var b: Projection = Kit.scale(rng.randf_range(0.8, 1.2), 1.0, rng.randf_range(0.75, 1.15), rng.randf_range(0.7, 1.1)) * Kit.rot_y(rng.randf() * TAU)
		sections.append({"center": Vector4(0.0, t * height, 0.0, 0.0) + off, "radius": maxf(r, 0.04), "v_scale": 1.0, "w_scale": 1.0, "basis": b})
	var m: ArrayTetraMesh4D = Flower.light_loft(sections, 3, 7)
	if m != null:
		m.calculate_boundary_normals(false)
	return m


## A stone material (one of a few greys).
static func material(i: int) -> TetraMaterial4D:
	var k: int = posmod(i, STONES.size())
	if not _mats.has(k):
		_mats[k] = Kit.flat(STONES[k])
	return _mats[k]
