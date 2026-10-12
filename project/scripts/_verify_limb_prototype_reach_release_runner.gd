extends Node
## TEMPORARY - verifies the reach-based release trigger (replacing the
## fixed-dwell stance_duration_sec, see limb_prototype_foot_target.gd's own
## header for why the timer version failed: 0/30 cycles under the
## static-root 0.05 bar, avg 0.658, max 1.355). This time checked against a
## RELAXED bar consistent with Step 1's already-measured moving-root
## tracking envelope (~0.2-0.6), not the static-root 0.05 standard, which
## was only ever valid for a stationary root. The real signal is the MAX
## residual staying well clear of the 1.3+ blowups just seen - the reach
## trigger's whole point is to release BEFORE the chain is forced into a
## geometrically-impossible overreach, so a low max (not just a better
## average) is what actually proves it's doing its job.
##
## Checked at the moment PLANTED->LIFTING actually fires (the true "just
## before a new cycle begins" instant under a reach-based trigger, since
## there's no fixed dwell to time against anymore).
##
## Pure numeric check, headless-safe. Not part of the shipped scene - wired
## in as a temporary autoload with limb_prototype_test.tscn set as the main
## scene.

const TARGET_CYCLES := 30
const MAX_FRAMES := 12000
const RELAXED_LOWER := 0.2
const RELAXED_UPPER := 0.6
const BLOWUP_THRESHOLD := 1.0 # Comfortably below the 1.355 max seen with the timer-based trigger - any result at/above this would mean the reach trigger isn't actually preventing overreach.


func _reset_chain(ik_chain: Node) -> void:
	for joint in ik_chain.joints:
		joint.global_basis = Projection()


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var foot_target: Node4D = flat_plane.get_node("FootTarget")
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchor/IKChain")

	print("1.nodes_resolve: foot_target=%s ik_chain=%s" % [foot_target != null, ik_chain != null])
	print("2.reach_release_fraction=%.3f max_reach=%.3f release_distance=%.3f" % [
		foot_target.reach_release_fraction, foot_target.max_reach, foot_target.reach_release_fraction * foot_target.max_reach,
	])

	_reset_chain(ik_chain)

	var planted_violations: int = 0
	var last_state: int = foot_target.state
	var last_locked_position: Vector4 = foot_target.locked_position
	var was_planted_last_frame: bool = true

	# The very FIRST release, right after the chain's identity reset, is a
	# cold-start transient, not steady-state behavior - the same pattern
	# seen repeatedly earlier in this project (2-joint/5-joint cold starts,
	# the very first moving-target sample, etc.). Consumed here as an
	# uncounted warm-up cycle rather than folded into the real statistics.
	var warmed_up: bool = false
	var cycles_checked: int = 0
	var distances: Array = []

	var frame: int = 0
	while frame < MAX_FRAMES and cycles_checked < TARGET_CYCLES:
		await get_tree().physics_frame

		if foot_target.state == foot_target.FootState.PLANTED:
			if was_planted_last_frame and foot_target.global_position != last_locked_position:
				planted_violations += 1
				print("VIOLATION at frame=%d: planted position drifted from %s to %s" % [frame, last_locked_position, foot_target.global_position])
			last_locked_position = foot_target.locked_position
			was_planted_last_frame = true
		else:
			was_planted_last_frame = false

		# Fires exactly when the reach trigger releases - locked_position is
		# still the OLD (about-to-be-vacated) value at this instant.
		if last_state == foot_target.FootState.PLANTED and foot_target.state == foot_target.FootState.LIFTING:
			if not warmed_up:
				warmed_up = true
				var warmup_effector: Vector4 = ik_chain._end_effector_position()
				var warmup_distance: float = (warmup_effector - foot_target.locked_position).length()
				print("warmup (uncounted) t=%.3fs effector_distance_at_release=%.5f" % [frame / 60.0, warmup_distance])
			else:
				cycles_checked += 1
				var effector_pos: Vector4 = ik_chain._end_effector_position()
				var distance: float = (effector_pos - foot_target.locked_position).length()
				distances.append(distance)
				print("cycle=%d t=%.3fs effector_distance_at_release=%.5f" % [cycles_checked, frame / 60.0, distance])

		last_state = foot_target.state
		frame += 1

	var max_distance: float = 0.0
	var sum_distance: float = 0.0
	var in_relaxed_band: int = 0
	for d in distances:
		max_distance = maxf(max_distance, d)
		sum_distance += d
		if d >= RELAXED_LOWER and d <= RELAXED_UPPER:
			in_relaxed_band += 1
	var avg_distance: float = sum_distance / distances.size() if distances.size() > 0 else -1.0
	var max_clear_of_blowup: bool = max_distance < BLOWUP_THRESHOLD

	print("3.planted_violations=%d (expect 0)" % planted_violations)
	print("4.cycles_checked=%d avg_distance=%.5f max_distance=%.5f in_relaxed_band[%.1f-%.1f]=%d/%d max_clear_of_blowup(<%.1f)=%s" % [
		cycles_checked, avg_distance, max_distance, RELAXED_LOWER, RELAXED_UPPER, in_relaxed_band, distances.size(), BLOWUP_THRESHOLD, max_clear_of_blowup,
	])
	print("DONE")
	get_tree().quit()
