extends Node
## TEMPORARY - directly tests the two hypotheses raised about the motion
## lab's "flicking last segment" symptom: (1) is the resting leg actually
## near-fully-extended (little bend budget), and (2) is the per-step swing
## target displacement small relative to total limb length (so only the
## terminal segment needs to move to satisfy it)? Logs real numbers
## instead of reasoning from a screenshot. Wired in as a temporary
## autoload with limb_prototype_treadmill.tscn set as the main scene.

const SETTLE_FRAMES := 90


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("MotionLabCreature/Body")

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	body.select_gait("walk")

	var leg_anchor: Node4D = body._leg_anchors[0] # FL-equivalent (pair 0, side 0).
	var ik_chain = leg_anchor.get_node("IKChain")
	var foot_target = body.get_parent().get_node("FootTarget0")

	var total_reach: float = 0.0
	for l in ik_chain.link_lengths:
		total_reach += l

	print("=== resting-height / utilization check ===")
	print("  total_reach=%.3f" % total_reach)
	print("  hip (anchor) global_position.y=%.3f" % leg_anchor.global_position.y)
	print("  ankle target (FABRIK's own target) global_position.y=%.3f" % foot_target.global_position.y)
	print("  true ground contact point (foot_target.locked_ground_point).y=%.3f" % foot_target.locked_ground_point.y)
	var vertical_span_to_ankle: float = leg_anchor.global_position.y - foot_target.global_position.y
	var vertical_span_to_ground: float = leg_anchor.global_position.y - foot_target.locked_ground_point.y
	print("  vertical span hip->ankle-target = %.3f (%.1f%% of total_reach)" % [vertical_span_to_ankle, 100.0 * vertical_span_to_ankle / total_reach])
	print("  vertical span hip->true-ground = %.3f (%.1f%% of total_reach)" % [vertical_span_to_ground, 100.0 * vertical_span_to_ground / total_reach])

	print("=== per-joint bend angle during a real step (dot product between consecutive segment directions - 1.0 = perfectly straight) ===")
	var last_state: int = -1
	var step_count: int = 0
	for i in range(600): # 10s - several full gait cycles.
		await get_tree().physics_frame
		if foot_target.state != last_state:
			last_state = foot_target.state
			if last_state == 1: # LIFTING - a new step just started.
				step_count += 1
				var swing_dist: float = (foot_target.swing_target_position - foot_target.swing_start_position).length()
				print("  step %d: swing displacement=%.4f (%.1f%% of total_reach)" % [step_count, swing_dist, 100.0 * swing_dist / total_reach])
				var joints: Array = ik_chain.joints
				var dirs: Array = []
				for j in joints:
					dirs.append(j.global_basis.y)
				for j in range(dirs.size() - 1):
					print("    joint %d->%d dot=%.4f" % [j, j + 1, dirs[j].dot(dirs[j + 1])])
		if step_count >= 4:
			break

	print("DONE")
	get_tree().quit()
