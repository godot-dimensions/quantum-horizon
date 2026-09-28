extends RefCounted

## The cave inside the hill: a rough tunnel from the daylight, a long straight excavated
## corridor lined with work lights, and at its end a high chamber with a ruined plinth in
## the middle and the monolith on it. All of it baked by _bake_terrain_runner.gd what=cave.
##
## Everything here is in the cave's own frame. The scene is hung 1 km along x from the pen
## (cave.tscn, cave_4d.gd) so the two never touch, and nothing in this file needs to know.
##
## THE WALK IS THE POINT. Ramon's note: "walk a bit to reach the site with symmetry framing
## a wow moment". So the corridor is straight, centred on the plinth, and lit in evenly
## spaced pairs - in x AND in w, since this is four-dimensional and a slice turned into W
## should frame it the same way - and the chamber opens out at the end of it with the
## monolith dead centre, tall, lit from below, and a ceiling too high to see.
##
## WALLS ARE A DENSITY, THE FLOOR IS A HEIGHT. The cave's air is a union of three shapes
## (tunnel, corridor, chamber) and the rock is everything else; dual contouring draws the
## boundary. The floor is split off because it is the biggest flat thing in the cave, and
## a height draws a flat thing in a fraction of the tetrahedra - the walls' air runs on
## below the floor and those cells are dropped, since nothing can see them.
##
## THE GRID IS STRETCHED PER AXIS, AND THERE ARE TWO OF THEM. VoxelField4D is n cells along
## every axis, but the cave is 57 m long and 19 m across in W, so cubic cells would be
## either too coarse across or far too many along. Grid space maps to the cave with a
## different cell size per axis - an affine stretch, which dual contouring does not mind -
## and the narrow tunnel and the big chamber get a grid each, sized to them: one grid for
## both put 101,000 tetrahedra into the walls, and every tetrahedron is about 1.25 KB of
## video memory whether it is on screen or not. Both grids contour the SAME air, so where
## they overlap they draw the same surface, and each covers the ragged edge the other
## leaves at its boundary.
##
## THE DARK IS PAINTED ON. No shadows in 4D here: occlusion in the colours, the walls
## falling to black as they rise so the chamber has a ceiling you cannot see, and the lamps
## doing the rest. It is the theatre's recipe - a black sky, a faint key, a few coloured
## lamps - underground.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

## Where you arrive, facing into the cave (toward -z).
const ARRIVE := Vector4(0.0, 0.0, -0.5, 0.0)
## The daylight behind you, the way back out.
const DAYLIGHT_Z := 5.8

## The rough tunnel from the daylight: z range, half-width (in x and w), height.
const TUNNEL := Vector2(6.6, -5.0)
const TUNNEL_HALF := 2.4
const TUNNEL_HIGH := 4.3
## The excavated corridor.
const CORRIDOR := Vector2(-5.0, -24.5)
const CORRIDOR_HALF := 3.2
const CORRIDOR_HIGH := 6.2
## The chamber: centre on the floor, and its radii (x, up, z, w).
const CHAMBER := Vector4(0.0, 0.0, -36.0, 0.0)
const CHAMBER_R := Vector4(13.0, 17.0, 12.0, 8.0)

## The work lights down the corridor, one ring of four stands at each of these z.
const STATIONS := [-7.5, -12.5, -17.5, -22.5]
const STAND_OFFSET := 2.45

## The plinth: three tiers, each this much smaller than the last, and its top.
const PLINTH_BASE := 6.4
const PLINTH_STEP := 1.6
const PLINTH_RISE := 0.5
const PLINTH_TOP := 1.5

## The two grids, as [low corner, high corner, points per axis]. The tunnel's reaches a few
## metres into the chamber so the two overlap round the corridor's mouth.
const CHUNKS := [
	[Vector4(-4.6, -2.0, -28.5, -4.6), Vector4(4.6, 7.6, 10.5, 4.6), 12],
	[Vector4(-16.0, -2.0, -52.0, -10.5), Vector4(16.0, 19.8, -19.5, 10.5), 15],
]
## The whole cave's extent, for the floor and its collider.
const LO := Vector4(-16.0, -2.0, -52.0, -10.5)
const HI := Vector4(16.0, 19.8, 10.5, 10.5)

