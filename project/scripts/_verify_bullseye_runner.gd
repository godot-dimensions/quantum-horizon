extends Node
## TEMPORARY - verifies bullseye_range.tscn (rail mode + bullseye targets
## consolidated) end to end. Not part of the shipped scene.

@onready var player: CharacterBody4D = $"../Range/FlatPlane/Player"
@onready var player_head: Node4D = $"../Range/FlatPlane/Player/PlayerHead"
@onready var start_trigger: Area4D = $"../Range/FlatPlane/StartTrigger"
@onready var spawner: Node4D = $"../Range/FlatPlane/RailTargetSpawner"
@onready var weapon: Node = $"../Range/BullseyeWeapon"
@onready var rail_controller: Node = $"../Range/RailController"
@onready var stats_hud: Control = $"../Range/RailStatsHud"
@onready var crosshair: Control = $"../Range/Crosshair"
@onready var gun_core: Node4D = $"../Range/FlatPlane/Player/PlayerHead/FirstPersonCamera/GunViewmodel/Core"
@onready var projectiles: Node4D = $"../Range/FlatPlane/Projectiles"

const SHOT_RESOLUTION_TIMEOUT_FRAMES := 220

func _wait_physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _wait_process_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _fire_and_await_resolution() -> Dictionary:
	var result: Dictionary = {"resolved": false, "hit": false, "ring_score": -1, "slice_score_percent": -1}
	var on_resolved := func(hit: bool, ring_score: int, slice_score_percent: int) -> void:
		result.resolved = true
		result.hit = hit
		result.ring_score = ring_score
		result.slice_score_percent = slice_score_percent
	weapon.shot_resolved.connect(on_resolved)
	weapon._fire()
	var frames_waited := 0
	while not result.resolved and frames_waited < SHOT_RESOLUTION_TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames_waited += 1
	weapon.shot_resolved.disconnect(on_resolved)
	return result

func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)

## Reproduces bullseye_target.gd's own get_alignment_t() formula exactly -
## an independent regression check of the implementation.
func _expected_alignment_t(target_position: Vector4) -> float:
	var rel: Vector4 = target_position - player.global_position
	var ana_offset: float = rel.dot(player.global_basis.w)
	var rel_length: float = rel.length()
	var angle_deg: float = absf(rad_to_deg(asin(clampf(ana_offset / rel_length, -1.0, 1.0)) if rel_length > 0.0001 else 0.0))
	var inner_threshold_deg: float = rad_to_deg(asin(clampf(0.25 / rel_length, -1.0, 1.0))) if rel_length > 0.0001 else 0.0
	if angle_deg <= inner_threshold_deg:
		return 1.0
	if angle_deg >= 30.0:
		return 0.0
	var t: float = clampf((30.0 - angle_deg) / (30.0 - inner_threshold_deg), 0.0, 1.0)
	return t * t

func _ready() -> void:
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run()

