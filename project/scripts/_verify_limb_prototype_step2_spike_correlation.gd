extends Node
## TEMPORARY - checks whether the ~0.5-1.3 unit effector-to-raycast-target
## distance spikes seen in the step 2 report are actually COINCIDENT with
## the body's wander-retarget events (a new _target_xzw chosen), not just
## superficially similar in frequency. Detects retargets by polling the
## body's own _target_xzw every frame for a change (same "reach into
## otherwise-private state for a controlled test" convention already used
## throughout this project's verify runners), and independently detects
## distance spikes (crossing above a threshold) every frame, then reports
## the time gap between each spike and its nearest PRECEDING retarget.
## Pure numeric check, headless-safe - no screenshots. Not part of the
## shipped scene - wired in as a temporary autoload with
## limb_prototype_test.tscn set as the main scene.

const RUN_SECONDS := 10.0
const SPIKE_THRESHOLD := 0.3 # Comfortably above ordinary tracking noise (<=0.1 in the step 2 log), well below the observed 0.5-1.3 spikes.


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("Body")
	var foot_target: Node4D = flat_plane.get_node("FootTarget")
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchor/IKChain")

	for joint in ik_chain.joints:
		joint.global_basis = Projection()

	var retarget_frames: Array = []
	var last_target: Vector4 = body._target_xzw

	var spike_frames: Array = [] # frames where distance crosses ABOVE threshold (rising edge only)
	var was_above: bool = false

	var total_frames: int = int(RUN_SECONDS * 60.0)
	for frame in range(total_frames):
		await get_tree().physics_frame

		if body._target_xzw != last_target:
			retarget_frames.append(frame)
			last_target = body._target_xzw

		var effector_pos: Vector4 = ik_chain._end_effector_position()
		var distance: float = (effector_pos - foot_target.global_position).length()
		var is_above: bool = distance > SPIKE_THRESHOLD
		if is_above and not was_above:
			spike_frames.append({"frame": frame, "distance": distance})
		was_above = is_above

	print("1.retarget_count=%d retarget_frames=%s" % [retarget_frames.size(), retarget_frames])
	print("2.spike_count=%d" % spike_frames.size())

	var coincident_count: int = 0
	for spike in spike_frames:
		var spike_frame: int = spike["frame"]
		# Nearest PRECEDING retarget (a spike should follow a retarget, not the other way around).
		var nearest_preceding: int = -1
		for retarget_frame in retarget_frames:
			if retarget_frame <= spike_frame:
				nearest_preceding = retarget_frame
			else:
				break
		if nearest_preceding == -1:
			print("spike_frame=%d distance=%.4f -> no preceding retarget at all (t=%.3fs)" % [spike_frame, spike["distance"], spike_frame / 60.0])
			continue
		var gap_frames: int = spike_frame - nearest_preceding
		var gap_sec: float = gap_frames / 60.0
		var is_coincident: bool = gap_sec <= 0.35 # generous margin over one slew_time_constant_sec (0.35s)
		if is_coincident:
			coincident_count += 1
		print("spike_frame=%d (t=%.3fs) distance=%.4f <- nearest_preceding_retarget=%d (t=%.3fs) gap=%.3fs coincident=%s" % [
			spike_frame, spike_frame / 60.0, spike["distance"], nearest_preceding, nearest_preceding / 60.0, gap_sec, is_coincident,
		])

	print("3.coincident_spikes=%d/%d" % [coincident_count, spike_frames.size()])
	print("DONE")
	get_tree().quit()
