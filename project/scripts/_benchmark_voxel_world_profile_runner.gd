extends Node
## TEMPORARY - performance instrumentation SPIKE (measurement only, per
## explicit request). Reports raw per-stage timing/memory/histogram data.
## This script makes NO recommendations and changes NO production
## behavior - it only prints numbers. Delete this file,
## _profile_terrain4d.gd, and the "SPIKE INSTRUMENTATION" blocks in
## noise_4d.gd/voxel_world_4d.gd/dual_contour_4d.gd/
## terrain4d_chunk_pool.gd once the numbers are captured.
##
## Part A: shape-controlled noise-speed comparison. The first pass at
## this (a product-of-3-sinusoids stand-in) produced a much lower
## collapse rate (42%) than live noise (72-80%) - not a fair comparison,
## since a product of oscillating terms flips sign far more readily
## through space than live noise's smooth additive fractal sum does, so
## the earlier delta was confounded by field SHAPE, not just sampling
## SPEED. This version instead builds an additive multi-octave sine sum
## structurally matched to live noise's own fractal_noise() shape (same
## frequency/persistence ladder, sum not product), then CALIBRATES its
## frequency against a quick h=3 probe until its collapse rate lands
## near live noise's own range, before locking that frequency in and
## running the full sweep - see _calibrate_shape_matched_standin().
##
## Part B: wider-W slice histogram. Part A/the original spike both used
## w_brick_radius=1, which - as flagged in the previous report - makes
## it mechanically impossible for the slice-histogram buckets 2+ to ever
## be populated (nothing resident can be more than 1 step from the slice
## if only 3 W-coordinates were ever populated). This reruns the same
## histogram measurement with w_brick_radius=3 and 5, holding
## horizontal/vertical radius at the showcase's current default (3, 1),
## to see whether meaningful resident-brick mass actually sits far from
## the slice once the world is shaped more realistically in W.
##
## Sweep: horizontal_brick_radius in [3, 5, 7] for Part A (vertical/w
## radius fixed at 1) - h=3 is the showcase's current default (441
## bricks); h=5 and h=7 give 1089 (2.47x) and 2025 (4.59x).
##
## Part D: native Math4D.fastnoise2_4d() (FastNoise2 SuperSimplex, see
## engine/modules/4d/math/math_4d.cpp) vs live GDScript Noise4D AND the
## already-integrated native Math4D.noise_4d() (OpenSimplexNoise, Part C).
## Same fractal-octave wrapper shape and same calibrate-then-sweep
## methodology as Part C, for the same reason (a fair noise-COST
## comparison needs a matched collapse rate). This FastNoise2 vendor drop
## currently compiles only the SCALAR FastSIMD feature set (see
## noise/fastnoise2/dispatch_scalar.cpp) - not the SSE2/AVX2/AVX512 ladder
## FastNoise2 normally ships - and calls it one point at a time via
## GenSingle4D(), which FastNoise2's own docs flag as "VERY SLOW" relative
## to its batch Gen*Array/GenUniformGrid entry points; both are real,
## measured costs of fitting FastNoise2 into this codebase's existing
## per-point density-callable architecture, not artifacts of the benchmark.

const SWEEP_HORIZONTAL_RADII := [3, 5, 7]
const VERTICAL_RADIUS := 1
const W_RADIUS := 1
const WIDE_W_RADII := [3, 5]

const STEP_SIZE := 0.75
const NOISE_SEED := 1
const NOISE_FREQUENCY := 0.06
const NOISE_AMPLITUDE := 6.0
const NOISE_PERSISTENCE := 0.55
const GROUND_LEVEL := 0.0

const CALIBRATION_TARGET_COLLAPSE_PCT := 76.0  # midpoint of live noise's observed 71.5-79.8% range
const CALIBRATION_FREQUENCY_CANDIDATES := [0.03, 0.045, 0.06, 0.08, 0.1, 0.15]

var _noise: Noise4D
var _shape_matched_frequency := NOISE_FREQUENCY

func _ready() -> void:
	_noise = Noise4D.new(NOISE_SEED)
	_run()

