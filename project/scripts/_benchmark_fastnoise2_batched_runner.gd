extends Node
## TEMPORARY - FastNoise2 batched (Math4D.fastnoise2_4d_grid, backed by
## GenUniformGrid4D) vs the already-integrated native OpenSimplexNoise vs
## live GDScript noise, h=3 ONLY per explicit instruction. Self-contained -
## does NOT touch _benchmark_voxel_world_profile_runner.gd (that file has
## unrelated in-flight edits elsewhere - reusing it risks exactly the kind
## of collision this session already hit once).
##
## Optimized (non-dev) engine build required - the previous attempt at
## this used a -Dev (unoptimized, /Od) build for the actual benchmark run,
## not just build verification, and combined with GenSingle4D's documented
## per-call slowness that made the run effectively never finish. This
## pass calls GenUniformGrid4D (via fastnoise2_4d_grid) instead - the
## batch API FastNoise2's own docs say GenSingle4D-style one-point-at-a-
## time calls are "VERY SLOW" relative to.
##
## Adds a coarse "still alive" progress ping inside the population loop
## itself (not just relying on print() between fully-returned function
## calls), specifically so a rerun that's genuinely slow (vs. actually
## stuck) is distinguishable from outside without repeating the process-
## inspection investigation that was needed last time.

const H := 3
const V := 1
const W := 1
const STEP_SIZE := 0.75
const SEED := 1
const NOISE_FREQUENCY := 0.06
const NOISE_AMPLITUDE := 6.0
const NOISE_PERSISTENCE := 0.55
const GROUND_LEVEL := 0.0
const CALIBRATION_TARGET_COLLAPSE_PCT := 76.0
const CALIBRATION_FREQUENCY_CANDIDATES := [0.03, 0.045, 0.06, 0.08, 0.1, 0.15]
# Already established and re-confirmed multiple times earlier this
# session - not re-derived here, this pass calibrates FastNoise2 only.
const NATIVE_OPENSIMPLEX_FREQUENCY := 0.03

const PING_INTERVAL_USEC := 5_000_000  # 5s

var _noise: Noise4D
var _fastnoise2_frequency := NOISE_FREQUENCY
var _start_usec := 0
var _last_ping_usec := 0

func _ready() -> void:
	_noise = Noise4D.new(SEED)
	_start_usec = Time.get_ticks_usec()
	_last_ping_usec = _start_usec
	_run()

func _ping(label: String) -> void:
	var now := Time.get_ticks_usec()
	if now - _last_ping_usec >= PING_INTERVAL_USEC:
		print("  ... still alive: %s (%.1fs elapsed total)" % [label, (now - _start_usec) / 1000000.0])
		_last_ping_usec = now

# --- density sources for the point-by-point (existing, unmodified) path ---

func _density_live_noise(p: Vector4) -> float:
	var height := GROUND_LEVEL + NOISE_AMPLITUDE * _noise.fractal_noise(Vector4(p.x, 0.0, p.z, p.w) * NOISE_FREQUENCY, 3, NOISE_PERSISTENCE, 2.0)
	return p.y - height

func _density_native_opensimplex(p: Vector4) -> float:
	var total := 0.0
	var amplitude := 1.0
	var frequency := NATIVE_OPENSIMPLEX_FREQUENCY
	var max_value := 0.0
	for i in range(3):
		total += Math4D.noise_4d(SEED, p.x * frequency, 0.0, p.z * frequency, p.w * frequency) * amplitude
		max_value += amplitude
		amplitude *= NOISE_PERSISTENCE
		frequency *= 2.0
	var height := GROUND_LEVEL + NOISE_AMPLITUDE * (total / max_value)
	return p.y - height

