extends Node
## TEMPORARY - verifies TerrainColorBands survives editing, not just
## initial generation: an edit that raises part of a flat DIRT-band plane
## into GRASS-band height (and, at the raised column's edges, ROCK-band
## steepness) must be picked up on the very next regen, with the
## unedited surface staying in its original band. Not part of the shipped
## scene. Pure logic - no scene dependencies.

const STEP := Vector4(0.5, 0.5, 0.5, 0.5)
## Y is offset by -0.75 (half a nominal cell) specifically so brick coord
## (0,0,0,0)'s own NOMINAL y-range straddles y=0.0 (HIGH_HEIGHT_THRESHOLD)
## right in its middle: [-0.75, 0.75). With WORLD_ORIGIN.y=0 instead, brick
## boundaries land EXACTLY on multiples of the 1.5-unit cell size, and 0.0
## is one such boundary - meaning NO single brick's nominal ownership can
## ever contain both a DIRT (y<0) and a GRASS (y>=0) tet at once, since
## ownership is bounded by nominal bounds, not by density (caught
## empirically: a "raised" edit whose crossing landed past y=0.0 kept
## producing GRASS=0, because those tets' centroids belonged to a
## different, never-created brick one coordinate up).
const WORLD_ORIGIN := Vector4(0, -0.75, 0, 0)
## Deliberately off the STEP=0.5 grid (not a multiple of it): a plane
## height exactly on a grid line makes the density at that shared boundary
## exactly 0.0, which the meshing backend's "is this cell uniform" check
## (min_d >= 0.0 or max_d <= 0.0) reads as uniform from BOTH adjacent
## cells at once - a real edge case caught empirically (every band read 0
## until this was avoided), not a bug in the color-band code itself.
const PLANE_HEIGHT := -0.4  # world Y, well below HIGH_HEIGHT_THRESHOLD=0.0 -> DIRT band baseline
## world Y, above HIGH_HEIGHT_THRESHOLD=0.0 -> GRASS band after the edit -
## MUST land within this brick's own NOMINAL y-range [-0.75, 0.75), not
## just its actual/apron-included range, since a tet's OWNERSHIP (and
## therefore whether THIS brick's cached_band_meshes ever see it) is
## bounded by nominal, not actual, bounds - the earlier RAISED_HEIGHT
## attempts (+1.85, then +0.35) each landed outside this brick's own
## nominal ownership even though +0.35 was within its actual sampling
## range, which is exactly why GRASS kept reading 0.
const RAISED_HEIGHT := 0.4

## A pure horizontal plane: density = p.y - PLANE_HEIGHT, so the gradient
## (and therefore the meshing backend's per-cell normal) is EXACTLY
## Vector4(0,1,0,0) everywhere on this baseline field - a perfectly
## controlled "flat, shallow, low" starting point with no ambiguity about
## which band it should land in.
func _flat_density(p: Vector4) -> float:
	return p.y - PLANE_HEIGHT

func _band_tet_count(brick: VoxelBrick4D, band: int) -> int:
	if band >= brick.cached_band_meshes.size():
		return 0
	var mesh: ArrayTetraMesh4D = brick.cached_band_meshes[band]
	if mesh == null:
		return 0
	return mesh.get_simplex_cell_indices().size() / 4

func _ready() -> void:
	_run()

