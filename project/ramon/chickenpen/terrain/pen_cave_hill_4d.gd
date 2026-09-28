extends RefCounted

## The hill with the hole in it, back and to the right of the pen: a round grassy hill with a
## rock face at its foot, and in the face a great half-sunk arch going into the dark.
## Walking to the back of it takes you to the cave (cave/cave.tscn).
##
## Baked like the hills - _bake_terrain_runner.gd what=cave_hill - and saved as one mesh.
##
## THE OPENING SITS HALF IN THE GROUND. Ramon, 28 Sept: bigger, more epic, and not a sewer
## pipe - "a circular opening would for example sit halfway in the ground, like half a
## circle or ellipse". So the tunnel's cross-section is an ellipsoid centred ON the ground
## line, 7.2 m across and 5 m tall above it, and you walk straight in off the field. Its
## lower half is simply not there, which is what makes it read as a hole in a hillside
## rather than a hole in a rock.
##
## TWO PIECES, ONE MESH. Most of the hill is a height, which is cheap and exact - but a height
## has no inside, so it cannot have a tunnel in it. Round the mouth the hill is a density
## field instead, through the voxel port's dual contouring: a block of the same hill (the
## height turned into a density, h - y), a rock face pushed out of its foot, and the tunnel
## taken out of both. Under that block the height is carved away, so its surface never runs
## through the tunnel. The carve stops a metre and a half inside the block's edge, and in
## that band both surfaces are the same hill in the same colours, so the join does not show.
##
## THE TUNNEL IS ROUND IN THREE DIRECTIONS, NOT TWO. It runs into the hill along z, and its
## cross-section is round in (x, w) and tall in y. Turn the slice into W and the arch is
## still an arch - one that was only round in x and y would close up to a slot.
##
## DARKNESS WITHOUT A LIGHT. The pen has no 4D shadows, so the dark is painted on: the 4D
## occlusion count darkens the walls as the rock closes round them, the colour falls toward
## black with depth, and the far end is black outright. It reads like the theatre's night,
## where the dark is also baked rather than lit.

const TerrainBake := preload("res://ramon/chickenpen/terrain/terrain_bake_4d.gd")

## The hill: centre, half-size in x, z, w, and its height.
const HILL := Vector4(17.0, 0.0, -40.0, 0.0)
const HALF := Vector3(14.0, 10.0, 9.0)
const TOP := 11.0
## Where the slope starts, as a fraction of the half-size. Small, so it is a dome and not a
## table.
const SHOULDER := 0.15
## Squareness of the footprint: 2 is round, higher is boxier. Three is round enough to read
## as a hill and square enough that box colliders stay close to its sides.
const ROUNDNESS := 3.0

## The arch: where its middle meets the ground, its half-width (in x and in w) and height.
const MOUTH := Vector4(16.5, 0.0, -28.6, 0.0)
const ARCH_HALF_WIDTH := 3.6
const ARCH_HEIGHT := 5.0
## The tunnel runs this far in, and its last few metres close round into a blind end.
const TUNNEL_DEPTH := 7.0
const END_ROUNDING := 2.5
## The floor inside sits a hair above the field, so the tunnel's own dark floor is drawn
## rather than the field's green one.
const FLOOR := 0.04
## The rock face the arch is cut into: how far it stands out of the hill beside and above
## the opening, and how far in front of the hill's foot its face is.
const FACE_MARGIN := 1.2
const FACE_ABOVE := 1.3
## The hillside round the entrance: how high it stands over the arch, and how far either
## side of the mouth (in x and w) it has come down to the field.
const SHOULDER_HEIGHT := 8.0
const SHOULDER_WIDTH := 9.5

## The block of hill that is dual-contoured instead of drawn as a height: a 14 m cube in
## grid terms, round the mouth.
const BLOCK_MIN := Vector4(9.5, -1.2, -40.0, -7.0)
const BLOCK_SIZE := 14.0
const BLOCK_GRID := 14
## The part of the height taken away under the block, inset from its edges.
const CARVE_INSET := 1.5

