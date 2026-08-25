extends Node
## TEMPORARY - Step 3 re-verification after adding stance_duration_sec (the
## first real gait parameter this prototype exposes - see
## limb_prototype_foot_target.gd's own header for the full rationale).
## Pure numeric check, headless-safe (no screenshots - the visual lift arc
## was already confirmed in the prior windowed pass; a 30-cycle run at
## stance_duration_sec=2.0s takes ~75-90s of SIMULATED time, which in a
## windowed/rendered run turned out to run several times slower than real
## time on this machine and got killed mid-run by the shell timeout,
## crashing on a freed-node access during teardown - confirmed directly,
## not guessed, from that run's own error output. Headless has no such
## real-time throttling, so this reruns the same check that way instead of
## fighting the windowed run's pacing.
##
## 1. locked_position stays EXACTLY fixed every frame while Planted.
## 2. Right as each stance period ends (state_elapsed reaches
##    stance_duration_sec, the moment Planted->Lifting becomes eligible
##    again), the LIMB's actual effector distance to locked_position is
##    checked against 0.05 - the same threshold used throughout every
##    earlier IK convergence test in this project.

const TARGET_CYCLES := 30
const MAX_FRAMES := 12000 # 200s of simulated time - generous ceiling, not expected to be needed.
const CONVERGENCE_THRESHOLD := 0.05


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
	var foot_target: Node4D = flat_plane.get_node("FootTarget")
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchor/IKChain")

	print("1.nodes_resolve: body=%s foot_target=%s ik_chain=%s" % [
		body != null, foot_target != null, ik_chain != null,
	])
	print("2.drift_threshold=%.3f lift_duration=%.3fs swing_duration=%.3fs stance_duration=%.3fs" % [
		foot_target.DRIFT_THRESHOLD, foot_target.lift_duration_sec, foot_target.swing_duration_sec, foot_target.stance_duration_sec,
	])

	_reset_chain(ik_chain)

	var planted_violations: int = 0
	var last_state: int = foot_target.state
	var last_locked_position: Vector4 = foot_target.locked_position
	var was_planted_last_frame: bool = true

	var cycles_checked: int = 0
	var cycles_converged: int = 0
	var convergence_distances: Array = []
	var stance_check_frames_left: int = -1
	var stance_check_target: Vector4 = Vector4.ZERO
	var stance_check_cycle: int = 0
	var stance_frames: int = int(foot_target.stance_duration_sec * 60.0)

	var frame: int = 0
	while frame < MAX_FRAMES and cycles_checked < TARGET_CYCLES:
		await get_tree().physics_frame

		if foot_target.state == foot_target.FootState.PLANTED:
			if was_planted_last_frame and foot_target.global_position != last_locked_position:
				planted_violations += 1
				print("VIOLATION at frame=%d: planted position drifted from %s to %s" % [frame, last_locked_position, foot_target.global_position])
			last_locked_position = foot_target.locked_position
			was_planted_last_frame = true
		else:
			was_planted_last_frame = false

		if last_state == foot_target.FootState.SWINGING and foot_target.state == foot_target.FootState.PLANTED:
			cycles_checked += 1
			stance_check_frames_left = stance_frames
			stance_check_target = foot_target.locked_position
			stance_check_cycle = cycles_checked
			print("t=%.3fs cycle=%d completed -> locked at %s" % [frame / 60.0, cycles_checked, foot_target.locked_position])

		last_state = foot_target.state

		if stance_check_frames_left > 0:
			stance_check_frames_left -= 1
			if stance_check_frames_left == 0:
				var effector_pos: Vector4 = ik_chain._end_effector_position()
				var distance: float = (effector_pos - stance_check_target).length()
				var converged: bool = distance <= CONVERGENCE_THRESHOLD
				convergence_distances.append(distance)
				if converged:
					cycles_converged += 1
				print("cycle=%d effector_distance_at_stance_end=%.5f converged=%s" % [stance_check_cycle, distance, converged])

		frame += 1

	var max_distance: float = 0.0
	var sum_distance: float = 0.0
	for d in convergence_distances:
		max_distance = maxf(max_distance, d)
		sum_distance += d
	var avg_distance: float = sum_distance / convergence_distances.size() if convergence_distances.size() > 0 else -1.0

	print("3.planted_violations=%d (expect 0)" % planted_violations)
	print("4.cycles_checked=%d cycles_converged=%d avg_distance=%.5f max_distance=%.5f" % [cycles_checked, cycles_converged, avg_distance, max_distance])
	print("DONE")
	get_tree().quit()
