extends Node
## TEMPORARY - deliberately drives a target past max_reach and observes
## FABRIK's native behavior directly, to inform the reach_release_fraction
## decision (keep as-is / simplify / retire) required before calling this
## task done.
##
## Uses the 2-joint generic test chain (link_lengths [1.5, 1.2], total
## reach 2.7) rather than a real leg, so the target can be moved to an
## exact, controlled distance without interference from gait-cycle timing.

const SETTLE_FRAMES := 120


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Node4D = get_tree().current_scene
	var chain2: Node4D = scene.get_node("Chain2/IKChain")
	var target2: Node4D = scene.get_node("Chain2/Target2")
	var total_reach: float = 0.0
	for length in chain2.link_lengths:
		total_reach += length

	# Move the target to 1.5x max_reach, well beyond anything achievable.
	target2.global_position = Vector4(total_reach * 1.5, 0, 0, 0)
	chain2.solve_fabrik()

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	var anchor_pos: Vector4 = chain2.joints[0].global_position
	var effector: Vector4 = chain2._end_effector_position()
	var reach_achieved: float = (effector - anchor_pos).length()
	var joint_positions: Array = []
	for j in chain2.joints:
		joint_positions.append(j.global_position)

	print("=== over-reach probe ===")
	print("  total_reach=%.4f target_distance=%.4f (%.2fx reach)" % [total_reach, (target2.global_position - anchor_pos).length(), (target2.global_position - anchor_pos).length() / total_reach])
	print("  anchor=%s target=%s effector=%s" % [anchor_pos, target2.global_position, effector])
	print("  joint_positions=%s" % [joint_positions])
	print("  reach_achieved=%.4f (expect close to total_reach=%.4f - straight, fully-extended chain)" % [reach_achieved, total_reach])
	print("  effector_direction_matches_target_bearing=%s" % [(effector - anchor_pos).normalized().is_equal_approx((target2.global_position - anchor_pos).normalized())])

	print("DONE")
	get_tree().quit()
