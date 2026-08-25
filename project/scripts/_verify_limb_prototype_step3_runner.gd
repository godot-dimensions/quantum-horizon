extends Node
## TEMPORARY - Step 3 re-verification after adding stance_duration_sec (the
## first real gait parameter this prototype exposes - see
## limb_prototype_foot_target.gd's own header). Same two numeric checks as
## the first pass, plus this time the effector-convergence check fires
## right when a foot becomes ELIGIBLE to leave Planted again (state_elapsed
## reaches stance_duration_sec), i.e. right before a new cycle can begin -
## not an arbitrary fixed delay - so "reaches sub-0.05 before the next cycle
## begins" is checked at the actual moment that matters, not a guessed one.
##
## 1. locked_position stays EXACTLY fixed every frame while Planted.
## 2. Right as each stance period ends, the LIMB's actual effector distance
##    to locked_position is checked against the 0.05 threshold used
##    throughout every earlier IK convergence test in this project (not a
##    new number invented for this check).
##
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_test.tscn set as the main scene.

const TARGET_CYCLES := 30
const MAX_RUN_SECONDS := 120.0 # Safety cap - stance_duration_sec=2.0 + lift(0.15) + swing(0.35) means ~2.5s/cycle minimum, so 30 cycles needs up to ~75-90s depending on how long drift takes to re-trip after each stance completes.
const CONVERGENCE_THRESHOLD := 0.05 # Same threshold used throughout every earlier static IK convergence test in this project.


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
	var body: Node4D = flat_plane.get_node("Body")
	var foot_target: Node4D = flat_plane.get_node("FootTarget")
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchor/IKChain")

	print("1.nodes_resolve: player=%s body=%s foot_target=%s ik_chain=%s" % [
		player != null, body != null, foot_target != null, ik_chain != null,
	])
	print("2.drift_threshold=%.3f lift_duration=%.3fs swing_duration=%.3fs stance_duration=%.3fs" % [
		foot_target.DRIFT_THRESHOLD, foot_target.lift_duration_sec, foot_target.swing_duration_sec, foot_target.stance_duration_sec,
	])

	_reset_chain(ik_chain)

	player.global_basis = Projection()
	player.global_position = Vector4(0, 6, -8, 0)
	player.global_basis = Basis4D.looking_at(body.position - player.global_position)

	var planted_violations: int = 0
	var last_state: int = foot_target.state
	var last_locked_position: Vector4 = foot_target.locked_position
	var was_planted_last_frame: bool = true

	var cycles_checked: int = 0
	var cycles_converged: int = 0
	var stance_check_frames_left: int = -1
	var stance_check_target: Vector4 = Vector4.ZERO
	var stance_check_cycle: int = 0
	var stance_frames: int = int(foot_target.stance_duration_sec * 60.0)

	var screenshot_cycle_done: bool = false
	var screenshot_frames_remaining: int = 0
	var shot_index: int = 0

	var max_frames: int = int(MAX_RUN_SECONDS * 60.0)
	var frame: int = 0
	while frame < max_frames and cycles_checked < TARGET_CYCLES:
		await get_tree().physics_frame

		# --- Check 1: PLANTED means EXACTLY fixed. ---
		if foot_target.state == foot_target.FootState.PLANTED:
			if was_planted_last_frame and foot_target.global_position != last_locked_position:
				planted_violations += 1
				print("VIOLATION at frame=%d: planted position drifted from %s to %s" % [frame, last_locked_position, foot_target.global_position])
			last_locked_position = foot_target.locked_position
			was_planted_last_frame = true
		else:
			was_planted_last_frame = false

		# --- Detect a completed cycle: transition INTO Planted from Swinging. Start the stance-completion countdown from here. ---
		if last_state == foot_target.FootState.SWINGING and foot_target.state == foot_target.FootState.PLANTED:
			cycles_checked += 1
			stance_check_frames_left = stance_frames
			stance_check_target = foot_target.locked_position
			stance_check_cycle = cycles_checked
			print("t=%.3fs cycle=%d completed -> locked at %s" % [frame / 60.0, cycles_checked, foot_target.locked_position])

		# --- Detect the START of a step (Planted -> Lifting) to grab a screenshot sequence. ---
		if not screenshot_cycle_done and last_state == foot_target.FootState.PLANTED and foot_target.state == foot_target.FootState.LIFTING:
			screenshot_frames_remaining = 36
			print("t=%.3fs step begins (Planted -> Lifting)" % (frame / 60.0))
			player.global_position = body.position + Vector4(0, 3, -6, 0)
			player.global_basis = Basis4D.looking_at(body.position - player.global_position)

		if screenshot_frames_remaining > 0:
			if screenshot_frames_remaining % 4 == 0:
				await _screenshot("limb_prototype_step3_seq%02d.png" % shot_index)
				shot_index += 1
			screenshot_frames_remaining -= 1
			if screenshot_frames_remaining == 0:
				screenshot_cycle_done = true

		last_state = foot_target.state

		# --- Resolve the stance-completion convergence check. ---
		if stance_check_frames_left > 0:
			stance_check_frames_left -= 1
			if stance_check_frames_left == 0:
				var effector_pos: Vector4 = ik_chain._end_effector_position()
				var distance: float = (effector_pos - stance_check_target).length()
				var converged: bool = distance <= CONVERGENCE_THRESHOLD
				if converged:
					cycles_converged += 1
				print("cycle=%d effector_distance_at_stance_end=%.5f converged=%s" % [stance_check_cycle, distance, converged])

		frame += 1

	print("3.planted_violations=%d (expect 0)" % planted_violations)
	print("4.cycles_checked=%d cycles_converged=%d" % [cycles_checked, cycles_converged])
	print("DONE")
	get_tree().quit()
