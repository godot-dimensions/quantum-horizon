extends Node
## TEMPORARY - measures how many physics ticks the 5-joint chain actually
## takes to cross the 0.05 convergence threshold for the first time, for the
## representative "diag" pose from _verify_ik_chain_5joint_runner.gd
## (moderate reach, 59.5% of max_reach - not a near-full-extension edge
## case). The earlier report only showed the plateaued residual at frame
## 2400; this answers the real follow-up question of how fast it gets there.
## Not part of the shipped scene - wired in as a temporary autoload with
## single_joint_test.tscn set as the main scene.

const DISTANCE_CONVERGENCE_THRESHOLD := 0.05
const MAX_FRAMES := 600


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var ik_chain: Node = flat_plane.get_node("IKChain")

	player.global_position = Vector4(3, 0.5, 3, 0)
	player.global_basis = Projection()
	for joint in ik_chain.joints:
		joint.global_basis = Projection()

	print("1.pose=diag player_pos=%s" % player.global_position)

	var crossed_frame: int = -1
	for frame in range(MAX_FRAMES):
		await get_tree().physics_frame
		var effector_pos: Vector4 = ik_chain._end_effector_position()
		var distance: float = (effector_pos - player.global_position).length()
		var tick: int = frame + 1
		var is_converged: bool = distance <= DISTANCE_CONVERGENCE_THRESHOLD
		# Log every tick through the first two seconds (where crossing is
		# expected to happen), then sparsely after, so the log stays readable
		# without hiding the actual crossing moment.
		if tick <= 120 or tick % 20 == 0 or (crossed_frame == -1 and is_converged):
			print("tick=%d t=%.4fs distance=%.5f" % [tick, tick / 60.0, distance])
		if crossed_frame == -1 and is_converged:
			crossed_frame = tick
			print(">>> CROSSED 0.05 threshold at tick=%d (t=%.4fs)" % [crossed_frame, crossed_frame / 60.0])

	if crossed_frame == -1:
		print("2.NEVER CROSSED within %d ticks" % MAX_FRAMES)
	else:
		print("2.crossed_tick=%d crossed_time_sec=%.4f" % [crossed_frame, crossed_frame / 60.0])

	print("DONE")
	get_tree().quit()