const GRASS := Color(0.20, 0.27, 0.12)
const GRASS_HIGH := Color(0.29, 0.33, 0.15)
const BANK := Color(0.30, 0.27, 0.20)
const STONE_DARK := Color(0.19, 0.195, 0.205)
## Dark grey, a little cool, because the evening sun warms everything it lands on and a
## neutral grey came out terracotta (Ramon, 28 Sept: "dark grey, not terracotta").
const FACE_ROCK := Color(0.29, 0.30, 0.32)
const FACE_ROCK_DARK := Color(0.17, 0.175, 0.19)

var _bumps := FastNoiseLite.new()
var _grain := FastNoiseLite.new()


func _init() -> void:
	_bumps.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bumps.seed = 31
	_bumps.frequency = 1.0 / 4.0
	_grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_grain.seed = 47
	_grain.frequency = 1.0 / 1.6
	_grain.fractal_type = FastNoiseLite.FRACTAL_FBM
	_grain.fractal_octaves = 3


## How far out from the hill's middle (x, z, w) is: 1 on its footprint's edge, with a wobble
## so the edge is not ruled.
func hill_extent(x: float, z: float, w: float) -> float:
	var d := Vector3(absf(x - HILL.x) / HALF.x, absf(z - HILL.z) / HALF.y, absf(w - HILL.w) / HALF.z)
	var q: float = pow(pow(d.x, ROUNDNESS) + pow(d.y, ROUNDNESS) + pow(d.z, ROUNDNESS), 1.0 / ROUNDNESS)
	return q + 0.04 * _bumps.get_noise_3d(x * 0.8, z * 0.8, w * 0.8)


## The hill's height, whole: the dome, and the shoulder that wraps round the entrance.
func hill_height(x: float, z: float, w: float) -> float:
	var q: float = hill_extent(x, z, w)
	var dome: float = TOP * (1.0 - smoothstep(SHOULDER, 1.0, q))
	dome += 0.35 * _bumps.get_noise_3d(x, z, w) * (1.0 - smoothstep(0.8, 1.0, q))
	return maxf(dome, shoulder_height(x, z, w)) - 0.2


## The hillside round the entrance (Ramon, 28 Sept: "the hill that connects to the cave
## entrance ... slightly bigger"). Turf stands up over the arch and runs down either side of
## the rock face to the field, reaching further forward the further it is from the arch, so
## the entrance sits IN the hill rather than in front of it. Directly round the arch it stops
## at the rock face, so the rock frames the opening and is not buried.
##
## It is part of the height, not only of the dual-contoured block: its outer flanks are
## smooth slopes, which the height draws perfectly well, and the block only has to cover the
## part round the arch where the slope turns to a face.
func shoulder_height(x: float, z: float, w: float) -> float:
	var lateral: float = Vector2(x - MOUTH.x, w - MOUTH.w).length()
	# Rounded across, highest over the arch: a ridge, not a table. A flat-topped shoulder
	# hid the dome behind it and read as a block of rock.
	var fade: float = 1.0 - smoothstep(1.0, SHOULDER_WIDTH, lateral)
	if fade <= 0.0:
		return -1.0
	var face: float = MOUTH.z + 0.9
	var reach: float = 0.3 + 5.0 * smoothstep(ARCH_HALF_WIDTH + 0.4, ARCH_HALF_WIDTH + 3.4, lateral)
	var rise: float = smoothstep(face + reach, face - 1.2, z)
	return SHOULDER_HEIGHT * fade * rise + 0.3 * _bumps.get_noise_3d(x, z, w)


## The height as it is drawn: the whole hill, less the part under the dual-contoured block.
func height(x: float, z: float, w: float) -> float:
	var lo: Vector4 = BLOCK_MIN + Vector4.ONE * CARVE_INSET
	var hi: Vector4 = BLOCK_MIN + Vector4.ONE * (BLOCK_SIZE - CARVE_INSET)
	if x > lo.x and x < hi.x and z > lo.z and z < hi.z and w > lo.w and w < hi.w:
		return -0.5
	return hill_height(x, z, w)