const ROCK := Color(0.31, 0.295, 0.28)
const ROCK_DARK := Color(0.17, 0.165, 0.155)
const FLOOR_DIRT := Color(0.16, 0.15, 0.135)
const FLOOR_TRODDEN := Color(0.24, 0.225, 0.20)
const STONE := Color(0.36, 0.34, 0.31)
const STONE_DARK := Color(0.24, 0.23, 0.21)
const STEEL := Color(0.30, 0.31, 0.33)
const LAMP := Color(1.0, 0.98, 0.92)
const CRATE := Color(0.42, 0.31, 0.19)
const CASE := Color(0.86, 0.42, 0.12)
const GENERATOR := Color(0.85, 0.66, 0.12)
const TABLE := Color(0.50, 0.50, 0.52)
const SCREEN := Color(0.45, 0.80, 1.0)
const CABLE := Color(0.05, 0.05, 0.06)
const PLANK := Color(0.30, 0.22, 0.15)

var _rough := FastNoiseLite.new()
var _grain := FastNoiseLite.new()


func _init() -> void:
	_rough.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_rough.seed = 61
	_rough.frequency = 1.0 / 3.5
	_rough.fractal_type = FastNoiseLite.FRACTAL_FBM
	_rough.fractal_octaves = 3
	_grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_grain.seed = 67
	_grain.frequency = 1.0 / 1.4


# ------------------------------------------------------------------ the air

## Positive in the air, in metres, roughly: the union of tunnel, corridor and chamber.
func air_density(p: Vector4) -> float:
	var rough: float = _rough.get_noise_3d(p.x + p.w * 0.7, p.y, p.z) + 0.5 * _rough.get_noise_3d(p.w, p.z * 0.8, p.x)
	var tunnel: float = _tube(p, TUNNEL, TUNNEL_HALF, TUNNEL_HIGH) + 0.45 * rough
	# The corridor was dug, not found: straighter, with only a little of the rock's
	# roughness left in its walls.
	var corridor: float = _tube(p, CORRIDOR, CORRIDOR_HALF, CORRIDOR_HIGH) + 0.18 * rough
	var q := Vector4((p.x - CHAMBER.x) / CHAMBER_R.x, (p.y - CHAMBER.y) / CHAMBER_R.y,
		(p.z - CHAMBER.z) / CHAMBER_R.z, (p.w - CHAMBER.w) / CHAMBER_R.w)
	var chamber: float = (1.0 - q.length()) * 9.0 + 0.7 * rough
	return _smooth_max(_smooth_max(tunnel, corridor, 1.2), chamber, 2.0)


## A tube along z from [param span].x down to [param span].y: round in (x, w), [param high]
## tall, centred on the floor so its lower half is under it, with rounded ends.
func _tube(p: Vector4, span: Vector2, half: float, high: float) -> float:
	var before: float = maxf(0.0, p.z - span.x)
	var after: float = maxf(0.0, span.y - p.z)
	var along: float = (before + after) / half
	var u := Vector4(p.x / half, p.y / high, along, p.w / half)
	return (1.0 - u.length()) * half


