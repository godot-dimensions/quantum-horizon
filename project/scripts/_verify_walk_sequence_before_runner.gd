extends Node
## TEMPORARY - computes the REAL chronological firing order (phase_progress
## = duty_factor - offset, using ACTUAL physical leg identities from
## anchor position, not assignment labels) for walk's CURRENT phase_
## offsets, and compares it against the intended real lateral-sequence
## walk footfall pattern (LH->LF->RH->RF, i.e. in this project's own
## FL/FR/BL/BR naming: BL->FL->BR->FR) to confirm whether the current
## assignment actually reproduces that intended sequence or merely
## satisfies "evenly spaced, no bunching" without matching it.

func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")
	var gc: Node = root.get_node("GaitController")

	body.select_gait("walk")
	await get_tree().physics_frame

	print("=== walk phase_offsets (current) = %s, duty_factor=%.3f ===" % [gc.phase_offsets, gc.duty_factor])

	var rows: Array = []
	for i in range(4):
		var anchor: Node4D = body.get_node("LegAnchor%d" % i)
		var ft: Node = root.get_node("FootTarget%d" % i)
		var role: String = "F" if anchor.position.x > 0 else "B"
		var side: String = "L" if anchor.position.z > 0 else "R"
		var identity: String = role + side # FL/FR/BL/BR.
		var offset: float = gc.phase_offsets[ft.leg_index]
		var fire_phase: float = fmod(gc.duty_factor - offset, 1.0)
		if fire_phase < 0.0:
			fire_phase += 1.0
		rows.append({"identity": identity, "offset": offset, "fire_phase": fire_phase})

	var sorted_rows: Array = rows.duplicate()
	sorted_rows.sort_custom(func(a, b): return a["fire_phase"] < b["fire_phase"])

	print("=== REAL chronological firing order (this project's naming) ===")
	var sequence: Array = []
	for row in sorted_rows:
		sequence.append(row["identity"])
		print("  fire_phase=%.3f: %s (offset=%.3f)" % [row["fire_phase"], row["identity"], row["offset"]])
	print("Sequence: %s" % " -> ".join(sequence))

	# LH->LF->RH->RF (real lateral-sequence walk, from the earlier gait
	# research) translated into this project's FL/FR/BL/BR naming:
	# L=left, R=right, H=hind=back, F=front. LH=BL, LF=FL, RH=BR, RF=FR.
	var intended: Array = ["BL", "FL", "BR", "FR"]
	print("Intended (LH->LF->RH->RF translated): %s" % " -> ".join(intended))
	print("MATCHES INTENDED SEQUENCE: %s" % (sequence == intended))

	print("DONE")
	get_tree().quit()
