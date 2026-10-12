extends Node
## TEMPORARY - re-runs the two specific failures the FABRIK replacement was
## built to fix, now that CCD/two-bone are gone entirely, over a real,
## ongoing gait cycle (not static poses):
##
## 1. The BL near-horizontal-drift case (seed_bend_angles_deg era): BL's
##    last joint (cannon bone) used to settle into a near-horizontal
##    orientation (one captured example: dir=(-0.9475, 0.3196, 0, 0), i.e.
##    dot-with-down ~0.32) during ordinary real gait, not just at spawn.
##    Tracks BL's last joint's dot with world-down every frame it's
##    PLANTED - if FABRIK's per-frame position solve genuinely fixed this
##    (rather than just reducing it), the minimum observed dot should sit
##    much closer to 1.0 (pointing down), not near 0.32.
## 2. The 142-frame sustained-growth run (two-bone era, frames 620-762 on
##    FL): residual climbed steadily for well over 100 consecutive frames
##    while the solver's own outputs moved smoothly - a genuine
##    convergence-rate problem, not a snap/discontinuity. Tracks the
##    longest run of frames where residual is STILL INCREASING (not just
##    "large") for all 4 legs - if this run length collapses to a small
##    number of frames, that's the sustained-lag failure gone, not just
##    smaller peak residuals.
##
## Also doubles as the required full-real-gait-cycle check (cycle counts +
## max residual + min planted effector y, same shape as the earlier
## combined verification) since this already exercises all 4 legs through
## many real stance/swing cycles.
##
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.

const TRACE_SECONDS := 20.0
const GROWTH_EPSILON := 0.0001 # Residual increase this small or less doesn't count as "still growing" - floating point noise floor.
const MAX_ACCEPTABLE_RESIDUAL := 0.05 # Same convergence threshold used throughout this whole investigation.
const E_DOWN := Vector4(0, -1, 0, 0)


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
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
	const LEG_NAMES := ["FL", "FR", "BL", "BR"]
	const BL_INDEX := 2

	var last_states: Array = []
	for ft in foot_targets:
		last_states.append(ft.state)

	var max_residual: Array = [0.0, 0.0, 0.0, 0.0]
	var min_planted_effector_y: Array = [INF, INF, INF, INF]
	var cycle_counts: Array = [0, 0, 0, 0]
	var prev_residual: Array = [0.0, 0.0, 0.0, 0.0]
	var current_growth_run: Array = [0, 0, 0, 0]
	var longest_growth_run: Array = [0, 0, 0, 0]

	var min_bl_last_joint_dot_down: float = INF
	var min_bl_last_joint_dir: Vector4 = Vector4.ZERO

	var total_frames: int = int(TRACE_SECONDS * 60.0)
	for frame in range(total_frames):
		await get_tree().physics_frame
		for leg in range(4):
			var ft = foot_targets[leg]
			var chain = ik_chains[leg]
			var effector: Vector4 = chain._end_effector_position()
			var residual: float = (ft.global_position - effector).length()

			max_residual[leg] = maxf(max_residual[leg], residual)
			if ft.state == ft.FootState.PLANTED:
				min_planted_effector_y[leg] = minf(min_planted_effector_y[leg], effector.y)

			if last_states[leg] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING:
				cycle_counts[leg] += 1
			last_states[leg] = ft.state

			if frame > 0 and residual > prev_residual[leg] + GROWTH_EPSILON:
				current_growth_run[leg] += 1
				longest_growth_run[leg] = maxi(longest_growth_run[leg], current_growth_run[leg])
			else:
				current_growth_run[leg] = 0
			prev_residual[leg] = residual

			if leg == BL_INDEX and ft.state == ft.FootState.PLANTED:
				var last_joint: Node4D = chain.joints[chain.joints.size() - 1]
				var last_dir: Vector4 = last_joint.global_basis.y
				var dot_down: float = last_dir.dot(E_DOWN)
				if dot_down < min_bl_last_joint_dot_down:
					min_bl_last_joint_dot_down = dot_down
					min_bl_last_joint_dir = last_dir

	print("=== 1. BL near-horizontal-drift case ===")
	print("  min_last_joint_dot_down_while_planted=%.4f (old failing case: ~0.32; expect much closer to 1.0)" % min_bl_last_joint_dot_down)
	print("  direction_at_that_frame=%s" % [min_bl_last_joint_dir])

	print("=== 2. sustained-growth-run check (old failing case: FL ran 142 consecutive frames) ===")
	for leg in range(4):
		print("  %s longest_consecutive_residual_growth_run=%d frames" % [LEG_NAMES[leg], longest_growth_run[leg]])

	print("=== 3. full real gait cycle (all 4 legs, %.1fs) ===" % TRACE_SECONDS)
	for leg in range(4):
		print("  %s max_residual=%.5f (threshold=%.2f, %s) min_planted_effector_y=%.5f cycle_count=%d" % [
			LEG_NAMES[leg], max_residual[leg], MAX_ACCEPTABLE_RESIDUAL,
			"OK" if max_residual[leg] <= MAX_ACCEPTABLE_RESIDUAL else "EXCEEDED",
			min_planted_effector_y[leg] if min_planted_effector_y[leg] < INF else -999.0,
			cycle_counts[leg],
		])

	print("DONE")
	get_tree().quit()
