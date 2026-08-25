extends Node
## TEMPORARY - verifies creature wander movement + continuous ground-
## tracking while actually moving (not just at rest): follows one
## creature with the camera and takes a screenshot sequence over several
## real seconds, logging (x,y,z,w) each step, so height-vs-slope tracking
## can be confirmed both numerically (does y vary in a way that isn't
## explained by "flat ground") and visually (does the creature visibly
## sit on the surface in every frame of the sequence, not just at rest).
## Not part of the shipped scene.

const STEP_COUNT := 8
const STEP_SECONDS := 1.0

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

func _run() -> void:
	var waited_frames := 0
	while (showcase._settled_msec < 0 or not showcase._creatures_spawned) and waited_frames < 1800:
		await get_tree().process_frame
		waited_frames += 1
	print("1a.settled_and_spawned_before_timeout: %s (expect true) waited_frames=%d" % [showcase._settled_msec >= 0 and showcase._creatures_spawned, waited_frames])

	var creatures: Array = showcase._creatures
	print("1b.creature_count: %d" % [creatures.size()])
	if creatures.is_empty():
		print("NO CREATURES SPAWNED - cannot verify movement. DONE")
		get_tree().quit()
		return

	var creature: Node4D = creatures[0]
	var camera: Camera4D = showcase.camera
	camera.radius = 6.0

	var positions := []
	for step in range(STEP_COUNT):
		# Re-center the camera on the creature's CURRENT position every
		# step, since it's moving - otherwise it would wander out of frame
		# and the sequence would just show empty terrain.
		camera.look_at_target = creature.global_position
		camera._apply_orbit()
		await _wait_frames(2)
		await _screenshot("creature_movement_step%d.png" % [step])
		positions.append(creature.position)
		print("step %d: local_position=%s" % [step, creature.position])
		await get_tree().create_timer(STEP_SECONDS).timeout

	# Movement sanity: horizontal (x/z/w) position must actually change
	# over the sequence - if it never moved, height-tracking-while-moving
	# can't be claimed at all.
	var start_xzw := Vector4(positions[0].x, 0.0, positions[0].z, positions[0].w)
	var end_xzw := Vector4(positions[-1].x, 0.0, positions[-1].z, positions[-1].w)
	var horizontal_travel: float = start_xzw.distance_to(end_xzw)
	print("2a.horizontal_travel_over_sequence: %.3f (expect > 0.5 - confirms real movement happened, not a stationary creature)" % [horizontal_travel])

	# Height-tracking sanity: y should NOT be constant across the sequence
	# if the creature crossed any real slope - and critically, the y
	# values should be consistent with an INDEPENDENT recomputation of the
	# terrain height at each recorded (x,z,w) via the same density
	# function the terrain itself uses, not just "y changed" (which could
	# also happen from a bug that drifts height incorrectly).
	var min_y: float = positions[0].y
	var max_y: float = positions[0].y
	var max_height_error := 0.0
	for p in positions:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
		# showcase._density(p) is the SAME heightfield the terrain mesh was
		# built from - independent of the creature's own raycast logic, so
		# this is a genuine cross-check, not circular.
		var density_at_p: float = showcase._density(Vector4(p.x, p.y - showcase.creature_size.y * 0.5, p.z, p.w))
		max_height_error = maxf(max_height_error, absf(density_at_p))
	print("2b.height_range_over_sequence: min=%.3f max=%.3f spread=%.3f (expect spread > 0.1 if the path crossed real slope)" % [min_y, max_y, max_y - min_y])
	print("2c.max_density_error_at_recorded_feet_positions: %.4f (expect small - confirms recorded height actually matches the REAL terrain surface at that (x,z,w), independent of the creature's own logic)" % [max_height_error])

	print("DONE")
	get_tree().quit()
