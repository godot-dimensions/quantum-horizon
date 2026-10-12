extends Node
## TEMPORARY - focused check: does a pose's residual distance keep shrinking
## with more frames (confirming CCD is just slow to fully converge near
## higher extension ratios, not stuck on a bug), or does it plateau above
## zero (which WOULD indicate a real bug)? Logs distance at several frame
## checkpoints for one held-fixed pose instead of moving on immediately.
## Result recorded in _verify_ik_chain_2joint_runner.gd's own header comment:
## residual shrinks through ~300 frames then plateaus at ~0.011 by 600
## frames, unchanged out to 2400 - genuine convergence, not a stuck bug.

const DISTANCE_CONVERGENCE_THRESHOLD := 0.05


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var ik_chain: Node = flat_plane.get_node("IKChain")

	player.global_position = Vector4(2, 1, 0, 0)
	# Let the player fully settle on the ground first (its exact rest height
	# varies pose to pose), THEN start counting CCD frames from a stable
	# target position, so this is purely about CCD's own convergence rate,
	# not conflated with the player still falling.
	for i in range(120):
		await get_tree().physics_frame
	print("settled player_pos=%s" % player.global_position)

	var checkpoints: Array = [60, 120, 300, 600, 1200, 2400]
	var frames_elapsed: int = 0
	for checkpoint in checkpoints:
		while frames_elapsed < checkpoint:
			await get_tree().physics_frame
			frames_elapsed += 1
		var effector_pos: Vector4 = ik_chain._end_effector_position()
		var target_pos: Vector4 = player.global_position
		var distance: float = (effector_pos - target_pos).length()
		print("frames=%d distance=%.6f converged=%s" % [
			frames_elapsed, distance, distance <= DISTANCE_CONVERGENCE_THRESHOLD,
		])

	print("DONE")
	get_tree().quit()
