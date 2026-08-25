class_name VoxelWorld4D
extends RefCounted
## Sparse hash+brick voxel world (NanoVDB-style, adapted to 4D) - the
## editable storage layer beneath the terrain system. Owns the single
## shared world_origin/step grid alignment that makes independently
## generated neighboring bricks agree exactly at their shared boundary
## (see VoxelBrick4D), the sparse brick hash itself, and brick lifecycle:
## creation with a correctness-checked tile-collapse test, and meshing via
## a swappable backend (see terrain4d_mesh_backend_mt.gd - Marching
## Tetrahedra, swapped in after DC was found not watertight at any tested
## resolution; terrain4d_mesh_backend_dc.gd is kept, unreferenced, as the
## prior trusted implementation) with output filtered so each real-world
## tet is emitted by exactly one brick.
##
## Editing (set_density_region/edit_sphere/edit_box) mutates brick density
## in place and re-runs the exact same collapse/meshing pipeline on every
## affected brick, expanded by the meshing backend's own declared apron
## reach - see those functions below.
##
## Two regeneration paths exist side by side:
##   regenerate_dirty_bricks() - fully synchronous, blocks the calling
##     thread until every dirty brick is meshed. Still the default for
##     edit_sphere/edit_box/set_density_region (sync=true) so existing
##     callers/tests see unchanged, immediately-consistent behavior.
##   process_regeneration_async() - dispatches one WorkerThreadPool job
##     per dirty brick and finalizes whatever jobs have completed since
##     the last call; a real game loop should call this every frame
##     instead, and pass sync=false to the edit functions, so an edit
##     never blocks a frame - see the comment on process_regeneration_async
##     for the thread-safety reasoning (what runs on the worker thread
##     vs. what stays on the calling thread, and why).

var world_origin: Vector4
var step: Vector4
## The real procedural density field (Vector4 -> float) - e.g. a
## terrain_generator-style get_density. Sampled directly only during
## brick creation/collapse-checking; regeneration reads from each brick's
## own stored density instead (see VoxelBrick4D.stored_density_fn), so a
## future edit is respected by regen without this world needing to know
## about edits at all.
var density_fn: Callable

var _bricks: Dictionary = {}  # packed brick-coord int -> VoxelBrick4D
## packed brick-coord int -> WorkerThreadPool task id, for a regen job
## dispatched by process_regeneration_async() that hasn't been finalized
## yet (see that function).
var _pending_regen_tasks: Dictionary = {}
## Keys (set-like: value is always `true`) of every brick currently
## marked dirty - lets regeneration (sync or async) iterate only bricks
## that actually need work instead of scanning every resident brick on
## every call. This is a REAL measured bottleneck, not a theoretical one:
## a bare `for key in _bricks` scan run once per frame during population
## turned into an O(total resident bricks) cost EVERY frame as that total
## grew into the thousands - a showcase scene that should have loaded in
## a few seconds took over a minute because of exactly this.
var _dirty_brick_keys: Dictionary = {}
## Keys of every brick that is NOT collapsed (has real density/mesh data)
## - lets renderers/culling (TerrainChunkPool4D.update()) iterate only
## bricks that could possibly need a pooled node, instead of every
## resident brick - most of which collapse in a real world and are
## irrelevant to rendering. The other half of the same bottleneck above.
var _dense_brick_keys: Dictionary = {}

func _init(p_world_origin: Vector4, p_step: Vector4, p_density_fn: Callable) -> void:
	world_origin = p_world_origin
	step = p_step
	density_fn = p_density_fn

## Packs a brick coordinate into a single int Dictionary key. Coordinates
## are masked to 16 bits each (two's complement) before packing - plenty
## of range for any brick grid this project will reach (+-32768 bricks per
## axis, i.e. +-32768*3 nominal cells) - and never unpacked, since every
## caller already has the Vector4i coordinate on hand.
static func brick_key(coord: Vector4i) -> int:
	return ((coord.x & 0xFFFF) << 48) | ((coord.y & 0xFFFF) << 32) | ((coord.z & 0xFFFF) << 16) | (coord.w & 0xFFFF)

func has_brick(coord: Vector4i) -> bool:
	return _bricks.has(brick_key(coord))

## Marks an existing, non-collapsed brick dirty without going through
## set_density_region - for callers that mutated a brick's density by
## some other means and need to force a re-mesh. Both `dirty` fields on
## VoxelBrick4D itself are just plain vars (GDScript has no property
## setters here) - going through this function instead of poking
## `brick.dirty = true` directly matters because regeneration (sync or
## async) iterates _dirty_brick_keys, not brick fields, since scanning
## every resident brick every call was a real measured bottleneck at
## scale (see the comment on _dirty_brick_keys). No-op if the brick
## doesn't exist or is collapsed - a collapsed brick has no density array
## to remesh from.
func mark_brick_dirty(coord: Vector4i) -> void:
	var key := brick_key(coord)
	if not _bricks.has(key):
		return
	var brick: VoxelBrick4D = _bricks[key]
	if brick.is_collapsed:
		return
	brick.dirty = true
	_dirty_brick_keys[key] = true

