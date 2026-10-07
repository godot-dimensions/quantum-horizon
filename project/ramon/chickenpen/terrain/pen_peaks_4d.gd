extends RefCounted

## The mountains round the pen, second version: separate peaks in three bands - a low rim
## close in, a middle range, and big snow-capped mountains far off - with sky between them.
## Ramon, 28 Sept: the first version (pen_hills_4d.gd, kept as "Classic") "obscures the sky";
## he wanted small, medium and large mountains, all in the one radial mesh, and asked "what
## do you use voronoi for the seed?". The first version used no Voronoi at all - ridged
## simplex noise on direction, one continuous wall. This one is Voronoi throughout.
##
## A PEAK IS A VORONOI CELL. Each band scatters seed points over the sphere of directions
## round the pen - the (x, z, w) sphere, so there are mountains through W as well - with
## FastNoiseLite's cellular noise, one cell per seed. Three readings of the same cells make
## a mountain:
##   F1, the distance to the cell's seed: the mountain's shape, highest at the seed.
##   the cell's own random value: whether this cell has a mountain at all (coverage - the
##     cells left empty are the gaps you see sky through) and how tall it is (variation).
##   F2 - F1, how far from the cell's border: the mountain comes down to nothing there, so
##     two neighbours of different heights meet in a saddle instead of a cliff.
## Along the ray out from the pen a mountain is a ridge centred on its band's distance, as
## real ranges look from a valley; the bands take the highest of the three, not the sum.
##
## EVERY NUMBER IS A PARAMETER on the Hills node in the pen (pen_mountains_4d.gd), which
## bakes this from them with a button; see there for what each one does. This file only
## reads them.
##
## THE SAME MESH AS BEFORE, cut to fit. The shell is the cube-sphere of the first version,
## but its radial layers are placed from the bands: one at each band's crest and one either
## side at its depth, so a ridge always falls on a layer however the bands are moved.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

## Where the ground leaves the field, in metres from the valley's centre: 50 in layout A, 62 in
## layout B (PenLayout/PLAN_B.md step 8: "the collision ring to get a bit bigger to make more space"),
## set by the mountains node (pen_mountains_4d.gd valley_radius).
var R_IN: float = 50.0
## Layers every bake has, from the join with the field out (the first ones counted from R_IN).
const NEAR_STEPS := [0.0, 8.0, 20.0, 40.0]
const FAR_EDGE := 600.0
## Layers closer than this are merged.
const MIN_LAYER_GAP := 7.0

const FIELD := Color(0.16, 0.22, 0.11)
const MEADOW := Color(0.30, 0.34, 0.15)
const SCRUB := Color(0.22, 0.24, 0.12)
const ROCK := Color(0.38, 0.34, 0.30)
const SNOW := Color(0.88, 0.87, 0.90)
const HAZE := Color(0.60, 0.50, 0.58)

## The colour where the mountains leave the field (FIELD, or the pen's even green: pen_mountains_4d.gd).
var field_colour := FIELD
var face_cells := 16
var rise := 0.025
var foothills := 5.0
var foothills_growth := 0.04
var rock_from := 40.0
var snow_from := 90.0
var haze := 0.8
var haze_distance := 240.0
## One per band: distance, depth, spacing (radians), height, variation, coverage, width,
## sharpness, and its three noises.
var bands: Array = []

var _hills := FastNoiseLite.new()
var _patches := FastNoiseLite.new()


## Reads every parameter from [param settings] (the Hills node), by name.
func _init(settings: Object) -> void:
	var seed_: int = int(settings.get("mountain_seed"))
	face_cells = int(settings.get("face_cells"))
	rise = float(settings.get("rise"))
	foothills = float(settings.get("foothills"))
	foothills_growth = float(settings.get("foothills_growth"))
	rock_from = float(settings.get("rock_from"))
	snow_from = float(settings.get("snow_from"))
	haze = float(settings.get("haze"))
	haze_distance = float(settings.get("haze_distance"))
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.seed = seed_
	_hills.frequency = 1.0 / 70.0
	_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hills.fractal_octaves = 3
	_patches.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_patches.seed = seed_ + 23
	_patches.frequency = 1.0 / 25.0
	var i := 0
	for name in ["rim", "medium", "large"]:
		i += 1
		if not bool(settings.get(name + "_enabled")):
			continue
		var band := {
			"distance": float(settings.get(name + "_distance")),
			"depth": maxf(float(settings.get(name + "_depth")), 1.0),
			"scale": 1.0 / deg_to_rad(maxf(float(settings.get(name + "_spacing_degrees")), 1.0)),
			"height": float(settings.get(name + "_height")),
			"variation": clampf(float(settings.get(name + "_variation")), 0.0, 1.0),
			"coverage": clampf(float(settings.get(name + "_coverage")), 0.0, 1.0),
			"width": maxf(float(settings.get(name + "_width")), 0.05),
			"sharpness": maxf(float(settings.get(name + "_sharpness")), 0.1),
		}
		var cells_seed: int = seed_ * 31 + i * 1009
		band["f1"] = _cells(cells_seed, FastNoiseLite.RETURN_DISTANCE)
		band["edge"] = _cells(cells_seed, FastNoiseLite.RETURN_DISTANCE2_SUB)
		band["value"] = _cells(cells_seed, FastNoiseLite.RETURN_CELL_VALUE)
		bands.append(band)


