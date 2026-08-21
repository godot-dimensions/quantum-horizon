extends Node
## TEMPORARY - Step 1 of the limb-prototype: confirms the unmodified 3-joint
## ik_chain_controller.gd still converges on the player when its own ROOT
## (the floating Body) is continuously wandering underneath it, isolated
## from any foot-placement logic (that's steps 2/3). Logs BOTH the
## effector-to-player distance AND the body's own position repeatedly
## through the run, so a genuinely moving root (not a stuck one) is part of
## the evidence, not assumed. Not part of the shipped scene - wired in as a
## temporary autoload with limb_prototype_test.tscn set as the main scene.

const RUN_SECONDS := 6.0
const SAMPLE_INTERVAL_FRAMES := 30 # 0.5s at 60fps


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
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchor/IKChain")

	print("1.nodes_resolve: player=%s body=%s ik_chain=%s joint_count=%d" % [
		player != null, body != null, ik_chain != null, ik_chain.joints.size(),
	])

	var poses: Array = [
		{"name": "diag", "player_pos": Vector4(2, 0.5, 2, 0), "body_center": Vector4(2, 5, 2, 0)},
		{"name": "w_offset", "player_pos": Vector4(1, 1, 1, 2.5), "body_center": Vector4(1, 5, 1, 2.5)},
	]

	var total_frames: int = int(RUN_SECONDS * 60.0)
	for pose in poses:
		player.global_position = pose["player_pos"]
		player.global_basis = Projection()

		var center: Vector4 = pose["body_center"]
		body.position = center
		body.wander_min = Vector4(center.x - 2.5, 0, center.z - 2.5, center.w - 2.5)
		body.wander_max = Vector4(center.x + 2.5, 0, center.z + 2.5, center.w + 2.5)
		body._pick_new_target()
		_reset_chain(ik_chain)

		print("--- pose=%s player_pos=%s body_start=%s ---" % [pose["name"], player.global_position, body.position])
		var start_body_pos: Vector4 = body.position
		var max_body_displacement: float = 0.0
		for frame in range(total_frames):
			await get_tree().physics_frame
			if frame % SAMPLE_INTERVAL_FRAMES == 0:
				var effector_pos: Vector4 = ik_chain._end_effector_position()
				var distance: float = (effector_pos - player.global_position).length()
				var body_displacement: float = (body.position - start_body_pos).length()
				max_body_displacement = maxf(max_body_displacement, body_displacement)
				print("t=%.2fs body_pos=%s body_displacement_from_start=%.3f effector_pos=%s distance=%.4f" % [
					frame / 60.0, body.position, body_displacement, effector_pos, distance,
				])

		print(">>> pose=%s max_body_displacement_from_start=%.3f (proves genuine wander, not a stuck root)" % [pose["name"], max_body_displacement])

		# Numeric measurement is already done above - only the photo op moves
		# the player now. A straight-on view from the player's own actual
		# position looked directly along roughly the same line the limb
		# reaches toward, hiding the thin limb behind the body's near face
		# (confirmed directly from an earlier screenshot); offset sideways
		# instead for an angle that actually shows the limb reaching out.
		var to_body: Vector4 = body.position - player.global_position
		var horizontal: Vector4 = Vector4(to_body.x, 0, to_body.z, 0)
		var perp: Vector4 = Vector4(-horizontal.z, 0, horizontal.x, 0)
		perp = perp.normalized() if perp.length() > 0.01 else Vector4(1, 0, 0, 0)
		var photo_pos: Vector4 = player.global_position + perp * 5.0
		photo_pos.y = maxf(body.position.y, player.global_position.y) + 1.0
		player.global_position = photo_pos
		player.global_basis = Basis4D.looking_at(body.position - photo_pos)
		await get_tree().physics_frame
		await _screenshot("limb_prototype_step1_%s.png" % pose["name"])

	print("DONE")
	get_tree().quit()