func get_brick(coord: Vector4i) -> VoxelBrick4D:
	return _bricks.get(brick_key(coord), null)

func get_all_bricks() -> Array:
	return _bricks.values()

## Every non-collapsed (dense) resident brick - O(dense count), not
## O(total resident) - see _dense_brick_keys. This is what
## TerrainChunkPool4D.update() iterates instead of get_all_bricks().
func get_dense_bricks() -> Array:
	var result := []
	for key in _dense_brick_keys:
		result.append(_bricks[key])
	return result

func dense_brick_count() -> int:
	return _dense_brick_keys.size()

## Creates (sampling + tile-collapse-checking, but NOT meshing - see
## regenerate_dirty_bricks) the brick at `coord` if it doesn't already
## exist, and returns it either way.
func get_or_create_brick(coord: Vector4i) -> VoxelBrick4D:
	var key := brick_key(coord)
	if _bricks.has(key):
		return _bricks[key]
	var brick := VoxelBrick4D.new(coord)
	_bricks[key] = brick
	_sample_and_collapse_check(brick, key)
	return brick

## Phase 1 of brick creation: sample the brick's own full NOMINAL-
## resolution grid - not just its 16 outer corners, which is unsound as a
## collapse test (a solid cave, thin sheet, or isolated feature entirely
## inside a brick, touching none of its corners, would be silently and
## permanently skipped). Only if a sign flip is found among those samples
## does this go on to sample the apron extension and mark the brick for
## meshing; a uniform brick is marked collapsed and never gets a dense
## array at all - collapse-checking and real generation share this first
## (density-only) phase, so a brick that turns out non-uniform isn't
## paying "extra" for the check.
func _sample_and_collapse_check(brick: VoxelBrick4D, key: int) -> void:
	var nominal: Dictionary = VoxelBrick4D.nominal_bounds(brick.brick_coord, world_origin, step)
	var n := VoxelBrick4D.NOMINAL_POINTS_PER_AXIS
	var nominal_samples: Array = []
	nominal_samples.resize(n * n * n * n)
	var first_sign := true
	var uniform_negative := false
	var uniform := true
	# SPIKE INSTRUMENTATION (temporary - see Terrain4DProfile): times the
	# mandatory 256-point collapse-check sampling loop as a whole, so it
	# can be compared against Noise4D.fractal_noise's own self-reported
	# time (the delta is loop/array-write/GDScript-call overhead outside
	# the noise math itself). Remove the two Terrain4DProfile lines (and
	# this paragraph) once the spike's numbers are captured.
	var _profile_t0 := Time.get_ticks_usec()
	for i in range(n):
		for j in range(n):
			for k in range(n):
				for l in range(n):
					var pos := Vector4(
						nominal.min.x + i * step.x, nominal.min.y + j * step.y,
						nominal.min.z + k * step.z, nominal.min.w + l * step.w
					)
					var d: float = density_fn.call(pos)
					nominal_samples[((i * n + j) * n + k) * n + l] = d
					var negative := d < 0.0
					if first_sign:
						uniform_negative = negative
						first_sign = false
					elif negative != uniform_negative:
						uniform = false
	Terrain4DProfile.add("collapse_check_sampling", Time.get_ticks_usec() - _profile_t0)

	if uniform:
		brick.is_collapsed = true
		brick.is_collapsed_solid = uniform_negative
		brick.dirty = false
		return

	brick.is_collapsed = false
	brick.dirty = true
	_dense_brick_keys[key] = true
	_dirty_brick_keys[key] = true
	_sample_full_apron(brick, nominal_samples)

