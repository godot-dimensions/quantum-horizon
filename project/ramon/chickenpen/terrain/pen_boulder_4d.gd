extends RefCounted

## Chunky boulders for the Watchstone and the range (6 Oct 2026, PenLayout/PLAN_WATCHSTONE.md
## step 2; Ramon, of the concept paintings: "make rocks either out of 4d primitives or something
## more unique like you did with the cave entrance build. but the rocks can be a bit chunky").
##
## THE PAINTINGS' BOULDERS: big, light grey, rounded at the edges, their faces chiselled flat, moss
## on whatever looks up.
##
## A 4D PRIMITIVE, ROUNDED AND CHISELLED. The tesseract's surface (its eight cubic cells), each
## cell cut into a small grid, every grid point pushed out onto a rounded box (a superellipsoid,
## round at the edges and corners in all four directions), then the chisel: a handful of planes at
## random angles, and every point beyond one is pressed back onto it, so each cut is a flat face.
## Flat-shaded, so the facets read as cut stone. The cuts lean upward more often than down, so most
## boulders have a flattish top for moss.
##
## CHEAP ON PURPOSE. The first build dual-contoured each boulder as the cave's rock face is: about
## 27,000 tetrahedra a boulder, and soft white blocks. This is about 2,200 (four cells a side, the
## bottom cell left out, since a boulder's underside is never seen), and its facets are flat.
##
## In a unit frame, half a metre to a metre and a bit each way, scaled where it is placed.
## Baked like the hills: _bake_terrain_runner.gd what=boulder_<n>, saved to terrain/baked/boulder_<n>.res.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

## The variants: half-size in x, y, z and W, how many chisel cuts, a seed of their own.
##   0 the block      1 the slab (tall)     2 the flat one
##   3 the round one  4 the wedge (cut hard on one side)   5 the small one
const VARIANTS := [
	{"half": Vector4(1.0, 0.8, 0.9, 0.85), "cuts": 7, "seed": 11},
	{"half": Vector4(0.7, 1.15, 0.65, 0.7), "cuts": 6, "seed": 23},
	{"half": Vector4(1.1, 0.55, 1.0, 0.9), "cuts": 6, "seed": 37},
	{"half": Vector4(0.9, 0.85, 0.9, 0.9), "cuts": 8, "seed": 41},
	{"half": Vector4(1.0, 0.9, 0.8, 0.8), "cuts": 5, "seed": 53, "wedge": true},
	{"half": Vector4(0.75, 0.6, 0.7, 0.65), "cuts": 6, "seed": 67},
]
## Grid cells along each side of each of the tesseract's cells. Even, so neighbouring cells
## split their shared faces the same way (terrain_bake_4d.gd, bake_shell's note on n).
const CELLS := 4
## How square the rounded box is: 2 is a ball, higher is boxier.
const SQUARENESS := 4.4

## A touch cool: the evening sun warms everything it lands on, and a neutral grey came out beige.
const STONE := Color(0.56, 0.58, 0.62)
const STONE_DARK := Color(0.42, 0.44, 0.48)
const MOSS := Color(0.40, 0.53, 0.16)
const MOSS_LIGHT := Color(0.54, 0.64, 0.21)

var half: Vector4
var _cuts: Array = []
var _grain := FastNoiseLite.new()
var _moss := FastNoiseLite.new()


func _init(variant: int = 0) -> void:
	var v: Dictionary = VARIANTS[clampi(variant, 0, VARIANTS.size() - 1)]
	half = v["half"]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(v["seed"])
	_grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_grain.seed = int(v["seed"]) + 3
	_grain.frequency = 1.6
	_moss.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moss.seed = int(v["seed"]) + 9
	_moss.frequency = 2.2
	for k in int(v["cuts"]):
		# Mostly sideways and upward; W in it too, so the faces are chiselled in all four
		# directions and a turned slice still finds flat faces. The first cut is the top.
		var n := Vector4(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.35, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-0.7, 0.7))
		if k == 0:
			n = Vector4(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25), rng.randf_range(-0.2, 0.2))
		n = n.normalized()
		var reach: float = absf(n.x) * half.x + absf(n.y) * half.y + absf(n.z) * half.z + absf(n.w) * half.w
		var depth: float = rng.randf_range(0.6, 0.8)
		if bool(v.get("wedge", false)) and k == 1:
			n = Vector4(0.8, 0.45, 0.0, 0.2).normalized()
			reach = absf(n.x) * half.x + absf(n.y) * half.y + absf(n.w) * half.w
			depth = 0.55
		_cuts.append([n, reach * depth])


