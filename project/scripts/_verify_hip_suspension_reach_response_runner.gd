extends Node
## TEMPORARY - confirms hip_suspension_solver.gd's new reach_response_
## weight actually produces a real, nonzero pitch/roll response on the
## motion lab's flat, uniform-leg platform, where the OLD ground-height-
## only formula was measured to output exactly 0.00 degrees the entire
## time (confirmed, not assumed - there was no ground-height signal to
## react to). Also checks the response stays bounded/sane (no NaN, no
## runaway growth) rather than just "nonzero at any cost."

const OBSERVE_FRAMES := 900 # 15s - a bit under 4 full walk cycles.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")
	var solver: Node = root.get_node("HipSuspensionSolver")

	print("resting_extension_fraction=%.3f reach_response_weight=%.3f" % [solver.resting_extension_fraction, solver.reach_response_weight])

	body.select_gait("walk")
	var max_tilt_deg: float = 0.0
	var nonzero_frame_count: int = 0
	var any_nan: bool = false
	for i in range(OBSERVE_FRAMES):
		await get_tree().physics_frame
		var up: Vector4 = body.global_basis.y
		if is_nan(up.x) or is_nan(up.y) or is_nan(up.z):
			any_nan = true
			continue
		var tilt_deg: float = rad_to_deg(acos(clampf(up.y, -1.0, 1.0)))
		if tilt_deg > 0.001:
			nonzero_frame_count += 1
		max_tilt_deg = maxf(max_tilt_deg, tilt_deg)
		if i % 120 == 0:
			print("  frame %d: tilt=%.3fdeg body.position.y=%.3f" % [i, tilt_deg, body.position.y])

	print("=== RESULT over %ds walk ===" % (OBSERVE_FRAMES / 60))
	print("  max tilt: %.3f degrees (old ground-height-only formula measured exactly 0.000 here)" % max_tilt_deg)
	print("  fraction of frames with nonzero tilt: %.1f%%" % (100.0 * float(nonzero_frame_count) / float(OBSERVE_FRAMES)))
	print("  any NaN encountered: %s" % any_nan)

	print("DONE")
	get_tree().quit()
