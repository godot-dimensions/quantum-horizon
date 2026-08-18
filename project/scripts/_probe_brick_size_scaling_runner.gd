extends Node
## TEMPORARY - measures how collapse-check cost, apron cost, regen-phase
## cost, and edit fanout actually scale with VoxelBrick4D.NOMINAL_POINTS_PER_AXIS,
## at whatever value that const is CURRENTLY set to (this script doesn't
## change it - the caller edits voxel_brick_4d.gd, reruns this, and reverts
## when done, exactly like every other real-code-change-then-measure step
## in this session). Small world (h=2) - only per-brick averages matter
## here, not population statistics.

const H := 2
const V := 1
const W := 1
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

func _carve_air(_old_density: float, _dist: float) -> float:
	return 5.0

func _run() -> void:
	Terrain4DProfile.reset()
	var step := Vector4(STEP_SIZE, STEP_SIZE, STEP_SIZE, STEP_SIZE)
	var world := VoxelWorld4D.new(Vector4.ZERO, step, Callable(self, "_density"))
	for bx in range(-H, H + 1):
		for by in range(-V, V + 1):
			for bz in range(-H, H + 1):
				for bw in range(-W, W + 1):
					world.get_or_create_brick(Vector4i(bx, by, bz, bw))
	world.regenerate_dirty_bricks()

	var profile: Dictionary = Terrain4DProfile.snapshot()
	var collapse: Dictionary = profile.get("collapse_check_sampling", {"usec": 0, "calls": 0})
	var apron: Dictionary = profile.get("apron_sampling", {"usec": 0, "calls": 0})
	var p1: Dictionary = profile.get("generate_phase1_density", {"usec": 0, "calls": 0})
	var p2: Dictionary = profile.get("generate_phase2_qef", {"usec": 0, "calls": 0})
	var p3: Dictionary = profile.get("generate_phase3_tet", {"usec": 0, "calls": 0})

	var dense := 0
	var total_active_cells := 0
	for brick in world.get_all_bricks():
		if not brick.is_collapsed:
			dense += 1
	var n_axis: int = VoxelBrick4D.NOMINAL_POINTS_PER_AXIS
	var apron_cells: int = VoxelBrick4D.APRON_CELLS
	print("=== N=%d (APRON_CELLS=%d, ACTUAL=%d) ===" % [n_axis, apron_cells, VoxelBrick4D.ACTUAL_POINTS_PER_AXIS])
	print("collapse_check_avg_usec_per_brick=%.2f (calls=%d)" % [
		(float(collapse.usec) / float(collapse.calls)) if collapse.calls > 0 else 0.0, collapse.calls
	])
	print("apron_extra_avg_usec_per_dense_brick=%.2f (calls=%d)" % [
		(float(apron.usec) / float(apron.calls)) if apron.calls > 0 else 0.0, apron.calls
	])
	print("regen_phase1_avg_usec_per_brick=%.2f phase2_qef_avg=%.2f phase3_tet_avg=%.2f (dense=%d)" % [
		(float(p1.usec) / float(p1.calls)) if p1.calls > 0 else 0.0,
		(float(p2.usec) / float(p2.calls)) if p2.calls > 0 else 0.0,
		(float(p3.usec) / float(p3.calls)) if p3.calls > 0 else 0.0,
		dense,
	])

	# Fanout probe: a centered small (r=0.3) and medium (r=1.2) edit against
	# brick (0,0,0,0)'s own center - same geometry as
	# _measure_edit_latency_runner.gd's interior cases, just counting
	# affected bricks (via _dirty_brick_keys read right after the call),
	# not timing.
	var cell_size := (n_axis - 1) * STEP_SIZE
	var half_cell := 0.5 * cell_size
	var center := Vector4(half_cell, GROUND_LEVEL + half_cell, half_cell, half_cell)
	for r in [0.3, 1.2]:
		world.edit_sphere(center, r, Callable(self, "_carve_air"), false)
		var affected: int = world._dirty_brick_keys.size()
		world._dirty_brick_keys.clear()
		print("fanout_at_radius_%.1f=%d" % [r, affected])

	print("DONE")
	get_tree().quit()