func _run_point_by_point(h: int, v: int, w: int, density_fn: Callable, label: String) -> Dictionary:
	Terrain4DProfile.reset()
	var step := Vector4(STEP_SIZE, STEP_SIZE, STEP_SIZE, STEP_SIZE)
	var world := VoxelWorld4D.new(Vector4.ZERO, step, density_fn)
	var total_bricks := (2 * h + 1) * (2 * h + 1) * (2 * v + 1) * (2 * w + 1)
	var t0 := Time.get_ticks_usec()
	var n := 0
	for bx in range(-h, h + 1):
		for by in range(-v, v + 1):
			for bz in range(-h, h + 1):
				for bw in range(-w, w + 1):
					world.get_or_create_brick(Vector4i(bx, by, bz, bw))
					n += 1
					_ping("%s population %d/%d" % [label, n, total_bricks])
	var t_pop := Time.get_ticks_usec() - t0
	_ping("%s entering regen" % [label])
	var t1 := Time.get_ticks_usec()
	world.regenerate_dirty_bricks()
	var t_regen := Time.get_ticks_usec() - t1
	return _summarize(world, t_pop, t_regen)

# --- FastNoise2 batched path - bypasses VoxelWorld4D's point-by-point
# Callable sampling entirely (that architecture calls density_fn once per
# grid point no matter what's inside it, so a "batched" density_fn would
# just be a batch-of-one, defeating the purpose) - constructs VoxelBrick4D
# instances directly using one Math4D.fastnoise2_4d_grid() call per
# octave per sampling phase, matching VoxelWorld4D._sample_and_collapse_check
# / _sample_full_apron's OWN logic shape (collapse-check the nominal grid
# first, only sample+store the full actual grid if non-uniform), just with
# the per-point native call swapped for a per-brick batched one. Reuses
# real VoxelBrick4D/VoxelWorld4D/DualContour4D for storage and regen so
# the regen-phase (QEF/tet) comparison stays apples-to-apples.

func _sample_fastnoise2_octave_sum(x0: float, z0: float, w0: float, step_x: float, step_z: float, step_w: float, n: int) -> PackedFloat64Array:
	var total := PackedFloat64Array()
	total.resize(n * n * n * n)
	var amplitude := 1.0
	var frequency := _fastnoise2_frequency
	var max_value := 0.0
	for octave in range(3):
		# y0=0, step_y=0 for every octave - matches the "zero out p.y
		# before scaling" heightfield convention _density_live_noise/
		# _density_native_opensimplex both use (height never depends on
		# the real grid y, only x/z/w), applied here by holding the
		# noise's y-role input constant instead of varying it.
		var layer: PackedFloat64Array = Math4D.fastnoise2_4d_grid(
			SEED, x0 * frequency, 0.0, z0 * frequency, w0 * frequency,
			step_x * frequency, 0.0, step_z * frequency, step_w * frequency, n
		)
		for idx in range(total.size()):
			total[idx] += layer[idx] * amplitude
		max_value += amplitude
		amplitude *= NOISE_PERSISTENCE
		frequency *= 2.0
	for idx in range(total.size()):
		total[idx] /= max_value
	return total

