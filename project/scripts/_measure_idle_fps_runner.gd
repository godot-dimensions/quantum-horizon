extends Node
## TEMPORARY diagnostic - ONE measurement: FPS at genuinely confirmed idle
## (zero regen jobs in flight/queued, settled, nothing loading or editing),
## not just "10 frames after settling was first detected" (the earlier
## measurement's gate, which turned out to already satisfy the idle
## condition by construction - see below - but wasn't explicitly confirmed
## frame-by-frame at measurement time, which this does).
##
## Note on "Meshing catch-up: Xms" in the showcase's own perf HUD: this is
## NOT a live/currently-updating counter that drops to 0 at idle - it's a
## ONE-TIME FROZEN measurement of how long the catch-up phase TOOK
## (_settled_msec - _population_done_msec, computed once when settling is
## first detected, then never recomputed - see
## terrain4d_voxel_showcase.gd's _update_perf_label). It will keep showing
## its historical value (e.g. "2100 ms") forever after settling, which is
## NOT evidence that catch-up work is still ongoing. The actual live
## idle signal is world.pending_regen_task_count() == 0, which this script
## polls directly and explicitly confirms holds steady before measuring.
## Not part of the shipped scene.

@onready var showcase: Node4D = $"../Scene/World/TerrainRig/VoxelShowcase"

func _wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _measure_avg_fps(frame_count: int) -> float:
	var total := 0.0
	for i in range(frame_count):
		await get_tree().process_frame
		total += Engine.get_frames_per_second()
	return total / float(frame_count)

func _ready() -> void:
	await _wait_frames(3)
	await _run()

func _run() -> void:
	var world: VoxelWorld4D = showcase.world

	var waited_frames := 0
	while (showcase._settled_msec < 0 or not showcase._creatures_spawned) and waited_frames < 1800:
		await get_tree().process_frame
		waited_frames += 1
	print("0.settled_and_spawned_before_timeout: %s waited_frames=%d" % [showcase._settled_msec >= 0 and showcase._creatures_spawned, waited_frames])
	print("0b.population_done_msec=%d settled_msec=%d frozen_catch_up_duration_ms=%d (historical, NOT a live counter)" % [
		showcase._population_done_msec, showcase._settled_msec, showcase._settled_msec - showcase._population_done_msec
	])

	# Explicitly confirm pending_regen_task_count() stays at 0 for a solid
	# stretch (not just "was 0 the instant settling was first detected") -
	# the actual live idle signal, polled frame-by-frame, not assumed.
	var confirmed_idle_streak := 0
	var max_pending_seen_after_settle := 0
	for i in range(120):
		await get_tree().process_frame
		var pending: int = world.pending_regen_task_count()
		max_pending_seen_after_settle = maxi(max_pending_seen_after_settle, pending)
		if pending == 0:
			confirmed_idle_streak += 1
		else:
			confirmed_idle_streak = 0
	print("1a.max_pending_regen_tasks_seen_over_120_frames_after_settle: %d (expect 0)" % [max_pending_seen_after_settle])
	print("1b.confirmed_idle_streak_frames_at_end: %d / 120" % [confirmed_idle_streak])

	# Measure FPS now, at confirmed idle - also tracking pending regen task
	# count DURING the measurement window itself, not just before it, so
	# "confirmed idle throughout" is actually verified, not assumed.
	var total_fps := 0.0
	var max_pending_during_measurement := 0
	const MEASURE_FRAMES := 90
	for i in range(MEASURE_FRAMES):
		await get_tree().process_frame
		total_fps += Engine.get_frames_per_second()
		max_pending_during_measurement = maxi(max_pending_during_measurement, world.pending_regen_task_count())
	var fps_idle := total_fps / float(MEASURE_FRAMES)
	print("2a.avg_fps_CONFIRMED_IDLE (%d frames): %.2f" % [MEASURE_FRAMES, fps_idle])
	print("2b.max_pending_regen_tasks_during_measurement_window: %d (expect 0 - confirms idle held throughout, not just at the start)" % [max_pending_during_measurement])

	print("DONE")
	get_tree().quit()