func _run() -> void:
	var world := VoxelWorld4D.new(WORLD_ORIGIN, STEP, Callable(self, "_flat_density"))
	# Nominal cell size = (NOMINAL_POINTS_PER_AXIS-1)*step = 3*0.5 = 1.5 per
	# axis. Brick coord (0,0,0,0) spans nominal y in [-0.75, 0.75) (see
	# WORLD_ORIGIN above) - straddles both PLANE_HEIGHT and RAISED_HEIGHT.
	var coord := Vector4i(0, 0, 0, 0)
	var brick := world.get_or_create_brick(coord)
	world.regenerate_dirty_bricks()

	print("1a.brick_not_collapsed: %s (expect false - a real surface crosses it)" % [brick.is_collapsed])
	var dirt_before := _band_tet_count(brick, TerrainColorBands.DIRT)
	var grass_before := _band_tet_count(brick, TerrainColorBands.GRASS)
	var rock_before := _band_tet_count(brick, TerrainColorBands.ROCK)
	print("1b.baseline_band_tet_counts: DIRT=%d GRASS=%d ROCK=%d (expect DIRT>0, GRASS==0, ROCK==0 - flat plane well below the height threshold, shallow everywhere)" % [dirt_before, grass_before, rock_before])

	# Edit A: raise a SINGLE grid column (only x/z/w=0.5, leaving x/z/w=1.0
	# untouched) up to RAISED_HEIGHT - narrow enough to leave a genuinely
	# unedited region for the DIRT check, but exposes real steep side-wall
	# geometry where old and new surfaces meet (-> ROCK), regardless of
	# whether it's wide enough for a flat top.
	var narrow_center := Vector4(0.5, 0.0, 0.5, 0.5)
	var narrow_half_extent := Vector4(0.1, 1.0, 0.1, 0.1)  # y-span covers both PLANE_HEIGHT and RAISED_HEIGHT
	world.edit_box(narrow_center, narrow_half_extent, func(_old_d: float, world_pos: Vector4) -> float:
		return world_pos.y - RAISED_HEIGHT
	)

	print("2a.brick_still_not_collapsed_after_edit: %s (expect false)" % [brick.is_collapsed])
	var dirt_after := _band_tet_count(brick, TerrainColorBands.DIRT)
	var rock_after := _band_tet_count(brick, TerrainColorBands.ROCK)
	print("2b.post_narrow_edit_band_tet_counts: DIRT=%d GRASS=%d ROCK=%d" % [dirt_after, _band_tet_count(brick, TerrainColorBands.GRASS), rock_after])
	print("2c.rock_band_appeared_after_edit: %s (expect true - the raised column's side walls are steep enough for ROCK band)" % [rock_after > rock_before])
	print("2d.dirt_band_still_present: %s (expect true - the UNEDITED part of the plane, still low, must remain DIRT, not get reclassified/lost)" % [dirt_after > 0])

	# Edit B: widen to cover BOTH x/z/w=0.5 and x/z/w=1.0 together, so a
	# cell exists whose all 16 corners are consistently at the new height -
	# a genuine flat top (not just a thin spike), which is what a GRASS
	# classification actually requires (a single edited grid line, tried
	# first, produced no cell with all-new corners, hence no flat top to
	# classify at all - not a band-logic bug, just too narrow a feature).
	var wide_center := Vector4(0.75, 0.0, 0.75, 0.75)
	var wide_half_extent := Vector4(0.6, 1.0, 0.6, 0.6)
	world.edit_box(wide_center, wide_half_extent, func(_old_d: float, world_pos: Vector4) -> float:
		return world_pos.y - RAISED_HEIGHT
	)
	var grass_after_wide := _band_tet_count(brick, TerrainColorBands.GRASS)
	print("2e.post_wide_edit_band_tet_counts: DIRT=%d GRASS=%d ROCK=%d" % [_band_tet_count(brick, TerrainColorBands.DIRT), grass_after_wide, _band_tet_count(brick, TerrainColorBands.ROCK)])
	print("2f.grass_band_appeared_after_wide_edit: %s (expect true - a genuinely flat, high top now exists within this brick's own nominal ownership, and the very next regen picks it up)" % [grass_after_wide > grass_before])

	# Direct classification sanity check, independent of the mesh backend
	# entirely - confirms TerrainColorBands itself, not just the pipeline
	# around it, does what's documented.
	print("3a.classify_flat_low_is_dirt: %s (expect true)" % [TerrainColorBands.classify(Vector4(0, -1.0, 0, 0), Vector4(0, 1, 0, 0)) == TerrainColorBands.DIRT])
	print("3b.classify_flat_high_is_grass: %s (expect true)" % [TerrainColorBands.classify(Vector4(0, 2.0, 0, 0), Vector4(0, 1, 0, 0)) == TerrainColorBands.GRASS])
	print("3c.classify_steep_is_rock_regardless_of_height: %s (expect true)" % [TerrainColorBands.classify(Vector4(0, 2.0, 0, 0), Vector4(1, 0, 0, 0)) == TerrainColorBands.ROCK])

	print("DONE")
	get_tree().quit()
