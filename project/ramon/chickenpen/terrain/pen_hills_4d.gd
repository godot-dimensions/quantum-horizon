extends RefCounted

## The land around the chicken pen: foothills that rise out of the field, and a ring of
## mountains behind them - in every direction of (x, z, w), not just the four you can walk.
##
## Nothing here runs in play. _bake_terrain_runner.gd calls [method bake_shell] once and saves
## the result; the pen loads the saved mesh.
##
## HOW IT MEETS THE FIELD. The field is a flat box to 60 m in x, z and w. The hills start at
## 50 m, a little below the field's surface, so the first few metres of their slope are
## hidden under it and there is no seam to see; by 58 m they are above it and climbing.
## Nobody walks on them - physics here is bounding boxes only (hub_demo_lessons.md) - and
## pen_bounds_4d.gd keeps the player on the field before the slope starts.
##
## HOW FAR IS FAR. Aerial perspective is baked in: colour slides toward a violet-grey haze
## with distance, so the mountains read as a long way off against the orange sky without
## any fog in the renderer.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

## Where the hills start, in metres from the pen's centre in (x, z, w).
const R_IN := 50.0
## Layer radii of the shell. Close together near the field, where you can see the shape of
## a slope, and far apart behind, where only the skyline matters.
const RADII := [50.0, 58.0, 70.0, 90.0, 125.0, 185.0, 280.0, 420.0, 600.0]
## Cells along each edge of the cube-sphere's six faces: about 5.6 degrees each.
const FACE_CELLS := 16

const FIELD := Color(0.16, 0.22, 0.11)
const MEADOW := Color(0.30, 0.34, 0.15)
const SCRUB := Color(0.22, 0.24, 0.12)
const ROCK := Color(0.38, 0.34, 0.30)
const SNOW := Color(0.88, 0.87, 0.90)
const HAZE := Color(0.60, 0.50, 0.58)

var _hills := FastNoiseLite.new()
var _ridges := FastNoiseLite.new()
var _patches := FastNoiseLite.new()


func _init(seed_: int = 4) -> void:
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.seed = seed_
	_hills.frequency = 1.0 / 70.0
	_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hills.fractal_octaves = 3
	_ridges.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridges.seed = seed_ + 11
	_ridges.frequency = 1.0
	_ridges.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridges.fractal_octaves = 4
	_patches.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_patches.seed = seed_ + 23
	_patches.frequency = 1.0 / 25.0


## Ground height at (x, z, w).
func height(x: float, z: float, w: float) -> float:
	var r: float = sqrt(x * x + z * z + w * w)
	var foot: float = smoothstep(R_IN, R_IN + 45.0, r)
	# A steady climb away from the pen, then rolling hills on top of it.
	var rise: float = foot * (r - R_IN) * 0.06
	var hills: float = foot * (6.0 + (r - R_IN) * 0.1) * (_hills.get_noise_3d(x, z, w) * 0.5 + 0.5)
	# Mountains: ridged noise on DIRECTION, so ridges run outward like real ranges seen from
	# a valley, plus a little along r so they are not perfect cones.
	var ring: float = smoothstep(170.0, 400.0, r) * (1.0 - 0.45 * smoothstep(460.0, 600.0, r))
	var mountains := 0.0
	if ring > 0.0:
		var d := Vector3(x, z, w) / r
		var ridge: float = _ridges.get_noise_3d(d.x * 3.2 + r * 0.0015, d.y * 3.2, d.z * 3.2) * 0.5 + 0.5
		mountains = ring * (40.0 + 150.0 * ridge * ridge)
	return -0.4 + rise + hills + mountains


## Ground colour before occlusion, from where it is and which way it faces.
func colour(p: Vector4, normal: Vector4, r: float) -> Color:
	var slope: float = 1.0 - clampf(normal.y, 0.0, 1.0)
	var patch: float = _patches.get_noise_3d(p.x, p.z, p.w) * 0.5 + 0.5
	# The field's own green where the hills leave it, lighter meadow as they climb.
	var c: Color = FIELD.lerp(MEADOW, smoothstep(R_IN, R_IN + 30.0, r) * (0.4 + 0.6 * patch))
	c = c.lerp(SCRUB, smoothstep(0.55, 0.8, patch) * 0.6)
	c = c.lerp(ROCK, smoothstep(0.28, 0.5, slope))
	# Bare rock above the tree line, snow on the tops that are flat enough to hold it.
	c = c.lerp(ROCK, smoothstep(60.0, 110.0, p.y))
	c = c.lerp(SNOW, smoothstep(125.0, 165.0, p.y) * (1.0 - smoothstep(0.35, 0.6, slope)))
	var haze: float = 1.0 - exp(-maxf(r - 70.0, 0.0) / 240.0)
	return c.lerp(HAZE, haze * 0.8)


## The whole ring, as one builder ready for TerrainBake.mesh_of.
func bake_shell() -> TerrainBake.Builder:
	# Occlusion at two scales: the crease of a slope, and the valley between hills. Both
	# grow with distance, because a far cell is tens of metres across and a 3 m
	# neighbourhood would see nothing of its shape.
	var ao := [[3.0, 0.55, 0.02], [12.0, 0.45, 0.08]]
	return TerrainBake.bake_height_shell(PackedFloat32Array(RADII), FACE_CELLS, height, colour, ao)
