extends Node
## TEMPORARY - verifies creature cube spawning: each spawned creature must
## have a real Node4D + MeshInstance4D with a BoxTetraMesh4D mesh, and its
## height must actually reflect the raycast hit against the terrain's own
## collision (not left at spawn_height, not NaN/garbage) - i.e. genuinely
## seated on the uneven terrain, not just placed at a fixed height. Not
## part of the shipped scene.

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
	print("2a.creature_count: %d (expect > 0, ideally == %d)" % [creatures.size(), showcase.creature_count])

	var all_have_mesh := true
	var all_heights_plausible := true
	var all_not_at_spawn_height := true
	var heights := []
	for creature in creatures:
		var node4d: Node4D = creature
		var mesh_instance: MeshInstance4D = null
		for child in node4d.get_children():
			if child is MeshInstance4D:
				mesh_instance = child
		if mesh_instance == null or not (mesh_instance.mesh is BoxTetraMesh4D):
			all_have_mesh = false
		var h: float = node4d.position.y
		heights.append(h)
		if not is_finite(h) or h < -20.0 or h > 15.0:
			all_heights_plausible = false
		if absf(h - showcase.creature_spawn_height) < 1.0:
			all_not_at_spawn_height = false

	print("2b.all_creatures_have_box_tetra_mesh: %s (expect true)" % [all_have_mesh])
	print("2c.all_heights_plausible_for_terrain: %s (expect true) heights=%s" % [all_heights_plausible, heights])
	print("2d.no_creature_stuck_at_spawn_height: %s (expect true - confirms the raycast actually found the terrain, not just fell through to a default)" % [all_not_at_spawn_height])

	# Height VARIATION across creatures is the real "genuinely uneven
	# terrain" signal - if the terrain were flat (or the raycast were
	# broken and returning a constant), every creature would land at
	# roughly the same height regardless of where it was scattered.
	var min_h: float = heights[0] if heights.size() > 0 else 0.0
	var max_h: float = heights[0] if heights.size() > 0 else 0.0
	for h in heights:
		min_h = minf(min_h, h)
		max_h = maxf(max_h, h)
	print("2e.height_variation_across_creatures: min=%.2f max=%.2f spread=%.2f (expect spread > 0.5 - confirms they're following real uneven terrain, not a flat plane)" % [min_h, max_h, max_h - min_h])

	await _screenshot("creature_cubes_view.png")

	# The default camera framing (fixed at scene start, before creatures
	# exist) has no reason to happen to cover where randomly-scattered
	# creatures landed - retarget it directly at the first creature for a
	# second, confirmable close-up shot, rather than assuming the first
	# screenshot's framing was ever going to catch one.
	if creatures.size() > 0:
		var camera: Camera4D = showcase.camera
		var first_creature: Node4D = creatures[0]
		# global_position, not position - the camera's look_at_target is in
		# WORLD space (OverheadCamera is a direct child of World, a sibling
		# of TerrainRig, not a child of it), while the creature's own
		# `position` is LOCAL to its parent (under TerrainRig).
		camera.look_at_target = first_creature.global_position
		camera.radius = 4.0
		camera._apply_orbit()
		await _wait_frames(3)
		await _screenshot("creature_cubes_closeup.png")

	print("DONE")
	get_tree().quit()
