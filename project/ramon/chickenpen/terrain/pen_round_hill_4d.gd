extends RefCounted

## A plain grassy hill, the cave hill's dome without its door (6 Oct 2026, Ramon: "make a similar
## hill like the cave entrance next to the other side of the wall, so it creates a funnel effect.
## ofcourse this one withoutcave opening. and another hill next to the tower").
##
## The same recipe as terrain/pen_cave_hill_4d.gd's dome: a footprint round enough to read as a
## hill and square enough that box colliders stay close to its sides (ROUNDNESS), a top that is a
## dome and not a table, a little noise on both, and the cave hill's own grass, turf and bank colours.
## Each shape is in its own frame, centred on the origin; its node (scripts/pen_round_hill_4d.gd)
## puts it in the field.
##
## Baked like the cave hill: _bake_terrain_runner.gd what=hill_west (or hill_tower), saved to
## terrain/baked/<shape>.res.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")
const CaveHill := preload("res://ramon/chickenpen/terrain/pen_cave_hill_4d.gd")

## The shapes: half-size in x, z and W, height, and a seed of their own so no two hills share bumps.
##   hill_west    at the dry wall's west end, the funnel's other side (the cave hill is the first)
##   hill_tower   beside the watchtower, east of it, so the balloon keeps the west side
const SHAPES := {
	"hill_west": {"half": Vector3(12.0, 10.0, 9.0), "top": 9.5, "seed": 53},
	"hill_tower": {"half": Vector3(10.0, 9.0, 8.0), "top": 8.0, "seed": 71},
	# Layout B's mounds (PenLayout/PLAN_B.md step 36; Ramon: "add subtle hills slumps here and there to
	# make it a little less flat"): low and broad, under trees and behind landmarks, off the paths.
	"mound_a": {"half": Vector3(8.0, 7.0, 6.0), "top": 2.0, "seed": 101},
	"mound_b": {"half": Vector3(7.0, 6.0, 6.0), "top": 1.6, "seed": 113},
	"mound_c": {"half": Vector3(7.0, 6.5, 6.0), "top": 1.8, "seed": 127},
	"mound_d": {"half": Vector3(6.0, 6.5, 5.0), "top": 1.5, "seed": 139},
	"mound_e": {"half": Vector3(6.0, 5.0, 5.0), "top": 1.3, "seed": 151},
}
const SHOULDER := 0.15
const ROUNDNESS := 3.0

var half: Vector3
var top: float
var _bumps := FastNoiseLite.new()
var _grain := FastNoiseLite.new()


func _init(shape: String = "hill_west") -> void:
	var s: Dictionary = SHAPES.get(shape, SHAPES["hill_west"])
	half = s["half"]
	top = s["top"]
	_bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bumps.seed = int(s["seed"])
	_bumps.frequency = 1.0 / 4.0
	_grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_grain.seed = int(s["seed"]) + 7
	_grain.frequency = 1.0 / 1.6
	_grain.fractal_type = FastNoiseLite.FRACTAL_FBM
	_grain.fractal_octaves = 3


## How far out from the middle (x, z, w) is: 1 on the footprint's edge, wobbled.
func extent(x: float, z: float, w: float) -> float:
	var d := Vector3(absf(x) / half.x, absf(z) / half.y, absf(w) / half.z)
	var q: float = pow(pow(d.x, ROUNDNESS) + pow(d.y, ROUNDNESS) + pow(d.z, ROUNDNESS), 1.0 / ROUNDNESS)
	return q + 0.04 * _bumps.get_noise_3d(x * 0.8, z * 0.8, w * 0.8)


func height(x: float, z: float, w: float) -> float:
	var q: float = extent(x, z, w)
	var dome: float = top * (1.0 - smoothstep(SHOULDER, 1.0, q))
	dome += 0.35 * _bumps.get_noise_3d(x, z, w) * (1.0 - smoothstep(0.8, 1.0, q))
	return dome - 0.2


func colour(p: Vector4, normal: Vector4, _r: float) -> Color:
	var slope: float = 1.0 - clampf(normal.y, 0.0, 1.0)
	var grain: float = _grain.get_noise_3d(p.x, p.z, p.w) * 0.5 + 0.5
	var c: Color = CaveHill.grass.lerp(CaveHill.grass_high, smoothstep(1.0, top, p.y) * (0.4 + 0.6 * grain))
	return c.lerp(CaveHill.BANK.lerp(CaveHill.STONE_DARK, grain), smoothstep(0.45, 0.75, slope))


func bake() -> TerrainBake.Builder:
	return TerrainBake.bake_height_box(
		Vector3(-half.x * 1.1, -half.y * 1.1, -half.z * 1.1),
		Vector3(half.x * 1.1, half.y * 1.1, half.z * 1.1),
		1.35, height, colour, [[0.8, 0.5], [3.0, 0.45]], -0.05)


## The boxes you bump into: tiers, each three crossed boxes as wide as the dome is at the tier's
## foot (the cave hill's own, without the tunnel to cut round). [centre, size] in the hill's frame.
func solid_boxes() -> Array:
	var out := []
	var tiers: Array = [[0.0, 1.8], [1.8, top * 0.42], [top * 0.42, top * 0.7], [top * 0.7, top - 0.4]]
	for tier in tiers:
		if float(tier[1]) <= float(tier[0]) + 0.2:
			continue
		var q: float = _extent_at_height(float(tier[0]) + 0.25)
		var y: float = (float(tier[0]) + float(tier[1])) * 0.5
		var tall: float = float(tier[1]) - float(tier[0])
		for long in 3:
			var f := Vector3(0.62, 0.62, 0.62)
			f[long] = 0.97
			out.append([Vector4(0.0, y, 0.0, 0.0), Vector4(half.x * 2.0 * q * f.x, tall, half.y * 2.0 * q * f.y, half.z * 2.0 * q * f.z)])
	return out


## The footprint fraction at which the dome comes down to [param y].
func _extent_at_height(y: float) -> float:
	var lo := SHOULDER
	var hi := 1.0
	for i in 30:
		var mid: float = (lo + hi) * 0.5
		if top * (1.0 - smoothstep(SHOULDER, 1.0, mid)) - 0.2 > y:
			lo = mid
		else:
			hi = mid
	return lo
