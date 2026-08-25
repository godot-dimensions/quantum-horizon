extends Node
## TEMPORARY - Step 2 of the limb-prototype: confirms the raycast-driven
## foot target actually lands on the ground and the limb's effector
## converges to it continuously as the body wanders - and separately
## confirms the wander path genuinely varies in W, not just X/Z, since a
## flat W would make the "4D-ness" of this whole prototype meaningless. Not
## part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_test.tscn set as the main scene.

const RUN_SECONDS := 10.0
const SAMPLE_INTERVAL_FRAMES := 30 # 0.5s at 60fps
const SCREENSHOT_INTERVAL_FRAMES := 120 # 2s at 60fps


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
	var foot_target: Node4D = flat_plane.get_node("FootTarget")
	var ik_chain: Node = flat_plane.get_node("Body/LimbAnchor/IKChain")

	print("1.nodes_resolve: player=%s body=%s foot_target=%s ik_chain=%s" % [
		player != null, body != null, foot_target != null, ik_chain != null,
	])

	_reset_chain(ik_chain)

	# Fixed external observer - not the wandering body, not the foot target.
	player.global_basis = Projection()
	player.global_position = Vector4(0, 6, -8, 0)
	player.global_basis = Basis4D.looking_at(body.position - player.global_position)

	var total_frames: int = int(RUN_SECONDS * 60.0)
	var min_w: float = INF
	var max_w: float = -INF
	var all_hits: bool = true
	var shot_index: int = 0
	for frame in range(total_frames):
		await get_tree().physics_frame
		min_w = minf(min_w, body.position.w)
		max_w = maxf(max_w, body.position.w)
		if not foot_target.last_hit:
			all_hits = false

		if frame % SAMPLE_INTERVAL_FRAMES == 0:
			var effector_pos: Vector4 = ik_chain._end_effector_position()
			var foot_pos: Vector4 = foot_target.global_position
			var distance: float = (effector_pos - foot_pos).length()
			print("t=%.2fs body_pos=%s foot_target=%s effector_pos=%s distance=%.4f last_hit=%s" % [
				frame / 60.0, body.position, foot_pos, effector_pos, distance, foot_target.last_hit,
			])

		if frame % SCREENSHOT_INTERVAL_FRAMES == 0:
			player.global_basis = Basis4D.looking_at(body.position - player.global_position)
			await _screenshot("limb_prototype_step2_t%d.png" % shot_index)
			shot_index += 1

	print("2.w_range=[%.3f, %.3f] (span=%.3f) all_raycasts_hit=%s" % [min_w, max_w, max_w - min_w, all_hits])
	print("DONE")
	get_tree().quit()