## Phase 2 (only reached for a non-collapsed brick): fills the brick's
## persistent density array over its full apron-extended region, reusing
## the nominal samples phase 1 already computed rather than resampling
## them, and sampling only the genuinely new apron-only points.
func _sample_full_apron(brick: VoxelBrick4D, nominal_samples: Array) -> void:
	# SPIKE INSTRUMENTATION (temporary - see Terrain4DProfile): times this
	# whole function (only ever called for non-collapsed bricks) as
	# "apron_sampling". Remove the two Terrain4DProfile lines (and this
	# comment) once the spike's numbers are captured.
	var _profile_t0 := Time.get_ticks_usec()
	var actual: Dictionary = VoxelBrick4D.actual_bounds(brick.brick_coord, world_origin, step)
	var actual_n := VoxelBrick4D.ACTUAL_POINTS_PER_AXIS
	var nominal_n := VoxelBrick4D.NOMINAL_POINTS_PER_AXIS
	var apron := VoxelBrick4D.APRON_CELLS
	brick.density = PackedByteArray()
	brick.density.resize(actual_n * actual_n * actual_n * actual_n * 2)
	for i in range(actual_n):
		var ni := i - apron
		var in_nominal_i := ni >= 0 and ni < nominal_n
		for j in range(actual_n):
			var nj := j - apron
			var in_nominal_j := nj >= 0 and nj < nominal_n
			for k in range(actual_n):
				var nk := k - apron
				var in_nominal_k := nk >= 0 and nk < nominal_n
				for l in range(actual_n):
					var nl := l - apron
					var d: float
					if in_nominal_i and in_nominal_j and in_nominal_k and nl >= 0 and nl < nominal_n:
						d = nominal_samples[((ni * nominal_n + nj) * nominal_n + nk) * nominal_n + nl]
					else:
						var pos := Vector4(
							actual.min.x + i * step.x, actual.min.y + j * step.y,
							actual.min.z + k * step.z, actual.min.w + l * step.w
						)
						d = density_fn.call(pos)
					DualContour4D._write_density(brick.density, ((i * actual_n + j) * actual_n + k) * actual_n + l, d)
	Terrain4DProfile.add("apron_sampling", Time.get_ticks_usec() - _profile_t0)

## Convenience sphere-shaped "dig or place" edit - every point within
## `radius` of `center` gets `new_value_fn(old_density: float, distance_from_center: float) -> float`
## applied; points outside the sphere are left untouched (this wrapper
## enforces the membership test, so callers don't have to). "Dig" and
## "place" are both just different new_value_fn bodies (e.g. return a
## large positive value to carve out air, a large negative value to fill
## in solid).
func edit_sphere(center: Vector4, radius: float, new_value_fn: Callable, sync: bool = true) -> void:
	var region_min := Vector4(center.x - radius, center.y - radius, center.z - radius, center.w - radius)
	var region_max := Vector4(center.x + radius, center.y + radius, center.z + radius, center.w + radius)
	var radius_sq := radius * radius
	var sphere_fn := func(old_density: float, world_pos: Vector4) -> float:
		var dist_sq := world_pos.distance_squared_to(center)
		if dist_sq > radius_sq:
			return old_density
		return new_value_fn.call(old_density, sqrt(dist_sq))
	set_density_region(region_min, region_max, sphere_fn, sync)

## Convenience axis-aligned box "dig or place" edit - the other half of
## the sphere/box tool decision. Every point inside
## [center - half_extent, center + half_extent] gets
## `new_value_fn(old_density: float, world_pos: Vector4) -> float`
## applied unconditionally - the scanned region already IS the shape, so
## no extra membership test is needed (unlike edit_sphere).
func edit_box(center: Vector4, half_extent: Vector4, new_value_fn: Callable, sync: bool = true) -> void:
	set_density_region(center - half_extent, center + half_extent, new_value_fn, sync)

## The general edit primitive both convenience wrappers above reduce to.
## Mutates density in place across every brick whose OWN storage (nominal
## core OR apron - both matter, since a brick's cached apron copy going
## stale would desync it from an edited neighbor at their shared seam)
## overlaps [region_min, region_max] expanded by the meshing backend's own
## declared stencil_radius_cells(), creating/un-collapsing bricks as
## needed, then eagerly regenerates every touched brick - a single call is
## a fully-applied edit, nothing left half-done.
##
## `new_value_fn(old_density: float, world_pos: Vector4) -> float` decides
## the new density at every grid point in the scanned region - the CALLER
## owns the tool's actual shape; this function only needs the affected
## WORLD REGION, not the shape itself (edit_sphere's wrapper is exactly
## this: it does its own distance check and returns old_density unchanged
## outside the sphere, before this function or the caller's fn ever sees
## a point outside it - well, the caller's fn does see it, in that wrapper
## - but set_density_region itself stays shape-agnostic).
##
## `sync` (default true) regenerates every touched brick synchronously
## before returning, matching this function's original behavior. Pass
## false to instead just mark the affected bricks dirty and return
## immediately - the caller must then drive process_regeneration_async()
## itself (e.g. once a frame) to actually pick the edit up.
func set_density_region(region_min: Vector4, region_max: Vector4, new_value_fn: Callable, sync: bool = true) -> void:
	var apron_cells := TerrainMeshBackendMT.stencil_radius_cells()
	var apron_margin := Vector4(step.x, step.y, step.z, step.w) * float(apron_cells)
	var dirty_min := region_min - apron_margin
	var dirty_max := region_max + apron_margin

	for coord in _bricks_overlapping_actual(dirty_min, dirty_max):
		var brick := get_or_create_brick(coord)
		var key := brick_key(coord)
		if brick.is_collapsed:
			_uncollapse_brick(brick, key)
		_apply_edit_to_brick(brick, region_min, region_max, new_value_fn)
		brick.dirty = true
		_dirty_brick_keys[key] = true

	if sync:
		regenerate_dirty_bricks()

