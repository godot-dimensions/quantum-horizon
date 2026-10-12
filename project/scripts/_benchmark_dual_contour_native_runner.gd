extends Node
## TEMPORARY - benchmarks SingleVertexDualContour4D.generate_native() (native QEF-
## solve/gradient/tet-assembly, see dual_contour_native_4d.h/.cpp) against
## generate() (GDScript), ONLY after _verify_dual_contour_native_runner.gd
## confirmed identical output on 3 cases (including catching and fixing a
## real bounds_min bug - see that script's own history). Reports the
## isolated per-brick/per-active-cell delta first (the number to trust
## most, per this session's own established standard), then a macro
## h=3 sweep matching the shape of every other density-source comparison
## this session, over the SAME 441 real brick coordinates with the
## already-integrated native OpenSimplexNoise heightfield (no live-GDScript-
## noise confound - phase 1 is identical between the two paths being
## compared here, so no calibration is needed the way cross-noise-source
## comparisons needed it).
##
## Progress-pings every few seconds, matching the pattern that replaced
## the ambiguous multi-hour-silent-FastNoise2-run - this is expected to be
## fast (seconds), but the ping costs nothing and removes any doubt.

const H := 3
const V := 1
const W := 1
const STEP_SIZE := 0.75
const SEED := 1
const NOISE_FREQUENCY := 0.03 # already-calibrated native OpenSimplexNoise frequency from earlier this session
const NOISE_AMPLITUDE := 6.0
const NOISE_PERSISTENCE := 0.55
const GROUND_LEVEL := 0.0
const NOMINAL_POINTS_PER_AXIS := 4
const APRON_CELLS := 1
const ACTUAL_POINTS_PER_AXIS := NOMINAL_POINTS_PER_AXIS + 2 * APRON_CELLS

const PING_INTERVAL_USEC := 5_000_000

var _start_usec := 0
var _last_ping_usec := 0

func _ready() -> void:
	_start_usec = Time.get_ticks_usec()
	_last_ping_usec = _start_usec
	_run()

func _ping(label: String) -> void:
	var now := Time.get_ticks_usec()
	if now - _last_ping_usec >= PING_INTERVAL_USEC:
		print("  ... still alive: %s (%.1fs elapsed total)" % [label, (now - _start_usec) / 1000000.0])
		_last_ping_usec = now

func _density(p: Vector4) -> float:
	var total := 0.0
	var amplitude := 1.0
	var frequency := NOISE_FREQUENCY
	var max_value := 0.0
	for i in range(3):
		total += Math4D.noise_4d(SEED, p.x * frequency, 0.0, p.z * frequency, p.w * frequency) * amplitude
		max_value += amplitude
		amplitude *= NOISE_PERSISTENCE
		frequency *= 2.0
	var height := GROUND_LEVEL + NOISE_AMPLITUDE * (total / max_value)
	return p.y - height

func _brick_actual_bounds(coord: Vector4i, step: Vector4) -> Dictionary:
	var cells_per_axis := NOMINAL_POINTS_PER_AXIS - 1
	var nominal_min := Vector4(
		coord.x * cells_per_axis * step.x, coord.y * cells_per_axis * step.y,
		coord.z * cells_per_axis * step.z, coord.w * cells_per_axis * step.w
	)
	var apron_margin := Vector4(step.x, step.y, step.z, step.w) * float(APRON_CELLS)
	var actual_min := nominal_min - apron_margin
	var actual_max := nominal_min + Vector4(cells_per_axis * step.x, cells_per_axis * step.y, cells_per_axis * step.z, cells_per_axis * step.w) + apron_margin
	return { "min": actual_min, "max": actual_max }

