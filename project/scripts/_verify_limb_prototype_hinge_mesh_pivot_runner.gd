extends Node
## TEMPORARY - STEP 2 of the hinge diagnosis: for one static real pose,
## compares three independently-computed Y-coordinates that all claim to
## represent "where the FL foot touches the ground":
##   (a) the raycast's own ground-hit Y (what _compute_live_target() saw)
##   (b) the IK chain's end-effector Y (ik_chain._end_effector_position())
##   (c) the rendered foot mesh's (ExtensionMesh3) actual bottom-most world Y,
##       read via MeshInstance4D.get_rect_bounds_global() - the engine's own
##       bound AABB query (Mesh4D::get_rect_bounds(), confirmed present and
##       GDScript-exposed via Node4D.get_rect_bounds_global on
##       MeshInstance4D), not a hand-derived guess.
## Isolates whether ground-clipping (if any) is a real IK-target miss (b far
## from a) or a mesh-origin/pivot offset (c far from b) - they need
## different fixes, so this measures both independently instead of assuming
## either.
##
## Background derivation (to be confirmed here, not trusted blindly):
## OrthoplexTetraMesh4D is symmetric about its own local origin (vertices at
## +-size/2 on each axis - confirmed against the engine's own C++ source).
## ExtensionMesh3 sits at LOCAL position (0, link_lengths[2]/2, 0, 0) under
## joint3 with mesh size.y = link_lengths[2], so its local +Y vertex should
## transform to EXACTLY joint3.global_position + joint3.global_basis.y *
## link_lengths[2] - i.e. exactly the same point _end_effector_position()
## computes. If that's right, (b) and (c) should coincide almost exactly;
## if they don't, the derivation (or an assumption in it, e.g. no extra
## local rotation on ExtensionMesh3) is wrong somewhere and needs a second
## look, not a forced fix.
##
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.

const SETTLE_FRAMES := 120


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var body: Node4D = flat_plane.get_node("Body")
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchorFL/IKChain")
	var foot_target: Node4D = flat_plane.get_node("FootTargetFL")
	var extension_mesh3: MeshInstance4D = flat_plane.get_node("Body/LimbAnchorFL/IKChain/Joint1/Joint2/Joint3/ExtensionMesh3")

	print("1.nodes_resolve: ik_chain=%s foot_target=%s extension_mesh3=%s" % [ik_chain != null, foot_target != null, extension_mesh3 != null])

	# Let the real, live FSM run normally (real raycast targets, real hinge-
	# constrained solve) until FL is settled and PLANTED, so this is a real
	# in-context pose, not an artificially-posed one.
	var settle_frames_elapsed: int = 0
	while foot_target.state != foot_target.FootState.PLANTED or settle_frames_elapsed < SETTLE_FRAMES:
		await get_tree().physics_frame
		settle_frames_elapsed += 1
		if settle_frames_elapsed > 3600: # 60s safety cap.
			print("TIMEOUT waiting for FL to settle into PLANTED - aborting.")
			print("DONE")
			get_tree().quit()
			return

	# (a) The raycast ground-hit that produced this exact plant, read
	# straight from the live FSM's own last-known target computation - the
	# most direct "what did the raycast actually see" signal available
	# without duplicating its raycast logic here.
	var raycast_target: Vector4 = foot_target.locked_position
	print("2.raycast_ground_hit_locked_position=%s (y=%.5f)" % [raycast_target, raycast_target.y])

	# (b) IK end-effector, computed the exact same way the solver itself
	# does.
	var effector_pos: Vector4 = ik_chain._end_effector_position()
	print("3.ik_end_effector_position=%s (y=%.5f)" % [effector_pos, effector_pos.y])

	# (c) Rendered mesh AABB, via the engine's own bound query - printed raw
	# first since this binding's exact return shape hasn't been used
	# anywhere else in this codebase yet (confirmed via search), so it's
	# worth seeing the actual shape before assuming how to index it.
	var rect_bounds = extension_mesh3.get_rect_bounds_global()
	print("4.extension_mesh3_get_rect_bounds_global_raw=%s (type=%s)" % [rect_bounds, typeof(rect_bounds)])

	# Cross-check via direct transform of the known local vertex (per the
	# header comment's derivation) - independent of how to interpret (4)'s
	# raw shape.
	var half_extent_y: float = extension_mesh3.mesh.size.y * 0.5
	var mesh_plus_y_world: Vector4 = extension_mesh3.global_position + extension_mesh3.global_basis.y * half_extent_y
	var mesh_minus_y_world: Vector4 = extension_mesh3.global_position - extension_mesh3.global_basis.y * half_extent_y
	print("5.manual_transform: mesh_size_y=%.4f half_extent_y=%.4f mesh_local_plusY_world=%s (y=%.5f) mesh_local_minusY_world=%s (y=%.5f)" % [
		extension_mesh3.mesh.size.y, half_extent_y, mesh_plus_y_world, mesh_plus_y_world.y, mesh_minus_y_world, mesh_minus_y_world.y,
	])

	var mesh_bottom_y: float = minf(mesh_plus_y_world.y, mesh_minus_y_world.y)
	print("6.=== SUMMARY ===")
	print("   raycast_ground_y=%.5f" % raycast_target.y)
	print("   ik_effector_y=%.5f (diff_from_raycast=%.5f)" % [effector_pos.y, effector_pos.y - raycast_target.y])
	print("   mesh_bottom_y_manual=%.5f (diff_from_effector=%.5f, diff_from_raycast=%.5f)" % [
		mesh_bottom_y, mesh_bottom_y - effector_pos.y, mesh_bottom_y - raycast_target.y,
	])

	print("DONE")
	get_tree().quit()
