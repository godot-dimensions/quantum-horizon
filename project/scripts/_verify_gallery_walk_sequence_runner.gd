extends Node
## TEMPORARY - same chronological-firing-order check as _verify_walk_
## sequence_before_runner.gd, but for the gallery's steed (shares the
## same gait_controller.gd PRESETS["walk"] just corrected) - confirms the
## fix applies correctly to this consumer too, not just the motion lab.

func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var steed: Node = flat_plane.get_node("Steed1")
	var body: Node4D = steed.get_node("Body")
	var gc: Node = steed.get_node("GaitController")

	await get_tree().physics_frame
	print("=== gallery Steed1 walk phase_offsets = %s, duty_factor=%.3f ===" % [gc.phase_offsets, gc.duty_factor])

	var rows: Array = []
	for leg_name in ["FL", "FR", "BL", "BR"]:
		var anchor: Node4D = body.get_node("LimbAnchor%s" % leg_name)
		var ft: Node = steed.get_node("FootTarget%s" % leg_name)
		var offset: float = gc.phase_offsets[ft.leg_index]
		var fire_phase: float = fmod(gc.duty_factor - offset, 1.0)
		if fire_phase < 0.0:
			fire_phase += 1.0
		rows.append({"identity": leg_name, "offset": offset, "fire_phase": fire_phase})

	var sorted_rows: Array = rows.duplicate()
	sorted_rows.sort_custom(func(a, b): return a["fire_phase"] < b["fire_phase"])
	var sequence: Array = []
	for row in sorted_rows:
		sequence.append(row["identity"])
		print("  fire_phase=%.3f: %s (offset=%.3f)" % [row["fire_phase"], row["identity"], row["offset"]])
	print("Sequence: %s" % " -> ".join(sequence))

	var intended: Array = ["BL", "FL", "BR", "FR"]
	print("Intended (LH->LF->RH->RF translated): %s" % " -> ".join(intended))
	print("MATCHES INTENDED SEQUENCE: %s" % (sequence == intended))

	print("DONE")
	get_tree().quit()