## Enumerates brick coordinates whose ACTUAL (apron-included) bounds
## overlap [region_min, region_max] - not just nominal bounds, since a
## brick needs touching even when only its apron (not its nominal core)
## falls inside an edit's reach. Scans a small local range of candidate
## coordinates (derived from nominal cell size, padded by 1 whole brick
## on each side - always safely larger than the 1-cell apron actually in
## play) and keeps only those whose exact actual_bounds truly overlap.
func _bricks_overlapping_actual(region_min: Vector4, region_max: Vector4) -> Array:
	var cells_per_axis := VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1
	var cell_size := Vector4(cells_per_axis * step.x, cells_per_axis * step.y, cells_per_axis * step.z, cells_per_axis * step.w)
	var lo_x := floori((region_min.x - world_origin.x) / cell_size.x) - 1
	var lo_y := floori((region_min.y - world_origin.y) / cell_size.y) - 1
	var lo_z := floori((region_min.z - world_origin.z) / cell_size.z) - 1
	var lo_w := floori((region_min.w - world_origin.w) / cell_size.w) - 1
	var hi_x := floori((region_max.x - world_origin.x) / cell_size.x) + 1
	var hi_y := floori((region_max.y - world_origin.y) / cell_size.y) + 1
	var hi_z := floori((region_max.z - world_origin.z) / cell_size.z) + 1
	var hi_w := floori((region_max.w - world_origin.w) / cell_size.w) + 1

	var result := []
	for cx in range(lo_x, hi_x + 1):
		for cy in range(lo_y, hi_y + 1):
			for cz in range(lo_z, hi_z + 1):
				for cw in range(lo_w, hi_w + 1):
					var coord := Vector4i(cx, cy, cz, cw)
					var actual: Dictionary = VoxelBrick4D.actual_bounds(coord, world_origin, step)
					var actual_min: Vector4 = actual.min
					var actual_max: Vector4 = actual.max
					if _aabb_overlaps(actual_min, actual_max, region_min, region_max):
						result.append(coord)
	return result

static func _aabb_overlaps(a_min: Vector4, a_max: Vector4, b_min: Vector4, b_max: Vector4) -> bool:
	return a_min.x <= b_max.x and a_max.x >= b_min.x \
		and a_min.y <= b_max.y and a_max.y >= b_min.y \
		and a_min.z <= b_max.z and a_max.z >= b_min.z \
		and a_min.w <= b_max.w and a_max.w >= b_min.w

## A collapsed brick has no dense array at all - rebuild one from the
## live procedural field (exactly the phase-2 sampling a non-collapsed
## brick already got at creation time) before an edit can mutate it. No
## attempt to re-collapse a brick automatically if an edit happens to
## leave it uniform again - once a brick has ever gone dense, it stays
## dense; re-collapsing is a possible future optimization, not required
## for correctness.
func _uncollapse_brick(brick: VoxelBrick4D, key: int) -> void:
	var nominal: Dictionary = VoxelBrick4D.nominal_bounds(brick.brick_coord, world_origin, step)
	var n := VoxelBrick4D.NOMINAL_POINTS_PER_AXIS
	var nominal_samples: Array = []
	nominal_samples.resize(n * n * n * n)
	for i in range(n):
		for j in range(n):
			for k in range(n):
				for l in range(n):
					var pos := Vector4(
						nominal.min.x + i * step.x, nominal.min.y + j * step.y,
						nominal.min.z + k * step.z, nominal.min.w + l * step.w
					)
					nominal_samples[((i * n + j) * n + k) * n + l] = density_fn.call(pos)
	_sample_full_apron(brick, nominal_samples)
	brick.is_collapsed = false
	_dense_brick_keys[key] = true

