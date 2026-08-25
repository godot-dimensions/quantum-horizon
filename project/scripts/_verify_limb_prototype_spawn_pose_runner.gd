extends Node
## TEMPORARY - screenshots the treadmill immediately at spawn to confirm the
## new _seed_spawn_pose() call (limb_prototype_foot_target.gd) actually
## produces a standing pose on the very first rendered frame, instead of
## every joint sitting at its scene-authored identity basis (limbs pointing
## straight up) for the first slew_time_constant_sec or so. Also runs a
## short stretch afterward to confirm the seeding doesn't leave any lasting
## effect on steady-state gait (a one-shot _ready()-time seed should not).
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.

const STEADY_STATE_CHECK_SECONDS := 8.0


func _ready() -> void:
	# Capture as early as possible - a bare single process_frame renders
	# solid black (nothing has been drawn to the viewport texture yet), so
	# wait one more before reading it back. Still early enough (2 frames,
	# well under slew_time_constant_sec's ~21-frame catch-up window) that
	# this is testing the _ready()-time seed, not the normal per-frame
	# partial CCD sweep gradually catching up on its own.
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/limb_prototype_spawn_pose_frame0.png")
	print("1.captured spawn-frame screenshot")

	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var foot_targets: Array = [
		flat_plane.get_node("FootTargetFL"),
		flat_plane.get_node("FootTargetFR"),
		flat_plane.get_node("FootTargetBL"),
		flat_plane.get_node("FootTargetBR"),
	]

	# Steady-state sanity check: gait should still cycle normally after the
	# one-shot spawn seed - no lasting interference expected, confirming
	# directly rather than assuming.
	var cycle_counts: Array = [0, 0, 0, 0]
	var last_states: Array = []
	for ft in foot_targets:
		last_states.append(ft.state)

	var total_frames: int = int(STEADY_STATE_CHECK_SECONDS * 60.0)
	for frame in range(total_frames):
		await get_tree().physics_frame
		for i in range(4):
			var ft = foot_targets[i]
			if last_states[i] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING:
				cycle_counts[i] += 1
			last_states[i] = ft.state

	print("2.steady_state_cycle_counts[FL,FR,BL,BR]=%s over %.1fs (expect several per leg, nonzero)" % [cycle_counts, STEADY_STATE_CHECK_SECONDS])
	print("DONE")
	get_tree().quit()
