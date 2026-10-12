extends Node
## TEMPORARY - confirms the hopper-tilt hypothesis directly before
## changing anything: logs the ground-height regression's per-leg inputs
## (locked_position.y, max_reach, resting_extension_fraction, and the
## resulting target_anchor_y/y-value fed into the pitch/roll regression)
## for Hopper specifically, at a standstill (body.halted=true set
## immediately, before any wander/gait motion), with reach_response_
## weight confirmed at its safe 0.0 default. Checks whether the front/
## back max_reach asymmetry ALONE produces a large height-target spread
## across planted legs with nothing moving.

func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var hopper: Node = flat_plane.get_node("Hopper1")
	var body: Node4D = hopper.get_node("Body")
	var solver: Node = hopper.get_node("HipSuspensionSolver")

	# Standstill: halt immediately, before any wander motion accumulates.
	body.halted = true
	for i in range(5): # A handful of frames for the initial spawn pose/raycast to settle.
		await get_tree().physics_frame

	print("=== Hopper standstill: per-leg regression inputs ===")
	print("solver.resting_extension_fraction=%.4f solver.reach_response_weight=%.4f (expect 0.0)" % [solver.resting_extension_fraction, solver.reach_response_weight])

	var rows: Array = []
	for leg_name in ["FL", "FR", "BL", "BR"]:
		var anchor: Node4D = body.get_node("LimbAnchor%s" % leg_name)
		var ft: Node = hopper.get_node("FootTarget%s" % leg_name)
		var target_anchor_y: float = ft.locked_position.y + solver.resting_extension_fraction * ft.max_reach
		var y_value: float = target_anchor_y - anchor.position.y
		rows.append({"leg": leg_name, "x": anchor.position.x, "z": anchor.position.z, "max_reach": ft.max_reach, "locked_y": ft.locked_position.y, "target_anchor_y": target_anchor_y, "y_value": y_value})
		print("  %s: anchor(x=%.3f,z=%.3f) max_reach=%.3f locked_position.y=%.3f -> target_anchor_y=%.3f, y_value(fed to regression)=%.3f" % [leg_name, anchor.position.x, anchor.position.z, ft.max_reach, ft.locked_position.y, target_anchor_y, y_value])

	# Manually replicate the solver's own pitch regression to show the spread's real effect.
	var xs: Array = []
	var ys: Array = []
	for row in rows:
		xs.append(row["x"])
		ys.append(row["y_value"])
	var y_mean: float = 0.0
	for y in ys:
		y_mean += y
	y_mean /= ys.size()
	var x_mean: float = 0.0
	for x in xs:
		x_mean += x
	x_mean /= xs.size()
	var num: float = 0.0
	var den: float = 0.0
	for i in range(xs.size()):
		var dx: float = xs[i] - x_mean
		num += dx * (ys[i] - y_mean)
		den += dx * dx
	var pitch_slope: float = num / den if den > 0.0001 else 0.0
	var implied_tilt_deg: float = rad_to_deg(atan(pitch_slope))
	print("y_value spread across legs: max=%.3f min=%.3f (diff=%.3f)" % [ys.max(), ys.min(), ys.max() - ys.min()])
	print("computed pitch_slope=%.4f -> implied tilt from x-spread ALONE = %.2f degrees" % [pitch_slope, implied_tilt_deg])

	print("=== measured actual body tilt at this standstill instant ===")
	var up: Vector4 = body.global_basis.y
	var actual_tilt: float = rad_to_deg(acos(clampf(up.y, -1.0, 1.0)))
	print("actual body tilt = %.3f degrees" % actual_tilt)

	print("DONE")
	get_tree().quit()
