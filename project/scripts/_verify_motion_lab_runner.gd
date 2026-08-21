extends Node
## TEMPORARY - confirms the procedurally-built motion-lab rig actually
## works: no NaN, the ik_chain<->foot_target mutual-reference fix-up landed
## correctly (not left pointing at the temporary dummy), and rebuilding
## across limb_count/segment_count/scale/gait combinations doesn't crash or
## leave a broken rig. Not part of the shipped scene - wired in as a
## temporary autoload with limb_prototype_treadmill.tscn set as the main
## scene.

const SETTLE_FRAMES := 90 # 1.5s


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _check_rig(label: String) -> bool:
	var scene: Control = get_tree().current_scene
	var body: Node = scene.get_node("FlatPlane/MotionLabCreature/Body")
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")

	var ok: bool = true
	var expected_legs: int = body.limb_count
	var expected_segments: int = body.segment_count

	if body._leg_anchors.size() != expected_legs:
		print("  [%s] FAIL: leg anchor count = %d, expected %d" % [label, body._leg_anchors.size(), expected_legs])
		ok = false
	if body._foot_targets.size() != expected_legs:
		print("  [%s] FAIL: foot target count = %d, expected %d" % [label, body._foot_targets.size(), expected_legs])
		ok = false

	var body_pos: Vector4 = body.global_position
	if is_nan(body_pos.x) or is_nan(body_pos.y) or is_nan(body_pos.z) or is_nan(body_pos.w):
		print("  [%s] FAIL: body position is NaN: %s" % [label, body_pos])
		ok = false

	for i in range(body._leg_anchors.size()):
		var anchor: Node4D = body._leg_anchors[i]
		var ik_chain: Node = anchor.get_node("IKChain")
		if ik_chain.joints.size() != expected_segments:
			print("  [%s] FAIL: leg %d has %d joints, expected %d" % [label, i, ik_chain.joints.size(), expected_segments])
			ok = false
		# The mutual-reference fix-up landed correctly if ik_chain.target IS
		# the real FootTarget (has a "state" property, unlike the anchor
		# dummy it started as) - not just "non-null."
		if ik_chain.target == null or not ("state" in ik_chain.target):
			print("  [%s] FAIL: leg %d ik_chain.target didn't get fixed up (still the anchor dummy or null)" % [label, i])
			ok = false
		var effector: Vector4 = ik_chain._end_effector_position()
		if is_nan(effector.x) or is_nan(effector.y) or is_nan(effector.z) or is_nan(effector.w):
			print("  [%s] FAIL: leg %d effector position is NaN" % [label, i])
			ok = false
		var joint_chain_path: String = "Joint1"
		for seg in range(1, expected_segments):
			joint_chain_path += "/Joint%d" % (seg + 1)
		var foot: Node4D = ik_chain.get_node("%s/Foot" % joint_chain_path)
		var foot_pos: Vector4 = foot.global_position
		if is_nan(foot_pos.x) or is_nan(foot_pos.y) or is_nan(foot_pos.z) or is_nan(foot_pos.w):
			print("  [%s] FAIL: leg %d foot segment position is NaN" % [label, i])
			ok = false

	var gait: Node = root.get_node_or_null("GaitController")
	if gait == null:
		print("  [%s] FAIL: GaitController missing. root children: %s" % [label, root.get_children().map(func(c): return c.name)])
		ok = false
	elif gait.phase_offsets.size() != expected_legs:
		print("  [%s] FAIL: gait phase_offsets size = %d, expected %d" % [label, gait.phase_offsets.size(), expected_legs])
		ok = false

	if ok:
		print("  [%s] OK - %d legs x %d segments, gait=%s" % [label, expected_legs, expected_segments, body.current_gait])
	return ok


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var body: Node = scene.get_node("FlatPlane/MotionLabCreature/Body")

	print("=== motion lab rig check ===")
	var all_ok: bool = true

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	all_ok = _check_rig("default 4x3 walk") and all_ok

	body.select_gait("trot")
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	all_ok = _check_rig("4x3 trot") and all_ok

	body.set_limb_count(1) # 4 -> 6
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	all_ok = _check_rig("6x3 (gait forced to general set)") and all_ok

	body.set_segment_count(2) # 3 -> 5
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	all_ok = _check_rig("6x5") and all_ok

	body.set_limb_count(1) # 6 -> 8
	body.set_segment_count(-4) # 5 -> 1
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	all_ok = _check_rig("8x1") and all_ok

	body.set_body_scale(2.5)
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	all_ok = _check_rig("8x1 scale=2.5") and all_ok

	body.set_limb_count(-3) # 8 -> 2
	body.set_body_scale(0.5)
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	all_ok = _check_rig("2x1 scale=0.5") and all_ok

	body.select_gait("hop")
	body.set_limb_count(1) # 2 -> 4
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	all_ok = _check_rig("back to 4-leg, named gaits available again") and all_ok
	body.select_gait("canter_left") # exercise the full named-gait set once more.
	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	all_ok = _check_rig("4-leg cycled gait") and all_ok

	print("=== select_gait auto-unhalt check ===")
	body.halted = true
	body.select_gait("trot") # canter_left was selected above; confirm a FRESH selection un-halts too.
	print("  halted after select_gait: %s (expect false)" % body.halted)
	var gc: Node = scene.get_node("FlatPlane/MotionLabCreature/GaitController")
	var phase_at_select: float = gc.phase_progress
	for i in range(60):
		await get_tree().physics_frame
	var phase_after: float = gc.phase_progress
	var keeps_moving: bool = phase_after > phase_at_select + 0.01
	print("  phase advances after select_gait (not a one-shot twitch): %s (%.4f -> %.4f)" % [keeps_moving, phase_at_select, phase_after])
	all_ok = (not body.halted) and keeps_moving and all_ok

	print("=== halt check (KEY_0 toggle) ===")
	body.halted = true # select_gait's own auto-unhalt (checked above) left this false - re-set to isolate this check's own precondition.
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var gait: Node = root.get_node("GaitController")
	var phase_while_halted: float = gait.phase_progress
	for i in range(30):
		await get_tree().physics_frame
	var phase_still_halted: float = gait.phase_progress
	var halted_holds: bool = is_equal_approx(phase_while_halted, phase_still_halted)
	print("  phase_progress frozen while halted: %s (%.4f -> %.4f)" % [halted_holds, phase_while_halted, phase_still_halted])
	all_ok = halted_holds and all_ok

	body.halted = false
	for i in range(30):
		await get_tree().physics_frame
	var phase_after_unhalt: float = gait.phase_progress
	var unhalt_advances: bool = phase_after_unhalt > phase_still_halted + 0.001
	print("  phase_progress advances after unhalt: %s (-> %.4f)" % [unhalt_advances, phase_after_unhalt])
	all_ok = unhalt_advances and all_ok

	print("=== summary: all_ok=%s ===" % all_ok)
	print("DONE")
	get_tree().quit()