## One reading of a band's Voronoi cells. The three readings share seed, frequency and
## jitter, so they describe the same cells.
static func _cells(seed_: int, reading: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.fractal_type = FastNoiseLite.FRACTAL_NONE
	n.frequency = 1.0
	n.seed = seed_
	n.cellular_jitter = 1.0
	n.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	n.cellular_return_type = reading
	return n


## The shell's radial layers: the near ones, each band's crest and either side of it, and
## the far edge, sorted, with any two closer than MIN_LAYER_GAP merged.
func radii() -> PackedFloat32Array:
	var all: Array = NEAR_STEPS.map(func(s: float) -> float: return R_IN + s)
	for band in bands:
		for r in [band["distance"] - band["depth"], band["distance"], band["distance"] + band["depth"]]:
			if r > R_IN and r < FAR_EDGE:
				all.append(r)
	all.append(FAR_EDGE)
	all.sort()
	var crests: Array = bands.map(func(b: Dictionary) -> float: return float(b["distance"]))
	var out := PackedFloat32Array()
	for r in all:
		if out.is_empty() or r - out[out.size() - 1] >= MIN_LAYER_GAP:
			out.append(r)
		elif crests.has(r) or r == FAR_EDGE:
			# A crest or the edge wins over whatever it is merged with.
			out[out.size() - 1] = r
	return out


## Ground height at (x, z, w).
func height(x: float, z: float, w: float) -> float:
	var r: float = sqrt(x * x + z * z + w * w)
	var foot: float = smoothstep(R_IN, R_IN + 45.0, r)
	var ground: float = -0.4 + foot * (r - R_IN) * rise
	ground += foot * (foothills + (r - R_IN) * foothills_growth) * (_hills.get_noise_3d(x, z, w) * 0.5 + 0.5)
	if r < 1.0:
		return ground
	var d := Vector3(x, z, w) / r
	var peaks := 0.0
	for band in bands:
		peaks = maxf(peaks, _peak(band, d, r))
	return ground + peaks


## How tall [param band]'s mountain is at direction [param d], [param r] out.
func _peak(band: Dictionary, d: Vector3, r: float) -> float:
	var along: float = 1.0 - absf(r - float(band["distance"])) / float(band["depth"])
	if along <= 0.0:
		return 0.0
	var q: Vector3 = d * float(band["scale"])
	var value: float = (band["value"] as FastNoiseLite).get_noise_3dv(q) * 0.5 + 0.5
	var coverage: float = band["coverage"]
	if value >= coverage:
		return 0.0
	var f1: float = (band["f1"] as FastNoiseLite).get_noise_3dv(q) + 1.0
	var shape: float = clampf(1.0 - f1 / float(band["width"]), 0.0, 1.0)
	if shape <= 0.0:
		return 0.0
	var edge: float = (band["edge"] as FastNoiseLite).get_noise_3dv(q) + 1.0
	var tall: float = float(band["height"]) * lerpf(1.0 - float(band["variation"]), 1.0, value / maxf(coverage, 0.001))
	return tall * pow(shape, float(band["sharpness"])) * smoothstep(0.0, 0.18, edge) * smoothstep(0.0, 1.0, along)


## Ground colour before occlusion, from where it is and which way it faces.
func colour(p: Vector4, normal: Vector4, r: float) -> Color:
	var slope: float = 1.0 - clampf(normal.y, 0.0, 1.0)
	var patch: float = _patches.get_noise_3d(p.x, p.z, p.w) * 0.5 + 0.5
	var c: Color = field_colour.lerp(MEADOW, smoothstep(R_IN, R_IN + 30.0, r) * (0.4 + 0.6 * patch))
	c = c.lerp(SCRUB, smoothstep(0.55, 0.8, patch) * 0.6)
	c = c.lerp(ROCK, smoothstep(0.28, 0.5, slope))
	# Bare rock above the tree line, snow on the tops flat enough to hold it.
	c = c.lerp(ROCK, smoothstep(rock_from, rock_from * 1.8, p.y))
	c = c.lerp(SNOW, smoothstep(snow_from, snow_from * 1.3, p.y) * (1.0 - smoothstep(0.35, 0.6, slope)))
	var h: float = 1.0 - exp(-maxf(r - 70.0, 0.0) / maxf(haze_distance, 1.0))
	return c.lerp(HAZE, h * haze)


## The whole ring, as one builder ready for TerrainBake.mesh_of.
func bake_shell() -> TerrainBake.Builder:
	var ao := [[3.0, 0.55, 0.02], [12.0, 0.45, 0.08]]
	var n: int = face_cells + face_cells % 2
	return TerrainBake.bake_height_shell(radii(), n, height, colour, ao)
