extends Node
## TEMPORARY - Stage 3 verification: hop/canter_right/canter_left co-
## occurrence data (same methodology as _verify_limb_prototype_gait_runner.gd
## used for walk/trot: tally which OTHER legs are airborne whenever a given
## leg releases, into a 4x4 matrix - the actual data-driven "does this
## preset produce the intended synchronization pattern" check, not visual
## impression), plus a halt-state behavior check (Body freezes, a
## mid-swing leg finishes its cycle and plants rather than freezing
## mid-air, no NEW cycle starts while halted, cycling resumes on release).
##
## Leg order: 0=FL, 1=FR, 2=BL, 3=BR.
##
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.

const PRESET_RUN_SECONDS := 15.0
const LEG_NAMES := ["FL", "FR", "BL", "BR"]


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("Body")
	var gait: Node = flat_plane.get_node("GaitController")
	var foot_targets: Array = [
		flat_plane.get_node("FootTargetFL"),
		flat_plane.get_node("FootTargetFR"),
		flat_plane.get_node("FootTargetBL"),
		flat_plane.get_node("FootTargetBR"),
	]

	for preset_name in ["hop", "canter_right", "canter_left"]:
		await _run_preset_cooccurrence(gait, foot_targets, preset_name)

	await _run_halt_check(gait, body, foot_targets)

	print("DONE")
	get_tree().quit()


func _run_preset_cooccurrence(gait: Node, foot_targets: Array, preset_name: String) -> void:
	gait.apply_preset(preset_name)
	print("=== %s: preset_progress ===" % preset_name)
	print("  duty_factor=%.3f phase_offsets=%s reference_period_sec=%.3f" % [gait.duty_factor, gait.phase_offsets, gait.reference_period_sec])

	var cycle_counts: Array = [0, 0, 0, 0]
	var cooccurrence: Array = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
	var last_states: Array = []
	for ft in foot_targets:
		last_states.append(ft.state)

	var total_frames: int = int(PRESET_RUN_SECONDS * 60.0)
	for frame in range(total_frames):
		await get_tree().physics_frame
		for i in range(4):
			var ft = foot_targets[i]
			if last_states[i] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING:
				cycle_counts[i] += 1
				for j in range(4):
					if j == i:
						continue
					if foot_targets[j].state != foot_targets[j].FootState.PLANTED:
						cooccurrence[i][j] += 1
			last_states[i] = ft.state

	print("  cycle_counts[FL,FR,BL,BR]=%s (expect several per leg, nonzero)" % [cycle_counts])
	print("  cooccurrence matrix (row=leg that just released, col=other leg airborne at that moment):")
	for i in range(4):
		print("     %s: %s" % [LEG_NAMES[i], cooccurrence[i]])


func _run_halt_check(gait: Node, body: Node4D, foot_targets: Array) -> void:
	gait.apply_preset("walk")
	print("=== halt check (walk preset) ===")

	# Wait until some leg is actually mid-swing before engaging halt, so
	# the "finishes its current cycle" behavior is genuinely exercised,
	# not trivially true because nothing was swinging when halt engaged.
	var swinging_leg: int = -1
	for frame in range(3600):
		await get_tree().physics_frame
		for i in range(4):
			if foot_targets[i].state != foot_targets[i].FootState.PLANTED:
				swinging_leg = i
				break
		if swinging_leg != -1:
			break

	if swinging_leg == -1:
		print("  Never caught a leg mid-swing within 60s - aborting halt check.")
		return

	print("  engaging halt with leg %s mid-swing (state=%d)" % [LEG_NAMES[swinging_leg], foot_targets[swinging_leg].state])
	body.halted = true
	var body_pos_at_halt: Vector4 = body.position
	var phase_at_halt: float = gait.phase_progress

	var swinging_leg_planted: bool = false
	var body_drift: float = 0.0
	var phase_drift: float = 0.0
	var any_new_cycle_started: bool = false
	var last_states: Array = []
	for ft in foot_targets:
		last_states.append(ft.state)

	const HALT_HOLD_FRAMES := 300 # 5s - comfortably longer than lift+swing duration (0.5s) and a full gait period.
	for frame in range(HALT_HOLD_FRAMES):
		await get_tree().physics_frame
		body_drift = maxf(body_drift, (body.position - body_pos_at_halt).length())
		phase_drift = maxf(phase_drift, absf(gait.phase_progress - phase_at_halt))
		if foot_targets[swinging_leg].state == foot_targets[swinging_leg].FootState.PLANTED:
			swinging_leg_planted = true
		for i in range(4):
			var ft = foot_targets[i]
			if last_states[i] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING:
				any_new_cycle_started = true
			last_states[i] = ft.state

	print("  while halted (%d frames): body_position_drift=%.6f (expect 0.0) phase_progress_drift=%.6f (expect 0.0)" % [HALT_HOLD_FRAMES, body_drift, phase_drift])
	print("  mid-swing leg (%s) reached PLANTED while halted: %s (expect true - finishes its cycle, doesn't freeze mid-air)" % [LEG_NAMES[swinging_leg], swinging_leg_planted])
	print("  any_new_cycle_started_while_halted=%s (expect false)" % any_new_cycle_started)

	body.halted = false
	print("  released halt - running 300 more frames to confirm cycling resumes")
	var cycle_counts_after_release: Array = [0, 0, 0, 0]
	for frame in range(300):
		await get_tree().physics_frame
		for i in range(4):
			var ft = foot_targets[i]
			if last_states[i] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING:
				cycle_counts_after_release[i] += 1
			last_states[i] = ft.state
	print("  cycle_counts_after_release[FL,FR,BL,BR]=%s (expect at least one nonzero - cycling resumed)" % [cycle_counts_after_release])
