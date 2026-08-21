extends Node
## TEMPORARY - verifies two of the three treadmill fixes:
##   1. InfoLabel no longer overlaps Player's own PositionLabel (both
##      resolve, at different Y offsets).
##   2. Player's transform is NOT being overridden every frame anymore
##      (TreadmillCamera removed) - confirmed by checking global_position
##      stays exactly where it was placed across many frames with no input.
##   3. Body's wander stays confined to the new small range (never drifts
##      far from origin) over a real run.
## Not part of the shipped scene - wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.

const CHECK_FRAMES := 300


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: Node4D = flat_plane.get_node("Player")
	var body: Node4D = flat_plane.get_node("Body")
	var info_label: Label = scene.get_node("InfoLabel")
	var position_label: Label = player.get_node("PositionLabel")
	var treadmill_camera_exists: bool = flat_plane.has_node("TreadmillCamera")

	print("1.nodes_resolve: player=%s body=%s info_label=%s position_label=%s treadmill_camera_still_present=%s" % [
		player != null, body != null, info_label != null, position_label != null, treadmill_camera_exists,
	])
	print("2.info_label_offset_top=%.1f position_label_offset_bottom=%.1f (expect info_label below, no overlap)" % [
		info_label.offset_top, position_label.offset_bottom,
	])

	var initial_player_pos: Vector4 = player.global_position
	print("3.initial_player_position=%s" % [initial_player_pos])

	await _screenshot("limb_prototype_treadmill_fix_initial.png")

	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for i in range(CHECK_FRAMES):
		await get_tree().physics_frame
		min_x = minf(min_x, body.position.x)
		max_x = maxf(max_x, body.position.x)
		min_z = minf(min_z, body.position.z)
		max_z = maxf(max_z, body.position.z)

	var player_drift: float = (player.global_position - initial_player_pos).length()
	print("4.after_%d_frames_no_input: player_position=%s player_drift_from_initial=%.5f (expect ~0, no auto-override)" % [
		CHECK_FRAMES, player.global_position, player_drift,
	])
	print("5.body_wander_range_observed: x=[%.3f, %.3f] z=[%.3f, %.3f] (expect x within ~[-1.5,1.5], z pinned near 0)" % [
		min_x, max_x, min_z, max_z,
	])

	await _screenshot("limb_prototype_treadmill_fix_after.png")

	print("DONE")
	get_tree().quit()
