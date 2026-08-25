extends Node
## TEMPORARY - Step 4 (multi-limb gait) verification for whichever gait
## preset limb_prototype_test.tscn's GaitController is currently set to (run
## once per preset, comparing the two runs' own output - see the co-
## occurrence tally below for the actual data-driven distinctness check).
##
## 1. Per-limb locked-position correctness: 0 violations for each of the 4
##    legs individually, same check as every earlier single-limb stage.
## 2. Per-limb activity: each leg actually completes multiple cycles (none
##    stuck Planted or stuck cycling forever).
## 3. Co-occurrence: whenever a leg releases (Planted->Lifting), record
##    which OTHER legs are ALSO airborne (Lifting/Swinging) at that same
##    instant, tallied into a 4x4 matrix. This is the actual data-driven
##    "does this preset produce the intended pairing pattern" check - walk
##    (phase offsets 0/0.25/0.5/0.75) should show near-zero overlap between
##    any two legs; trot (diagonal pairs at phase 0 and 0.5) should show
##    overlap concentrated specifically between legs (0,3) and (1,2).
## Leg order: 0=FL, 1=FR, 2=BL, 3=BR.
##
## Screenshots taken periodically for a visual side-by-side against the
## other preset's run. Not part of the shipped scene - wired in as a
## temporary autoload with limb_prototype_test.tscn set as the main scene.

const RUN_SECONDS := 20.0
const SCREENSHOT_INTERVAL_FRAMES := 90 # 1.5s
const LEG_NAMES := ["FL", "FR", "BL", "BR"]


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _reset_chain(ik_chain: Node) -> void:
	for joint in ik_chain.joints:
		joint.global_basis = Projection()


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var body: Node4D = flat_plane.get_node("Body")
	var gait: Node = flat_plane.get_node("GaitController")
	var foot_targets: Array = [
		flat_plane.get_node("FootTargetFL"),
		flat_plane.get_node("FootTargetFR"),
		flat_plane.get_node("FootTargetBL"),
		flat_plane.get_node("FootTargetBR"),
	]
	var ik_chains: Array = [
		flat_plane.get_node("Body/LimbAnchorFL/IKChain"),
		flat_plane.get_node("Body/LimbAnchorFR/IKChain"),
		flat_plane.get_node("Body/LimbAnchorBL/IKChain"),
		flat_plane.get_node("Body/LimbAnchorBR/IKChain"),
	]

	print("1.nodes_resolve: foot_targets=%s ik_chains=%s gait=%s" % [
		foot_targets.all(func(n): return n != null), ik_chains.all(func(n): return n != null), gait != null,
	])
	print("2.preset=%s period_sec=%.3f duty_factor=%.3f phase_offsets=%s" % [
		gait.preset, gait.period_sec, gait.duty_factor, gait.phase_offsets,
	])

	for ik_chain in ik_chains:
		_reset_chain(ik_chain)

	player.global_basis = Projection()
	player.global_position = Vector4(0, 6, -8, 0)
	player.global_basis = Basis4D.looking_at(body.position - player.global_position)

	var violations: Array = [0, 0, 0, 0]
	var cycle_counts: Array = [0, 0, 0, 0]
	var last_states: Array = []
	var last_locked: Array = []
	var was_planted_last_frame: Array = [true, true, true, true]
	for i in range(4):
		last_states.append(foot_targets[i].state)
		last_locked.append(foot_targets[i].locked_position)

	var cooccurrence: Array = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]

	var total_frames: int = int(RUN_SECONDS * 60.0)
	for frame in range(total_frames):
		await get_tree().physics_frame

		for i in range(4):
			var ft = foot_targets[i]
			if ft.state == ft.FootState.PLANTED:
				if was_planted_last_frame[i] and ft.global_position != last_locked[i]:
					violations[i] += 1
					print("VIOLATION leg=%s frame=%d: planted position drifted from %s to %s" % [LEG_NAMES[i], frame, last_locked[i], ft.global_position])
				last_locked[i] = ft.locked_position
				was_planted_last_frame[i] = true
			else:
				was_planted_last_frame[i] = false

			if last_states[i] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING:
				cycle_counts[i] += 1
				for j in range(4):
					if j == i:
						continue
					if foot_targets[j].state != foot_targets[j].FootState.PLANTED:
						cooccurrence[i][j] += 1

			last_states[i] = ft.state

		if frame % SCREENSHOT_INTERVAL_FRAMES == 0:
			player.global_basis = Basis4D.looking_at(body.position - player.global_position)
			var states_str: String = ""
			for i in range(4):
				var ft = foot_targets[i]
				var c: String = "P"
				if ft.state == ft.FootState.LIFTING:
					c = "L"
				elif ft.state == ft.FootState.SWINGING:
					c = "S"
				states_str += c
			print("t=%.2fs states[FL,FR,BL,BR]=%s" % [frame / 60.0, states_str])
			await _screenshot("limb_prototype_gait_%s_t%d.png" % [gait.preset, frame])

	print("3.violations=%s (expect all 0)" % [violations])
	print("4.cycle_counts[FL,FR,BL,BR]=%s" % [cycle_counts])
	print("5.cooccurrence matrix (row=leg that just released, col=other leg airborne at that moment):")
	for i in range(4):
		print("   %s: %s" % [LEG_NAMES[i], cooccurrence[i]])
	print("DONE")
	get_tree().quit()