## Mutates `brick`'s own stored density in place at every grid point
## (core or apron - the full actual grid) that falls inside
## [region_min, region_max], skipping whole axis rows/planes/cells early
## once they're outside the region rather than scanning all
## ACTUAL_POINTS_PER_AXIS^4 points unconditionally.
func _apply_edit_to_brick(brick: VoxelBrick4D, region_min: Vector4, region_max: Vector4, new_value_fn: Callable) -> void:
	var actual: Dictionary = VoxelBrick4D.actual_bounds(brick.brick_coord, world_origin, step)
	var actual_min: Vector4 = actual.min
	var n := VoxelBrick4D.ACTUAL_POINTS_PER_AXIS
	for i in range(n):
		var x := actual_min.x + i * step.x
		if x < region_min.x or x > region_max.x:
			continue
		for j in range(n):
			var y := actual_min.y + j * step.y
			if y < region_min.y or y > region_max.y:
				continue
			for k in range(n):
				var z := actual_min.z + k * step.z
				if z < region_min.z or z > region_max.z:
					continue
				for l in range(n):
					var w := actual_min.w + l * step.w
					if w < region_min.w or w > region_max.w:
						continue
					var point_index := ((i * n + j) * n + k) * n + l
					var old_density: float = DualContour4D._read_density(brick.density, point_index)
					var new_density: float = new_value_fn.call(old_density, Vector4(x, y, z, w))
					DualContour4D._write_density(brick.density, point_index, new_density)

## Meshes every dirty, non-collapsed brick via the DC-backed mesh backend,
## reading density from each brick's OWN stored array (not the live
## procedural field) - the same code path a future edit's regen will use,
## so this stays correct once editing is added.
func regenerate_dirty_bricks() -> void:
	for key in _dirty_brick_keys.keys():
		_dirty_brick_keys.erase(key)
		var brick: VoxelBrick4D = _bricks[key]
		if brick.is_collapsed or not brick.dirty:
			continue
		var nominal: Dictionary = VoxelBrick4D.nominal_bounds(brick.brick_coord, world_origin, step)
		var actual: Dictionary = VoxelBrick4D.actual_bounds(brick.brick_coord, world_origin, step)
		var raw_result: Dictionary = TerrainMeshBackendMT.generate_brick_mesh(
			actual.min, step, VoxelBrick4D.ACTUAL_POINTS_PER_AXIS,
			brick.stored_density_fn(world_origin, step)
		)
		var owned_result := _filter_to_brick_ownership(raw_result, nominal.min, nominal.max)
		_build_brick_mesh(brick, owned_result)
		brick.dirty = false

## Non-blocking equivalent of regenerate_dirty_bricks() - call this once a
## frame (or whenever convenient) instead. Unlike regenerate_dirty_bricks(),
## a brick's new mesh is NOT guaranteed ready by the time this call
## returns; it becomes ready on some LATER call, once its background job
## has finished, which is exactly why TerrainChunkPool4D checks
## brick.mesh_version rather than assuming a brick is current.
##
## Thread-safety split, deliberately: the background job (the Callable
## passed to WorkerThreadPool.add_task below) only ever touches a
## just-duplicated PackedByteArray snapshot of this brick's density plus
## pure-data helpers (TerrainMeshBackendDC/DualContour4D/
## _filter_to_brick_ownership - none of which create engine Resource/
## Object instances or touch RenderingServer/PhysicsServer state, only
## Packed*Array/Dictionary/Vector4 math) - never the live brick.density
## array a concurrent edit might be mutating, and never anything that
## creates a Godot Resource. Building the actual ArrayTetraMesh4D and
## baking its ConcaveMeshShape4D (_build_brick_mesh) happens back on
## WHICHEVER THREAD CALLS THIS FUNCTION, after the job is confirmed
## complete - Resource/PhysicsServer-adjacent construction is not
## documented as safe to do from an arbitrary worker thread in this
## engine, so it deliberately never happens on one. This split is the
## one part of the plan's threading slice that most needs a human's
## verification pass - see the plan doc.
func process_regeneration_async() -> void:
	_finalize_completed_regen_tasks()
	_dispatch_pending_regen_tasks()