func _run() -> void:
	await _wait_physics_frames(30)

	# 1. Basic resolution: everything wired up, 5 targets spawned at _ready().
	print("1a.nodes_resolve: player=%s start_trigger=%s spawner=%s weapon=%s rail_controller=%s stats_hud=%s" % [
		player != null, start_trigger != null, spawner != null, weapon != null, rail_controller != null, stats_hud != null,
	])
	print("1b.five_targets_spawned: count=%d (expect 5)" % [spawner._targets.size()])
	print("1c.mount_attached_under_player: mount_exists=%s (expect true)" % [
		player.has_node("Mount") and player.get_node("Mount").get_child_count() > 0,
	])

	# 2. Ring scoring - direct calls at known offsets against one of the
	# spawned targets, repositioned to a clean, known spot.
	var target: Node4D = spawner._targets[0]
	target.global_position = Vector4(0, 1.5, -6, 0)
	var ring_cases: Array = [
		[Vector2(0.0, 0.0), 10],
		[Vector2(0.15, 0.0), 9],
		[Vector2(0.95, 0.0), 1],
		[Vector2(1.5, 0.0), 0],
	]
	for i in ring_cases.size():
		var offset: Vector2 = ring_cases[i][0]
		var expected: int = ring_cases[i][1]
		var world_point: Vector4 = target.global_position + Vector4(offset.x, offset.y, 0, 0)
		var actual: int = target.get_ring_score(world_point)
		print("2%s.ring_score(offset=%s): expected=%d actual=%d (match=%s)" % [
			"abcd"[i], offset, expected, actual, expected == actual,
		])

	# 3. Slice-alignment scoring - direct calls, player fixed at a known pose.
	player.global_position = Vector4(0, 1, 6, 0)
	player.global_basis = Projection()
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
	target.global_position = Vector4(0, 1.5, -6, 0)
	var expected_aligned: float = _expected_alignment_t(target.global_position)
	var actual_aligned: float = target.get_alignment_t()
	print("3a.alignment_dead_on: expected=%.4f actual=%.4f (match=%s, expect ~1.0)" % [
		expected_aligned, actual_aligned, is_equal_approx(expected_aligned, actual_aligned),
	])

	# 4. Start trigger fires via genuine physics overlap - walk forward with
	# real WASD input from the starting area, not a teleport. A teleport
	# doesn't work here: this engine's physics backend (AxisAlignedBox
	# PhysicsEngine4D) only detects area entry via a same-tick swept-motion
	# check against a position cache that refreshes at the END of each tick -
	# a teleport races that cache with a near-zero-motion sweep on the very
	# next tick, and the entry edge gets skipped PERMANENTLY (not delayed -
	# confirmed against the engine source: by the following tick the cache
	# has already caught up to the teleported position, so the "was this
	# already overlapping" check reads true and the entry gate never opens).
	# Real incremental WASD motion has no such gap - the cached "before" rect
	# is always genuinely one tick behind, not a discontinuous jump.
	player.global_position = Vector4(0, 1, 6, 0)
	player.global_basis = Projection()
	player.linear_velocity = Vector4.ZERO
	await _wait_physics_frames(3)
	var trigger_fired: Array = [false]
	var on_triggered := func(_body: PhysicsBody4D) -> void: trigger_fired[0] = true
	start_trigger.triggered.connect(on_triggered)
	Input.action_press(&"move_forward")
	var walk_frames := 0
	while not trigger_fired[0] and walk_frames < 120:
		await get_tree().physics_frame
		walk_frames += 1
	Input.action_release(&"move_forward")
	print("4a.start_trigger_fires_on_overlap: fired=%s walk_frames=%d (expect true, well under 120)" % [
		trigger_fired[0], walk_frames,
	])
	start_trigger.triggered.disconnect(on_triggered)

	# 5. Ride actually started: translation locked, snapped to PATH_START.
	print("5a.ride_started: riding=%s rail_locked=%s position=%s (expect true, true, ~PATH_START)" % [
		rail_controller._riding, player.rail_locked, player.global_position,
	])

	# 6. WASD is ignored while locked - simulated input shouldn't move the
	# player off the rail's own lerp.
	var position_before_input: Vector4 = player.global_position
	Input.action_press(&"move_forward")
	await _wait_physics_frames(3)
	Input.action_release(&"move_forward")
	var position_after_input: Vector4 = player.global_position
	var expected_position: Vector4 = rail_controller.PATH_START.lerp(
		rail_controller.PATH_END, clampf(rail_controller._elapsed_sec / rail_controller.RIDE_DURATION_SEC, 0.0, 1.0)
	)
	print("6a.wasd_ignored_while_locked: position=%s expected_from_lerp=%s (match=%s, not position_before=%s)" % [
		position_after_input, expected_position, position_after_input.is_equal_approx(expected_position), position_before_input,
	])

	# 7. Mouse-look and slice-rotation stay fully live while locked - call
	# player._input() directly with a synthetic mouse-motion event (same
	# code path a real mouse move takes, bypassing the Input system itself
	# for a deterministic test).
	var basis_before_look: Projection = player.global_basis
	var look_event := InputEventMouseMotion.new()
	look_event.relative = Vector2(80, 0)
	player._input(look_event)
	var basis_after_look: Projection = player.global_basis
	print("7a.mouselook_live_while_locked: basis_changed=%s rail_still_locked=%s (expect true, true)" % [
		not basis_after_look.x.is_equal_approx(basis_before_look.x), player.rail_locked,
	])
	player.global_basis = Projection() # Reset for the aim tests below.
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0

	# 8. Multi-target hit resolution during the ride - reposition a target to
	# the muzzle's own x/y line (same barrel-offset correction as before) so
	# the shot lands dead center, confirm the running totals update, and
	# confirm the spawner's own target count drops by exactly one (consumed,
	# not respawned mid-ride).
	var targets_before_hit: int = spawner._targets.size()
	var score_updates: Array = []
	var on_score_updated := func(aim_total: int, slice_total: int) -> void: score_updates.append([aim_total, slice_total])
	rail_controller.score_updated.connect(on_score_updated)
	var muzzle: Vector4 = weapon.gun_barrel.global_position
	target.global_position = Vector4(muzzle.x, muzzle.y, target.global_position.z, 0)
	await _wait_physics_frames(2)
	var hit_result: Dictionary = await _fire_and_await_resolution()
	print("8a.dead_center_hit_during_ride: resolved=%s hit=%s ring_score=%d slice_score_percent=%d (expect true, true, 10, ~100)" % [
		hit_result.resolved, hit_result.hit, hit_result.ring_score, hit_result.slice_score_percent,
	])
	print("8b.target_consumed_not_respawned: targets %d->%d (expect -1)" % [targets_before_hit, spawner._targets.size()])
	print("8c.run_totals_updated: score_updates=%s (expect one entry, [10, 100])" % [score_updates])
	rail_controller.score_updated.disconnect(on_score_updated)

	# 9. Completion - force-advance the ride and confirm ride_completed fires
	# with the accumulated totals, and the HUD shows the results text.
	var completed_totals: Array = [null, null]
	# Mutate the array's slots, not the outer variable itself - reassigning
	# a captured local inside a lambda doesn't propagate back out in
	# GDScript, only mutating a shared container's contents does (same
	# reason _fire_and_await_resolution() above sets result.resolved = true
	# rather than result = {...}).
	var on_completed := func(aim_total: int, slice_total: int) -> void:
		completed_totals[0] = aim_total
		completed_totals[1] = slice_total
	rail_controller.ride_completed.connect(on_completed)
	rail_controller._elapsed_sec = rail_controller.RIDE_DURATION_SEC
	await _wait_physics_frames(2)
	print("9a.ride_completed_fires: totals=%s riding=%s (expect [10, 100]-ish, false)" % [completed_totals, rail_controller._riding])
	print("9b.hud_shows_results: label=%s (expect it to contain RIDE COMPLETE)" % [stats_hud.label.text])
	rail_controller.ride_completed.disconnect(on_completed)

	# 10. Auto-reset after the results display window - force-advance the
	# results timer and confirm the full reset: teleport, unlock, all 5
	# targets respawned fresh, HUD reverts to "Ready".
	rail_controller._results_timer_sec = 0.01
	await _wait_physics_frames(3)
	print("10a.auto_reset: position=%s rail_locked=%s target_count=%d (expect ~RESET_POSITION, false, 5)" % [
		player.global_position, player.rail_locked, spawner._targets.size(),
	])
	print("10b.hud_reverts_to_ready: label=%s (expect it to contain Ready)" % [stats_hud.label.text])

	# 11. Re-arm: the same trigger fires again for a second ride via another
	# genuine walk-in (same reasoning as test 4 - no teleports), and the
	# session-best comparison correctly tracks the max across both runs, not
	# just the latest one.
	player.global_basis = Projection()
	player.linear_velocity = Vector4.ZERO
	await _wait_physics_frames(3)
	var second_trigger_fired: Array = [false]
	var on_triggered_2 := func(_body: PhysicsBody4D) -> void: second_trigger_fired[0] = true
	start_trigger.triggered.connect(on_triggered_2)
	Input.action_press(&"move_forward")
	var walk_frames_2 := 0
	while not second_trigger_fired[0] and walk_frames_2 < 120:
		await get_tree().physics_frame
		walk_frames_2 += 1
	Input.action_release(&"move_forward")
	print("11a.trigger_rearmed: fired_again=%s walk_frames=%d (expect true, well under 120)" % [second_trigger_fired[0], walk_frames_2])
	start_trigger.triggered.disconnect(on_triggered_2)

	# Second run scores lower than the first (0 vs 10) - session best should
	# still report the FIRST run's higher totals, not be overwritten by this
	# smaller second run.
	rail_controller._elapsed_sec = rail_controller.RIDE_DURATION_SEC
	await _wait_physics_frames(2)
	print("11b.session_best_survives_lower_run: label=%s (expect best still 10 / 100, this run's own totals 0 / 0)" % [stats_hud.label.text])

	# Reset once more, back to a clean state for the visual check below.
	rail_controller._results_timer_sec = 0.01
	await _wait_physics_frames(3)

	# Visual check.
	player.global_position = Vector4(0, 1, 6, 0)
	player.global_basis = Projection()
	await _wait_physics_frames(2)
	await _screenshot("bullseye_range.png")

	print("DONE")
