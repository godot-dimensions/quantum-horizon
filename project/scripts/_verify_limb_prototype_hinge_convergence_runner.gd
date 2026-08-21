extends Node
## TEMPORARY - re-runs the same effector-to-target convergence methodology
## as _verify_ik_chain_3joint_runner.gd (reset chain, place target at a set
## pose, run CONVERGENCE_FRAMES physics ticks, measure residual distance),
## against the limb prototype's OWN FL leg chain, run twice per pose: once
## with the shipped hinge constraints active, once with them cleared
## (hinge_min_deg/hinge_max_deg emptied at runtime) as the "before" baseline
## for the SAME chain (same segment lengths) - isolating exactly what the
## hinge constraints changed, not conflating it with the unrelated
## single_joint_test.tscn chain's own different segment lengths.
##
## Poses are the SAME four relative offsets from the chain's base joint used
## by the original 3-joint test (near/side/diag/w_offset - derived there as
## pose-minus-(0,5,0,0), since that test's base sat at height 5), reapplied
## relative to THIS chain's own base (the FL anchor's actual position),
## rather than assuming an identical absolute base position.
##
## Body speed is zeroed for the duration of this test so the anchor holds
## still - wander motion mid-test would move the goalposts pose to pose.
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_test.tscn set as the main scene.

const CONVERGENCE_FRAMES := 600
const DISTANCE_CONVERGENCE_THRESHOLD := 0.05

const POSE_OFFSETS := [
	{"name": "near", "offset": Vector4(0.5, -4.0, 0.5, 0.0)},
	{"name": "side", "offset": Vector4(3.0, -4.0, 1.0, 0.0)},
	{"name": "diag", "offset": Vector4(2.0, -4.5, 2.0, 0.0)},
	{"name": "w_offset", "offset": Vector4(1.0, -4.0, 1.0, 2.5)},
]

## NOT part of "the same test poses" requirement - added on top to separate
## two different candidate causes of the above poses' hinge-constrained
## failure: the (expected, by-design) w-blindness vs. the placeholder angle
## ranges simply not covering these borrowed poses' geometry. Mimics what
## limb_prototype_foot_target.gd's own raycast actually asks the chain to
## reach in real gameplay - straight down to the ground plus a modest
## forward_lead_distance-scale lead (see that script's own default of 1.5),
## not the wide sideways/diagonal reaches the original poses were composed
## for. w=0, matching real gameplay (the FSM never asks for a w offset in
## this scene).
const REALISTIC_POSE := {"name": "realistic_ground", "offset": Vector4(1.5, -4.5, 0.0, 0.0)}


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _reset_chain(ik_chain: Node) -> void:
	for joint in ik_chain.joints:
		joint.global_basis = Projection()


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run_poses(ik_chain: Node, foot_target: Node4D, anchor: Node4D, label: String, poses: Array) -> bool:
	var all_converged: bool = true
	for pose in poses:
		var target_pos: Vector4 = anchor.global_position + pose["offset"]
		foot_target.global_position = target_pos
		_reset_chain(ik_chain)
		for i in range(CONVERGENCE_FRAMES):
			await get_tree().physics_frame # Relies solely on ik_chain's own automatic _physics_process, same as the original 3-joint test - no extra manual sweep call.

		var effector_pos: Vector4 = ik_chain._end_effector_position()
		var distance: float = (effector_pos - target_pos).length()
		var converged: bool = distance <= DISTANCE_CONVERGENCE_THRESHOLD
		all_converged = all_converged and converged
		print("[%s] pose=%s target=%s effector=%s distance=%.5f converged=%s" % [
			label, pose["name"], target_pos, effector_pos, distance, converged,
		])

		var base_pos: Vector4 = ik_chain.joints[0].global_position
		var mid_point: Vector4 = (base_pos + target_pos) * 0.5
		var horizontal_reach: Vector4 = Vector4(target_pos.x - base_pos.x, 0, target_pos.z - base_pos.z, 0)
		var perp: Vector4 = Vector4(-horizontal_reach.z, 0, horizontal_reach.x, 0)
		perp = perp.normalized() if perp.length() > 0.01 else Vector4(1, 0, 0, 0)
		var photo_pos: Vector4 = mid_point + perp * 8.0
		photo_pos.y = maxf(mid_point.y, 2.0) + 1.0

		var scene: Control = get_tree().current_scene
		var flat_plane: Node4D = scene.get_node("FlatPlane")
		var player: CharacterBody4D = flat_plane.get_node("Player")
		player.global_position = photo_pos
		player.global_basis = Basis4D.looking_at(mid_point - photo_pos)
		await get_tree().physics_frame
		await _screenshot("ik_hinge_convergence_%s_%s.png" % [label, pose["name"]])
	return all_converged


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("Body")
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchorFL/IKChain")
	var anchor: Node4D = flat_plane.get_node("Body/LimbAnchorFL")
	var foot_target: Node4D = flat_plane.get_node("FootTargetFL")

	print("1.nodes_resolve: ik_chain=%s anchor=%s foot_target=%s joint_count=%d" % [
		ik_chain != null, anchor != null, foot_target != null, ik_chain.joints.size(),
	])

	var max_reach: float = 0.0
	for length in ik_chain.link_lengths:
		max_reach += length
	print("2.link_lengths=%s max_reach=%.3f hinge_min_deg=%s hinge_max_deg=%s hinge_bend_sign=%s" % [
		ik_chain.link_lengths, max_reach, ik_chain.hinge_min_deg, ik_chain.hinge_max_deg, ik_chain.hinge_bend_sign,
	])

	body.speed = 0.0 # Freeze wander for the duration of this test - see header comment.

	# foot_target has its own _physics_process (the Planted/Lifting/Swinging
	# FSM) that overwrites global_position every frame from ITS OWN state
	# (locked_position while Planted) - discovered directly when an initial
	# run showed the effector converging to the same fixed point regardless
	# of which pose was set, i.e. the manual position override below was
	# being stomped every frame. Disabling it for this isolated IK-only test
	# makes the manual override actually stick.
	foot_target.set_physics_process(false)

	# Saved before clearing, so the "with hinge" pass below (which reuses
	# these arrays) runs the SHIPPED config, not a leftover empty one.
	var saved_min: Array = ik_chain.hinge_min_deg.duplicate()
	var saved_max: Array = ik_chain.hinge_max_deg.duplicate()
	var saved_sign: Array = ik_chain.hinge_bend_sign.duplicate()

	print("3.=== WITHOUT hinge constraints (baseline, same segment lengths) ===")
	ik_chain.hinge_min_deg.clear()
	ik_chain.hinge_max_deg.clear()
	var without_converged: bool = await _run_poses(ik_chain, foot_target, anchor, "without_hinge", POSE_OFFSETS)

	print("4.=== WITH hinge constraints (shipped config) ===")
	ik_chain.hinge_min_deg.append_array(saved_min)
	ik_chain.hinge_max_deg.append_array(saved_max)
	ik_chain.hinge_bend_sign.append_array(saved_sign)
	var with_converged: bool = await _run_poses(ik_chain, foot_target, anchor, "with_hinge", POSE_OFFSETS)

	print("5.without_hinge_all_converged=%s with_hinge_all_converged=%s" % [without_converged, with_converged])

	print("6.=== Realistic ground-target pose (not part of the original test poses) ===")
	var realistic_converged: bool = await _run_poses(ik_chain, foot_target, anchor, "with_hinge", [REALISTIC_POSE])
	print("7.realistic_pose_converged=%s" % realistic_converged)

	print("DONE")
	get_tree().quit()
