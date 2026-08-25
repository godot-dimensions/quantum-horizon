extends Node
## TEMPORARY - decisive test: for 4 REAL gameplay targets that the
## constrained CCD solve currently fails to reach, brute-force search the
## entire allowed hinge-angle space directly (no CCD, no physics ticking)
## to answer: is a good solution actually IN the allowed ranges (making
## this a search/local-minimum problem, fixable with stuck-state detection)
## or is it genuinely NOT reachable within the current ranges (making this
## a range problem, fixable only by widening them)?
##
## Forward kinematics here is a direct, non-iterative sum: after the plane-
## alignment fix (ik_chain_controller.gd), EVERY joint shares the exact
## same hinge plane (root_forward_local + world down, only bend_sign
## differing per joint) - it does NOT compound through a parent's rotated
## basis. So each segment's WORLD direction is a pure function of its own
## angle alone: dir_i = e_down*cos(angle_i) + (root_forward_local*bend_sign
## [i])*sin(angle_i), and effector = anchor + sum(link_lengths[i] * dir_i).
## No scene manipulation, no physics frames, no CCD - just the same
## geometry the solver itself uses, evaluated directly over a dense grid.
##
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene (only used to read
## the FL chain's real, current config - anchor position, link_lengths,
## hinge ranges - not to run gameplay).

const GRID_STEPS_PER_JOINT := 50 # 50^3 = 125,000 combinations per target - kept modest since this all runs synchronously within one frame (no awaits inside the grid loop, pure GDScript math, no benefit to spreading it across frames).

## The 4 real gameplay targets confirmed failing under the constrained CCD
## solve in the prior diagnosis session (relative offsets from the FL
## anchor's position at sample time - see that session's own log for the
## unconstrained-solve angles these were derived from).
const REAL_FAILING_TARGETS := [
	Vector4(-0.33783615707895, -4.5, -1.41893646474045, 0.0),
	Vector4(-1.38424706432946, -4.5, -0.50186546200278, 0.0),
	Vector4(-0.27238175381457, -4.5, 1.43296620810293, 0.0),
	Vector4(-1.0911412310001, -4.5, -0.96798491072309, 0.0),
]


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchorFL/IKChain")
	var anchor: Node4D = flat_plane.get_node("Body/LimbAnchorFL")

	var link_lengths: Array = ik_chain.link_lengths
	var hinge_min: Array = ik_chain.hinge_min_deg
	var hinge_max: Array = ik_chain.hinge_max_deg
	var bend_sign: Array = ik_chain.hinge_bend_sign
	var e_down := Vector4(0, -1, 0, 0)

	print("1.link_lengths=%s hinge_min_deg=%s hinge_max_deg=%s bend_sign=%s forward_direction_provider=%s grid=%d^3=%d combos/target" % [
		link_lengths, hinge_min, hinge_max, bend_sign, ik_chain.forward_direction_provider, GRID_STEPS_PER_JOINT, GRID_STEPS_PER_JOINT ** 3,
	])

	for target_index in range(REAL_FAILING_TARGETS.size()):
		var rel: Vector4 = REAL_FAILING_TARGETS[target_index]
		var target_pos: Vector4 = anchor.global_position + rel

		# e_fwd re-derived PER TARGET this time, not once globally - with the
		# fix, the hinge plane tracks the body's live travel direction, which
		# was different at each of these 4 samples' own capture moments (the
		# whole point of the fix). The raycast target itself encodes that
		# direction: probe_xzw = anchor + travel_dir*forward_lead_distance
		# (limb_prototype_foot_target.gd's own formula), so travel_dir is
		# recoverable as rel's own horizontal direction - this is exactly
		# what get_travel_direction() would have returned at that instant,
		# not a re-derivation of different information.
		var e_fwd: Vector4 = Vector4(rel.x, 0, rel.z, 0).normalized()

		var best_distance: float = INF
		var best_angles: Vector3 = Vector3.ZERO

		for i0 in range(GRID_STEPS_PER_JOINT):
			var a0_deg: float = lerpf(hinge_min[0], hinge_max[0], float(i0) / (GRID_STEPS_PER_JOINT - 1))
			var dir0: Vector4 = e_down * cos(deg_to_rad(a0_deg)) + (e_fwd * bend_sign[0]) * sin(deg_to_rad(a0_deg))
			var seg0: Vector4 = dir0 * link_lengths[0]

			for i1 in range(GRID_STEPS_PER_JOINT):
				var a1_deg: float = lerpf(hinge_min[1], hinge_max[1], float(i1) / (GRID_STEPS_PER_JOINT - 1))
				var dir1: Vector4 = e_down * cos(deg_to_rad(a1_deg)) + (e_fwd * bend_sign[1]) * sin(deg_to_rad(a1_deg))
				var seg01: Vector4 = seg0 + dir1 * link_lengths[1]

				for i2 in range(GRID_STEPS_PER_JOINT):
					var a2_deg: float = lerpf(hinge_min[2], hinge_max[2], float(i2) / (GRID_STEPS_PER_JOINT - 1))
					var dir2: Vector4 = e_down * cos(deg_to_rad(a2_deg)) + (e_fwd * bend_sign[2]) * sin(deg_to_rad(a2_deg))
					var effector: Vector4 = anchor.global_position + seg01 + dir2 * link_lengths[2]

					var distance: float = (effector - target_pos).length()
					if distance < best_distance:
						best_distance = distance
						best_angles = Vector3(a0_deg, a1_deg, a2_deg)

			if i0 % 20 == 0:
				print("   ...target %d, %.0f%% through joint0 sweep, best_so_far=%.4f" % [target_index, 100.0 * i0 / GRID_STEPS_PER_JOINT, best_distance])

		print("2.[target %d] rel=%s best_distance=%.4f best_angles_deg=%s (within_ranges by construction) verdict=%s" % [
			target_index, rel, best_distance, best_angles,
			"SEARCH/LOCAL-MINIMUM PROBLEM (good solution exists, CCD just isn't finding it)" if best_distance <= 0.1 else "RANGE PROBLEM (no good solution exists even with brute force)",
		])

	print("DONE")
	get_tree().quit()
