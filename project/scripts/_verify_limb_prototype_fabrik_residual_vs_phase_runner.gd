extends Node
## TEMPORARY - logs FL's residual against swing-phase PROGRESS (not
## wall-clock frame number) across several full gait cycles, to pin down
## whether the ~0.285-0.289 residual found by the full gait-cycle trace
## lines up with a consistent point in the cycle (e.g. peak lift height,
## the lift/swing transition, or lift-off/landing) rather than being
## scattered noise.
##
## combined_phase_t is continuous across the whole swing event:
## 0.0 = lift-off (Planted->Lifting), 1.0 = the Lifting->Swinging
## transition, 2.0 = landing (Swinging->Planted). PLANTED frames are
## excluded (residual there is already known to be tiny - see
## min_planted_effector_y in the prior gait-cycle trace).
##
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.

const TRACE_SECONDS := 20.0
const BUCKET_COUNT := 40 # phase_t in [0,2], bucket width 0.05.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var ft = flat_plane.get_node("FootTargetFL")
	var chain = flat_plane.get_node("Body/LimbAnchorFL/IKChain")

	var bucket_max_residual: Array = []
	var bucket_count: Array = []
	for i in range(BUCKET_COUNT + 1):
		bucket_max_residual.append(0.0)
		bucket_count.append(0)

	# Per-swing-event peak (one entry per LIFTING+SWINGING run), so we can
	# see directly whether the peak lands at the SAME phase_t every cycle.
	var per_cycle_peak_residual: Array = []
	var per_cycle_peak_phase_t: Array = []
	var current_cycle_peak_residual: float = -1.0
	var current_cycle_peak_phase_t: float = -1.0
	var in_swing_event: bool = false

	var total_frames: int = int(TRACE_SECONDS * 60.0)
	for frame in range(total_frames):
		await get_tree().physics_frame
		var effector: Vector4 = chain._end_effector_position()
		var residual: float = (ft.global_position - effector).length()

		var phase_t: float = -1.0
		if ft.state == ft.FootState.LIFTING:
			phase_t = clampf(ft.state_elapsed_sec / ft.lift_duration_sec, 0.0, 1.0)
		elif ft.state == ft.FootState.SWINGING:
			phase_t = 1.0 + clampf(ft.state_elapsed_sec / ft.swing_duration_sec, 0.0, 1.0)

		if phase_t >= 0.0:
			if not in_swing_event:
				in_swing_event = true
				current_cycle_peak_residual = -1.0
				current_cycle_peak_phase_t = -1.0
			if residual > current_cycle_peak_residual:
				current_cycle_peak_residual = residual
				current_cycle_peak_phase_t = phase_t

			var bucket: int = clampi(int(round(phase_t / 2.0 * BUCKET_COUNT)), 0, BUCKET_COUNT)
			bucket_count[bucket] += 1
			bucket_max_residual[bucket] = maxf(bucket_max_residual[bucket], residual)
		else:
			if in_swing_event:
				in_swing_event = false
				per_cycle_peak_residual.append(current_cycle_peak_residual)
				per_cycle_peak_phase_t.append(current_cycle_peak_phase_t)

	if in_swing_event:
		per_cycle_peak_residual.append(current_cycle_peak_residual)
		per_cycle_peak_phase_t.append(current_cycle_peak_phase_t)

	print("=== per-cycle peak residual and the phase_t it occurred at ===")
	for i in range(per_cycle_peak_residual.size()):
		print("  cycle %d: peak_residual=%.5f at phase_t=%.3f" % [i, per_cycle_peak_residual[i], per_cycle_peak_phase_t[i]])

	print("=== residual-vs-phase_t histogram (bucket width 0.05, phase_t 0=lift-off 1=lift/swing-transition 2=landing) ===")
	for i in range(BUCKET_COUNT + 1):
		if bucket_count[i] > 0:
			print("  phase_t=%.2f  max_residual=%.5f  frame_count=%d" % [float(i) / BUCKET_COUNT * 2.0, bucket_max_residual[i], bucket_count[i]])

	print("DONE")
	get_tree().quit()