## The real density source, matching the showcase's own _density()
## exactly (heightfield via Noise4D.fractal_noise, 3 octaves).
func _density_live_noise(p: Vector4) -> float:
	var height := GROUND_LEVEL + NOISE_AMPLITUDE * _noise.fractal_noise(Vector4(p.x, 0.0, p.z, p.w) * NOISE_FREQUENCY, 3, NOISE_PERSISTENCE, 2.0)
	return p.y - height

## HACK - SPIKE ONLY, not a real design. Additive 3-octave sine sum
## (sum of sin() terms per octave across x/z/w, weighted by the SAME
## persistence ladder live noise uses: 1, persistence, persistence^2) -
## structurally matched to fractal_noise()'s own SUM-of-octaves shape,
## unlike the original stand-in's product-of-3-sinusoids shape (which is
## why that one's collapse rate came out so much lower - see the
## paragraph on Part A above). Frequency is calibrated below rather than
## hardcoded, since collapse rate is sensitive to it and the goal here is
## a MATCHED collapse rate, not a convenient one.
func _density_shape_matched_standin(p: Vector4) -> float:
	var f := _shape_matched_frequency
	var o1 := sin(p.x * f + 0.3) + sin(p.z * f + 1.7) + sin(p.w * f + 2.9)
	var o2 := sin(p.x * f * 2.0 + 4.1) + sin(p.z * f * 2.0 + 0.6) + sin(p.w * f * 2.0 + 3.3)
	var o3 := sin(p.x * f * 4.0 + 1.1) + sin(p.z * f * 4.0 + 2.4) + sin(p.w * f * 4.0 + 5.0)
	var raw := o1 + o2 * NOISE_PERSISTENCE + o3 * NOISE_PERSISTENCE * NOISE_PERSISTENCE
	var max_value := 3.0 * (1.0 + NOISE_PERSISTENCE + NOISE_PERSISTENCE * NOISE_PERSISTENCE)
	var height := GROUND_LEVEL + NOISE_AMPLITUDE * (raw / max_value)
	return p.y - height

## PROTOTYPE - see Math4D.noise_4d() (engine/modules/4d/math/math_4d.cpp),
## a native binding of Godot 3.5's OpenSimplexNoise C source (ported,
## zero Godot-specific dependencies in the underlying math per the
## feasibility research). Same fractal-octave wrapper shape as
## Noise4D.fractal_noise (3 octaves, same persistence ladder) so this is
## an apples-to-apples structural comparison, not just a raw single-call
## comparison - frequency is calibrated the same way as the shape-matched
## sine standin, for the same reason (a fair noise-COST comparison needs
## a matched collapse rate, not just a matched formula).
const NATIVE_NOISE_SEED := 1
var _native_frequency := NOISE_FREQUENCY

func _density_native_opensimplex(p: Vector4) -> float:
	var _profile_t0 := Time.get_ticks_usec()
	var total := 0.0
	var amplitude := 1.0
	var frequency := _native_frequency
	var max_value := 0.0
	for i in range(3):
		total += Math4D.noise_4d(NATIVE_NOISE_SEED, p.x * frequency, p.y * frequency, p.z * frequency, p.w * frequency) * amplitude
		max_value += amplitude
		amplitude *= NOISE_PERSISTENCE
		frequency *= 2.0
	Terrain4DProfile.add("native_noise_fractal", Time.get_ticks_usec() - _profile_t0)
	var height := GROUND_LEVEL + NOISE_AMPLITUDE * (total / max_value)
	return p.y - height

