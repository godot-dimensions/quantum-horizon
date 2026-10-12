extends Node
## TEMPORARY - verifies area_capture_test.tscn's draw/preview/lock-in loop
## end to end, including that the preview box picks up a real w-extent when
## the player's aim direction changes w-component between the two corner
## presses (not just x/z). Not part of the shipped scene. Wired in as a
## temporary autoload with area_capture_test.tscn set as the main scene.

const DRAW_AREA := &"draw_area"


func _press_action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Node4D = get_tree().current_scene
	var player: CharacterBody4D = scene.get_node("Player")
	var player_head: Node4D = scene.get_node("Player/PlayerHead")
	var controller: Node = scene.get_node("AreaCapture")
	var cluster: Node = scene.get_node("TargetCluster")
	var radar: Control = scene.get_node("HUD/RadarOrbHud/SliceRadar")

	print("1.nodes_resolve: player=%s player_head=%s controller=%s cluster=%s radar=%s (expect all true)" % [
		player != null, player_head != null, controller != null, cluster != null, radar != null,
	])
	print("1b.cluster_cube_count: %d (expect 5)" % [cluster.cubes.size()])
	for i in cluster.cubes.size():
		print("1c.cube[%d]_position: %s" % [i, cluster.cubes[i].position])
	print("1d.radar_refs_resolve: player=%s cluster=%s (expect both true)" % [
		radar._player != null, radar._target_cluster != null,
	])

	# Ghost placement-preview: idle, no press yet. A reachable straight-down
	# look should show it; the same look from far above (out of
	# GHOST_MAX_DISTANCE) should hide it.
	player.global_position = Vector4(0, 5, 10, 0)
	player.global_basis = Projection()
	player_head.basis = Basis4D.looking_at(Vector4(0, -1, 0, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("1e.ghost_visible_in_range: %s position=%s (expect true, near player's feet)" % [
		controller._ghost_indicator.visible, controller._ghost_indicator.position,
	])

	player.global_position = Vector4(0, 25, 10, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("1f.ghost_hidden_out_of_range: %s (expect true - distance ~24.8 > GHOST_MAX_DISTANCE=15, so ghost should be hidden)" % [
		not controller._ghost_indicator.visible,
	])
	player.global_position = Vector4(0, 5, 10, 0)

	# Default spawn orientation (identity basis, facing -z) already looks
	# roughly toward the cluster (spawn z=10, cluster z=2) - a plain forward
	# view, no aim setup needed, to see the cluster + radar as a player would.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _screenshot("area_capture_cluster_and_radar.png")

	# Deterministic aim, no mouse involved - identity body basis, PlayerHead's
	# own basis pointed down-and-forward via Basis4D.looking_at (builds an
	# orthonormal basis whose -z axis - the direction player_head.gd/
	# area_capture_controller.gd's raycast actually uses - points along the
	# given direction), rather than guessing from_yz's exact sign convention.
	player.global_position = Vector4(0, 5, 10, 0)
	player.global_basis = Projection()
	player_head.basis = Basis4D.looking_at(Vector4(0, -1, -0.3, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("2a.aim_a: origin=%s direction=%s" % [player_head.global_position, -player_head.global_basis.z])
	await _press_action(DRAW_AREA)
	print("2b.after_first_press: drawing=%s corner_a=%s (expect drawing=true, corner_a.y near 0 - ground top)" % [
		controller._drawing, controller._corner_a,
	])
	await _screenshot("area_capture_corner_a.png")

	# Second aim: same downward/forward lean, but now with a real w-component -
	# rotating the 4D slice between the two placements is exactly what should
	# let the resulting box pick up a genuine w-extent, per the design.
	player_head.basis = Basis4D.looking_at(Vector4(0, -1, -0.3, 0.9))
	await get_tree().physics_frame
	await get_tree().physics_frame

	print("3a.aim_b: origin=%s direction=%s" % [player_head.global_position, -player_head.global_basis.z])
	print("3b.live_preview_before_second_press: box_exists=%s size=%s position=%s" % [
		controller._preview_box != null,
		controller._preview_box.mesh.size if controller._preview_box != null else null,
		controller._preview_box.position if controller._preview_box != null else null,
	])
	var w_extent: float = controller._preview_box.mesh.size.w if controller._preview_box != null else 0.0
	print("3c.w_extent_picked_up: %.3f (expect clearly > MIN_AXIS_EXTENT=0.3, ideally several units - confirms the box is NOT flattened to the x/z footprint)" % [w_extent])
	await _screenshot("area_capture_live_preview.png")

	await _press_action(DRAW_AREA)
	print("4a.after_second_press: drawing=%s captured_count=%d (expect drawing=false, captured_count=1)" % [
		controller._drawing, controller.captured_boxes.size(),
	])
	if controller.captured_boxes.size() > 0:
		var box: MeshInstance4D = controller.captured_boxes[0]
		var mat: TetraMaterial4D = box.material_override
		print("4b.captured_material_color: %s (expect CAPTURED_COLOR (0.9,0.7,0.1,1.0), NOT the translucent preview color)" % [mat.albedo_color])
	await _screenshot("area_capture_locked_in.png")

	# Look back toward a more forward-facing view (matching the opening
	# cluster_and_radar shot) so the radar's dome and the now-captured box's
	# footprint indicator are both actually visible in frame together.
	player.global_basis = Projection()
	player_head.basis = Basis4D.looking_at(Vector4(0, -1, -0.3, 0.0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _screenshot("area_capture_radar_with_area.png")

	# 5. Confirm a fresh draw cycle starts cleanly and doesn't erase the
	# already-captured box.
	player_head.basis = Basis4D.looking_at(Vector4(0, -1, 0.5, -0.4))
	await get_tree().physics_frame
	await _press_action(DRAW_AREA)
	print("5a.second_box_starts: drawing=%s corner_a=%s captured_count_unchanged=%d (expect drawing=true, captured_count still 1)" % [
		controller._drawing, controller._corner_a, controller.captured_boxes.size(),
	])

	# 6. Reset button (R / reset_capture) - clears everything, including the
	# box still mid-draw.
	await _press_action(&"reset_capture")
	print("6a.after_reset: drawing=%s captured_count=%d preview_box_is_null=%s (expect drawing=false, captured_count=0, preview_box_is_null=true)" % [
		controller._drawing, controller.captured_boxes.size(), controller._preview_box == null,
	])
	await _screenshot("area_capture_after_reset.png")

	print("DONE")
	get_tree().quit()
