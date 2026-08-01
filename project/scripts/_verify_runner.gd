extends Node
## TEMPORARY - verifies play-area size, sprint, result persistence, and the
## POI arrow. Not part of the shipped scene.

@onready var player: CharacterBody4D = $"../Main/FlatPlane/Player"
@onready var spawner: Node4D = $"../Main/FlatPlane/TargetSpawner"
@onready var poi_arrow: Control = $"../Main/PoiArrow"

func _wait_physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _press_action(action: String) -> void:
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run()

func _run() -> void:
	await _wait_physics_frames(30)

	# 1. Play area size.
	print("1. XZ_RANGE=%s W_RANGE=%s (expect 20.0/20.0, 5x the original 4.0/4.0)" % [spawner.XZ_RANGE, spawner.W_RANGE])

	# 2. Sprint: measure distance covered in 30 ticks without vs. with Shift held.
	player.global_position = Vector4(0, 1, 0, 0)
	player.linear_velocity = Vector4.ZERO
	Input.action_press("move_forward")
	await _wait_physics_frames(30)
	Input.action_release("move_forward")
	var normal_distance: float = player.global_position.distance_to(Vector4(0, 1, 0, 0))

	player.global_position = Vector4(0, 1, 0, 0)
	player.linear_velocity = Vector4.ZERO
	var shift_event := InputEventKey.new()
	shift_event.keycode = KEY_SHIFT
	shift_event.pressed = true
	Input.parse_input_event(shift_event)
	Input.action_press("move_forward")
	await _wait_physics_frames(30)
	Input.action_release("move_forward")
	var shift_release := InputEventKey.new()
	shift_release.keycode = KEY_SHIFT
	shift_release.pressed = false
	Input.parse_input_event(shift_release)
	var sprint_distance: float = player.global_position.distance_to(Vector4(0, 1, 0, 0))
	print("2. normal_distance=%.3f sprint_distance=%.3f ratio=%.2f (expect ~2.5)" % [
		normal_distance, sprint_distance, sprint_distance / normal_distance,
	])

	# 3. Result persistence: force a catch, toggle stopwatch on then off, confirm ResultLabel stays visible.
	player.global_position = spawner._current_target.global_position
	await _press_action("catch_target")
	print("3a. after catch: catch_count=%s result_label.visible=%s text=%s" % [
		spawner._catch_count, spawner.result_label.visible, spawner.result_label.text,
	])
	await _press_action("toggle_stopwatch_display")
	await _press_action("toggle_stopwatch_display")
	print("3b. after toggling stopwatch on then off: time_label.visible=%s result_label.visible=%s (expect false/true)" % [
		spawner.time_label.visible, spawner.result_label.visible,
	])

	# 4. POI arrow: place the player at a known offset from the origin (the
	# spawn area center), try a few different Player-body orientations, and
	# for each one independently recompute the expected angle (same formula
	# the arrow script uses, but computed fresh here) directly from the
	# Player's own basis/position - not the camera's - then compare against
	# the arrow's real output, plus screenshot each for a genuine visual
	# check of shape/direction.
	var player_head: Node4D = player.get_node("PlayerHead")

	var test_bases: Array = [
		["identity", Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))],
		["yaw_a", Basis4D.from_zx(1.0)],
		["yaw_b", Basis4D.from_zx(-1.2)],
	]
	for entry in test_bases:
		var label: String = entry[0]
		player.global_position = Vector4(10, 1, 3, 0)
		player.basis = entry[1]
		player_head.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
		await _wait_physics_frames(3)
		var rel: Vector4 = Vector4.ZERO - player.global_position
		var basis: Projection = player.global_basis
		var expected_angle: float = atan2(rel.dot(basis.x), -rel.dot(basis.z))
		print("4.%s: expected_angle=%.4f arrow.rotation=%.4f (match=%s)" % [
			label, expected_angle, poi_arrow.rotation, is_equal_approx(expected_angle, poi_arrow.rotation),
		])
		await _screenshot("poi_arrow_%s.png" % label)

	# 4d. Pitch regression check: same yaw as yaw_a, but with PlayerHead
	# pitched hard up/down (yz). If the arrow reads the camera instead of the
	# Player body, pitch alone shifts the angle here even though the player
	# hasn't turned at all - this is the exact bug that was just fixed.
	player.global_position = Vector4(10, 1, 3, 0)
	player.basis = Basis4D.from_zx(1.0)
	await _wait_physics_frames(3)
	var baseline_rotation: float = poi_arrow.rotation
	player_head.basis = Basis4D.from_yz(1.4)
	await _wait_physics_frames(3)
	print("4d.pitch_up: baseline_rotation=%.4f arrow.rotation=%.4f (match=%s, expect true - pitch must not move the arrow)" % [
		baseline_rotation, poi_arrow.rotation, is_equal_approx(baseline_rotation, poi_arrow.rotation),
	])
	player_head.basis = Basis4D.from_yz(-1.4)
	await _wait_physics_frames(3)
	print("4e.pitch_down: baseline_rotation=%.4f arrow.rotation=%.4f (match=%s, expect true - pitch must not move the arrow)" % [
		baseline_rotation, poi_arrow.rotation, is_equal_approx(baseline_rotation, poi_arrow.rotation),
	])

	# 5. Real gameplay path: drive Player._input() directly with actual
	# InputEventMouseMotion events (normal-look mode, not rotate_4d), instead
	# of assigning bases by hand, then compare against an independent
	# recomputation from Player's real resulting basis after each move.
	player.global_position = Vector4(10, 1, 3, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	player_head.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	var mouse_moves: Array = [Vector2(80, 0), Vector2(-40, 60), Vector2(0, -90), Vector2(25, -25)]
	for rel in mouse_moves:
		var ev := InputEventMouseMotion.new()
		ev.relative = rel
		player._input(ev)
		await _wait_physics_frames(2)
		var rel_vec: Vector4 = Vector4.ZERO - player.global_position
		var basis: Projection = player.global_basis
		var expected_angle: float = atan2(rel_vec.dot(basis.x), -rel_vec.dot(basis.z))
		print("5.mouse_move(%s): expected_angle=%.4f arrow.rotation=%.4f (match=%s)" % [
			rel, expected_angle, poi_arrow.rotation, is_equal_approx(expected_angle, poi_arrow.rotation),
		])

	# 6. Slice-rotation (rotate_4d / left-click-drag) path: yaw first via
	# normal look, then hold rotate_4d and drag - the one input combination
	# not yet exercised (xw/zw compose onto Player's basis too).
	player.global_position = Vector4(10, 1, 3, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	player_head.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	var yaw_ev := InputEventMouseMotion.new()
	yaw_ev.relative = Vector2(60, 0)
	player._input(yaw_ev)
	await _wait_physics_frames(2)
	Input.action_press("rotate_4d")
	var slice_moves: Array = [Vector2(70, 0), Vector2(0, 50), Vector2(-30, 20)]
	for rel in slice_moves:
		var ev := InputEventMouseMotion.new()
		ev.relative = rel
		player._input(ev)
		await _wait_physics_frames(2)
		var rel_vec: Vector4 = Vector4.ZERO - player.global_position
		var basis: Projection = player.global_basis
		var expected_angle: float = atan2(rel_vec.dot(basis.x), -rel_vec.dot(basis.z))
		print("6.slice_move(%s): expected_angle=%.4f arrow.rotation=%.4f (match=%s)" % [
			rel, expected_angle, poi_arrow.rotation, is_equal_approx(expected_angle, poi_arrow.rotation),
		])
	Input.action_release("rotate_4d")
	await _screenshot("poi_arrow_slice_rotated.png")

	# 7. Degeneracy check: the player's actual spawn point is (0,1,0,0) - the
	# spawn area's horizontal center. rel's x/z/w components are all near
	# zero there, so atan2(near_zero, near_zero) is only stable in theory;
	# tiny position deltas near that point should NOT cause the arrow to
	# swing wildly if the logic is sound.
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	player_head.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	var near_origin_positions: Array = [
		Vector4(0, 1, 0, 0),
		Vector4(0.05, 1, -0.02, 0.01),
		Vector4(-0.03, 1, 0.04, -0.02),
		Vector4(0.01, 1, 0.01, -0.05),
		Vector4(0.5, 1, 0, 0),
	]
	for pos in near_origin_positions:
		player.global_position = pos
		await _wait_physics_frames(2)
		print("7.near_origin(%s): arrow.rotation=%.4f" % [pos, poi_arrow.rotation])

	# 8. Cube slice-highlight color: target's w-extent is centered at 5.0,
	# half-width 0.5, so the "middle half" (highlight zone) is 4.75..5.25.
	spawner._current_target.global_position = Vector4(0, 0.5, 0, 5.0)
	var mat: Resource = spawner._current_target_material
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	player.global_position = Vector4(0, 1, 3, 5.0)
	await _wait_physics_frames(2)
	print("8a.on_slice(w=5.0): albedo=%s (expect green)" % [mat.albedo_color])
	await _screenshot("cube_green_on_slice.png")
	player.global_position = Vector4(0, 1, 3, 5.2)
	await _wait_physics_frames(2)
	print("8b.within_middle_half(w=5.2): albedo=%s (expect green)" % [mat.albedo_color])
	player.global_position = Vector4(0, 1, 3, 5.3)
	await _wait_physics_frames(2)
	print("8c.outside_middle_half(w=5.3): albedo=%s (expect orange)" % [mat.albedo_color])
	await _screenshot("cube_orange_off_slice.png")
	player.global_position = Vector4(0, 1, 3, 6.5)
	await _wait_physics_frames(2)
	print("8d.far_off_slice(w=6.5): albedo=%s (expect orange)" % [mat.albedo_color])

	get_tree().quit()
