extends Node
## TEMPORARY - dense screenshot sequence through one or more real
## Planted->Lifting->Swinging->Planted cycles, to actually LOOK at whether
## the lift/swing arc is visually correct (foot lifts, arcs across, plants
## down) rather than trusting the numeric checks alone. Captures frequently
## (every 2 frames = ~33ms) starting just before the first detected
## Planted->Lifting transition on ANY leg, through that leg's full cycle
## back to Planted, then continues watching for a couple more cycles on
## OTHER legs too. Not part of the shipped scene - wired in as a temporary
## autoload with limb_prototype_treadmill.tscn set as the main scene.

const MAX_RUN_SECONDS := 15.0
const CYCLES_TO_CAPTURE := 3
const CAPTURE_INTERVAL_FRAMES := 2
const PRE_ROLL_FRAMES := 12 # ~0.2s before the transition, so the "still planted" starting pose is visible too.
const POST_ROLL_FRAMES := 12 # ~0.2s after landing, to confirm it actually stays planted.
const LEG_NAMES := ["FL", "FR", "BL", "BR"]
# Camera-offset direction per leg, face-on to the hinge bend plane (spanned
# by world up and root_forward_local = +X for this scene - see
# ik_chain_controller.gd) rather than the leg's own local-XZ outward
# direction. An outward-facing camera (this constant's OLD value, mostly
# +-X) looks nearly EDGE-ON to an X-Y bend plane, flattening any real
# zigzag into what looks like a near-straight line - confirmed directly:
# _verify_limb_prototype_hinge_zigzag_sideview_runner.gd's Z-facing camera
# showed a clear hip-left/knee-right/ankle-left zigzag on the exact same
# pose this script's old camera made look like a smooth curve. Sign per leg
# picked to stay on the side away from the body's own Z-thickness (FL/BL
# sit at local z=+0.5, FR/BR at z=-0.5).
const LEG_OUTWARD_DIR := [
	Vector4(0, 0, -1, 0), # FL (z=+0.5): view from -Z.
	Vector4(0, 0, 1, 0), # FR (z=-0.5): view from +Z.
	Vector4(0, 0, -1, 0), # BL (z=+0.5): view from -Z.
	Vector4(0, 0, 1, 0), # BR (z=-0.5): view from +Z.
]


func _screenshot(image_name: String) -> void:
	# No extra `await process_frame` here - the caller already awaits
	# physics_frame once per loop iteration, and rendering keeps pace with
	# that. An extra await here would consume a REAL frame that the loop's
	# manually-incremented `frame` counter doesn't know about, silently
	# desyncing the counter from actual elapsed simulation time whenever a
	# screenshot fires (which is often, inside the dense capture windows).
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _reset_chain(ik_chain: Node) -> void:
	for joint in ik_chain.joints:
		joint.global_basis = Projection()


