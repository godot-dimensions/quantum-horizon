class_name VoxelBrick4D
extends RefCounted
## One brick of the sparse hash+brick voxel world (see voxel_world_4d.gd) -
## a small dense density grid plus whatever mesh/collision data the active
## meshing backend (see terrain4d_mesh_backend_dc.gd) produced from it.
##
## Grid point counts (see the plan doc's Storage section for the full
## derivation): NOMINAL_POINTS_PER_AXIS is this brick's own points, exactly
## shared/aligned with neighboring bricks at the boundary - this is what
## makes two independently-generated neighboring bricks agree exactly at
## their shared boundary with zero cross-brick communication, as long as
## both are built from the same world_origin/step (see VoxelWorld4D).
## APRON_CELLS extends sampling 1 cell beyond that on every side, matching
## the current meshing backend's traced stencil reach - ACTUAL_POINTS_PER_AXIS
## is the real stored/sampled grid size.
const NOMINAL_POINTS_PER_AXIS := 4
const APRON_CELLS := 1
const ACTUAL_POINTS_PER_AXIS := NOMINAL_POINTS_PER_AXIS + 2 * APRON_CELLS

var brick_coord: Vector4i = Vector4i.ZERO

## Only populated for a non-collapsed brick - int16-packed via
## DualContour4D's existing _write_density/_read_density convention, sized
## to ACTUAL_POINTS_PER_AXIS^4 * 2 bytes. This is the brick's persistent,
## editable state: regeneration always reads FROM here, never resamples
## the live procedural field directly, so a future edit (which mutates
## this array in place) is respected by regen.
var density: PackedByteArray = PackedByteArray()

## True if every sampled point in this brick's own nominal region agreed
## in sign - the brick was never densely sampled/meshed at all (see
## VoxelWorld4D._sample_and_collapse_check). Only `is_collapsed_solid` is
## meaningful when this is true; `density` stays empty.
var is_collapsed: bool = false
var is_collapsed_solid: bool = false

## True whenever this brick's cached mesh/collision no longer reflects its
## current density array (freshly created, or edited) and needs a
## regenerate_dirty_bricks() pass before being rendered/collided against.
var dirty: bool = true

var cached_mesh: ArrayTetraMesh4D = null
## Per-color-band subsets of cached_mesh's own tets (see
## TerrainColorBands) - one ArrayTetraMesh4D per band, indexed by
## TerrainColorBands.ROCK/GRASS/DIRT, always TerrainColorBands.BAND_COUNT
## entries (never null; a band with zero tets this regen is just an empty
## mesh, which a MeshInstance4D displays as nothing). Rebuilt from scratch
## every regenerate - see VoxelWorld4D._build_brick_mesh() - so an edit
## that moves the surface across a band boundary is picked up on the very
## next regen, same as any other geometry change; nothing here is cached
## per-tet across regenerations.
var cached_band_meshes: Array = []
var cached_collision_shape: ConcaveMeshShape4D = null
## Parallel to cached_mesh's tets - which dual-cube id each tet belongs to,
## for hover/edit-targeting features exactly like terrain_generator's
## tet_source_ids today.
var cached_tet_source_ids: PackedInt32Array = PackedInt32Array()

## Incremented every time VoxelWorld4D rebuilds this brick's cached_mesh -
## `dirty` alone can't tell a renderer "this brick's mesh changed since I
## last displayed it", since regenerate_dirty_bricks() clears `dirty` the
## moment it finishes regenerating, which may be well before (or without
## any relation to) when a pool/renderer gets around to looking at it.
## A monotonically increasing version number is a signal independent of
## that timing - a consumer just remembers the version it last synced to.
var mesh_version: int = 0

## TEMPORARY - per-brick regen phase-timing snapshot from the most recent
## regenerate (see VoxelWorld4D._finalize_completed_regen_tasks), for
## measurement scripts that need a race-free per-stage breakdown even under
## concurrent async regen (phase1/2/3 come back thread-locally from
## DualContour4D.generate()'s return value rather than the shared
## Terrain4DProfile static, which would race across concurrently-running
## WorkerThreadPool jobs - see that function's own comment). Empty until
## the first regen. Delete alongside the rest of this session's SPIKE
## INSTRUMENTATION once no longer needed.
var last_regen_timing_usec: Dictionary = {}

func _init(coord: Vector4i) -> void:
	brick_coord = coord

## World-space bounds of this brick's NOMINAL (non-apron) region - the
## portion it actually "owns" for rendering/collision purposes. Brick
## coordinates are integers in units of NOMINAL cells (NOMINAL_POINTS_PER_AXIS - 1
## per axis), so adjacent brick coordinates' nominal regions tile the world
## with no gap and no overlap.
static func nominal_bounds(coord: Vector4i, world_origin: Vector4, step: Vector4) -> Dictionary:
	var cells_per_axis := NOMINAL_POINTS_PER_AXIS - 1
	var origin := Vector4(
		world_origin.x + coord.x * cells_per_axis * step.x,
		world_origin.y + coord.y * cells_per_axis * step.y,
		world_origin.z + coord.z * cells_per_axis * step.z,
		world_origin.w + coord.w * cells_per_axis * step.w
	)
	return {
		"min": origin,
		"max": Vector4(
			origin.x + cells_per_axis * step.x,
			origin.y + cells_per_axis * step.y,
			origin.z + cells_per_axis * step.z,
			origin.w + cells_per_axis * step.w
		),
	}

## World-space bounds of this brick's ACTUAL (apron-included) sampling
## region - what the meshing backend is actually called over.
static func actual_bounds(coord: Vector4i, world_origin: Vector4, step: Vector4) -> Dictionary:
	var nominal: Dictionary = nominal_bounds(coord, world_origin, step)
	var apron := APRON_CELLS
	return {
		"min": Vector4(
			nominal.min.x - apron * step.x, nominal.min.y - apron * step.y,
			nominal.min.z - apron * step.z, nominal.min.w - apron * step.w
		),
		"max": Vector4(
			nominal.max.x + apron * step.x, nominal.max.y + apron * step.y,
			nominal.max.z + apron * step.z, nominal.max.w + apron * step.w
		),
	}

## Builds a Callable matching DualContour4D.generate()'s density_fn
## signature (Vector4 -> float), reading from THIS brick's own stored
## density array by converting a grid-point world position back to a
## local index - used instead of resampling the live procedural field, so
## a future edit (which mutates `density` directly) is respected by
## regeneration. Only ever called by generate() at the exact grid points
## implied by actual_bounds()/step/ACTUAL_POINTS_PER_AXIS, so the
## world-position-to-index round-trip is exact modulo floating point, not
## an approximation.
func stored_density_fn(world_origin: Vector4, step: Vector4) -> Callable:
	var actual: Dictionary = actual_bounds(brick_coord, world_origin, step)
	return Callable(self, "_sample_stored_density").bind(actual.min, step)

func _sample_stored_density(pos: Vector4, actual_min: Vector4, step: Vector4) -> float:
	var ix := int(roundf((pos.x - actual_min.x) / step.x))
	var iy := int(roundf((pos.y - actual_min.y) / step.y))
	var iz := int(roundf((pos.z - actual_min.z) / step.z))
	var iw := int(roundf((pos.w - actual_min.w) / step.w))
	var n := ACTUAL_POINTS_PER_AXIS
	var point_index := ((ix * n + iy) * n + iz) * n + iw
	return DualContour4D._read_density(density, point_index)