func _calibrate_native_opensimplex() -> void:
	print("--- calibration: native OpenSimplexNoise frequency vs. collapse rate (h=3 probe, target=%.1f%%) ---" % [CALIBRATION_TARGET_COLLAPSE_PCT])
	var best_freq: float = CALIBRATION_FREQUENCY_CANDIDATES[0]
	var best_diff := INF
	for freq in CALIBRATION_FREQUENCY_CANDIDATES:
		_native_frequency = freq
		var world := VoxelWorld4D.new(Vector4.ZERO, Vector4(STEP_SIZE, STEP_SIZE, STEP_SIZE, STEP_SIZE), Callable(self, "_density_native_opensimplex"))
		var total := 0
		var collapsed := 0
		for bx in range(-3, 4):
			for by in range(-VERTICAL_RADIUS, VERTICAL_RADIUS + 1):
				for bz in range(-3, 4):
					for bw in range(-W_RADIUS, W_RADIUS + 1):
						var brick := world.get_or_create_brick(Vector4i(bx, by, bz, bw))
						total += 1
						if brick.is_collapsed:
							collapsed += 1
		var rate := float(collapsed) / float(total) * 100.0
		var diff := absf(rate - CALIBRATION_TARGET_COLLAPSE_PCT)
		print("  candidate freq=%.3f -> collapse_rate=%.1f%% (diff=%.1f)" % [freq, rate, diff])
		if diff < best_diff:
			best_diff = diff
			best_freq = freq
	_native_frequency = best_freq
	print("  chosen freq=%.3f" % [best_freq])
	Terrain4DProfile.reset()  # calibration probes pollute the profile - clear before the real sweep

## Cheap probe (population/collapse-check only, no meshing) at a fixed
## h=3 size, over each candidate frequency, picking whichever lands
## closest to CALIBRATION_TARGET_COLLAPSE_PCT. Reports every candidate's
## result so the choice is auditable, not just asserted.
func _calibrate_shape_matched_standin() -> void:
	print("--- calibration: shape-matched standin frequency vs. collapse rate (h=3 probe, target=%.1f%%) ---" % [CALIBRATION_TARGET_COLLAPSE_PCT])
	var best_freq: float = CALIBRATION_FREQUENCY_CANDIDATES[0]
	var best_diff := INF
	for freq in CALIBRATION_FREQUENCY_CANDIDATES:
		_shape_matched_frequency = freq
		var world := VoxelWorld4D.new(Vector4.ZERO, Vector4(STEP_SIZE, STEP_SIZE, STEP_SIZE, STEP_SIZE), Callable(self, "_density_shape_matched_standin"))
		var total := 0
		var collapsed := 0
		for bx in range(-3, 4):
			for by in range(-VERTICAL_RADIUS, VERTICAL_RADIUS + 1):
				for bz in range(-3, 4):
					for bw in range(-W_RADIUS, W_RADIUS + 1):
						var brick := world.get_or_create_brick(Vector4i(bx, by, bz, bw))
						total += 1
						if brick.is_collapsed:
							collapsed += 1
		var rate := float(collapsed) / float(total) * 100.0
		var diff := absf(rate - CALIBRATION_TARGET_COLLAPSE_PCT)
		print("  candidate freq=%.3f -> collapse_rate=%.1f%% (diff=%.1f)" % [freq, rate, diff])
		if diff < best_diff:
			best_diff = diff
			best_freq = freq
	_shape_matched_frequency = best_freq
	print("  chosen freq=%.3f" % [best_freq])

## PROTOTYPE - see Math4D.fastnoise2_4d() (engine/modules/4d/math/math_4d.cpp),
## a native binding of FastNoise2's SuperSimplex generator. Same
## fractal-octave wrapper shape as _density_native_opensimplex() above (3
## octaves, same persistence ladder), calibrated the same way, for the same
## apples-to-apples reason.
const FASTNOISE2_SEED := 1
var _fastnoise2_frequency := NOISE_FREQUENCY

func _density_fastnoise2(p: Vector4) -> float:
	var _profile_t0 := Time.get_ticks_usec()
	var total := 0.0
	var amplitude := 1.0
	var frequency := _fastnoise2_frequency
	var max_value := 0.0
	for i in range(3):
		total += Math4D.fastnoise2_4d(FASTNOISE2_SEED, p.x * frequency, p.y * frequency, p.z * frequency, p.w * frequency) * amplitude
		max_value += amplitude
		amplitude *= NOISE_PERSISTENCE
		frequency *= 2.0
	Terrain4DProfile.add("fastnoise2_fractal", Time.get_ticks_usec() - _profile_t0)
	var height := GROUND_LEVEL + NOISE_AMPLITUDE * (total / max_value)
	return p.y - height