func _set_mesh_visibility(node: Node, vis: bool) -> void:
	if node is MeshInstance4D:
		node.visible = vis
	for child in node.get_children():
		_set_mesh_visibility(child, vis)


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var body: Node4D = flat_plane.get_node("Body")
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
	var anchors: Array = [
		flat_plane.get_node("Body/LimbAnchorFL"),
		flat_plane.get_node("Body/LimbAnchorFR"),
		flat_plane.get_node("Body/LimbAnchorBL"),
		flat_plane.get_node("Body/LimbAnchorBR"),
	]

	print("1.nodes_resolve: player=%s body=%s foot_targets=%s" % [
		player != null, body != null, foot_targets.all(func(n): return n != null),
	])

	for ik_chain in ik_chains:
		_reset_chain(ik_chain)

	# Take over the camera directly (skip the scene's own TreadmillCamera
	# node so we can frame closer for this inspection) - fixed close
	# 3rd-person offset, re-aimed at the body every frame.
	player.global_basis = Projection()

	var last_states: Array = []
	for ft in foot_targets:
		last_states.append(ft.state)

	var shot_index: int = 0
	var cycles_captured: int = 0
	var capture_frames_remaining: int = 0
	var capturing_leg: int = -1
	var frame: int = 0
	var max_frames: int = int(MAX_RUN_SECONDS * 60.0)

	# Ring buffer of recent frame numbers so we can retroactively confirm a
	# pre-roll happened even though the burst wasn't already running -
	# simplest correct approach: always capture every frame into a small
	# rolling window, and on a detected transition, dump the last
	# PRE_ROLL_FRAMES-worth immediately, then continue capturing forward.
	# To keep this simple and avoid buffering actual images, we instead
	# START a light-weight "always capturing at reduced rate" mode: capture
	# every CAPTURE_INTERVAL_FRAMES continuously from the start, but only
	# actually SAVE frames that fall within [transition-PRE_ROLL,
	# transition+step_duration+POST_ROLL] for whichever cycles we care
	# about. Detect transitions first, THEN decide what to save, by running
	# the sim twice: once dry (find transition frame numbers), once for
	# real (screenshot around them). Two passes is simplest and clearest.

	# --- Pass 1: dry run to find cycle start frames (no screenshots). ---
	var cycle_start_frames: Array = []
	while frame < max_frames and cycle_start_frames.size() < CYCLES_TO_CAPTURE:
		await get_tree().physics_frame
		for i in range(4):
			var ft = foot_targets[i]
			if last_states[i] == ft.FootState.PLANTED and ft.state == ft.FootState.LIFTING:
				cycle_start_frames.append({"frame": frame, "leg": i})
				print("dry_run: cycle_start frame=%d leg=%s" % [frame, LEG_NAMES[i]])
			last_states[i] = ft.state
		frame += 1

	print("2.cycle_start_frames=%s" % [cycle_start_frames])

	if cycle_start_frames.is_empty():
		print("NO CYCLES OBSERVED within %d frames - cannot capture a sequence." % max_frames)
		print("DONE")
		get_tree().quit()
		return

	# --- Pass 2: reset the whole scene and re-run for real, screenshotting
	# densely around each recorded cycle-start frame. ---
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame

	scene = get_tree().current_scene
	flat_plane = scene.get_node("FlatPlane")
	player = flat_plane.get_node("Player")
	body = flat_plane.get_node("Body")
	foot_targets = [
		flat_plane.get_node("FootTargetFL"),
		flat_plane.get_node("FootTargetFR"),
		flat_plane.get_node("FootTargetBL"),
		flat_plane.get_node("FootTargetBR"),
	]
	ik_chains = [
		flat_plane.get_node("Body/LimbAnchorFL/IKChain"),
		flat_plane.get_node("Body/LimbAnchorFR/IKChain"),
		flat_plane.get_node("Body/LimbAnchorBL/IKChain"),
		flat_plane.get_node("Body/LimbAnchorBR/IKChain"),
	]
	anchors = [
		flat_plane.get_node("Body/LimbAnchorFL"),
		flat_plane.get_node("Body/LimbAnchorFR"),
		flat_plane.get_node("Body/LimbAnchorBL"),
		flat_plane.get_node("Body/LimbAnchorBR"),
	]
	for ik_chain in ik_chains:
		_reset_chain(ik_chain)
	player.global_basis = Projection()

	var max_capture_frame: int = 0
	for entry in cycle_start_frames:
		max_capture_frame = maxi(max_capture_frame, entry["frame"] + 60) # generous tail past each cycle start

	var currently_isolated: int = -1
	frame = 0
	while frame <= max_capture_frame:
		await get_tree().physics_frame

		# Default wide framing when no capture window is active; overridden
		# below with a leg-specific shot while one is.
		player.global_position = body.position + Vector4(0, 6, -15, 0)
		player.global_basis = Basis4D.looking_at(body.position - player.global_position)

		var in_window: bool = false
		for entry_index in range(cycle_start_frames.size()):
			var entry: Dictionary = cycle_start_frames[entry_index]
			var start_frame: int = entry["frame"]
			if frame >= start_frame - PRE_ROLL_FRAMES and frame <= start_frame + 30 + POST_ROLL_FRAMES:
				in_window = true
				var tracked_leg: int = entry["leg"]
				# Isolate the tracked leg (hide the other 3) so there is no
				# ambiguity about which visible geometry belongs to the leg
				# whose cycle is actually being captured this burst - two
				# earlier passes at this both showed 2 legs clustered too
				# close together on screen to tell apart.
				if currently_isolated != tracked_leg:
					for i in range(4):
						_set_mesh_visibility(anchors[i], i == tracked_leg)
					currently_isolated = tracked_leg
				var anchor_pos: Vector4 = anchors[tracked_leg].global_position
				player.global_position = anchor_pos + LEG_OUTWARD_DIR[tracked_leg] * 5.0 + Vector4(0, 2.5, 0, 0)
				player.global_basis = Basis4D.looking_at(anchor_pos - player.global_position)
				if (frame - (start_frame - PRE_ROLL_FRAMES)) % CAPTURE_INTERVAL_FRAMES == 0:
					var states_str: String = ""
					for ft2 in foot_targets:
						var c: String = "P"
						if ft2.state == ft2.FootState.LIFTING:
							c = "L"
						elif ft2.state == ft2.FootState.SWINGING:
							c = "S"
						states_str += c
					await _screenshot("limb_prototype_liftswing_leg%s_cycle%d_f%04d_states%s.png" % [
						LEG_NAMES[entry["leg"]], entry_index, frame, states_str,
					])
					var tracked_ft = foot_targets[tracked_leg]
					var rel_to_anchor: Vector4 = tracked_ft.global_position - anchor_pos
					print("shot leg=%s frame=%d states[FL,FR,BL,BR]=%s foot_world=%s foot_rel_anchor=%s" % [
						LEG_NAMES[entry["leg"]], frame, states_str, tracked_ft.global_position, rel_to_anchor,
					])
					shot_index += 1
				break

		if not in_window and currently_isolated != -1:
			for i in range(4):
				_set_mesh_visibility(anchors[i], true)
			currently_isolated = -1

		frame += 1

	print("3.total_screenshots=%d" % shot_index)
	print("DONE")
	get_tree().quit()
