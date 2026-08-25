extends Node
## TEMPORARY - verifies the gait clock's period is actually LINKED to the
## body's real movement speed (gait_controller.gd), not just switched
## between presets. Same data-driven checks as the walk/trot distinctness
## stage (per-limb locked-position correctness + co-occurrence matrix), run
## once per body speed - compare this run's own numbers against the OTHER
## speed's run (same preset, only Body.speed changed in the scene) rather
## than a visual impression:
## 1. cycle_counts should scale UP with speed over the same wall-clock
##    window (faster body -> shorter period -> more strides).
## 2. the co-occurrence signature (which legs pair up) should stay intact -
##    duty_factor/phase_offsets are speed-invariant by design, only
##    period_sec scales.
## Pure numeric check, headless-safe (no screenshots - this is a numbers
## comparison, not a visual one). Not part of the shipped scene - wired in
## as a temporary autoload with limb_prototype_test.tscn set as the main
## scene.

const RUN_SECONDS := 20.0
const LEG_NAMES := ["FL", "FR", "BL", "BR"]


func _reset_chain(ik_chain: Node) -> void:
	for joint in ik_chain.joints:
		joint.global_basis = Projection()


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("Body")
	var gait: Node = flat_plane.get_node("GaitController")
	var foot_targets: Array = [
		flat_plane.get_node("FootTargetFL"),
		flat_plane.get_node("FootTargetFR"),
		flat_plane.get_node("FootTargetBL"),
		flat_plane.get_node("FootTargetBR"),
	]
	var ik_chains: Array = [
		flat_plane.get_node("Body/LimbAnchorFL/IKChain"),
		flat_plane.get_node("Body/LimbAnchorFR/IKChain"),
		flat_plane.get_node("Body/LimbAnchorBL/IKChain"),
		flat_plane.get_node("Body/LimbAnchorBR/IKChain"),
	]

	print("1.nodes_resolve: foot_targets=%s ik_chains=%s gait=%s" % [
		foot_targets.all(func(n): return n != null), ik_chains.all(func(n): return n != null), gait != null,
	])
	print("2.preset=%s body_speed=%.3f reference_speed=%.3f reference_period_sec=%.3f duty_factor=%.3f valid_speed_ceiling=%.4f (body_speed_vs_ceiling=%s)" % [
		gait.preset, body.speed, gait.reference_speed, gait.reference_period_sec, gait.duty_factor, gait.valid_speed_ceiling,
		"within" if body.speed <= gait.valid_speed_ceiling else "PAST CEILING",
	])

	for ik_chain in ik_chains:
		_reset_chain(ik_chain)

	var violations: Array = [0, 0, 0, 0]
	var cycle_counts: Array = [0, 0, 0, 0]
	var last_states: Array = []
	var last_locked: Array = []
	var was_planted_last_frame: Array = [true, true, true, true]
	for i in range(4):
		last_states.append(foot_targets[i].state)
		last_locked.append(foot_targets[i].locked_position)

	var cooccurrence: Array = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
	var period_samples: Array = []

	var total_frames: int = int(RUN_SECONDS * 60.0)
	for frame in range(total_frames):
		await get_tree().physics_frame

		if frame % 60 == 0:
			period_samples.append(gait.period_sec)

		for i in range(4):
			var ft = foot_targets[i]
			if ft.state == ft.FootState.PLANTED:
				if was_planted_last_frame[i] and ft.global_position != last_locked[i]:
					violations[i] += 1
					print("VIOLATION leg=%s frame=%d: planted position drifted from %s to %s" % [LEG_NAMES[i], frame, last_locked[i], ft.global_position])
				last_locked[i] = ft.locked_position
				was_planted_last_frame[i] = true
			else:
				was_planted_last_frame[i] = false

			if last_states[i] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING:
				cycle_counts[i] += 1
				for j in range(4):
					if j == i:
						continue
					if foot_targets[j].state != foot_targets[j].FootState.PLANTED:
						cooccurrence[i][j] += 1

			last_states[i] = ft.state

	var period_sum: float = 0.0
	for p in period_samples:
		period_sum += p
	var avg_period: float = period_sum / period_samples.size() if period_samples.size() > 0 else -1.0

	var override_counts: Array = []
	for ft in foot_targets:
		override_counts.append(ft.reach_override_count)

	print("3.avg_period_sec_over_run=%.4f (reference_period_sec=%.4f at reference_speed=%.3f)" % [avg_period, gait.reference_period_sec, gait.reference_speed])
	print("4.violations=%s (expect all 0)" % [violations])
	print("5.cycle_counts[FL,FR,BL,BR]=%s total=%d" % [cycle_counts, cycle_counts[0] + cycle_counts[1] + cycle_counts[2] + cycle_counts[3]])
	print("6.cooccurrence matrix (row=leg that just released, col=other leg airborne at that moment):")
	for i in range(4):
		print("   %s: %s" % [LEG_NAMES[i], cooccurrence[i]])
	print("7.reach_override_count[FL,FR,BL,BR]=%s total=%d (expect rare/zero now that the gate is authoritative)" % [
		override_counts, override_counts[0] + override_counts[1] + override_counts[2] + override_counts[3],
	])
	print("DONE")
	get_tree().quit()