func _calibrate_fastnoise2() -> void:
	print("--- calibration: FastNoise2 SuperSimplex frequency vs. collapse rate (h=3 probe, target=%.1f%%) ---" % [CALIBRATION_TARGET_COLLAPSE_PCT])
	var best_freq: float = CALIBRATION_FREQUENCY_CANDIDATES[0]
	var best_diff := INF
	for freq in CALIBRATION_FREQUENCY_CANDIDATES:
		_fastnoise2_frequency = freq
		var world := VoxelWorld4D.new(Vector4.ZERO, Vector4(STEP_SIZE, STEP_SIZE, STEP_SIZE, STEP_SIZE), Callable(self, "_density_fastnoise2"))
		var total := 0
		var collapsed := 0
		for bx in range(-3, 4):
			for by in range(-VERTICAL_RADIUS, VERTICAL_RADIUS + 1):
				for bz in range(-3, 4):
					for bw in range(-W_RADIUS, W_RADIUS + 1):
						var brick := world.get_or_create_brick(Vector4i(bx, by, bz, bw))
						total += 1
						if brick.is_collapsed:
							collapsed += 1
		var rate := float(collapsed) / float(total) * 100.0
		var diff := absf(rate - CALIBRATION_TARGET_COLLAPSE_PCT)
		print("  candidate freq=%.3f -> collapse_rate=%.1f%% (diff=%.1f)" % [freq, rate, diff])
		if diff < best_diff:
			best_diff = diff
			best_freq = freq
	_fastnoise2_frequency = best_freq
	print("  chosen freq=%.3f" % [best_freq])
	Terrain4DProfile.reset()  # calibration probes pollute the profile - clear before the real sweep

func _run() -> void:
	print("=== PART A: shape-controlled noise-speed comparison ===")
	_calibrate_shape_matched_standin()

	print("")
	print("=== A1: live Noise4D density ===")
	var live_results := []
	for h in SWEEP_HORIZONTAL_RADII:
		var r := _run_one_size(h, VERTICAL_RADIUS, W_RADIUS, Callable(self, "_density_live_noise"))
		live_results.append(r)
		_print_one_size_report("LIVE", r)

	print("")
	print("=== A2: shape-matched standin density (frequency=%.3f, calibrated above) ===" % [_shape_matched_frequency])
	var matched_results := []
	for h in SWEEP_HORIZONTAL_RADII:
		var r := _run_one_size(h, VERTICAL_RADIUS, W_RADIUS, Callable(self, "_density_shape_matched_standin"))
		matched_results.append(r)
		_print_one_size_report("SHAPE-MATCHED", r)

	print("")
	print("=== A DELTA: live vs shape-matched standin (clean noise-speed isolation) ===")
	for idx in range(SWEEP_HORIZONTAL_RADII.size()):
		_print_delta(SWEEP_HORIZONTAL_RADII[idx], live_results[idx], matched_results[idx])

	print("")
	print("=== PART C: native Math4D.noise_4d() (OpenSimplexNoise prototype) vs live GDScript Noise4D ===")
	_calibrate_native_opensimplex()

	print("")
	print("=== C: native OpenSimplexNoise density (frequency=%.3f, calibrated above) ===" % [_native_frequency])
	var native_results := []
	for h in SWEEP_HORIZONTAL_RADII:
		var r := _run_one_size(h, VERTICAL_RADIUS, W_RADIUS, Callable(self, "_density_native_opensimplex"))
		native_results.append(r)
		_print_one_size_report("NATIVE-OPENSIMPLEX", r)

	print("")
	print("=== C DELTA: live GDScript noise vs native OpenSimplexNoise ===")
	for idx in range(SWEEP_HORIZONTAL_RADII.size()):
		_print_delta(SWEEP_HORIZONTAL_RADII[idx], live_results[idx], native_results[idx])

	print("")
	print("=== PART D: native Math4D.fastnoise2_4d() (FastNoise2 SuperSimplex prototype) vs live GDScript Noise4D and native OpenSimplexNoise ===")
	_calibrate_fastnoise2()

	print("")
	print("=== D: native FastNoise2 density (frequency=%.3f, calibrated above) ===" % [_fastnoise2_frequency])
	var fastnoise2_results := []
	for h in SWEEP_HORIZONTAL_RADII:
		var r := _run_one_size(h, VERTICAL_RADIUS, W_RADIUS, Callable(self, "_density_fastnoise2"))
		fastnoise2_results.append(r)
		_print_one_size_report("NATIVE-FASTNOISE2", r)

	print("")
	print("=== D DELTA: live GDScript noise vs native FastNoise2 ===")
	for idx in range(SWEEP_HORIZONTAL_RADII.size()):
		_print_delta(SWEEP_HORIZONTAL_RADII[idx], live_results[idx], fastnoise2_results[idx])

	print("")
	print("=== D DELTA: native OpenSimplexNoise (already integrated) vs native FastNoise2 ===")
	for idx in range(SWEEP_HORIZONTAL_RADII.size()):
		_print_delta(SWEEP_HORIZONTAL_RADII[idx], native_results[idx], fastnoise2_results[idx])

	print("")
	print("=== PART B: wider-W slice histogram (live noise, h=3 v=1 fixed - showcase's other current defaults) ===")
	for w in WIDE_W_RADII:
		var r := _run_one_size(3, VERTICAL_RADIUS, w, Callable(self, "_density_live_noise"))
		_print_one_size_report("W_RADIUS=%d" % w, r)

	print("DONE")
	get_tree().quit()

