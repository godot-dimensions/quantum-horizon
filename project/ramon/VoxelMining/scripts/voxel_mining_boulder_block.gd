@tool
extends "res://ramon/VoxelMining/scripts/voxel_mining_block.gd"
## Shape-freedom test #2: a lumpy "boulder" made of several overlapping
## spheres unioned together, to show that composing primitives works just as
## easily as swapping one - again, only [method _build_base_shape] changes.
##
## Density here uses [code]positive = inside[/code] (VoxelField4D's own
## convention, the opposite of the more common negative-inside SDF
## convention) so a union is the [i]max[/i] of the lumps' densities, not the
## min - a point counts as solid if it is inside any lump. The gradient at
## any point is whichever lump is currently "winning" (the largest density),
## the same "tightest constraint decides" pattern voxel_terrain_4d.gd's
## 24-cell layer already uses for its own two-constraint blend.

## How many spheres make up the boulder.
@export_range(2, 8, 1) var lump_count: int = 4
## How far a lump's center can wander from the boulder's own center, as a
## fraction of the boulder's overall half-size.
@export_range(0.0, 0.8, 0.01) var lump_spread_fraction: float = 0.4
## Each lump's own radius, as a fraction of the boulder's overall half-size.
@export_range(0.3, 1.0, 0.01) var lump_radius_fraction_min: float = 0.55
@export_range(0.3, 1.0, 0.01) var lump_radius_fraction_max: float = 0.85
## Reproducible randomness for lump placement - same seed, same boulder.
@export var boulder_seed: int = 1


func _build_base_shape(center: Vector4, size: int) -> void:
	var half_extent: float = float(size) * 0.5 * box_fill_fraction

	var rng := RandomNumberGenerator.new()
	rng.seed = boulder_seed
	var lump_centers: Array[Vector4] = []
	var lump_radii: PackedFloat32Array = []
	for i in range(lump_count):
		var jitter := Vector4(
			rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		var offset: Vector4 = jitter * (half_extent * lump_spread_fraction)
		var radius: float = half_extent * rng.randf_range(lump_radius_fraction_min, lump_radius_fraction_max)

		# However spread/radius are tuned, no lump's own surface is allowed to
		# reach past half_extent from the boulder's center - i.e. never past
		# where the box/sphere shapes already stay safely inside the grid.
		# Without this, a big enough spread+radius combination pokes a lump
		# out to the grid boundary, where dual contouring cannot build a cell
		# (it has no neighbor past the edge) and the surface just stops dead,
		# flat, exactly at the boundary - the "invisible box" hole.
		var reach: float = offset.length() + radius
		if reach > half_extent:
			var shrink: float = half_extent / reach
			offset *= shrink
			radius *= shrink

		lump_centers.append(center + offset)
		lump_radii.append(radius)

	_field.add_layer(
		VoxelField4D.VoxelMaterial.GROUND,
		func(p: Vector4) -> float:
			var best := -INF
			for i in range(lump_centers.size()):
				best = maxf(best, lump_radii[i] - (p - lump_centers[i]).length())
			return best,
		func(p: Vector4) -> Vector4:
			var best_density := -INF
			var best_gradient := Vector4.ZERO
			for i in range(lump_centers.size()):
				var offset: Vector4 = lump_centers[i] - p
				var length: float = offset.length()
				var density: float = lump_radii[i] - length
				if density > best_density:
					best_density = density
					best_gradient = Vector4.ZERO if is_zero_approx(length) else offset / length
			return best_gradient,
		1.0)