func _dispatch_pending_regen_tasks() -> void:
	for key in _dirty_brick_keys.keys():
		if _pending_regen_tasks.has(key):
			continue
		_dirty_brick_keys.erase(key)
		var brick: VoxelBrick4D = _bricks[key]
		if brick.is_collapsed or not brick.dirty:
			continue
		var nominal: Dictionary = VoxelBrick4D.nominal_bounds(brick.brick_coord, world_origin, step)
		var actual: Dictionary = VoxelBrick4D.actual_bounds(brick.brick_coord, world_origin, step)
		var actual_min: Vector4 = actual.min
		var nominal_min: Vector4 = nominal.min
		var nominal_max: Vector4 = nominal.max
		var world_step := step
		var points_per_axis := VoxelBrick4D.ACTUAL_POINTS_PER_AXIS
		# A real, independent copy (PackedByteArray.duplicate(), not a
		# reference) taken NOW on the calling thread - the background job
		# below only ever reads this snapshot, never brick.density itself,
		# so a later edit mutating brick.density concurrently can never
		# race with the job reading it.
		var density_snapshot: PackedByteArray = brick.density.duplicate()
		# WorkerThreadPool.add_task() Callables are fire-and-forget -
		# wait_for_task_completion() returns an Error status, NOT the
		# Callable's return value - so the job writes its result into this
		# captured single-element Array instead (Array is a reference type
		# in GDScript, so the same underlying array the job appends to is
		# the one read back below once the task is confirmed complete).
		var result_slot := []
		var job := func() -> void:
			var n := points_per_axis
			var density_fn := func(pos: Vector4) -> float:
				var ix := int(roundf((pos.x - actual_min.x) / world_step.x))
				var iy := int(roundf((pos.y - actual_min.y) / world_step.y))
				var iz := int(roundf((pos.z - actual_min.z) / world_step.z))
				var iw := int(roundf((pos.w - actual_min.w) / world_step.w))
				var point_index := ((ix * n + iy) * n + iz) * n + iw
				return DualContour4D._read_density(density_snapshot, point_index)
			var raw_result: Dictionary = TerrainMeshBackendMT.generate_brick_mesh(actual_min, world_step, n, density_fn)
			var owned: Dictionary = _filter_to_brick_ownership(raw_result, nominal_min, nominal_max)
			# Thread-local phase timings, copied straight through - see
			# DualContour4D.generate()'s own comment on why these (not
			# Terrain4DProfile) are the race-free source under concurrent
			# regen.
			owned["phase1_usec"] = raw_result.phase1_usec
			owned["phase2_usec"] = raw_result.phase2_usec
			owned["phase3_usec"] = raw_result.phase3_usec
			result_slot.append(owned)
		var task_id := WorkerThreadPool.add_task(job)
		_pending_regen_tasks[key] = {"task_id": task_id, "result_slot": result_slot}
		brick.dirty = false

func _finalize_completed_regen_tasks() -> void:
	var finished_keys := []
	for key in _pending_regen_tasks:
		var entry: Dictionary = _pending_regen_tasks[key]
		if WorkerThreadPool.is_task_completed(entry.task_id):
			finished_keys.append(key)
	for key in finished_keys:
		var entry: Dictionary = _pending_regen_tasks[key]
		WorkerThreadPool.wait_for_task_completion(entry.task_id)
		_pending_regen_tasks.erase(key)
		var result_slot: Array = entry.result_slot
		if result_slot.is_empty():
			continue
		var owned_result: Dictionary = result_slot[0]
		if not _bricks.has(key):
			continue
		# _build_brick_mesh bumps mesh_version - if this brick was edited
		# again while the job we're finalizing was still in flight, it's
		# already dirty=true again from that later edit, and the very
		# next _dispatch_pending_regen_tasks() call (right after this one
		# returns, within the same process_regeneration_async() call) will
		# see dirty=true and _pending_regen_tasks no longer holding this
		# key, and dispatch a fresh job against the current density -
		# nothing here needs to special-case that.
		#
		# This finalize step only ever runs on whichever single thread
		# calls process_regeneration_async() (never concurrently with
		# itself), so timing it directly here - unlike the worker-side
		# phase1/2/3 timings above - needs no thread-local workaround.
		var _mesh_build_t0 := Time.get_ticks_usec()
		_build_brick_mesh(_bricks[key], owned_result)
		var _mesh_build_usec := Time.get_ticks_usec() - _mesh_build_t0
		_bricks[key].last_regen_timing_usec = {
			"phase1_usec": owned_result.get("phase1_usec", 0),
			"phase2_usec": owned_result.get("phase2_usec", 0),
			"phase3_usec": owned_result.get("phase3_usec", 0),
			"mesh_build_usec": _mesh_build_usec,
		}

func has_pending_regen_tasks() -> bool:
	return not _pending_regen_tasks.is_empty()

func pending_regen_task_count() -> int:
	return _pending_regen_tasks.size()