func _create_brick_fastnoise2(coord: Vector4i, world_origin: Vector4, step: Vector4) -> VoxelBrick4D:
	var brick := VoxelBrick4D.new(coord)
	var nominal: Dictionary = VoxelBrick4D.nominal_bounds(coord, world_origin, step)
	var actual: Dictionary = VoxelBrick4D.actual_bounds(coord, world_origin, step)
	var n_nominal := VoxelBrick4D.NOMINAL_POINTS_PER_AXIS
	var n_actual := VoxelBrick4D.ACTUAL_POINTS_PER_AXIS

	var _t0 := Time.get_ticks_usec()
	var nominal_min: Vector4 = nominal.min
	var nominal_flat := _sample_fastnoise2_octave_sum(nominal_min.x, nominal_min.z, nominal_min.w, step.x, step.z, step.w, n_nominal)
	var first_sign := true
	var uniform_negative := false
	var uniform := true
	var idx := 0
	for i in range(n_nominal):
		for j in range(n_nominal):
			var y: float = nominal_min.y + j * step.y
			for k in range(n_nominal):
				for l in range(n_nominal):
					var height: float = GROUND_LEVEL + NOISE_AMPLITUDE * nominal_flat[idx]
					var d: float = y - height
					var negative := d < 0.0
					if first_sign:
						uniform_negative = negative
						first_sign = false
					elif negative != uniform_negative:
						uniform = false
					idx += 1
	Terrain4DProfile.add("fastnoise2_collapse_check_sampling", Time.get_ticks_usec() - _t0)

	if uniform:
		brick.is_collapsed = true
		brick.is_collapsed_solid = uniform_negative
		brick.dirty = false
		return brick

	brick.is_collapsed = false
	brick.density = PackedByteArray()
	brick.density.resize(n_actual * n_actual * n_actual * n_actual * 2)

	var _t1 := Time.get_ticks_usec()
	var actual_min: Vector4 = actual.min
	var actual_flat := _sample_fastnoise2_octave_sum(actual_min.x, actual_min.z, actual_min.w, step.x, step.z, step.w, n_actual)
	idx = 0
	for i in range(n_actual):
		for j in range(n_actual):
			var y: float = actual_min.y + j * step.y
			for k in range(n_actual):
				for l in range(n_actual):
					var height: float = GROUND_LEVEL + NOISE_AMPLITUDE * actual_flat[idx]
					var d: float = y - height
					DualContour4D._write_density(brick.density, idx, d)
					idx += 1
	Terrain4DProfile.add("fastnoise2_apron_sampling", Time.get_ticks_usec() - _t1)
	return brick

func _run_fastnoise2_batched(h: int, v: int, w: int) -> Dictionary:
	Terrain4DProfile.reset()
	var step := Vector4(STEP_SIZE, STEP_SIZE, STEP_SIZE, STEP_SIZE)
	var world := VoxelWorld4D.new(Vector4.ZERO, step, Callable())
	var total_bricks := (2 * h + 1) * (2 * h + 1) * (2 * v + 1) * (2 * w + 1)
	var t0 := Time.get_ticks_usec()
	var n := 0
	for bx in range(-h, h + 1):
		for by in range(-v, v + 1):
			for bz in range(-h, h + 1):
				for bw in range(-w, w + 1):
					var coord := Vector4i(bx, by, bz, bw)
					var brick := _create_brick_fastnoise2(coord, world.world_origin, step)
					var key := VoxelWorld4D.brick_key(coord)
					world._bricks[key] = brick
					if not brick.is_collapsed:
						world._dense_brick_keys[key] = true
						world._dirty_brick_keys[key] = true
					n += 1
					_ping("fastnoise2_batched population %d/%d" % [n, total_bricks])
	var t_pop := Time.get_ticks_usec() - t0
	_ping("fastnoise2_batched entering regen")
	var t1 := Time.get_ticks_usec()
	world.regenerate_dirty_bricks()
	var t_regen := Time.get_ticks_usec() - t1
	return _summarize(world, t_pop, t_regen)

func _summarize(world: VoxelWorld4D, t_pop: int, t_regen: int) -> Dictionary:
	var total := 0
	var collapsed := 0
	for brick in world.get_all_bricks():
		total += 1
		if brick.is_collapsed:
			collapsed += 1
	return {
		"population_usec": t_pop,
		"regen_usec": t_regen,
		"resident_total": total,
		"collapsed": collapsed,
		"collapse_rate_pct": (float(collapsed) / float(total) * 100.0) if total > 0 else 0.0,
		"profile": Terrain4DProfile.snapshot(),
	}

