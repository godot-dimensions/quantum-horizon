class_name TerrainMeshBackendDC
extends RefCounted
## SingleVertexDualContour4D-backed implementation of the brick meshing interface used
## by VoxelWorld4D - kept as a thin, swappable wrapper (rather than calling
## SingleVertexDualContour4D directly from the storage layer) so the still-open
## marching-cubes-vs-dual-contouring decision (pending external review)
## doesn't require touching brick/hash/apron/dirty-tracking code if it's
## revisited later. Any replacement backend just needs to implement the
## same two static functions.

const QEF_REGULARIZATION := 0.15

## How many cells beyond a crossing edge's own two grid points this
## backend's stencil actually reaches, in the other 3 axes - traced
## directly from SingleVertexDualContour4D's dual-cube corner-gathering loop (a
## crossing grid edge's 8 surrounding active cells span exactly 1 cell
## beyond the edge's two points along each non-edge axis). Both brick
## apron sizing (VoxelBrick4D.APRON_CELLS) and dirty-AABB expansion read
## this value rather than a hardcoded number, so a future backend swap
## can't silently under-size either.
static func stencil_radius_cells() -> int:
	return 1

## `density_fn` must return the density at exactly the grid points
## `bounds_min + index*world_step` for index in [0, points_per_axis) per
## axis - in practice a brick's own VoxelBrick4D.stored_density_fn(), so
## edits (which mutate that stored array) are respected.
static func generate_brick_mesh(bounds_min: Vector4, world_step: Vector4, points_per_axis: int, density_fn: Callable) -> Dictionary:
	var bounds_max := Vector4(
		bounds_min.x + (points_per_axis - 1) * world_step.x,
		bounds_min.y + (points_per_axis - 1) * world_step.y,
		bounds_min.z + (points_per_axis - 1) * world_step.z,
		bounds_min.w + (points_per_axis - 1) * world_step.w
	)
	# generate_native() (not generate()) - the real production integration,
	# not just a side benchmark: measured ~93x faster in isolation for the
	# QEF-solve+gradient+tet-assembly work this replaces (a native C++ port,
	# see engine/modules/4d/math/dual_contour_native_4d.h/.cpp), verified
	# to produce IDENTICAL output to generate() first (exact match on
	# active-cell/tet/crossing-edge counts, vertex positions, tet indices,
	# and normals across 3 test cases - see
	# _verify_dual_contour_native_runner.gd) - not trusted on a benchmark
	# number alone. generate() itself is left in place, unused by this
	# call site but still available as the trusted reference for any
	# future correctness re-check.
	return SingleVertexDualContour4D.generate_native(
		bounds_min, bounds_max,
		points_per_axis, points_per_axis, points_per_axis, points_per_axis,
		density_fn, QEF_REGULARIZATION, world_step
	)