## The meshing backend emits geometry across whatever bounds it's given -
## including this brick's apron - but neighboring bricks' aprons overlap,
## so without this filter two adjacent bricks would each independently
## emit (duplicate) tets in that shared strip. Keeps only tets whose
## centroid falls in this brick's own half-open nominal ownership
## interval [nominal_min, nominal_max), so each real-world tet is owned
## by exactly one brick, and compacts the vertex list to match (dropping
## now-unreferenced apron-region vertices) rather than leaving dead
## entries in the output mesh.
func _filter_to_brick_ownership(result: Dictionary, nominal_min: Vector4, nominal_max: Vector4) -> Dictionary:
	var positions: PackedVector4Array = result.unique_vertex_positions
	var tet_indices: PackedInt32Array = result.tet_vertex_indices
	var tet_normals: PackedVector4Array = result.tet_vertex_normals
	var tet_source_ids: PackedInt32Array = result.tet_source_ids
	var tet_count: int = result.tet_count
	# Absent for backends (e.g. TerrainMeshBackendDC) that don't distinguish
	# render-vs-collision degeneracy - treated as "nothing flagged", so
	# behavior for those backends is unchanged.
	var degenerate_flags: PackedByteArray = result.get("tet_degenerate_flags", PackedByteArray())
	var has_degenerate_flags: bool = degenerate_flags.size() == tet_count
	# One per tet (not 4, unlike tet_vertex_normals) - the backend's own
	# known-correct outward (solid -> air) direction, used to set
	# ArrayTetraMesh4D.simplex_cell_boundary_normals directly at mesh-build
	# time instead of letting calculate_boundary_normals() guess via its
	# origin-distance heuristic (see terrain4d_mesh_backend_mt.gd's own
	# comment on out_boundary_normals for why that heuristic is wrong for
	# terrain). Absent for backends that don't provide it - treated as
	# "fall back to the heuristic", so behavior for those is unchanged.
	var boundary_normals: PackedVector4Array = result.get("tet_boundary_normals", PackedVector4Array())
	var has_boundary_normals: bool = boundary_normals.size() == tet_count

	var kept_positions := PackedVector4Array()
	var kept_indices := PackedInt32Array()
	var kept_normals := PackedVector4Array()
	var kept_source_ids := PackedInt32Array()
	var kept_degenerate_flags := PackedByteArray()
	var kept_boundary_normals := PackedVector4Array()
	var remap := {}

	for t in range(tet_count):
		var base := t * 4
		var i0: int = tet_indices[base + 0]
		var i1: int = tet_indices[base + 1]
		var i2: int = tet_indices[base + 2]
		var i3: int = tet_indices[base + 3]
		var p0: Vector4 = positions[i0]
		var p1: Vector4 = positions[i1]
		var p2: Vector4 = positions[i2]
		var p3: Vector4 = positions[i3]
		var centroid := (p0 + p1 + p2 + p3) * 0.25
		if not _in_half_open_bounds(centroid, nominal_min, nominal_max):
			continue
		for src_idx in [i0, i1, i2, i3]:
			if not remap.has(src_idx):
				remap[src_idx] = kept_positions.size()
				kept_positions.append(positions[src_idx])
			kept_indices.append(remap[src_idx])
		kept_normals.append(tet_normals[base + 0])
		kept_normals.append(tet_normals[base + 1])
		kept_normals.append(tet_normals[base + 2])
		kept_normals.append(tet_normals[base + 3])
		kept_source_ids.append(tet_source_ids[t])
		kept_degenerate_flags.append(degenerate_flags[t] if has_degenerate_flags else 0)
		if has_boundary_normals:
			kept_boundary_normals.append(boundary_normals[t])

	return {
		"unique_vertex_positions": kept_positions,
		"tet_vertex_indices": kept_indices,
		"tet_vertex_normals": kept_normals,
		"tet_source_ids": kept_source_ids,
		"tet_count": kept_source_ids.size(),
		"tet_degenerate_flags": kept_degenerate_flags,
		"tet_boundary_normals": kept_boundary_normals,
	}

static func _in_half_open_bounds(p: Vector4, lo: Vector4, hi: Vector4) -> bool:
	return p.x >= lo.x and p.x < hi.x and p.y >= lo.y and p.y < hi.y \
		and p.z >= lo.z and p.z < hi.z and p.w >= lo.w and p.w < hi.w

