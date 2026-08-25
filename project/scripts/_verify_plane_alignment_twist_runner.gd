extends Node
## TEMPORARY - two-part verification of ik_chain_controller.gd's new
## _apply_plane_alignment_twist (post-hoc bend shaping):
##
## 1. SYNTHETIC segment-length check - directly calls the function on a
##    handful of representative, hand-built GENUINELY BENT chain shapes
##    (one per distinct segment-ratio set actually used by
##    CREATURE_CLASSES: steed/giraffe's shared ratios, hopper's front
##    ratios, hopper's back ratios), at several different orientations,
##    and confirms every consecutive segment distance still matches its
##    own link_length exactly (within float epsilon) after the twist - the
##    falsifiable claim the whole post-hoc design rests on. A first version
##    of this check used a perfectly STRAIGHT test chain and passed
##    vacuously (h=0 everywhere, so the blend was a no-op) - confirmed
##    directly, not assumed, that a genuinely bent chain is what actually
##    exercises the bend algebra.
## 2. LIVE gait check - enables the feature (and clears the old, still-
##    active +-100deg placeholder hinges - see their own note below) on
##    every leg of Steed1/Hopper1/Giraffe1 in the already-built
##    creature_gallery.tscn scene, runs a real settle + gait window, and
##    confirms no NaN, every consecutive segment length stays exact
##    throughout, and effector-to-target residual stays in a clean range
##    with no spikes - plus reports twist_clamp_engaged_count per leg
##    (expected near-zero).
##
## Not part of the shipped scene - wired in as a temporary autoload with
## creature_gallery.tscn set as the main scene.

const IK_CHAIN_SCRIPT := preload("res://scripts/ik_chain_controller.gd")
const SETTLE_FRAMES := 120
const GAIT_FRAMES := 300


func _ready() -> void:
	await get_tree().process_frame
	_run_synthetic_check()
	await _run_live_check()


func _run_synthetic_check() -> void:
	print("=== synthetic segment-length preservation check (genuinely bent chains) ===")
	var ratio_sets: Dictionary = {
		"steed_giraffe": [0.4, 0.333333, 0.266667],
		"hopper_front": [0.45, 0.35, 0.20],
		"hopper_back": [0.30, 0.45, 0.25],
	}
	var total_reach := 7.5
	var directions: Array = [
		Vector4(0, -1, 0, 0),
		Vector4(0.3, -0.9, 0.2, 0.05).normalized(),
		Vector4(-0.4, -0.8, 0.3, -0.2).normalized(),
	]

	var all_ok: bool = true
	for ratio_key in ratio_sets:
		var ratios: Array = ratio_sets[ratio_key]
		var link_lengths: Array[float] = []
		for r in ratios:
			link_lengths.append(total_reach * r)

		var ik_chain := Node4D.new()
		ik_chain.set_script(IK_CHAIN_SCRIPT)
		ik_chain.link_lengths = link_lengths
		ik_chain.enable_plane_alignment_twist = true

		for dir_index in range(directions.size()):
			var base_dir: Vector4 = directions[dir_index]
			var bend_perp: Vector4 = Vector4(base_dir.z, 0, -base_dir.x, 0.1).normalized()
			var anchor_pos := Vector4(0, 10, 0, 0)
			# A genuinely bent chain - alternate a real perpendicular offset
			# per joint, matching the rough shape a real FABRIK solve leaves.
			var points: Array[Vector4] = [anchor_pos]
			var cur: Vector4 = anchor_pos
			for i in range(link_lengths.size()):
				var wobble: float = 0.35 * (1.0 if i % 2 == 0 else -1.0)
				var seg_dir: Vector4 = (base_dir + bend_perp * wobble).normalized()
				cur = cur + seg_dir * link_lengths[i]
				points.append(cur)
			var target_pos: Vector4 = points[points.size() - 1]
			var toward_target_dir: Vector4 = (target_pos - anchor_pos).normalized()

			ik_chain._apply_plane_alignment_twist(points, anchor_pos, target_pos, toward_target_dir)

			var shape_ok: bool = true
			for i in range(link_lengths.size()):
				var actual_len: float = (points[i + 1] - points[i]).length()
				if not is_equal_approx(actual_len, link_lengths[i]):
					shape_ok = false
					print("  [%s dir=%d] FAIL: segment %d length = %.6f, expected %.6f" % [ratio_key, dir_index, i, actual_len, link_lengths[i]])
			var endpoint_ok: bool = points[points.size() - 1].is_equal_approx(target_pos)
			if not endpoint_ok:
				print("  [%s dir=%d] FAIL: target endpoint moved: %s vs %s" % [ratio_key, dir_index, points[points.size() - 1], target_pos])
			var this_ok: bool = shape_ok and endpoint_ok
			all_ok = all_ok and this_ok
			print("  [%s dir=%d] %s" % [ratio_key, dir_index, "OK" if this_ok else "FAIL"])

		ik_chain.free()

	print("=== synthetic check summary: all_ok=%s ===" % all_ok)


