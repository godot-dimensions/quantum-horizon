extends Node
## TEMPORARY - end-to-end smoke test for the hover camera + click-to-edit
## feature added to terrain4d_voxel_showcase.tscn: pan/zoom/4D-rotate the
## camera/rig directly (the same calls a real drag/scroll would trigger),
## confirm TerrainChunkPool4D.viewer_position actually follows the camera
## (not left pointing at a placeholder), then drive _perform_edit() at a
## known screen position - the same entry point a real click resolves to -
## to dig and place, screenshotting before/after so the change is visible,
## not just asserted. Not part of the shipped scene.

@onready var showcase: Node4D = $"../Scene/World/TerrainRig/VoxelShowcase"

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)
	print("SCREENSHOT_SAVED: %s" % [image_name])

func _ready() -> void:
	await _wait_frames(3)
	await _run()

func _find_hit_screen_pos(is_dig_probe: bool) -> Vector2:
	# Probe a small grid around viewport center rather than assuming dead
	# center hits terrain - cheap (no mutation, just raycasts) and more
	# robust to camera framing than a single fixed guess.
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var offsets := [Vector2.ZERO, Vector2(-80, -40), Vector2(80, -40), Vector2(-80, 40), Vector2(80, 40), Vector2(0, -100), Vector2(0, 100)]
	for offset in offsets:
		var screen_pos: Vector2 = center + offset
		var ray_params := RaycastParameters4D.new()
		var camera: Camera4D = showcase.camera
		ray_params.global_ray_origin = camera.viewport_to_world_ray_origin(screen_pos)
		ray_params.global_ray_direction = camera.viewport_to_world_ray_direction(screen_pos).normalized()
		ray_params.max_distance = showcase.max_edit_ray_distance
		var result: Dictionary = PhysicsServer4D.raycast_physics_objects(ray_params)
		if result.get("hit", false):
			print("probe hit at screen_pos=%s (is_dig_probe=%s)" % [screen_pos, is_dig_probe])
			return screen_pos
	return Vector2(-1, -1)

func _run() -> void:
	var waited_frames := 0
	while showcase._settled_msec < 0 and waited_frames < 1800:
		await get_tree().process_frame
		waited_frames += 1
	print("1a.settled_before_timeout: %s (expect true) waited_frames=%d" % [showcase._settled_msec >= 0, waited_frames])

	var camera: Camera4D = showcase.camera
	var chunk_pool: TerrainChunkPool4D = showcase.chunk_pool
	var rig: Node4D = showcase._rig

	# --- Camera pan/zoom/4D-rotate, driven directly (the same calls a
	# real drag/scroll would trigger) - confirm no crash and real motion. ---
	var look_at_before: Vector4 = camera.look_at_target
	camera.look_at_target += Vector4(1.0, 0.0, 0.5, 0.0)
	camera.refresh()
	print("2a.pan_moved_look_at_target: %s (expect true)" % [camera.look_at_target != look_at_before])

	var radius_before: float = camera.radius
	camera.radius = clampf(camera.radius - camera.zoom_step, camera.min_radius, camera.max_radius)
	camera._apply_orbit()
	print("2b.zoom_changed_radius: %s (expect true, unless already at min_radius)" % [camera.radius != radius_before])

	var rig_basis_before: Projection = rig.basis
	rig.basis = Basis4D.orthonormalized(Basis4D.from_xw(-0.3) * Basis4D.from_zw(0.15) * rig.basis)
	print("2c.slice_rotation_changed_rig_basis: %s (expect true)" % [rig.basis != rig_basis_before])

	await _wait_frames(3)  # let _process() re-derive viewer_position from the moved camera

	# --- viewer_position must actually be driven by the camera, not a
	# placeholder - the whole point of task 4. Move the camera again by a
	# known amount and confirm viewer_position (in the rig's un-rotated
	# space) changes correspondingly, not just non-zero. ---
	var viewer_pos_before: Vector4 = chunk_pool.viewer_position
	camera.look_at_target += Vector4(2.0, 0.0, 0.0, 0.0)
	camera.refresh()
	await _wait_frames(3)
	var viewer_pos_after: Vector4 = chunk_pool.viewer_position
	print("3a.viewer_position_nonzero: %s (expect true)" % [not viewer_pos_before.is_zero_approx()])
	print("3b.viewer_position_tracks_camera_movement: %s (expect true - proves it's live-driven, not a fixed placeholder)" % [not viewer_pos_after.is_equal_approx(viewer_pos_before)])

	await _screenshot("voxel_world_editor_before_edit.png")

	# --- Click-to-edit: dig, then place, at real raycast-hit screen
	# positions - the same entry point (_perform_edit) a real click
	# resolves to after the click-vs-drag check passes. ---
	var dig_screen_pos := _find_hit_screen_pos(true)
	print("4a.found_dig_hit_position: %s (expect true)" % [dig_screen_pos.x >= 0.0])
	if dig_screen_pos.x >= 0.0:
		var world: VoxelWorld4D = showcase.world
		var dense_before: int = world.dense_brick_count()
		showcase._perform_edit(dig_screen_pos, true)
		for i in range(300):
			world.process_regeneration_async()
			if not world.has_pending_regen_tasks():
				break
			await get_tree().process_frame
		print("4b.dig_did_not_hang: %s (expect true)" % [not world.has_pending_regen_tasks()])
		print("4c.dig_may_have_uncollapsed_a_brick: %d -> %d (dense_brick_count, informational)" % [dense_before, world.dense_brick_count()])
		await _screenshot("voxel_world_editor_after_dig.png")

		showcase._perform_edit(dig_screen_pos, false)
		for i in range(300):
			world.process_regeneration_async()
			if not world.has_pending_regen_tasks():
				break
			await get_tree().process_frame
		print("4d.place_did_not_hang: %s (expect true)" % [not world.has_pending_regen_tasks()])
		await _screenshot("voxel_world_editor_after_place.png")

	# --- Edit radius adjustment via the actual [ / ] key handler, not by
	# setting the var directly - exercises the real _input() code path. ---
	var radius_before_key: float = showcase.edit_radius
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_BRACKETRIGHT
	showcase._input(key_event)
	print("5a.bracket_right_increased_radius: %s (expect true, unless already at max_edit_radius) %.2f -> %.2f" % [showcase.edit_radius != radius_before_key, radius_before_key, showcase.edit_radius])

	print("DONE")
	get_tree().quit()