func _run() -> void:
	var step := Vector4(STEP_SIZE, STEP_SIZE, STEP_SIZE, STEP_SIZE)

	# --- Part 1: isolated per-brick/per-active-cell delta over 441 real
	# brick coordinates (h=3), same density source/step both paths - no
	# shape confound, no calibration needed. ---
	Terrain4DProfile.reset()
	var total_bricks := 0
	var total_active_cells := 0
	var n := 0
	var sweep_total := (2 * H + 1) * (2 * H + 1) * (2 * V + 1) * (2 * W + 1)
	for bx in range(-H, H + 1):
		for by in range(-V, V + 1):
			for bz in range(-H, H + 1):
				for bw in range(-W, W + 1):
					var coord := Vector4i(bx, by, bz, bw)
					var bounds: Dictionary = _brick_actual_bounds(coord, step)
					var gd_result: Dictionary = SingleVertexDualContour4D.generate(bounds.min, bounds.max, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, Callable(self, "_density"), 0.15, step)
					var native_result: Dictionary = SingleVertexDualContour4D.generate_native(bounds.min, bounds.max, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, Callable(self, "_density"), 0.15, step)
					total_bricks += 1
					total_active_cells += int(gd_result.active_cell_count)
					n += 1
					_ping("isolated delta %d/%d bricks" % [n, sweep_total])
	var profile: Dictionary = Terrain4DProfile.snapshot()
	var gd_qef: Dictionary = profile.get("generate_phase2_qef", { "usec": 0, "calls": 0 })
	var gd_tet: Dictionary = profile.get("generate_phase3_tet", { "usec": 0, "calls": 0 })
	var native_combined: Dictionary = profile.get("generate_phase23_native", { "usec": 0, "calls": 0 })
	var gd_combined_usec: int = gd_qef.usec + gd_tet.usec
	var native_usec: int = native_combined.usec

	print("=== PART 1: isolated per-brick/per-active-cell delta (h=3, %d bricks, %d total active cells) ===" % [total_bricks, total_active_cells])
	print("GDScript  (phase2_qef+phase3_tet): total_usec=%d avg_usec_per_brick=%.2f avg_usec_per_active_cell=%.3f" % [
		gd_combined_usec, float(gd_combined_usec) / float(total_bricks), float(gd_combined_usec) / float(total_active_cells)
	])
	print("Native    (phase23_native):        total_usec=%d avg_usec_per_brick=%.2f avg_usec_per_active_cell=%.3f" % [
		native_usec, float(native_usec) / float(total_bricks), float(native_usec) / float(total_active_cells)
	])
	var speedup: float = float(gd_combined_usec) / float(native_usec) if native_usec > 0 else 0.0
	var reduction_pct: float = (1.0 - float(native_usec) / float(gd_combined_usec)) * 100.0 if gd_combined_usec > 0 else 0.0
	print("speedup=%.2fx (%.1f%% reduction)" % [speedup, reduction_pct])

	# --- Part 2: macro test - full generate() vs generate_native() wall
	# time over the same 441-brick sweep, matching the shape of every
	# other density-source macro comparison this session (population/regen-
	# style total wall time), but WITHOUT VoxelWorld4D's collapse-check
	# gate (this measures generate()/generate_native() themselves, not the
	# collapse-check-skips-inactive-bricks optimization layered on top in
	# production) - already captured above via the same loop's wall time,
	# reported here as a simple total-wall-clock cross-check independent
	# of the Terrain4DProfile per-stage accounting.
	_ping("part 1 complete, starting part 2 (dedicated wall-clock cross-check)")
	var t0 := Time.get_ticks_usec()
	n = 0
	for bx in range(-H, H + 1):
		for by in range(-V, V + 1):
			for bz in range(-H, H + 1):
				for bw in range(-W, W + 1):
					var coord := Vector4i(bx, by, bz, bw)
					var bounds: Dictionary = _brick_actual_bounds(coord, step)
					SingleVertexDualContour4D.generate(bounds.min, bounds.max, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, Callable(self, "_density"), 0.15, step)
					n += 1
					_ping("macro gdscript %d/%d bricks" % [n, sweep_total])
	var t_gdscript_total := Time.get_ticks_usec() - t0

	t0 = Time.get_ticks_usec()
	n = 0
	for bx in range(-H, H + 1):
		for by in range(-V, V + 1):
			for bz in range(-H, H + 1):
				for bw in range(-W, W + 1):
					var coord := Vector4i(bx, by, bz, bw)
					var bounds: Dictionary = _brick_actual_bounds(coord, step)
					SingleVertexDualContour4D.generate_native(bounds.min, bounds.max, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, ACTUAL_POINTS_PER_AXIS, Callable(self, "_density"), 0.15, step)
					n += 1
					_ping("macro native %d/%d bricks" % [n, sweep_total])
	var t_native_total := Time.get_ticks_usec() - t0

	print("=== PART 2: macro full-call wall time (h=3, %d bricks, includes phase1 density sampling in both) ===" % [total_bricks])
	print("generate() total_usec=%d (%.2f ms)" % [t_gdscript_total, t_gdscript_total / 1000.0])
	print("generate_native() total_usec=%d (%.2f ms)" % [t_native_total, t_native_total / 1000.0])
	var macro_reduction: float = (1.0 - float(t_native_total) / float(t_gdscript_total)) * 100.0 if t_gdscript_total > 0 else 0.0
	print("macro_speedup=%.2fx (%.1f%% reduction, includes phase1 which is unchanged/identical - dilutes the phase2/3-only speedup above)" % [
		float(t_gdscript_total) / float(t_native_total) if t_native_total > 0 else 0.0, macro_reduction
	])

	print("DONE")
	get_tree().quit()