func _calibrate_fastnoise2() -> void:
	print("--- calibration: FastNoise2 batched (GenUniformGrid4D) frequency vs collapse rate (h=3 probe, target=%.1f%%) ---" % [CALIBRATION_TARGET_COLLAPSE_PCT])
	var best_freq: float = CALIBRATION_FREQUENCY_CANDIDATES[0]
	var best_diff := INF
	for freq in CALIBRATION_FREQUENCY_CANDIDATES:
		_fastnoise2_frequency = freq
		var r := _run_fastnoise2_batched(H, V, W)
		var diff: float = absf(r.collapse_rate_pct - CALIBRATION_TARGET_COLLAPSE_PCT)
		print("  candidate freq=%.3f -> collapse_rate=%.1f%% (diff=%.1f)" % [freq, r.collapse_rate_pct, diff])
		if diff < best_diff:
			best_diff = diff
			best_freq = freq
		_ping("calibration")
	_fastnoise2_frequency = best_freq
	print("  chosen freq=%.3f" % [best_freq])

func _print_report(label: String, r: Dictionary) -> void:
	print("--- %s h=%d v=%d w=%d ---" % [label, H, V, W])
	print("resident_total=%d collapsed=%d (%.1f%%) dense=%d" % [r.resident_total, r.collapsed, r.collapse_rate_pct, r.resident_total - r.collapsed])
	print("population_wall_usec=%d (%.2f ms)" % [r.population_usec, r.population_usec / 1000.0])
	print("regen_wall_usec=%d (%.2f ms)" % [r.regen_usec, r.regen_usec / 1000.0])
	var profile: Dictionary = r.profile
	for stage in profile:
		var entry: Dictionary = profile[stage]
		var avg: float = float(entry.usec) / float(entry.calls) if entry.calls > 0 else 0.0
		print("  %s: usec=%d calls=%d avg_usec_per_call=%.3f" % [stage, entry.usec, entry.calls, avg])

func _print_delta(label: String, live: Dictionary, other: Dictionary) -> void:
	var pop_reduction: float = (1.0 - float(other.population_usec) / float(live.population_usec)) * 100.0 if live.population_usec > 0 else 0.0
	print("--- DELTA: live GDScript noise vs %s ---" % [label])
	print("population_wall_usec: live=%d other=%d delta=%d (%.1f%% reduction)" % [
		live.population_usec, other.population_usec, live.population_usec - other.population_usec, pop_reduction
	])
	print("collapse_rate_pct: live=%.1f other=%.1f (match quality: |diff|=%.1f)" % [
		live.collapse_rate_pct, other.collapse_rate_pct, absf(live.collapse_rate_pct - other.collapse_rate_pct)
	])

func _run() -> void:
	print("=== live GDScript noise (h=3 baseline) ===")
	var live := _run_point_by_point(H, V, W, Callable(self, "_density_live_noise"), "live")
	_print_report("LIVE", live)

	print("=== native OpenSimplexNoise (already integrated, freq=%.3f) ===" % [NATIVE_OPENSIMPLEX_FREQUENCY])
	var native := _run_point_by_point(H, V, W, Callable(self, "_density_native_opensimplex"), "native_opensimplex")
	_print_report("NATIVE-OPENSIMPLEX", native)

	_calibrate_fastnoise2()
	print("=== FastNoise2 batched (GenUniformGrid4D, freq=%.3f) ===" % [_fastnoise2_frequency])
	var fn2 := _run_fastnoise2_batched(H, V, W)
	_print_report("FASTNOISE2-BATCHED", fn2)

	_print_delta("native OpenSimplexNoise", live, native)
	_print_delta("FastNoise2 batched", live, fn2)
	print("--- DELTA: native OpenSimplexNoise vs FastNoise2 batched ---")
	var direct_reduction: float = (1.0 - float(fn2.population_usec) / float(native.population_usec)) * 100.0 if native.population_usec > 0 else 0.0
	print("population_wall_usec: opensimplex=%d fastnoise2=%d delta=%d (%.1f%% %s)" % [
		native.population_usec, fn2.population_usec, native.population_usec - fn2.population_usec,
		absf(direct_reduction), ("reduction" if direct_reduction >= 0.0 else "INCREASE")
	])

	print("DONE")
	get_tree().quit()
