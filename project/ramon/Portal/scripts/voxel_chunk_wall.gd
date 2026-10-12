extends Node4D
## A wall made entirely of voxel chunks, whose openings heal shut again.
##
## Every artifact this prototype fought - the strip stripes, the collar shards,
## the black band at a window's edge - came from box geometry meeting cut
## geometry and depending on faces lining up exactly. A wall that is voxels all
## the way across has no such junction, so that class cannot occur.
##
## The wall owns the field; chunks only sample it. A shot appends a ball to
## `carves` and dirties the chunks it can reach, so cost tracks the edit rather
## than the wall - and because every chunk sees the whole list, a new cut
## interacts with the old ones exactly the way chipping does in VoxelMining.
##
## Openings are permanent by default. They can be made to heal after LIFETIME,
## which was originally a budget measure - a healed carve leaves the list, so a
## chunk rebuild never replays a long history of old holes - but a shooting range
## wants its holes to stay.

const ChunkScript := preload("res://ramon/Portal/scripts/voxel_wall_chunk.gd")

## How long an opening lasts before it heals shut, in seconds.
##
## There is deliberately NO grow/shrink animation. An earlier version eased the
## opening out to full size and back down through five quantised sizes, and each
## of those sizes was a re-contour of every chunk the ball touched: measured, 3
## shots cost 21 rebuilds where they now cost 6. The animation was multiplying
## the single most expensive operation in the system by seven to decorate it.
##
## Zero or less means openings are permanent, which is the default: a shooting
## range where the holes stay is what this is for.
##
## The cost consequence is real and worth knowing. Healing kept the carve list
## short, and every chunk rebuild replays every carve that reaches it - so with
## permanent holes, repeatedly shooting the SAME patch of wall makes each rebuild
## there progressively slower. Shooting fresh wall stays flat. Set a lifetime
## again if that ever starts to bite.
const LIFETIME := 0.0

var half_a: float = 6.0
var half_b: float = 2.0
var thickness: float = 0.6
var w_half_extent: float = 12.0
var face_cell: float = 0.25

## The wall's solid extent, inset one cell inside the chunk coverage so the outer
## edge is capped by geometry rather than running off the end of the grid.
var solid_half_a: float = 6.0
var solid_half_b: float = 2.0

var normal := Vector4(0.0, 0.0, 1.0, 0.0)
var up := Vector4(0.0, 1.0, 0.0, 0.0)
var right := Vector4(1.0, 0.0, 0.0, 0.0)

## Each entry: {"centre": Vector2, "radius": float, "age": float}.
var carves: Array[Dictionary] = []

var chunks: Array[Node4D] = []
var build_msec: float = 0.0
var last_rebuild_msec: float = 0.0
var last_dirty_count: int = 0
var rebuild_events: int = 0


func build() -> void:
	var started_usec: int = Time.get_ticks_usec()
	solid_half_a = half_a - face_cell
	solid_half_b = half_b - face_cell

	var owned: float = ChunkScript.owned_size(face_cell)
	var count_a: int = int(ceil(half_a * 2.0 / owned))
	var count_b: int = int(ceil(half_b * 2.0 / owned))

	for ia in range(count_a):
		for ib in range(count_b):
			var centre := Vector2(
				-half_a + owned * (float(ia) + 0.5),
				-half_b + owned * (float(ib) + 0.5))
			var chunk := ChunkScript.new()
			chunk.name = "Chunk_%d_%d" % [ia, ib]
			chunk.wall = self
			chunk.owned_centre = centre
			chunk.face_cell = face_cell
			chunk.thickness = thickness
			chunk.w_half_extent = w_half_extent
			chunk.position = Vector4(centre.x, centre.y, 0.0, 0.0)
			add_child(chunk)
			chunk.build()
			chunks.append(chunk)

	build_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0


func local_of(world_point: Vector4) -> Vector2:
	var offset: Vector4 = world_point - global_position
	return Vector2(offset.dot(right), offset.dot(up))


## How close to the floor a hole has to land before it snaps flush with it.
##
## Not cosmetic: CharacterBody4D has no step-up at all, so a hole whose bottom
## edge sits even a few centimetres above the floor is a hole you can look
## through and cannot walk through. Anyone shooting low clearly means "let me in
## there", so a near-miss is treated as that rather than as a window.
const FLOOR_SNAP_RANGE := 0.75


func carve_at(world_point: Vector4, radius: float) -> int:
	var centre: Vector2 = local_of(world_point)
	var floor_b: float = -solid_half_b
	var gap: float = (centre.y - radius) - floor_b
	if gap > 0.0 and gap <= FLOOR_SNAP_RANGE:
		centre.y = floor_b + radius
	carves.append({"centre": centre, "radius": radius, "age": 0.0})
	return _rebuild_near(centre, radius)


func _rebuild_near(centre: Vector2, radius: float) -> int:
	var started_usec: int = Time.get_ticks_usec()
	var affected: Array[Node4D] = _chunks_reaching(centre, radius)
	for chunk in affected:
		chunk.rebuild()
	last_dirty_count = affected.size()
	last_rebuild_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0
	rebuild_events += 1
	return affected.size()


## Chunks whose owned region the ball can influence. The reach includes the
## ghost ring, because a ball just outside a chunk still changes the QEF
## solution inside it through the cells it borrows.
func _chunks_reaching(centre: Vector2, radius: float) -> Array[Node4D]:
	var owned_half: float = ChunkScript.owned_size(face_cell) * 0.5
	var reach: float = radius + owned_half + face_cell * float(ChunkScript.GHOST_CELLS + 1)
	var affected: Array[Node4D] = []
	for chunk in chunks:
		var delta: Vector2 = chunk.owned_centre - centre
		if absf(delta.x) > reach or absf(delta.y) > reach:
			continue
		affected.append(chunk)
	return affected


## Heals every opening that has outlived LIFETIME, rebuilding each affected
## chunk ONCE however many carves expired on it this frame. Rebuilding per carve
## instead let one chunk be re-contoured several times in a single frame when
## holes overlapped, which is the worst case precisely when the wall is busiest.
func _process(delta_time: float) -> void:
	if LIFETIME <= 0.0 or carves.is_empty():
		return
	var expired: Array[Dictionary] = []
	for index in range(carves.size()):
		var carve: Dictionary = carves[index]
		carve.age += delta_time
		carves[index] = carve
		if carve.age >= LIFETIME:
			expired.append(carve)
	if expired.is_empty():
		return

	for carve in expired:
		carves.erase(carve)

	var dirty: Dictionary = {}
	for carve in expired:
		for chunk in _chunks_reaching(carve.centre, carve.radius):
			dirty[chunk] = true

	var started_usec: int = Time.get_ticks_usec()
	for chunk in dirty:
		chunk.rebuild()
	last_dirty_count = dirty.size()
	last_rebuild_msec = float(Time.get_ticks_usec() - started_usec) / 1000.0
	rebuild_events += 1


func total_tetra_count() -> int:
	var total := 0
	for chunk in chunks:
		total += chunk.tetra_count
	return total


func total_collider_count() -> int:
	var total := 0
	for chunk in chunks:
		total += chunk.collider_count
	return total
