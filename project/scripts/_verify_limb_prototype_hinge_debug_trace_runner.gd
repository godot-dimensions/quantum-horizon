extends Node
## TEMPORARY - minimal frame-by-frame trace of the constrained FL chain
## solving toward a TRIVIALLY reachable target (radius=1.0 from the anchor,
## well inside max_reach=7.5 and well inside even the current wide hinge
## ranges), to find WHERE the CCD sweep gets stuck. Written because widening
## hinge_min_deg/max_deg dramatically (e.g. joint0 -30..60 -> -90..90) had
## ZERO effect on the reach-probe's constrained_reach results (stayed
## exactly 0.000 in every direction, bit-identical before and after) - that
## insensitivity to the actual range VALUES is a strong signal of a real
## bug in the constraint/CCD interaction, not a range-tuning problem.
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.

const TRACE_FRAMES := 300


func _reset_chain(ik_chain: Node) -> void:
	for joint in ik_chain.joints:
		joint.global_basis = Projection()


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("Body")
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchorFL/IKChain")
	var anchor: Node4D = flat_plane.get_node("Body/LimbAnchorFL")
	var foot_target: Node4D = flat_plane.get_node("FootTargetFL")

	body.speed = 0.0
	foot_target.set_physics_process(false)

	print("1.hinge_min_deg=%s hinge_max_deg=%s hinge_bend_sign=%s root_forward_local=%s sweeps_per_frame=%d" % [
		ik_chain.hinge_min_deg, ik_chain.hinge_max_deg, ik_chain.hinge_bend_sign, ik_chain.root_forward_local, ik_chain.sweeps_per_frame,
	])

	# A REAL failing sample from _verify_limb_prototype_hinge_diagnosis_runner.gd's
	# most recent run (post plane-fix), not a synthetic direction - this is
	# the exact geometry that still failed to converge (residual 2.26) even
	# with the plane bug fixed and a 500-frame budget.
	var rel := Vector4(-0.33783615707895, -4.5, -1.41893646474045, 0.0)
	var target_pos: Vector4 = anchor.global_position + rel
	print("2.anchor=%s target=%s (real failing sample, rel=%s)" % [anchor.global_position, target_pos, rel])

	foot_target.global_position = target_pos
	_reset_chain(ik_chain)

	for frame in range(TRACE_FRAMES):
		await get_tree().physics_frame
		var effector: Vector4 = ik_chain._end_effector_position()
		var distance: float = (target_pos - effector).length()
		var angles: Array = []
		for j in range(ik_chain.joints.size()):
			angles.append(snappedf(ik_chain.get_current_hinge_angle_deg(j), 0.01))
		var joint_dirs: Array = []
		for j in range(ik_chain.joints.size()):
			joint_dirs.append(ik_chain.joints[j].global_basis.y)
		if frame < 10 or frame % 100 == 0:
			print("   frame=%d distance=%.4f angles_deg=%s joint_y_dirs=%s effector=%s" % [
				frame, distance, angles, joint_dirs, effector,
			])

	print("DONE")
	get_tree().quit()
