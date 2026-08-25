extends Node
## TEMPORARY diagnostic - ONE thing: for the currently-visible dense
## bricks, count how many have a world-space w-extent that does NOT
## straddle the camera's current 4D slice plane (i.e. every one of that
## brick's tets is guaranteed to produce an empty cross-section, since a
## tet only emits geometry when its corners disagree in sign relative to
## the slice - see CROSS_SECTION_LOOKUP in tetra_cross_section_shader.glsl).
##
## Reuses the SAME ana_offset formula already established in
## bearing_utility_4d.gd (BearingUtility4D.compute(): ana_offset =
## rel.dot(observer_basis.w), zero exactly on the slice), generalized from
## a single point target to a brick's whole local AABB via the standard
## "rotated-box support point" trick (project each of the 4 local axis
## extents onto the direction vector, choosing lo or hi per axis by the
## sign of that axis's contribution) - exact, not an approximation, and
## costs O(4) per brick, same order as the existing distance check.
##
## Camera4D is NOT a child of TerrainRig (siblings - see
## terrain4d_voxel_showcase.gd's own comment on this), so it does NOT
## inherit the rig's right-drag xw/zw rotation - camera.global_basis.w is
## printed directly below rather than assumed, since this whole
## computation's correctness depends on using the camera's ACTUAL basis.w,
## not an assumed axis-aligned one.
## Not part of the shipped scene.

@onready var showcase: Node4D = $"../Scene/World/TerrainRig/VoxelShowcase"

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _ready() -> void:
	await _wait_frames(3)
	await _run()

func _run() -> void:
	var waited_frames := 0
	while (showcase._settled_msec < 0 or not showcase._creatures_spawned) and waited_frames < 1800:
		await get_tree().process_frame
		waited_frames += 1
	print("0.settled_and_spawned_before_timeout: %s waited_frames=%d" % [showcase._settled_msec >= 0 and showcase._creatures_spawned, waited_frames])

	var world: VoxelWorld4D = showcase.world
	var chunk_pool: TerrainChunkPool4D = showcase.chunk_pool
	var rig: Node4D = showcase._rig
	var camera: Camera4D = showcase.camera

	print("1a.camera_global_basis_w: %s (expect ~(0,0,0,1) if the camera never applies its own 4D slice-rotation)" % [camera.global_basis.w])
	print("1b.rig_global_basis_w: %s" % [rig.global_basis.w])

	var inverse_basis: Projection = rig.global_basis.inverse()
	# Direction of the camera's own W-basis-axis, expressed in the rig's
	# LOCAL (un-rotated generation) space - the SAME conversion pattern
	# already established for viewer_position (world -> rig-local), just
	# applied to a direction vector instead of a position.
	var w_dir_local: Vector4 = inverse_basis * camera.global_basis.w
	var base_offset: float = (rig.global_position - camera.global_position).dot(camera.global_basis.w)
	print("1c.w_dir_local: %s  base_offset: %.4f" % [w_dir_local, base_offset])

	var dense_bricks: Array = world.get_dense_bricks()
	print("2.dense_brick_count: %d" % [dense_bricks.size()])

	var visible_bricks: Array = chunk_pool.visible_bricks()
	print("3.visible_brick_count: %d" % [visible_bricks.size()])

	var non_straddling_count := 0
	var straddling_count := 0
	var sample_lines := []
	for brick in visible_bricks:
		var b4: VoxelBrick4D = brick
		var nominal: Dictionary = VoxelBrick4D.nominal_bounds(b4.brick_coord, world.world_origin, world.step)
		var lo: Vector4 = nominal.min
		var hi: Vector4 = nominal.max

		# Rotated-AABB support-point projection onto w_dir_local, exact min
		# and max of (local_point.dot(w_dir_local)) over the box [lo, hi].
		var min_proj := 0.0
		var max_proj := 0.0
		for axis in range(4):
			var d: float = w_dir_local[axis]
			var lo_a: float = lo[axis]
			var hi_a: float = hi[axis]
			if d >= 0.0:
				min_proj += d * lo_a
				max_proj += d * hi_a
			else:
				min_proj += d * hi_a
				max_proj += d * lo_a
		var min_ana: float = min_proj + base_offset
		var max_ana: float = max_proj + base_offset
		var straddles: bool = min_ana <= 0.0 and max_ana >= 0.0
		if straddles:
			straddling_count += 1
		else:
			non_straddling_count += 1
			if sample_lines.size() < 10:
				sample_lines.append("  brick_coord=%s nominal_min=%s nominal_max=%s min_ana=%.3f max_ana=%.3f" % [b4.brick_coord, lo, hi, min_ana, max_ana])

	print("4a.straddling_slice_count: %d" % [straddling_count])
	print("4b.NON_straddling_slice_count: %d  (out of %d visible - these bricks contribute ZERO cross-section geometry every frame)" % [non_straddling_count, visible_bricks.size()])
	print("4c.fraction_non_straddling: %.1f%%" % [100.0 * float(non_straddling_count) / float(visible_bricks.size()) if visible_bricks.size() > 0 else 0.0])
	print("4d.sample_non_straddling_bricks (up to 10):")
	for line in sample_lines:
		print(line)

	print("DONE")
	get_tree().quit()