func _run_live_check() -> void:
	print("=== live gait check (feature ON, all 3 classes) ===")
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var creature_names: Array = ["Steed1", "Hopper1", "Giraffe1"]
	var leg_names: Array = ["FL", "FR", "BL", "BR"]

	for creature_name in creature_names:
		var creature: Node = flat_plane.get_node(creature_name)
		for leg_name in leg_names:
			var ik_chain = creature.get_node("Body/LimbAnchor%s/IKChain" % leg_name)
			ik_chain.enable_plane_alignment_twist = true
			# The scenes currently ALSO have the old iteration-time hinge
			# system enabled (wide +-100deg placeholder ranges) from an
			# earlier fix. That system and this new post-hoc one are
			# alternatives, not meant to stack - a hinge clamp engaging on
			# a twist-adjusted direction would silently break the exact-
			# reconstruction guarantee this whole design relies on. Cleared
			# here for this check; cleared in the scene files too once
			# this ships (see the plan's own rollout step).
			ik_chain.joint_hinge_min_deg = Array([], TYPE_FLOAT, "", null)
			ik_chain.joint_hinge_max_deg = Array([], TYPE_FLOAT, "", null)

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame

	var max_residual: Dictionary = {}
	var any_nan: bool = false
	var any_length_mismatch: bool = false
	for frame in range(GAIT_FRAMES):
		await get_tree().physics_frame
		for creature_name in creature_names:
			var creature: Node = flat_plane.get_node(creature_name)
			for leg_name in leg_names:
				var ik_chain = creature.get_node("Body/LimbAnchor%s/IKChain" % leg_name)
				var pts: Array[Vector4] = [ik_chain.joints[0].global_position]
				for j in range(ik_chain.joints.size()):
					var jp: Node4D = ik_chain.joints[j]
					pts.append(jp.global_position + jp.global_basis.y * ik_chain.link_lengths[j])
				for j in range(pts.size() - 1):
					if is_nan(pts[j].x) or is_nan(pts[j].y) or is_nan(pts[j].z) or is_nan(pts[j].w):
						any_nan = true
						continue
					if not is_equal_approx((pts[j + 1] - pts[j]).length(), float(ik_chain.link_lengths[j])):
						any_length_mismatch = true
				var effector: Vector4 = pts[pts.size() - 1]
				var target_pos: Vector4 = ik_chain.target.global_position
				var residual: float = (effector - target_pos).length()
				var key: String = "%s/%s" % [creature_name, leg_name]
				max_residual[key] = maxf(max_residual.get(key, 0.0), residual)

	print("  any_nan=%s any_length_mismatch=%s" % [any_nan, any_length_mismatch])
	for k in max_residual:
		print("  %s: max_residual=%.4f" % [k, max_residual[k]])

	print("=== twist_clamp_engaged_count per leg (expect near-zero) ===")
	for creature_name in creature_names:
		var creature: Node = flat_plane.get_node(creature_name)
		for leg_name in leg_names:
			var ik_chain = creature.get_node("Body/LimbAnchor%s/IKChain" % leg_name)
			print("  %s %s: %d" % [creature_name, leg_name, ik_chain.twist_clamp_engaged_count])

	print("DONE")
	get_tree().quit()