func colour(p: Vector4, normal: Vector4, _r: float) -> Color:
	var slope: float = 1.0 - clampf(normal.y, 0.0, 1.0)
	var grain: float = _grain.get_noise_3d(p.x, p.z, p.w) * 0.5 + 0.5
	var c: Color = GRASS.lerp(GRASS_HIGH, smoothstep(1.0, TOP, p.y) * (0.4 + 0.6 * grain))
	# Earth and stone where it is too steep for turf.
	return c.lerp(BANK.lerp(STONE_DARK, grain), smoothstep(0.45, 0.75, slope))


## Positive inside the tunnel. Round in (x, w), tall in y, centred on the ground, so what is
## above the floor is half an ellipsoid swept straight back, closing to a blind end.
func tunnel_density(p: Vector4) -> float:
	var u: float = (p.x - MOUTH.x) / ARCH_HALF_WIDTH
	var v: float = p.y / ARCH_HEIGHT
	var s: float = (p.w - MOUTH.w) / ARCH_HALF_WIDTH
	var into: float = MOUTH.z - p.z
	var end: float = maxf(0.0, into - (TUNNEL_DEPTH - END_ROUNDING)) / END_ROUNDING
	var inside: float = (1.0 - sqrt(u * u + v * v + s * s + end * end)) * ARCH_HALF_WIDTH
	return minf(inside, p.y - FLOOR)


## Positive inside the rock face: a slab pushed forward out of the hill's foot round the
## arch, its front a little in front of the mouth and rough.
func face_density(p: Vector4) -> float:
	var rough: float = 0.35 * (_grain.get_noise_3d(p.x, p.y, p.z) + 0.6 * _grain.get_noise_3d(p.w * 1.1 + 40.0, p.x, p.y))
	var front: float = (MOUTH.z + 0.9) - p.z
	var dx: float = (p.x - MOUTH.x) / (ARCH_HALF_WIDTH + FACE_MARGIN)
	var dw: float = (p.w - MOUTH.w) / (ARCH_HALF_WIDTH + FACE_MARGIN)
	var dy: float = maxf(p.y, 0.0) / (ARCH_HEIGHT + FACE_ABOVE)
	var e := 2.6
	var round_: float = (1.0 - pow(pow(absf(dx), e) + pow(absf(dw), e) + pow(dy, e), 1.0 / e)) * (ARCH_HALF_WIDTH + FACE_MARGIN)
	return minf(front, round_) + rough


func hill_density(p: Vector4) -> float:
	return hill_height(p.x, p.z, p.w) - p.y


## The block round the mouth, in world space: hill or rock face, whichever is there, with
## the tunnel taken out.
func block_density(p: Vector4) -> float:
	return minf(maxf(hill_density(p), face_density(p)), -tunnel_density(p))


## How far into the tunnel a point is: 0 at the mouth, 1 at the far end.
func tunnel_depth(p: Vector4) -> float:
	return clampf((MOUTH.z + 0.5 - p.z) / TUNNEL_DEPTH, 0.0, 1.0)


func block_colour(p: Vector4, normal: Vector4, r: float) -> Color:
	var grain: float = _grain.get_noise_3d(p.x * 2.0, p.y * 2.0, p.z * 2.0 + p.w) * 0.5 + 0.5
	var t: float = tunnel_density(p)
	if t > -0.6:
		# The tunnel's own walls and floor: rock going to black with depth, and the blind
		# end black outright.
		var c: Color = FACE_ROCK_DARK.lerp(STONE_DARK, grain)
		var depth: float = tunnel_depth(p)
		c = c.lerp(Color.BLACK, pow(smoothstep(0.0, 0.75, depth), 0.6))
		# Darker low down, where the light from the mouth reaches least.
		c = c.lerp(Color.BLACK, 0.35 * (1.0 - smoothstep(0.0, 2.0, p.y)) * smoothstep(0.0, 0.3, depth))
		return c
	if face_density(p) >= hill_density(p) - 0.15:
		var c: Color = FACE_ROCK.lerp(FACE_ROCK_DARK, grain * 0.7)
		# Moss and turf on whatever faces up.
		return c.lerp(GRASS, smoothstep(0.55, 0.85, normal.y) * 0.8)
	return colour(p, normal, r)