## A point of the tesseract's surface ([param u], each coordinate -1 to 1, one of them at an end)
## on the boulder: out onto the rounded box, then pressed back onto every cut it is beyond. Also
## which way its face looks, for the moss.
func shape(u: Vector4) -> Array:
	var e: float = SQUARENESS
	var d: float = pow(pow(absf(u.x), e) + pow(absf(u.y), e) + pow(absf(u.z), e) + pow(absf(u.w), e), 1.0 / e)
	var r: Vector4 = u / maxf(d, 1e-5)
	var p: Vector4 = r * half
	# The rounded box's own outward direction, until a cut says otherwise.
	var normal := Vector4(signf(r.x) * pow(absf(r.x), e - 1.0) / half.x, signf(r.y) * pow(absf(r.y), e - 1.0) / half.y,
		signf(r.z) * pow(absf(r.z), e - 1.0) / half.z, signf(r.w) * pow(absf(r.w), e - 1.0) / half.w).normalized()
	for c in _cuts:
		var n: Vector4 = c[0]
		var beyond: float = p.dot(n) - float(c[1])
		if beyond > 0.0:
			p -= n * beyond
			normal = n
	p += Vector4(0.0, 0.025 * _grain.get_noise_3d(p.x * 2.0, p.z * 2.0, p.w * 2.0), 0.0, 0.0)
	return [p, normal]


func colour(p: Vector4, normal: Vector4) -> Color:
	var grain: float = _grain.get_noise_3d(p.x * 3.0, p.y * 3.0, p.z * 3.0 + p.w) * 0.5 + 0.5
	var c: Color = STONE.lerp(STONE_DARK, grain * 0.6)
	# Darker toward the foot, where it meets the ground or the boulder below.
	c = c * lerpf(0.72, 1.0, smoothstep(-half.y, half.y * 0.2, p.y))
	# Moss on what looks up, in patches.
	var up: float = smoothstep(0.6, 0.85, normal.y)
	var patch: float = smoothstep(-0.2, 0.25, _moss.get_noise_3d(p.x, p.z, p.w))
	var m: Color = MOSS.lerp(MOSS_LIGHT, grain)
	c = c.lerp(m, up * (0.6 + 0.4 * patch))
	c.a = 1.0
	return c


func bake() -> TerrainBake.Builder:
	var out := TerrainBake.Builder.new()
	var n: int = CELLS
	# The tesseract's eight cells: each axis, each end. The bottom one (-y) is left out.
	for axis in 4:
		for end in [0, n]:
			if axis == 1 and end == 0:
				continue
			var others: Array = [0, 1, 2, 3]
			others.erase(axis)
			var outward := Vector4.ZERO
			outward[axis] = 1.0 if end == n else -1.0
			for a in n:
				for b in n:
					for c in n:
						var corners := PackedInt32Array()
						for k in 8:
							var g := Vector4i.ZERO
							g[axis] = end
							g[others[0]] = a + (k & 1)
							g[others[1]] = b + (k >> 1 & 1)
							g[others[2]] = c + (k >> 2 & 1)
							corners.append(_vertex(out, g, n))
						# Global parity of corner 0 (the end is 0 or n, both even).
						var odd: bool = (a + b + c) % 2 == 1
						TerrainBake._five_tets(out, corners, odd, outward)
	return out


## The welded vertex at grid point [param g] (0 to [param n] on each axis).
func _vertex(out: TerrainBake.Builder, g: Vector4i, n: int) -> int:
	if out.has_vertex(g):
		return out.vertex(g, Vector4.ZERO)
	var u := Vector4(float(g.x), float(g.y), float(g.z), float(g.w)) / float(n) * 2.0 - Vector4.ONE
	var s: Array = shape(u)
	return out.vertex(g, s[0], colour(s[0], s[1]))
