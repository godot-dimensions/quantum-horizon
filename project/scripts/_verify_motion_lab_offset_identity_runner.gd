extends Node
## TEMPORARY - single-instant trace, all 4 legs at once: physical identity
## (FL/FR/BL/BR, read directly from each leg's own anchor position, not
## assumed), foot_target.leg_index, and the ACTUAL phase_offsets[leg_index]
## value gait_controller.gd is using for it - to confirm the full chain
## (physical position -> leg_index -> assigned offset) matches this
## project's own documented convention (gait_controller.gd's own header:
## "Leg order (index 0-3) is FL, FR, BL, BR" with walk's own
## phase_offsets=[0.0,0.25,0.5,0.75]), not just that 4 evenly-spaced
## values exist somewhere.
##
## Also computes and prints the REAL chronological swing order this
## implies - local_phase = frac(phase_progress + offset) crosses
## duty_factor when phase_progress = duty_factor - offset (mod 1), so
## the chronological swing order is the DESCENDING-offset order, not the
## ascending order the offsets/leg_index happen to be assigned in. Worth
## stating explicitly since it's easy to assume "assigned in order 0.0,
## 0.25, 0.5, 0.75" means "swings in that same order" - it doesn't.

func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")
	var gc: Node = root.get_node("GaitController")

	body.select_gait("walk")
	for i in range(150): # 2.5s - past the gait-switch transient, into steady state.
		await get_tree().physics_frame

	print("=== single-instant trace: all 4 legs, identity + assigned phase_offset ===")
	print("gait_controller.duty_factor=%.3f phase_offsets(raw array)=%s" % [gc.duty_factor, gc.phase_offsets])

	var rows: Array = []
	for i in range(4):
		var anchor: Node4D = body.get_node("LegAnchor%d" % i)
		var ft: Node = root.get_node("FootTarget%d" % i)
		var role: String = "FRONT" if anchor.position.x > 0 else "BACK"
		var side: String = "LEFT" if anchor.position.z > 0 else "RIGHT"
		var identity: String = ("F" if role == "FRONT" else "B") + ("L" if side == "LEFT" else "R")
		var assigned_offset: float = gc.phase_offsets[ft.leg_index]
		var swing_at_phase: float = fmod(gc.duty_factor - assigned_offset, 1.0)
		if swing_at_phase < 0.0:
			swing_at_phase += 1.0
		rows.append({"node": "LegAnchor%d/FootTarget%d" % [i, i], "identity": identity, "leg_index": ft.leg_index, "offset": assigned_offset, "swing_at_phase": swing_at_phase})
		print("  %s: identity=%s (x=%.2f,z=%.2f) leg_index=%d assigned_offset=%.3f -> fires at phase_progress=%.3f" % [rows[i]["node"], identity, anchor.position.x, anchor.position.z, ft.leg_index, assigned_offset, swing_at_phase])

	print("=== expected convention check (gait_controller.gd's own header: FL,FR,BL,BR = offsets 0.0,0.25,0.5,0.75 in that order) ===")
	var expected: Dictionary = {"FL": 0.0, "FR": 0.25, "BL": 0.5, "BR": 0.75}
	var all_match: bool = true
	for row in rows:
		var exp: float = expected[row["identity"]]
		var match_ok: bool = absf(row["offset"] - exp) < 0.0001
		if not match_ok:
			all_match = false
		print("  %s: expected offset=%.3f, actual=%.3f -> %s" % [row["identity"], exp, row["offset"], "MATCH" if match_ok else "MISMATCH"])
	print("ALL MATCH EXPECTED CONVENTION: %s" % all_match)

	print("=== implied REAL chronological swing order (ascending phase_progress-of-firing, i.e. what you'd actually SEE first) ===")
	var sorted_rows: Array = rows.duplicate()
	sorted_rows.sort_custom(func(a, b): return a["swing_at_phase"] < b["swing_at_phase"])
	for row in sorted_rows:
		print("  phase_progress=%.3f: %s (offset=%.3f)" % [row["swing_at_phase"], row["identity"], row["offset"]])

	print("DONE")
	get_tree().quit()