## What you bump into. The hill as tiers of boxes stepped in to follow the dome, three boxes
## a tier - long in x, in z and in w - because one box round a rounded footprint either
## sticks out at the corners or leaves the sides walkable. Where a tier crosses the tunnel it
## is split round it, so the tunnel stays open to walk into. Then the rock face either side
## of the arch, and the blind end.
func solid_boxes() -> Array:
	var out := []
	var gap_x := Vector2(MOUTH.x - ARCH_HALF_WIDTH * 0.85, MOUTH.x + ARCH_HALF_WIDTH * 0.85)
	var gap_w := Vector2(MOUTH.w - ARCH_HALF_WIDTH * 0.85, MOUTH.w + ARCH_HALF_WIDTH * 0.85)
	var back: float = MOUTH.z - TUNNEL_DEPTH + 0.6
	for tier in [[0.0, 1.8], [1.8, 4.5], [4.5, 7.5], [7.5, TOP - 0.4]]:
		# How far out the dome is still as high as the bottom of this tier.
		var q: float = _extent_at_height(tier[0] + 0.25)
		var y: float = (tier[0] + tier[1]) * 0.5
		var tall: float = tier[1] - tier[0]
		for long in 3:
			var f := Vector3(0.62, 0.62, 0.62)
			f[long] = 0.97
			var centre := Vector4(HILL.x, y, HILL.z, 0.0)
			var size := Vector4(HALF.x * 2.0 * q * f.x, tall, HALF.y * 2.0 * q * f.y, HALF.z * 2.0 * q * f.z)
			if tier[0] < ARCH_HEIGHT - 0.5 and centre.z + size.z * 0.5 > back:
				out.append_array(_split_round_tunnel(centre, size, gap_x, gap_w, back))
			else:
				out.append([centre, size])
	# The hillside round the entrance, split round the tunnel like the tiers.
	var ring_front: float = MOUTH.z + 0.9 + 1.5
	var ring_back: float = HILL.z + HALF.y * 0.7
	var ring := Vector4(MOUTH.x, 1.5, (ring_front + ring_back) * 0.5, MOUTH.w)
	var ring_size := Vector4(SHOULDER_WIDTH * 1.3, 3.0, ring_front - ring_back, SHOULDER_WIDTH * 1.3)
	out.append_array(_split_round_tunnel(ring, ring_size, gap_x, gap_w, back))
	# The rock face beside the arch, in front of the hill's foot.
	var z0: float = HILL.z + HALF.y * 0.8
	var z1: float = MOUTH.z + 0.9
	for side in [-1.0, 1.0]:
		var inner: float = ARCH_HALF_WIDTH * 0.85
		var outer: float = ARCH_HALF_WIDTH + FACE_MARGIN
		out.append([Vector4(MOUTH.x + side * (inner + outer) * 0.5, ARCH_HEIGHT * 0.5, (z0 + z1) * 0.5, 0.0),
			Vector4(outer - inner, ARCH_HEIGHT, z1 - z0, outer * 2.0)])
		out.append([Vector4(MOUTH.x, ARCH_HEIGHT * 0.5, (z0 + z1) * 0.5, side * (inner + outer) * 0.5),
			Vector4(inner * 2.0, ARCH_HEIGHT, z1 - z0, outer - inner)])
	# The blind end, so the tunnel is blind to bodies as well as to eyes.
	out.append([Vector4(MOUTH.x, ARCH_HEIGHT * 0.5, back - 0.5, MOUTH.w), Vector4(gap_x.y - gap_x.x, ARCH_HEIGHT, 1.0, gap_w.y - gap_w.x)])
	return out


