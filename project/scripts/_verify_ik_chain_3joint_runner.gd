extends Node
## TEMPORARY - verifies the 3-joint IK chain in single_joint_test.tscn. Same
## methodology as _verify_ik_chain_2joint_runner.gd (see that file for the
## full rationale on numeric-distance-is-what-matters, the per-pose chain/
## basis reset, and the perpendicular photo-camera placement) - just against
## the 3-segment chain and its larger max_reach. Not part of the shipped
## scene - wired in as a temporary autoload with single_joint_test.tscn set
## as the main scene.

const CONVERGENCE_FRAMES := 600
const DISTANCE_CONVERGENCE_THRESHOLD := 0.05


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


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var ik_chain: Node = flat_plane.get_node("IKChain")

	print("1.nodes_resolve: player=%s ik_chain=%s joint_count=%d" % [
		player != null, ik_chain != null, ik_chain.joints.size(),
	])

	var max_reach: float = 0.0
	for length in ik_chain.link_lengths:
		max_reach += length
	print("2.max_reach=%.3f" % max_reach)

	# Base still at height 5, but max_reach is now 7.5 (was 5.5 for 2 joints),
	# so on-ground targets sit at a more comfortable fraction of max reach
	# than the 2-joint case did.
	var poses: Array = [
		{"name": "near", "pos": Vector4(0.5, 1, 0.5, 0)},
		{"name": "side", "pos": Vector4(3, 1, 1, 0)},
		{"name": "diag", "pos": Vector4(2, 0.5, 2, 0)},
		{"name": "w_offset", "pos": Vector4(1, 1, 1, 2.5)},
	]

	var all_converged: bool = true
	for pose in poses:
		player.global_position = pose["pos"]
		player.global_basis = Projection()
		_reset_chain(ik_chain)
		for i in range(CONVERGENCE_FRAMES):
			await get_tree().physics_frame

		var effector_pos: Vector4 = ik_chain._end_effector_position()
		var target_pos: Vector4 = player.global_position
		var distance: float = (effector_pos - target_pos).length()
		var target_dist_from_base: float = (target_pos - ik_chain.joints[0].global_position).length()
		var converged: bool = distance <= DISTANCE_CONVERGENCE_THRESHOLD
		all_converged = all_converged and converged
		print("pose=%s player_pos=%s effector_pos=%s distance=%.5f target_dist_from_base=%.3f (max_reach=%.3f, %.1f%%) converged=%s" % [
			pose["name"], target_pos, effector_pos, distance, target_dist_from_base, max_reach, 100.0 * target_dist_from_base / max_reach, converged,
		])

		var base_pos: Vector4 = ik_chain.joints[0].global_position
		var mid_point: Vector4 = (base_pos + target_pos) * 0.5
		var horizontal_reach: Vector4 = Vector4(target_pos.x - base_pos.x, 0, target_pos.z - base_pos.z, 0)
		var perp: Vector4 = Vector4(-horizontal_reach.z, 0, horizontal_reach.x, 0)
		perp = perp.normalized() if perp.length() > 0.01 else Vector4(1, 0, 0, 0)
		var photo_pos: Vector4 = mid_point + perp * 8.0
		photo_pos.y = maxf(mid_point.y, 2.0) + 1.0
		player.global_position = photo_pos
		player.global_basis = Basis4D.looking_at(mid_point - photo_pos)
		await get_tree().physics_frame
		await _screenshot("ik_chain_3joint_%s.png" % pose["name"])

	print("3.all_converged=%s" % all_converged)
	print("DONE")
	get_tree().quit()
