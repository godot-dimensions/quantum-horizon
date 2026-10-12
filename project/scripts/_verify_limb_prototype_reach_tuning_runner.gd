extends Node
## TEMPORARY - re-verifies override count + co-occurrence at the same three
## speed points already tested for the hard-gate restructure (2.0, 2.6, 3.4),
## now that reach_release_fraction has been raised (0.8 -> 0.9, see
## limb_prototype_foot_target.gd's own comment for the derivation). Runs all
## three speeds back-to-back in a single scene load (body.speed and the
## per-segment counters are reset between segments; foot FSM state itself is
## left running continuously across the boundary - a mid-cycle leg at a
## segment boundary is negligible noise over a 20s segment). Target: override
## count in single digits, not the 33-38% previously measured at 0.8.
##
## Pure numeric check, headless-safe. Not part of the shipped scene - wired
## in as a temporary autoload with limb_prototype_test.tscn set as the main
## scene.

const RUN_SECONDS := 20.0
const SPEEDS_TO_TEST := [2.0, 2.6, 3.4]
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

	print("1.nodes_resolve: foot_targets=%s ik_chains=%s gait=%s reach_release_fraction=%.2f" % [
		foot_targets.all(func(n): return n != null), ik_chains.all(func(n): return n != null), gait != null,
		foot_targets[0].reach_release_fraction,
	])

	for ik_chain in ik_chains:
		_reset_chain(ik_chain)

	# Final canonical run: shipped scene defaults only (reach_release_fraction
	# 0.97, duty_factor 0.6) - no runtime overrides. Earlier exploratory runs
	# (not reflected here) tried 0.8/0.9/0.97/0.99 for reach_release_fraction
	# and 0.6/0.75 for duty_factor; see limb_prototype_foot_target.gd's own
	# comment on reach_release_fraction for the full record of what was
	# tried and why 0.97 was picked.

	for speed in SPEEDS_TO_TEST:
		body.speed = speed
		for ft in foot_targets:
			ft.reach_override_count = 0

		var cycle_counts: Array = [0, 0, 0, 0]
		var cooccurrence: Array = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
		var last_states: Array = []
		for ft in foot_targets:
			last_states.append(ft.state)

		var total_frames: int = int(RUN_SECONDS * 60.0)
		for frame in range(total_frames):
			await get_tree().physics_frame
			for i in range(4):
				var ft = foot_targets[i]
				if last_states[i] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING:
					cycle_counts[i] += 1
					for j in range(4):
						if j == i:
							continue
						if foot_targets[j].state != foot_targets[j].FootState.PLANTED:
							cooccurrence[i][j] += 1
				last_states[i] = ft.state

		var override_counts: Array = []
		for ft in foot_targets:
			override_counts.append(ft.reach_override_count)
		var total_cycles: int = cycle_counts[0] + cycle_counts[1] + cycle_counts[2] + cycle_counts[3]
		var total_overrides: int = override_counts[0] + override_counts[1] + override_counts[2] + override_counts[3]

		print("=== speed=%.2f (period_sec=%.3f, valid_speed_ceiling=%.3f, %s) ===" % [
			speed, gait.period_sec, gait.valid_speed_ceiling,
			"within" if speed <= gait.valid_speed_ceiling else "PAST CEILING",
		])
		print("  cycle_counts[FL,FR,BL,BR]=%s total=%d" % [cycle_counts, total_cycles])
		print("  cooccurrence matrix (row=leg that just released, col=other leg airborne at that moment):")
		for i in range(4):
			print("     %s: %s" % [LEG_NAMES[i], cooccurrence[i]])
		print("  reach_override_count[FL,FR,BL,BR]=%s total=%d (%.1f%% of releases)" % [
			override_counts, total_overrides, 100.0 * total_overrides / total_cycles if total_cycles > 0 else -1.0,
		])

	print("DONE")
	get_tree().quit()
