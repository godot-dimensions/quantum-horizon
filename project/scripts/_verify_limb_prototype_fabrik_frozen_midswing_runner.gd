extends Node
## TEMPORARY - picks a representative mid-swing instant for FL, then
## FREEZES the target there (stops stepping physics frames entirely, so
## neither the FootTarget's own kinematic curve nor the Body's wander
## advance any further) and calls solve_fabrik() repeatedly, exactly as
## many times as a PLANTED (static) target would get across many real
## frames, to see whether the existing 10-iteration-per-call solve
## converges to near-zero given that same treatment.
##
## If it converges once frozen: the ~0.25 mid-swing plateau found by the
## residual-vs-phase trace is a genuine "target moves faster than
## convergence across frames" issue - raising fabrik_max_iterations is a
## real, direct lever.
## If it does NOT converge even frozen: the issue isn't iteration budget
## at all - this exact geometry is genuinely hard for the chain to reach
## well, pointing at the swing curve's shape/height rather than solver
## tuning.
##
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.

const TARGET_PHASE_T := 0.5 # Mid-swing (SWINGING state_elapsed_sec / swing_duration_sec).
const FROZEN_SOLVE_CALLS := 100
const MAX_WAIT_FRAMES := 3600


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var ft = flat_plane.get_node("FootTargetFL")
	var chain = flat_plane.get_node("Body/LimbAnchorFL/IKChain")

	var reached: bool = false
	for frame in range(MAX_WAIT_FRAMES):
		await get_tree().physics_frame
		if ft.state == ft.FootState.SWINGING:
			var t: float = ft.state_elapsed_sec / ft.swing_duration_sec
			if t >= TARGET_PHASE_T:
				reached = true
				break

	if not reached:
		print("Never reached mid-swing within %d frames - aborting." % MAX_WAIT_FRAMES)
		print("DONE")
		get_tree().quit()
		return

	# From here on, NO MORE physics_frame steps - the target, anchor, and
	# every other node in the scene are genuinely frozen. Only
	# solve_fabrik() itself is called, directly, repeatedly.
	var anchor_pos: Vector4 = chain.joints[0].global_position
	var frozen_target_pos: Vector4 = ft.global_position
	print("=== frozen mid-swing probe ===")
	print("  frozen at state_elapsed_sec=%.4f (phase_t=%.4f of swing_duration_sec=%.4f)" % [ft.state_elapsed_sec, ft.state_elapsed_sec / ft.swing_duration_sec, ft.swing_duration_sec])
	print("  anchor=%s target=%s distance=%.4f" % [anchor_pos, frozen_target_pos, (frozen_target_pos - anchor_pos).length()])

	var initial_effector: Vector4 = chain._end_effector_position()
	var initial_residual: float = (frozen_target_pos - initial_effector).length()
	print("  residual BEFORE any extra solve calls (i.e. what the live trace measured)=%.5f" % initial_residual)

	for call_num in range(FROZEN_SOLVE_CALLS):
		chain.solve_fabrik()
		if call_num < 10 or call_num % 10 == 0 or call_num == FROZEN_SOLVE_CALLS - 1:
			var effector: Vector4 = chain._end_effector_position()
			var residual: float = (frozen_target_pos - effector).length()
			print("  after %d extra solve_fabrik() calls: residual=%.5f" % [call_num + 1, residual])

	print("DONE")
	get_tree().quit()
