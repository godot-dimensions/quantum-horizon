extends Node
## TEMPORARY - isolated QEF-solve profiling, deliberately NOT using
## _benchmark_voxel_world_profile_runner.gd (that file is being actively
## edited elsewhere in this same repo for unrelated FastNoise2 work, and
## sharing it here would collide with that in-flight edit).
##
## Builds a real VoxelWorld4D at a few sizes using the ALREADY-INTEGRATED
## native OpenSimplexNoise binding (Math4D.noise_4d - the real production
## density path, see terrain4d_voxel_showcase.gd's own _density()),
## regenerates every dirty brick synchronously, then reads
## Terrain4DProfile's "generate_phase2_qef" (the whole QEF phase: corner
## gather, gradient, crossing-point collection, ATA/ATB accumulation, AND
## the solve) against "qef_solve_only" (just dual_contour_4d.gd's
## _solve_4x4() body, isolated via its own SPIKE INSTRUMENTATION wrapper)
## to answer "how much of the QEF phase is the solve itself vs. everything
## around it."

const SWEEP_HORIZONTAL_RADII := [3, 5, 7]
const VERTICAL_RADIUS := 1
const W_RADIUS := 1
const STEP_SIZE := 0.75
const NOISE_SEED := 1
const NOISE_FREQUENCY := 0.06
const NOISE_AMPLITUDE := 6.0
const NOISE_PERSISTENCE := 0.55
const GROUND_LEVEL := 0.0

func _ready() -> void:
	_run()

func _density(p: Vector4) -> float:
	var total := 0.0
	var amplitude := 1.0
	var frequency := NOISE_FREQUENCY
	var max_value := 0.0
	for i in range(3):
		total += Math4D.noise_4d(NOISE_SEED, p.x * frequency, 0.0, p.z * frequency, p.w * frequency) * amplitude
		max_value += amplitude
		amplitude *= NOISE_PERSISTENCE
		frequency *= 2.0
	var height := GROUND_LEVEL + NOISE_AMPLITUDE * (total / max_value)
	return p.y - height

func _run() -> void:
	for h in SWEEP_HORIZONTAL_RADII:
		_run_one_size(h)
	print("DONE")
	get_tree().quit()

func _run_one_size(h: int) -> void:
	Terrain4DProfile.reset()
	var step := Vector4(STEP_SIZE, STEP_SIZE, STEP_SIZE, STEP_SIZE)
	var world := VoxelWorld4D.new(Vector4.ZERO, step, Callable(self, "_density"))
	for bx in range(-h, h + 1):
		for by in range(-VERTICAL_RADIUS, VERTICAL_RADIUS + 1):
			for bz in range(-h, h + 1):
				for bw in range(-W_RADIUS, W_RADIUS + 1):
					world.get_or_create_brick(Vector4i(bx, by, bz, bw))
	world.regenerate_dirty_bricks()

	var profile: Dictionary = Terrain4DProfile.snapshot()
	var qef_total: Dictionary = profile.get("generate_phase2_qef", {"usec": 0, "calls": 0})
	var solve_only: Dictionary = profile.get("qef_solve_only", {"usec": 0, "calls": 0})
	var qef_usec: int = qef_total.usec
	var qef_calls: int = qef_total.calls  # one call per BRICK (the whole phase), not per solve
	var solve_usec: int = solve_only.usec
	var solve_calls: int = solve_only.calls  # one call per ACTIVE CELL (one solve each)
	var surrounding_usec: int = qef_usec - solve_usec

	var dense := 0
	for brick in world.get_all_bricks():
		if not brick.is_collapsed:
			dense += 1

	print("--- h=%d (dense_bricks=%d) ---" % [h, dense])
	print("generate_phase2_qef: total_usec=%d calls(bricks)=%d avg_usec_per_brick=%.2f" % [
		qef_usec, qef_calls, (float(qef_usec) / float(qef_calls)) if qef_calls > 0 else 0.0
	])
	print("qef_solve_only: total_usec=%d calls(active_cells)=%d avg_usec_per_solve=%.3f" % [
		solve_usec, solve_calls, (float(solve_usec) / float(solve_calls)) if solve_calls > 0 else 0.0
	])
	print("solve_share_of_qef_phase_pct=%.1f%% (surrounding_work_usec=%d = corner-gather/gradient/crossing-points/ATA-ATB, avg_active_cells_per_brick=%.1f)" % [
		(float(solve_usec) / float(qef_usec) * 100.0) if qef_usec > 0 else 0.0,
		surrounding_usec,
		(float(solve_calls) / float(qef_calls)) if qef_calls > 0 else 0.0,
	])
