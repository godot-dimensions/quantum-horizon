extends Node
## TEMPORARY - correlation diagnostic (same methodology as this project's
## earlier wander-retarget investigation): does the FL chain's effector-to-
## target residual spike in step with get_travel_direction() changing,
## during a single REAL stance (one full Planted duration, real wander, no
## resets, no synthetic poses)? This is the decisive check before deciding
## whether to freeze the hinge plane's forward direction per-footstep
## (confirmed mechanism) or abandon the live-tracking approach (not
## confirmed - would mean something else explains the observed regression).
##
## Logs every physics frame from the moment FL lands Planted until it
## releases: the effector-to-(fixed)-target residual, and whether
## get_travel_direction() changed by more than DIRECTION_CHANGE_THRESHOLD_DEG
## since the previous frame. Reports both the raw per-frame series and an
## automated correlation check (does a residual UPTICK land within
## CORRELATION_WINDOW_FRAMES of a flagged direction-change frame).
##
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.

const DIRECTION_CHANGE_THRESHOLD_DEG := 2.0 # Flag a frame if travel_direction rotated more than this since the previous frame.
const RESIDUAL_UPTICK_THRESHOLD := 0.01 # Flag a frame if residual grew by more than this since the previous frame.
const CORRELATION_WINDOW_FRAMES := 3 # An uptick within this many frames of a flagged direction-change counts as coincident.
const MAX_STANCE_FRAMES := 600 # Safety cap (10s) in case FL's stance runs unexpectedly long.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("Body")
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchorFL/IKChain")
	var foot_target: Node4D = flat_plane.get_node("FootTargetFL")

	print("1.nodes_resolve: body=%s ik_chain=%s foot_target=%s forward_direction_provider=%s" % [
		body != null, ik_chain != null, foot_target != null, ik_chain.forward_direction_provider,
	])

	# Wait for FL to be freshly Planted (a real landing, not a stance already
	# in progress) so the logged window covers a FULL stance from its start.
	var last_state = foot_target.state
	while true:
		await get_tree().physics_frame
		if last_state != foot_target.FootState.PLANTED and foot_target.state == foot_target.FootState.PLANTED:
			break
		last_state = foot_target.state

	print("2.FL just landed - logging through this stance (target=%s)" % [foot_target.locked_position])

	var residuals: Array = []
	var direction_change_frames: Array = []
	var last_travel_dir: Vector4 = body.get_travel_direction()
	var frame: int = 0

	while foot_target.state == foot_target.FootState.PLANTED and frame < MAX_STANCE_FRAMES:
		await get_tree().physics_frame

		var target_pos: Vector4 = foot_target.locked_position
		var effector: Vector4 = ik_chain._end_effector_position()
		var residual: float = (target_pos - effector).length()
		residuals.append(residual)

		var travel_dir: Vector4 = body.get_travel_direction()
		var angle_change_deg: float = rad_to_deg(acos(clampf(travel_dir.dot(last_travel_dir), -1.0, 1.0)))
		var direction_changed: bool = angle_change_deg > DIRECTION_CHANGE_THRESHOLD_DEG
		if direction_changed:
			direction_change_frames.append(frame)
		last_travel_dir = travel_dir

		print("   frame=%d residual=%.5f travel_dir=%s angle_change_deg=%.3f %s" % [
			frame, residual, travel_dir, angle_change_deg, "<<< DIRECTION_CHANGE" if direction_changed else "",
		])

		frame += 1

	print("3.stance_length_frames=%d direction_change_frames=%s" % [residuals.size(), direction_change_frames])

	# Automated correlation check: for each frame where residual upticked
	# meaningfully, is there a flagged direction-change within
	# CORRELATION_WINDOW_FRAMES?
	var uptick_frames: Array = []
	for i in range(1, residuals.size()):
		if residuals[i] - residuals[i - 1] > RESIDUAL_UPTICK_THRESHOLD:
			uptick_frames.append(i)

	var coincident_count: int = 0
	for uf in uptick_frames:
		var is_coincident: bool = false
		for df in direction_change_frames:
			if abs(uf - df) <= CORRELATION_WINDOW_FRAMES:
				is_coincident = true
				break
		if is_coincident:
			coincident_count += 1

	print("4.residual_uptick_frames=%s" % [uptick_frames])
	print("5.uptick_frames_coincident_with_direction_change=%d of %d (%.1f%%)" % [
		coincident_count, uptick_frames.size(),
		100.0 * coincident_count / uptick_frames.size() if uptick_frames.size() > 0 else -1.0,
	])
	print("6.verdict=%s" % [
		"MECHANISM CONFIRMED - upticks track direction changes" if uptick_frames.size() > 0 and float(coincident_count) / uptick_frames.size() >= 0.7
		else ("NO UPTICKS OBSERVED - residual did not spike during this stance" if uptick_frames.size() == 0
		else "MECHANISM NOT CONFIRMED - upticks do not track direction changes"),
	])

	print("DONE")
	get_tree().quit()