func _smooth_max(a: float, b: float, k: float) -> float:
	var h: float = clampf(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
	return lerpf(b, a, h) + k * h * (1.0 - h)


func rock_density(p: Vector4) -> float:
	return -air_density(p)


# ------------------------------------------------------------------ colour

func wall_colour(p: Vector4, normal: Vector4, _r: float) -> Color:
	var grain: float = _grain.get_noise_3d(p.x + p.w, p.y, p.z) * 0.5 + 0.5
	var c: Color = ROCK.lerp(ROCK_DARK, grain * 0.7)
	# Faces turned up catch dust and read lighter; overhangs go darker.
	c = c.lerp(FLOOR_TRODDEN, 0.3 * smoothstep(0.5, 0.9, normal.y))
	c = c.lerp(Color.BLACK, 0.4 * smoothstep(-0.3, -0.8, normal.y))
	# Up into the dark: the chamber's vault fades out long before its top.
	return c.lerp(Color.BLACK, smoothstep(6.0, 16.0, p.y) * 0.85)


func floor_height(x: float, z: float, w: float) -> float:
	# Inside the cave's footprint the floor is flat; outside it drops under the walls, so
	# those cells are left out of the bake.
	return 0.0 if air_density(Vector4(x, 0.4, z, w)) > -0.6 else -1.0


func floor_colour(p: Vector4, _normal: Vector4, _r: float) -> Color:
	var grain: float = _grain.get_noise_3d(p.x * 0.7, p.z * 0.7, p.w * 0.7) * 0.5 + 0.5
	var c: Color = FLOOR_DIRT.lerp(ROCK_DARK, grain * 0.5)
	# Worn lighter down the middle of the walk and round the plinth, where people go.
	var lateral: float = Vector2(p.x, p.w).length()
	var walk: float = (1.0 - smoothstep(0.6, 2.2, lateral)) * float(p.z > CHAMBER.z)
	var round_plinth: float = 1.0 - smoothstep(PLINTH_BASE * 0.5 + 0.5, PLINTH_BASE * 0.5 + 3.5,
		Vector3(p.x - CHAMBER.x, p.z - CHAMBER.z, p.w - CHAMBER.w).length())
	c = c.lerp(FLOOR_TRODDEN, 0.6 * maxf(walk, round_plinth))
	# Darker where the floor runs in under the walls.
	return c.lerp(Color.BLACK, 0.6 * (1.0 - smoothstep(0.2, 2.0, air_density(Vector4(p.x, 0.4, p.z, p.w)))))


# ------------------------------------------------------------------ props

## Every solid prop as [centre, size, colour, solid]. Drawn from this list and, where solid,
## collided with from it, so the two can never disagree.
func props() -> Array:
	var out := []
	# The plinth.
	for k in 3:
		var side: float = PLINTH_BASE - PLINTH_STEP * k
		out.append([CHAMBER + Vector4(0.0, PLINTH_RISE * (k + 0.5), 0.0, 0.0),
			Vector4(side, PLINTH_RISE, side, side), STONE if k != 1 else STONE_DARK, true])
	# Broken blocks of an older, larger plinth scattered round it.
	for d in [Vector4(3.9, 0.25, 2.6, 1.2), Vector4(-3.6, 0.2, -3.1, -1.9), Vector4(2.2, 0.3, -4.0, 2.8), Vector4(-2.8, 0.18, 3.4, -2.6)]:
		out.append([CHAMBER + d, Vector4(1.1, d.y * 2.0, 0.8, 0.9), STONE_DARK, true])
	# Columns on the four diagonals in (x, z) and the two ends of W: framing the plinth from
	# the corridor on the home slice, and from the corridor again with the slice turned.
	var columns := [[Vector3(5.2, 5.2, 0.0), 9.0], [Vector3(-5.2, 5.2, 0.0), 9.0],
		[Vector3(5.2, -5.2, 0.0), 3.4], [Vector3(-5.2, -5.2, 0.0), 5.6],
		[Vector3(0.0, 5.2, 5.2), 6.2], [Vector3(0.0, 5.2, -5.2), 2.4]]
	for c in columns:
		var at: Vector3 = c[0]
		var tall: float = c[1]
		var base := CHAMBER + Vector4(at.x, 0.0, -at.y, at.z)
		out.append([base + Vector4(0.0, 0.2, 0.0, 0.0), Vector4(1.6, 0.4, 1.6, 1.6), STONE_DARK, true])
		out.append([base + Vector4(0.0, 0.4 + tall * 0.5, 0.0, 0.0), Vector4(1.05, tall, 1.05, 1.05), STONE, true])
		if tall > 8.0:
			out.append([base + Vector4(0.0, 0.4 + tall + 0.2, 0.0, 0.0), Vector4(1.5, 0.4, 1.5, 1.5), STONE_DARK, true])
	# A fallen drum from one of the broken ones, lying along x.
	out.append([CHAMBER + Vector4(-7.4, 0.5, 6.0, -1.0), Vector4(3.0, 1.0, 1.0, 1.0), STONE, true])
	# The corridor's stands: a ring of four at each station.
	for z in STATIONS:
		for ring in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var at := Vector4(ring.x * STAND_OFFSET, 0.0, z, ring.y * STAND_OFFSET)
			out.append([at + Vector4(0.0, 1.35, 0.0, 0.0), Vector4(0.07, 2.7, 0.07, 0.07), STEEL, false])
			out.append([at + Vector4(0.0, 0.04, 0.0, 0.0), Vector4(0.55, 0.08, 0.55, 0.55), STEEL, false])
			out.append([at + Vector4(0.0, 2.75, -0.02, 0.0), Vector4(0.46, 0.30, 0.12, 0.46), STEEL, false])
			out.append([at + Vector4(0.0, 2.75, -0.09, 0.0), Vector4(0.38, 0.22, 0.03, 0.38), LAMP, false])
	# A walkway of boards down the corridor.
	var z := 3.0
	while z > CORRIDOR.y - 1.0:
		out.append([Vector4(0.0, 0.03, z, 0.0), Vector4(1.3, 0.06, 0.34, 1.3), PLANK, false])
		z -= 0.62
	# Cables either side of it, in x and in w.
	for s in [-1.0, 1.0]:
		out.append([Vector4(s * 1.3, 0.025, (4.0 + CHAMBER.z + 6.0) * 0.5, 0.0), Vector4(0.06, 0.05, 4.0 - CHAMBER.z - 6.0, 0.06), CABLE, false])
		out.append([Vector4(0.0, 0.025, (4.0 + CHAMBER.z + 6.0) * 0.5, s * 1.3), Vector4(0.06, 0.05, 4.0 - CHAMBER.z - 6.0, 0.06), CABLE, false])
	# Light towers round the plinth, facing it.
	for t in [Vector3(7.6, 5.0, 0.0), Vector3(-7.6, 5.0, 0.0), Vector3(7.6, -6.5, 0.0), Vector3(-7.6, -6.5, 0.0)]:
		var base := CHAMBER + Vector4(t.x, 0.0, -t.y, t.z)
		out.append([base + Vector4(0.0, 3.2, 0.0, 0.0), Vector4(0.14, 6.4, 0.14, 0.14), STEEL, true])
		out.append([base + Vector4(0.0, 0.1, 0.0, 0.0), Vector4(1.1, 0.2, 1.1, 1.1), STEEL, true])
		out.append([base + Vector4(0.0, 6.5, 0.0, 0.0), Vector4(1.5, 0.45, 0.5, 0.9), STEEL, false])
		out.append([base + Vector4(-signf(t.x) * 0.28, 6.5, 0.0, 0.0), Vector4(0.04, 0.34, 0.40, 0.8), LAMP, false])
	# The research site: two tables with instruments, crates, cases and a generator.
	for table in [[Vector4(-7.0, 0.0, -31.5, 0.0), 1.0], [Vector4(7.2, 0.0, -40.0, 0.0), -1.0]]:
		var at: Vector4 = table[0]
		out.append([at + Vector4(0.0, 0.86, 0.0, 0.0), Vector4(2.2, 0.06, 0.9, 0.9), TABLE, true])
		for leg in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			out.append([at + Vector4(leg.x * 1.0, 0.42, leg.y * 0.38, 0.0), Vector4(0.05, 0.84, 0.05, 0.8), STEEL, false])
		out.append([at + Vector4(-0.5, 1.02, 0.0, 0.0), Vector4(0.52, 0.26, 0.40, 0.40), STEEL, false])
		out.append([at + Vector4(-0.5, 1.03, 0.205, 0.0), Vector4(0.42, 0.18, 0.02, 0.32), SCREEN, false])
		out.append([at + Vector4(0.55, 0.93, 0.0, 0.0), Vector4(0.5, 0.08, 0.34, 0.34), CASE, false])
	for crate in [Vector4(-10.2, 0.55, -40.5, 1.5), Vector4(-10.2, 1.65, -40.5, 1.5), Vector4(-9.0, 0.55, -41.6, 1.2),
			Vector4(9.6, 0.55, -30.5, -1.8), Vector4(10.4, 0.55, -31.8, -1.0)]:
		out.append([crate, Vector4(1.1, 1.1, 1.1, 1.1), CRATE, true])
	for case in [Vector4(-8.8, 0.25, -39.0, 2.4), Vector4(9.1, 0.25, -32.6, -2.6), Vector4(-6.2, 0.25, -30.1, 0.9)]:
		out.append([case, Vector4(0.9, 0.5, 0.6, 0.6), CASE, true])
	out.append([Vector4(-9.2, 0.5, -28.4, 0.0), Vector4(1.4, 1.0, 0.8, 0.8), GENERATOR, true])
	out.append([Vector4(-9.2, 1.05, -28.4, 0.0), Vector4(1.0, 0.1, 0.5, 0.5), STEEL, false])
	# The surveyor's tripod, in front of the plinth to the left.
	var tripod := CHAMBER + Vector4(-4.2, 0.0, 5.0, 0.0)
	for leg in [Vector4(0.25, 0, 0.14, 0), Vector4(-0.25, 0, 0.14, 0), Vector4(0, 0, -0.28, 0), Vector4(0, 0, 0, 0.28), Vector4(0, 0, 0, -0.28)]:
		out.append([tripod + leg * 0.8 + Vector4(0.0, 0.6, 0.0, 0.0), Vector4(0.04, 1.2, 0.04, 0.04), STEEL, false])
	out.append([tripod + Vector4(0.0, 1.32, 0.0, 0.0), Vector4(0.26, 0.2, 0.34, 0.26), GENERATOR, false])
	return out


## Where the player cannot go, as boxes: every prop marked solid.
func solid_boxes() -> Array:
	var out := []
	for prop in props():
		if prop[3]:
			out.append([prop[0], prop[1]])
	return out


# ------------------------------------------------------------------ baking

func bake() -> TerrainBake.Builder:
	var walls := TerrainBake.Builder.new()
	for chunk in CHUNKS:
		var part: TerrainBake.Builder = _bake_walls(chunk[0], chunk[1], chunk[2])
		print("   walls, grid %d over %s: %d tetrahedra" % [chunk[2], chunk[1] - chunk[0], part.tet_count()])
		walls.append(part)
	var ground: TerrainBake.Builder = TerrainBake.bake_height_box(
		Vector3(LO.x + 1.0, LO.z + 1.0, LO.w + 1.0), Vector3(HI.x - 1.0, HI.z - 1.0, HI.w - 1.0),
		2.0, floor_height, floor_colour, [], -0.05)
	walls.append(ground)
	for prop in props():
		var colour: Color = prop[2]
		walls.append(TerrainBake.bake_box(prop[0], prop[1], func(q: Vector4, outward: Vector4) -> Color:
			# Tops lighter than sides, and the foot of anything standing on the floor darker.
			var c: Color = colour if outward.y > 0.5 else colour.darkened(0.25)
			return c.lerp(Color.BLACK, 0.35 * (1.0 - smoothstep(0.0, 0.4, q.y)) * float(outward.y < 0.5))))
	return walls


func _bake_walls(lo: Vector4, hi: Vector4, grid: int) -> TerrainBake.Builder:
	var field := VoxelField4D.new(grid)
	var cell: Vector4 = (hi - lo) / float(grid - 1)
	var mean: float = (cell.x + cell.y + cell.z + cell.w) * 0.25
	var to_world := func(g: Vector4) -> Vector4:
		return lo + g * cell
	var grid_density := func(g: Vector4) -> float:
		return rock_density(to_world.call(g)) / mean
	var grid_gradient := func(g: Vector4) -> Vector4:
		var h := 0.05
		var out := Vector4.ZERO
		for axis in 4:
			var e := Vector4.ZERO
			e[axis] = h
			out[axis] = (float(grid_density.call(g + e)) - float(grid_density.call(g - e))) / (2.0 * h)
		return out
	field.add_layer(VoxelField4D.VoxelMaterial.GROUND, grid_density, grid_gradient, 0.6)
	return TerrainBake.bake_density(field, to_world, rock_density, wall_colour, [[1.2, 0.55], [3.5, 0.5]], -0.05)
