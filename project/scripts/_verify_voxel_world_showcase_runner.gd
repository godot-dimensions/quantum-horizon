extends Node
## TEMPORARY - smoke-tests sandbox/terrain4d/terrain4d_voxel_showcase.tscn
## end to end (population, threaded regen convergence, chunk pool sync,
## perf HUD text) and takes a screenshot for a visual seam/gap sanity
## check. Not part of the shipped scene.

@onready var showcase: Node4D = $"../Scene/World/TerrainRig/VoxelShowcase"
@onready var perf_label: Label = $"../Scene/HUD/PerfLabel"

func _wait_process_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)

func _ready() -> void:
	await _wait_process_frames(3)
	await _run()

func _run() -> void:
	# Wait for population + meshing to fully settle, or time out - this is
	# a smoke test, not a benchmark, so a generous fixed cap is fine.
	var waited_frames := 0
	while showcase._settled_msec < 0 and waited_frames < 1800:
		await get_tree().process_frame
		waited_frames += 1
	print("1a.settled_before_timeout: %s (expect true) waited_frames=%d" % [showcase._settled_msec >= 0, waited_frames])
	print("1b.population_time_ms: %d" % [showcase._population_done_msec - showcase._load_start_msec])
	print("1c.meshing_catchup_ms: %d" % [showcase._settled_msec - showcase._population_done_msec])

	var world: VoxelWorld4D = showcase.world
	var total := 0
	var collapsed := 0
	for brick in world.get_all_bricks():
		total += 1
		if brick.is_collapsed:
			collapsed += 1
	print("2a.resident_bricks: %d (expect > 0)" % [total])
	print("2b.collapse_rate_pct: %.1f" % [(float(collapsed) / float(total) * 100.0) if total > 0 else 0.0])
	print("2c.no_pending_regen_tasks: %s (expect true)" % [not world.has_pending_regen_tasks()])

	var pool: TerrainChunkPool4D = showcase.chunk_pool
	print("3a.visible_bricks_positive: %d (expect > 0)" % [pool.visible_brick_count()])

	print("4a.perf_label_nonempty: %s (expect true)" % [not perf_label.text.is_empty()])
	print("4b.perf_label_text:\n%s" % [perf_label.text])

	await _wait_process_frames(5)
	await _screenshot("voxel_world_showcase_view.png")

	print("DONE")
	get_tree().quit()
