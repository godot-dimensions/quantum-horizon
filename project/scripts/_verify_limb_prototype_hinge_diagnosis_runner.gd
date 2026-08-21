extends Node
## TEMPORARY - diagnostic-only (makes no tuning decisions, applies no
## fixes). Three separate investigations against the FL leg's real,
## shipped, hinge-constrained chain:
##
## STEP 1: sample REAL raycast-computed foot targets from an actual live
## wander run (watch for PLANTED->LIFTING transitions and record
## ft.swing_target_position - the exact live-raycast target the FSM itself
## computed, not a synthetic pose) - then test each one against the
## constrained chain: does it converge, and if not, is the miss short of
## the target or past it, and along which axis?
##
## STEP 3: for each of those same real targets, run an UNCONSTRAINED solve
## (hinge cleared) and measure what angle each joint actually settles at,
## via ik_chain.get_current_hinge_angle_deg() - a real, observed answer
## instead of another guessed placeholder for what the ranges should be.
##
## STEP 4: separately, probe the constrained chain's actual reachable
## radius across a spread of directions within its own hinge plane (binary
## search per direction) and compare against max_reach and the current
## reach_release_fraction threshold - if the hinge constraints have shrunk
## the practical reach well below what reach_release_fraction=0.97 assumes,
## that threshold may now sit outside the constrained chain's real
## workspace entirely, silently disabling the backstop it's supposed to be.
##
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene (needs the real
## wander behavior, not the plain test scene).

const SAMPLE_RUN_SECONDS := 40.0
const SAMPLES_WANTED := 20
# Raised from an earlier 120 (2s): a _reset_chain()-from-identity start can
# be ~180 degrees away from a valid target on more than one joint at once,
# and closing that fully (not just "mostly") took ~400-450 frames in a
# direct trace (_verify_limb_prototype_hinge_debug_trace_runner.gd) even
# after fixing the plane-misalignment bug - 120 frames was cutting real,
# eventually-convergent cases off before they finished, not just correctly
# failing genuinely unreachable ones. Real gameplay never resets from
# identity between targets (only this test harness does, matching the
# original single_joint chain tests' own convention), so this budget is
# specific to fairly evaluating THIS reset-based methodology, not a claim
# about how long convergence takes during actual continuous walking.
const CONVERGENCE_FRAMES := 500
const DISTANCE_CONVERGENCE_THRESHOLD := 0.05
const DIRECTION_SAMPLES := 5 # -90/-45/0/45/90 deg, within the joint-0 hinge plane.
const REACH_SEARCH_ITERATIONS := 8 # Resolution ~= max_radius/256 - plenty for this purpose.


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
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchorFL/IKChain")
	var anchor: Node4D = flat_plane.get_node("Body/LimbAnchorFL")
	var foot_target: Node4D = flat_plane.get_node("FootTargetFL")

	print("1.nodes_resolve: ik_chain=%s anchor=%s foot_target=%s" % [ik_chain != null, anchor != null, foot_target != null])
	print("2.shipped_config: link_lengths=%s hinge_min_deg=%s hinge_max_deg=%s hinge_bend_sign=%s root_forward_local=%s reach_release_fraction=%.3f" % [
		ik_chain.link_lengths, ik_chain.hinge_min_deg, ik_chain.hinge_max_deg, ik_chain.hinge_bend_sign, ik_chain.root_forward_local, foot_target.reach_release_fraction,
	])

	# ==================== STEP 1: sample REAL live targets ====================
	print("3.=== STEP 1: sampling real raycast targets from live wander ===")
	var samples: Array = [] # {leg_index, anchor_pos_at_sample, target}
	var last_states: Array = []
	var foot_targets_all: Array = [
		flat_plane.get_node("FootTargetFL"),
		flat_plane.get_node("FootTargetFR"),
		flat_plane.get_node("FootTargetBL"),
		flat_plane.get_node("FootTargetBR"),
	]
	var anchors_all: Array = [
		flat_plane.get_node("Body/LimbAnchorFL"),
		flat_plane.get_node("Body/LimbAnchorFR"),
		flat_plane.get_node("Body/LimbAnchorBL"),
		flat_plane.get_node("Body/LimbAnchorBR"),
	]
	for ft in foot_targets_all:
		last_states.append(ft.state)

	var total_frames: int = int(SAMPLE_RUN_SECONDS * 60.0)
	for frame in range(total_frames):
		await get_tree().physics_frame
		if samples.size() >= SAMPLES_WANTED:
			break
		for i in range(4):
			var ft = foot_targets_all[i]
			if last_states[i] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING:
				samples.append({
					"leg_index": i,
					"anchor_pos": anchors_all[i].global_position,
					"target": ft.swing_target_position,
				})
				print("   sample leg=%d anchor=%s target=%s rel=%s" % [
					i, anchors_all[i].global_position, ft.swing_target_position, ft.swing_target_position - anchors_all[i].global_position,
				])
			last_states[i] = ft.state

	print("4.samples_collected=%d (wanted %d)" % [samples.size(), SAMPLES_WANTED])

	# Freeze everything for the isolated per-sample re-tests below.
	body.speed = 0.0
	for ft in foot_targets_all:
		ft.set_physics_process(false)

	var saved_min: Array = ik_chain.hinge_min_deg.duplicate()
	var saved_max: Array = ik_chain.hinge_max_deg.duplicate()

	print("5.=== STEP 1 (cont'd): re-testing each real sample against the CONSTRAINED FL chain ===")
	var constrained_miss_count: int = 0
	for s in samples:
		if s["leg_index"] != 0:
			continue # Only FL has an ik_chain reference above; test FL's own real samples.
		var rel: Vector4 = s["target"] - s["anchor_pos"]
		var target_pos: Vector4 = anchor.global_position + rel
		foot_target.global_position = target_pos
		_reset_chain(ik_chain)
		for i in range(CONVERGENCE_FRAMES):
			await get_tree().physics_frame
		var effector: Vector4 = ik_chain._end_effector_position()
		var miss: Vector4 = target_pos - effector
		var distance: float = miss.length()
		var converged: bool = distance <= DISTANCE_CONVERGENCE_THRESHOLD
		if not converged:
			constrained_miss_count += 1
		var reach_dir: Vector4 = (target_pos - anchor.global_position).normalized()
		var target_reach_dist: float = (target_pos - anchor.global_position).length()
		var effector_reach_dist: float = (effector - anchor.global_position).dot(reach_dir)
		print("   [constrained] rel=%s distance=%.4f converged=%s miss_xyzw=(%.3f,%.3f,%.3f,%.3f) along_reach_axis=%s (target_dist=%.3f effector_proj=%.3f)" % [
			rel, distance, converged, miss.x, miss.y, miss.z, miss.w,
			"short" if effector_reach_dist < target_reach_dist else "past", target_reach_dist, effector_reach_dist,
		])

	print("6.constrained_miss_count_of_FL_samples=%d" % constrained_miss_count)

	# ==================== STEP 3: unconstrained angles for the same targets ====================
	print("7.=== STEP 3: unconstrained solve + observed joint angles for the same real FL targets ===")
	ik_chain.hinge_min_deg.clear()
	ik_chain.hinge_max_deg.clear()
	var joint_angle_min: Array = [INF, INF, INF]
	var joint_angle_max: Array = [-INF, -INF, -INF]
	for s in samples:
		if s["leg_index"] != 0:
			continue
		var rel: Vector4 = s["target"] - s["anchor_pos"]
		var target_pos: Vector4 = anchor.global_position + rel
		foot_target.global_position = target_pos
		_reset_chain(ik_chain)
		for i in range(CONVERGENCE_FRAMES):
			await get_tree().physics_frame
		var effector: Vector4 = ik_chain._end_effector_position()
		var distance: float = (target_pos - effector).length()
		var angles: Array = []
		for j in range(ik_chain.joints.size()):
			var a: float = ik_chain.get_current_hinge_angle_deg(j)
			angles.append(a)
			joint_angle_min[j] = minf(joint_angle_min[j], a)
			joint_angle_max[j] = maxf(joint_angle_max[j], a)
		print("   [unconstrained] rel=%s distance=%.4f joint_angles_deg=%s" % [rel, distance, angles])

	print("8.observed_unconstrained_angle_range_per_joint_deg: min=%s max=%s (current shipped ranges: min=%s max=%s)" % [
		joint_angle_min, joint_angle_max, saved_min, saved_max,
	])

	# Restore shipped hinge config for step 4.
	ik_chain.hinge_min_deg.append_array(saved_min)
	ik_chain.hinge_max_deg.append_array(saved_max)

	# ==================== STEP 4: reachable-radius probe ====================
	print("9.=== STEP 4: constrained vs unconstrained reachable radius by direction (joint-0 hinge plane) ===")
	var max_reach: float = 0.0
	for length in ik_chain.link_lengths:
		max_reach += length
	var e_down := Vector4(0, -1, 0, 0)
	var e_fwd: Vector4 = ik_chain.global_basis * ik_chain.root_forward_local
	e_fwd = Vector4(e_fwd.x, 0, e_fwd.z, 0).normalized()

	# Unconstrained reach (already established in an earlier run, and
	# unaffected by the plane-alignment bug fix since an empty hinge config
	# never calls _apply_hinge_constraint at all) is not re-measured here -
	# only the constrained side, which the bug fix actually changes.
	for step in range(DIRECTION_SAMPLES):
		var angle_deg: float = -90.0 + step * (180.0 / (DIRECTION_SAMPLES - 1))
		var angle_rad: float = deg_to_rad(angle_deg)
		var dir: Vector4 = e_down * cos(angle_rad) + e_fwd * sin(angle_rad)

		var constrained_radius: float = await _find_max_reachable_radius(ik_chain, foot_target, anchor, dir, max_reach)

		print("   dir_angle_deg=%.1f constrained_reach=%.3f (max_reach=%.3f, reach_release_threshold=%.3f, threshold_within_constrained_reach=%s)" % [
			angle_deg, constrained_radius, max_reach, foot_target.reach_release_fraction * max_reach,
			constrained_radius >= foot_target.reach_release_fraction * max_reach,
		])

	print("DONE")
	get_tree().quit()


## Binary search along `dir` (from anchor) for the largest radius at which
## the chain still converges within CONVERGENCE_FRAMES.
func _find_max_reachable_radius(ik_chain: Node, foot_target: Node4D, anchor: Node4D, dir: Vector4, max_radius: float) -> float:
	var lo: float = 0.0
	var hi: float = max_radius * 1.05 # A little past nominal max_reach, in case the projected direction isn't exactly along a segment.
	for iteration in range(REACH_SEARCH_ITERATIONS):
		var mid: float = (lo + hi) * 0.5
		var target_pos: Vector4 = anchor.global_position + dir * mid
		foot_target.global_position = target_pos
		_reset_chain(ik_chain)
		for i in range(CONVERGENCE_FRAMES):
			await get_tree().physics_frame
		var effector: Vector4 = ik_chain._end_effector_position()
		var distance: float = (target_pos - effector).length()
		if distance <= DISTANCE_CONVERGENCE_THRESHOLD:
			lo = mid
		else:
			hi = mid
	return lo