func _run_one_size(h: int, v: int, w: int, density_fn: Callable) -> Dictionary:
	Terrain4DProfile.reset()
	var step := Vector4(STEP_SIZE, STEP_SIZE, STEP_SIZE, STEP_SIZE)
	var world := VoxelWorld4D.new(Vector4.ZERO, step, density_fn)

	var t_population_start := Time.get_ticks_usec()
	for bx in range(-h, h + 1):
		for by in range(-v, v + 1):
			for bz in range(-h, h + 1):
				for bw in range(-w, w + 1):
					world.get_or_create_brick(Vector4i(bx, by, bz, bw))
	var t_population_usec := Time.get_ticks_usec() - t_population_start

	var t_regen_start := Time.get_ticks_usec()
	world.regenerate_dirty_bricks()
	var t_regen_usec := Time.get_ticks_usec() - t_regen_start

	var cell_size := (VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * STEP_SIZE
	var half_cell := 0.5 * cell_size
	var center := Vector4(half_cell, GROUND_LEVEL + half_cell, half_cell, half_cell)

	var pool := TerrainChunkPool4D.new()
	add_child(pool)
	pool.world = world
	pool.max_render_distance = 100000.0
	pool.viewer_position = center
	pool.update()

	var total := 0
	var collapsed := 0
	var density_bytes := 0
	for brick in world.get_all_bricks():
		total += 1
		if brick.is_collapsed:
			collapsed += 1
		else:
			density_bytes += brick.density.size()
	var dense := total - collapsed

	# Slice-relative resident-brick histogram. Reuses
	# BearingUtility4D.compute() (see project/scripts/bearing_utility_4d.gd)
	# rather than reinventing slice-membership math - "body" is a plain
	# identity-transform Node4D standing in for the terrain rig at rest,
	# positioned at the same populated-center point the showcase's camera
	# targets. ana_offset is the signed distance along that body's local
	# W axis - bucketed in units of one brick's own nominal W-cell-width.
	var slice_body := Node4D.new()
	add_child(slice_body)
	slice_body.position = center
	var histogram := {"0": 0, "1": 0, "2": 0, "3": 0, "4+": 0}
	var histogram_dense := {"0": 0, "1": 0, "2": 0, "3": 0, "4+": 0}
	for brick in world.get_all_bricks():
		var nominal: Dictionary = VoxelBrick4D.nominal_bounds(brick.brick_coord, world.world_origin, world.step)
		var nominal_min: Vector4 = nominal.min
		var nominal_max: Vector4 = nominal.max
		var brick_center: Vector4 = (nominal_min + nominal_max) * 0.5
		var bearing: Dictionary = BearingUtility4D.compute(slice_body, brick_center)
		var steps_off: int = int(floor(absf(bearing.ana_offset) / cell_size))
		var bucket_key: String = str(steps_off) if steps_off < 4 else "4+"
		histogram[bucket_key] = histogram.get(bucket_key, 0) + 1
		if not brick.is_collapsed:
			histogram_dense[bucket_key] = histogram_dense.get(bucket_key, 0) + 1
	slice_body.queue_free()

	var profile := Terrain4DProfile.snapshot()
	pool.queue_free()

	var brick_count := (2 * h + 1) * (2 * h + 1) * (2 * v + 1) * (2 * w + 1)

	return {
		"horizontal_radius": h,
		"vertical_radius": v,
		"w_radius": w,
		"brick_count": brick_count,
		"resident_total": total,
		"collapsed": collapsed,
		"dense": dense,
		"collapse_rate_pct": (float(collapsed) / float(total) * 100.0) if total > 0 else 0.0,
		"density_memory_mb": density_bytes / (1024.0 * 1024.0),
		"population_usec": t_population_usec,
		"regen_usec": t_regen_usec,
		"histogram_all": histogram,
		"histogram_dense": histogram_dense,
		"profile": profile,
	}

const PROFILE_STAGES := [
	"collapse_check_sampling", "apron_sampling", "noise_fractal", "native_noise_fractal", "fastnoise2_fractal",
	"generate_phase1_density", "generate_phase2_qef", "qef_solve_only", "generate_phase3_tet",
	"mesh_collision_build", "chunk_pool_update",
]

func _print_one_size_report(label: String, r: Dictionary) -> void:
	print("--- %s h=%d v=%d w=%d target_brick_count=%d ---" % [label, r.horizontal_radius, r.vertical_radius, r.w_radius, r.brick_count])
	print("resident_total=%d collapsed=%d (%.1f%%) dense=%d" % [r.resident_total, r.collapsed, r.collapse_rate_pct, r.dense])
	print("density_memory_mb=%.3f" % [r.density_memory_mb])
	print("population_wall_usec=%d (%.2f ms)" % [r.population_usec, r.population_usec / 1000.0])
	print("regen_wall_usec=%d (%.2f ms)" % [r.regen_usec, r.regen_usec / 1000.0])
	var profile: Dictionary = r.profile
	for stage in PROFILE_STAGES:
		if profile.has(stage):
			var entry: Dictionary = profile[stage]
			var avg_usec: float = float(entry.usec) / float(entry.calls) if entry.calls > 0 else 0.0
			print("  %s: usec=%d (%.2f ms) calls=%d avg_usec_per_call=%.2f" % [stage, entry.usec, entry.usec / 1000.0, entry.calls, avg_usec])
		else:
			print("  %s: (no calls recorded)" % [stage])
	print("slice_histogram_all_bricks (bucket=W-cell-steps off the rest slice, 1 step=%.3f world units): %s" % [(VoxelBrick4D.NOMINAL_POINTS_PER_AXIS - 1) * STEP_SIZE, str(r.histogram_all)])
	print("slice_histogram_dense_only: %s" % [str(r.histogram_dense)])

func _print_delta(h: int, live: Dictionary, standin: Dictionary) -> void:
	print("--- DELTA at h=%d ---" % [h])
	var pop_reduction_pct: float = (1.0 - float(standin.population_usec) / float(live.population_usec)) * 100.0 if live.population_usec > 0 else 0.0
	print("population_wall_usec: live=%d standin=%d delta=%d (%.1f%% reduction)" % [
		live.population_usec, standin.population_usec, live.population_usec - standin.population_usec, pop_reduction_pct
	])
	var regen_reduction_pct: float = (1.0 - float(standin.regen_usec) / float(live.regen_usec)) * 100.0 if live.regen_usec > 0 else 0.0
	print("regen_wall_usec: live=%d standin=%d delta=%d (%.1f%% reduction)" % [
		live.regen_usec, standin.regen_usec, live.regen_usec - standin.regen_usec, regen_reduction_pct
	])
	var live_profile: Dictionary = live.profile
	var standin_profile: Dictionary = standin.profile
	for stage in PROFILE_STAGES:
		var live_usec: int = live_profile.get(stage, {}).get("usec", 0)
		var standin_usec: int = standin_profile.get(stage, {}).get("usec", 0)
		print("  %s: live=%d standin=%d delta=%d" % [stage, live_usec, standin_usec, live_usec - standin_usec])
	print("collapse_rate_pct: live=%.1f standin=%.1f (match quality: |diff|=%.1f)" % [live.collapse_rate_pct, standin.collapse_rate_pct, absf(live.collapse_rate_pct - standin.collapse_rate_pct)])