func _build_brick_mesh(brick: VoxelBrick4D, result: Dictionary) -> void:
	# SPIKE INSTRUMENTATION (temporary - see Terrain4DProfile): times this
	# whole function as "mesh_collision_build". Remove the two
	# Terrain4DProfile lines (and this comment) once the spike's numbers
	# are captured.
	var _profile_t0 := Time.get_ticks_usec()
	var mesh := ArrayTetraMesh4D.new()
	var indices: PackedInt32Array = mesh.append_vertices(result.unique_vertex_positions, false)
	var tet_indices: PackedInt32Array = result.tet_vertex_indices
	var tet_count: int = result.tet_count
	for t in range(tet_count):
		var base := t * 4
		mesh.append_tetra_cell_indices(
			indices[tet_indices[base + 0]], indices[tet_indices[base + 1]],
			indices[tet_indices[base + 2]], indices[tet_indices[base + 3]]
		)
	mesh.set_simplex_cell_vertex_normals(result.tet_vertex_normals)
	# Assign the backend's own known-correct (density-gradient-derived,
	# solid -> air) boundary normal directly, one per tet, rather than
	# letting calculate_boundary_normals() guess via its "assume normal
	# points away from the origin" heuristic - confirmed to be the actual
	# cause of a checkerboard of missing/culled facets across the live
	# terrain (that heuristic is documented to work for convex shapes
	# centered on the origin, and this terrain is an open, non-convex
	# sheet that mostly doesn't enclose the origin at all). Falls back to
	# the heuristic only for a backend that doesn't provide this data.
	var boundary_normals: PackedVector4Array = result.get("tet_boundary_normals", PackedVector4Array())
	if boundary_normals.size() == tet_count:
		mesh.simplex_cell_boundary_normals = boundary_normals
		mesh.calculate_boundary_normals(true)  # keep_existing=true: backstop only, for any zero/missing entry
	else:
		mesh.calculate_boundary_normals()
	brick.cached_mesh = mesh
	brick.cached_tet_source_ids = result.tet_source_ids

	# Discrete height/normal color banding (see TerrainColorBands) - one
	# small ArrayTetraMesh4D per band, rebuilt from scratch every regen
	# (never patched/reused across regenerations), so an edit that moves
	# the surface across a band boundary is picked up on the very next
	# regen exactly like any other geometry change - there is no per-tet
	# color cache to go stale.
	var positions: PackedVector4Array = result.unique_vertex_positions
	var tet_normals: PackedVector4Array = result.tet_vertex_normals
	var has_boundary_normals: bool = boundary_normals.size() == tet_count
	var band_meshes: Array = []
	var band_vertex_maps: Array = []
	# Parallel to band_meshes - each band's own boundary normals, in the
	# SAME order tets are appended into that band below (NOT indexed by
	# global tet index t, since a band mesh's own cell order is per-band-
	# compact, skipping every tet that landed in a different band).
	var band_boundary_normals: Array = []
	for b in range(TerrainColorBands.BAND_COUNT):
		var band_mesh := ArrayTetraMesh4D.new()
		band_vertex_maps.append(band_mesh.append_vertices(positions, false))
		band_meshes.append(band_mesh)
		band_boundary_normals.append(PackedVector4Array())
	for t in range(tet_count):
		var base := t * 4
		var i0: int = tet_indices[base + 0]
		var i1: int = tet_indices[base + 1]
		var i2: int = tet_indices[base + 2]
		var i3: int = tet_indices[base + 3]
		var centroid := (positions[i0] + positions[i1] + positions[i2] + positions[i3]) * 0.25
		var band: int = TerrainColorBands.classify(centroid, tet_normals[base])
		var vmap: PackedInt32Array = band_vertex_maps[band]
		(band_meshes[band] as ArrayTetraMesh4D).append_tetra_cell_indices(vmap[i0], vmap[i1], vmap[i2], vmap[i3])
		if has_boundary_normals:
			(band_boundary_normals[band] as PackedVector4Array).append(boundary_normals[t])
	for b in range(TerrainColorBands.BAND_COUNT):
		var band_mesh: ArrayTetraMesh4D = band_meshes[b]
		var band_normals: PackedVector4Array = band_boundary_normals[b]
		if has_boundary_normals and band_normals.size() == band_mesh.simplex_cell_indices.size() / 4:
			band_mesh.simplex_cell_boundary_normals = band_normals
			band_mesh.calculate_boundary_normals(true)  # keep_existing=true: backstop only
		else:
			band_mesh.calculate_boundary_normals()
	brick.cached_band_meshes = band_meshes

	# Collision shape excludes near-zero-volume tets specifically - they
	# break ConcaveMeshShape4D's closest-point-cache construction outright
	# ("degenerate or non-finite") - but the RENDER mesh above does NOT:
	# it has no such constraint, so every tet the backend computed is
	# displayed, and only collision pays the exclusion cost. Built as a
	# SEPARATE small mesh (re-appending the same unique_vertex_positions,
	# not sharing indices/vertices with `mesh` above - ArrayTetraMesh4D
	# instances own their own vertex list) rather than filtering `mesh`
	# itself, so the two purposes never fight over one array.
	var degenerate_flags: PackedByteArray = result.get("tet_degenerate_flags", PackedByteArray())
	var has_degenerate_flags: bool = degenerate_flags.size() == tet_count
	var collision_mesh := ArrayTetraMesh4D.new()
	var collision_indices: PackedInt32Array = collision_mesh.append_vertices(result.unique_vertex_positions, false)
	var collision_tet_count := 0
	for t in range(tet_count):
		if has_degenerate_flags and degenerate_flags[t] == 1:
			continue
		var base := t * 4
		collision_mesh.append_tetra_cell_indices(
			collision_indices[tet_indices[base + 0]], collision_indices[tet_indices[base + 1]],
			collision_indices[tet_indices[base + 2]], collision_indices[tet_indices[base + 3]]
		)
		collision_tet_count += 1
	if collision_tet_count > 0:
		brick.cached_collision_shape = ConcaveMeshShape4D.create_from_mesh(collision_mesh)
	else:
		brick.cached_collision_shape = null
	brick.mesh_version += 1
	Terrain4DProfile.add("mesh_collision_build", Time.get_ticks_usec() - _profile_t0)