## A box with the tunnel's footprint (x in gap_x, w in gap_w, z in front of [param back]) cut
## out of it: whatever lies left and right of the gap in x, then the parts of the middle
## strip on either side of it in w, then the part of the middle behind the tunnel.
func _split_round_tunnel(centre: Vector4, size: Vector4, gap_x: Vector2, gap_w: Vector2, back: float) -> Array:
	var lo: Vector4 = centre - size * 0.5
	var hi: Vector4 = centre + size * 0.5
	var out := []
	var add := func(a: Vector4, b: Vector4) -> void:
		if b.x - a.x > 0.05 and b.z - a.z > 0.05 and b.w - a.w > 0.05:
			out.append([(a + b) * 0.5, b - a])
	add.call(lo, Vector4(minf(gap_x.x, hi.x), hi.y, hi.z, hi.w))
	add.call(Vector4(maxf(gap_x.y, lo.x), lo.y, lo.z, lo.w), hi)
	var mx := Vector2(maxf(gap_x.x, lo.x), minf(gap_x.y, hi.x))
	add.call(Vector4(mx.x, lo.y, lo.z, lo.w), Vector4(mx.y, hi.y, hi.z, minf(gap_w.x, hi.w)))
	add.call(Vector4(mx.x, lo.y, lo.z, maxf(gap_w.y, lo.w)), Vector4(mx.y, hi.y, hi.z, hi.w))
	var mw := Vector2(maxf(gap_w.x, lo.w), minf(gap_w.y, hi.w))
	add.call(Vector4(mx.x, lo.y, lo.z, mw.x), Vector4(mx.y, hi.y, minf(back, hi.z), mw.y))
	return out


## The footprint fraction at which the dome comes down to [param y].
func _extent_at_height(y: float) -> float:
	var lo := SHOULDER
	var hi := 1.0
	for i in 30:
		var mid: float = (lo + hi) * 0.5
		if TOP * (1.0 - smoothstep(SHOULDER, 1.0, mid)) - 0.2 > y:
			lo = mid
		else:
			hi = mid
	return lo


## Where to stand to be taken through: the back of the tunnel, the full width of its floor.
## [centre, half-size].
func way_in() -> Array:
	var into: float = TUNNEL_DEPTH - 1.6
	return [Vector4(MOUTH.x, 1.2, MOUTH.z - into, MOUTH.w),
		Vector4(ARCH_HALF_WIDTH * 0.7, 1.4, 1.0, ARCH_HALF_WIDTH * 0.7)]


func bake() -> TerrainBake.Builder:
	var hill: TerrainBake.Builder = TerrainBake.bake_height_box(
		Vector3(HILL.x - HALF.x * 1.1, HILL.z - HALF.y * 1.1, -HALF.z * 1.1),
		Vector3(HILL.x + HALF.x * 1.1, HILL.z + HALF.y * 1.1, HALF.z * 1.1),
		1.35, height, colour, [[0.8, 0.5], [3.0, 0.45]], -0.05)
	var field := VoxelField4D.new(BLOCK_GRID)
	var cell: float = BLOCK_SIZE / float(BLOCK_GRID - 1)
	var to_world := func(g: Vector4) -> Vector4:
		return BLOCK_MIN + g * cell
	var grid_density := func(g: Vector4) -> float:
		return block_density(to_world.call(g)) / cell
	var grid_gradient := func(g: Vector4) -> Vector4:
		var h := 0.05
		var out := Vector4.ZERO
		for axis in 4:
			var e := Vector4.ZERO
			e[axis] = h
			out[axis] = (float(grid_density.call(g + e)) - float(grid_density.call(g - e))) / (2.0 * h)
		return out
	field.add_layer(VoxelField4D.VoxelMaterial.GROUND, grid_density, grid_gradient, 0.6)
	var block: TerrainBake.Builder = TerrainBake.bake_density(field, to_world, block_density, block_colour, [[0.8, 0.5], [3.0, 0.45]], -0.05)
	hill.append(block)
	return hill
