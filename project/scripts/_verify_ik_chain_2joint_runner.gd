extends Node
## TEMPORARY - verifies the 2-joint IK chain in single_joint_test.tscn: moves
## the player to several distinct positions (including one with a genuine
## nonzero W offset), lets CCD converge, and logs the ACTUAL numeric distance
## between the end effector and the player each time - not just a
## screenshot. This matters specifically for a 4D chain: a joint could be
## subtly wrong entirely in the W axis and that would be invisible in a
## rendered cross-section (unlike, say, a 3D elbow bent backwards, which
## would be visually obvious), so the distance number is the thing that
## actually confirms correctness. Screenshots are still taken per pose as a
## sanity check. Not part of the shipped scene - wired in as a temporary
## autoload with single_joint_test.tscn set as the main scene.
##
## Each joint is reset to an identity global_basis before every pose (see
## _reset_chain) - without this, a pose's convergence rate depends on
## whatever bent configuration the PREVIOUS pose happened to leave the chain
## in (confirmed directly: the same pose converged to distance=0.12 after
## 300 frames when following another pose, but to distance=0.017 after 300
## frames starting fresh - a 7x difference from starting-pose history alone).
## Resetting makes every pose's result comparable and reproducible.

const CONVERGENCE_FRAMES := 600 # Confirmed via a focused checkpoint sweep: residual plateaus by ~600 frames and doesn't improve further at 1200/2400.
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

	# Base is at height 5 and the player rests on the ground around y~0.3-0.9
	# (varies pose to pose - collision settling isn't perfectly consistent),
	# so any on-ground target is already fairly extended (roughly 75-95% of
	# max_reach) purely from the vertical gap. These stay clear of the most
	# extreme 95%+ edge, where CCD is known to converge far more slowly (the
	# effector's sensitivity to joint angle vanishes as the chain
	# straightens) - that slowdown is a real, expected property of CCD itself,
	# separately confirmed (see _verify_ik_chain_2joint_convergence_rate.gd)
	# to keep shrinking toward the same small residual given enough frames,
	# not get stuck - not something to paper over by relaxing the tolerance
	# here.
	var poses: Array = [
		{"name": "near", "pos": Vector4(0.3, 1, 0.3, 0)},
		{"name": "moderate_side", "pos": Vector4(2, 1, 0, 0)},
		{"name": "moderate_diag", "pos": Vector4(1, 0.5, 1, 0)},
		{"name": "w_offset_moderate", "pos": Vector4(0.5, 1, 0.5, 1.5)},
	]

	var all_converged: bool = true
	for pose in poses:
		player.global_position = pose["pos"]
		# Also reset the player's OWN basis, not just its position - the
		# previous pose's end-of-loop Basis4D.looking_at() call (below) tilts
		# it away from upright for the screenshot, and leaving that tilt in
		# place through this pose's whole multi-hundred-frame settle loop
		# fed gravity a non-world-down direction the whole time, causing a
		# real runaway slide (confirmed directly: one pose ended up 8+ units
		# off from where it was placed after 600 frames of this).
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

		# For the screenshot only (the numeric check above already happened):
		# pull the player/camera back further along the same base-to-target
		# direction before aiming at the base joint - since the target IS the
		# player's own position and the chain converges to sit right on top
		# of it, screenshotting from the player's converged position would
		# just be a close-up of mesh filling the frame.
		var base_pos: Vector4 = ik_chain.joints[0].global_position
		# Side-on view: offset PERPENDICULAR to the base-to-target reach (in
		# the x/z plane), not further along it - straight-along shots
		# foreshorten the whole arm into one overlapping silhouette (confirmed
		# directly: an earlier version did this and both segments nearly
		# vanished behind each other). Aimed at the reach's own midpoint so
		# both the base and the target end land in frame.
		var mid_point: Vector4 = (base_pos + target_pos) * 0.5
		var horizontal_reach: Vector4 = Vector4(target_pos.x - base_pos.x, 0, target_pos.z - base_pos.z, 0)
		var perp: Vector4 = Vector4(-horizontal_reach.z, 0, horizontal_reach.x, 0)
		perp = perp.normalized() if perp.length() > 0.01 else Vector4(1, 0, 0, 0)
		var photo_pos: Vector4 = mid_point + perp * 6.0
		photo_pos.y = maxf(mid_point.y, 2.0) + 1.0
		player.global_position = photo_pos
		player.global_basis = Basis4D.looking_at(mid_point - photo_pos)
		await get_tree().physics_frame
		await _screenshot("ik_chain_2joint_%s.png" % pose["name"])

	print("3.all_converged=%s" % all_converged)
	print("DONE")
	get_tree().quit()
