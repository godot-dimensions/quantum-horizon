extends Node
## TEMPORARY - verifies the shooting_gallery.tscn experiment end to end.
## Not part of the shipped scene.

@onready var player: CharacterBody4D = $"../Gallery/FlatPlane/Player"
@onready var player_head: Node4D = $"../Gallery/FlatPlane/Player/PlayerHead"
@onready var spawner: Node4D = $"../Gallery/FlatPlane/GalleryTargetSpawner"
@onready var duck_spawner: Node4D = $"../Gallery/FlatPlane/DuckRowSpawner"
@onready var poi_arrow: Control = $"../Gallery/PoiArrow"
@onready var crosshair: Control = $"../Gallery/Crosshair"
@onready var barrier: StaticBody4D = $"../Gallery/FlatPlane/Barrier"
@onready var minimap_camera: Camera4D = $"../Gallery/MiniMapContainer/MiniMapViewport/MiniMapCamera"
@onready var minimap_overlay: Control = $"../Gallery/MiniMapOverlay"
@onready var player_trail: Node = $"../Gallery/FlatPlane/PlayerTrail"
@onready var fall_respawn: Node = $"../Gallery/FlatPlane/FallRespawn"
@onready var slice_radar: Control = $"../Gallery/SliceRadar"
@onready var slice_glow: Control = $"../Gallery/SliceAlignmentGlow"
const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")

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

	# 1. Input Map: rotate_4d is right-click, fire is left-click.
	var rotate_events: Array = InputMap.action_get_events(&"rotate_4d")
	var fire_events: Array = InputMap.action_get_events(&"fire")
	print("1a.rotate_4d button_index=%s (expect 2/right-click)" % [rotate_events[0].button_index])
	print("1b.fire button_index=%s (expect 1/left-click)" % [fire_events[0].button_index])

	# 2. Node paths resolve (all @onready vars non-null).
	print("2.paths: player=%s player_head=%s spawner=%s poi_arrow=%s crosshair=%s barrier=%s" % [
		player != null, player_head != null, spawner != null, poi_arrow != null, crosshair != null, barrier != null,
	])

	# 3. Target spawn bounds: force several respawns and sample each position.
	for i in 8:
		var pos: Vector4 = spawner._current_target.global_position
		var in_xz: bool = absf(pos.x) <= 4.01 and absf(pos.z) <= 4.01
		var in_y: bool = pos.y >= 0.99 and pos.y <= 2.01
		var in_w: bool = absf(pos.w) <= 4.01
		print("3.spawn[%d]: pos=%s in_xz=%s in_y=%s in_w=%s" % [i, pos, in_xz, in_y, in_w])
		spawner._on_catch()
		await _wait_physics_frames(2)

	# 4. Barrier blocks movement: from the green floor spawn, walk toward the
	# orange floor (forward/-z) for a while and confirm the player never
	# crosses the barrier's z=5 boundary.
	player.global_position = Vector4(0, 1, 7, 0)
	player.linear_velocity = Vector4.ZERO
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	Input.action_press("move_forward")
	await _wait_physics_frames(90)
	Input.action_release("move_forward")
	print("4.barrier_blocks_walk: player.z=%.3f (expect > 5.0, i.e. stopped short of/at the barrier)" % [player.global_position.z])

	# 5. Barrier occludes raycasts: a level ray at a low height (below the
	# barrier's 1.1-unit top) crossing the barrier's z-span should hit the
	# barrier itself, not whatever's behind it - regardless of the player,
	# this is testing the barrier's own physical presence directly.
	var occlude_ray := RaycastParameters4D.new()
	occlude_ray.global_ray_origin = Vector4(0, 0.9, 7, 0) # low height, green-floor side
	occlude_ray.global_ray_direction = Vector4(0, 0, -1, 0)
	occlude_ray.collide_with_areas = true
	occlude_ray.set_exclude_nodes([player]) # test 4 left the player parked right at the barrier
	var occlude_result: Dictionary = PhysicsServer4D.raycast_physics_objects(occlude_ray)
	var hit_is_barrier: bool = occlude_result.get("hit", false) and occlude_result.get("body") == barrier
	var occlude_body: Object = occlude_result.get("body")
	print("5.barrier_occludes: hit=%s body_is_barrier=%s hit_body=%s global_point=%s (expect true, true)" % [
		occlude_result.get("hit", false), hit_is_barrier,
		(occlude_body.name if occlude_body else "<none>"), occlude_result.get("global_point"),
	])

	# 6. Hitscan catch on a direct hit: level shot at eye height (1.75, clears
	# the 1.1-tall barrier) at a target placed at that same height, directly
	# ahead, on the orange floor side.
	player.global_position = Vector4(0, 1, 7, 0) # PlayerHead is +0.75 above this -> eye height 1.75
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	spawner._current_target.global_position = Vector4(0, 1.75, 0, 0)
	await _wait_physics_frames(2)
	var before_count: int = spawner._catch_count
	var hit_ray := RaycastParameters4D.new()
	hit_ray.global_ray_origin = player_head.global_position
	hit_ray.global_ray_direction = -player_head.global_basis.z
	hit_ray.collide_with_areas = true
	hit_ray.set_exclude_nodes([player])
	var hit_result: Dictionary = PhysicsServer4D.raycast_physics_objects(hit_ray)
	var hit_body: Object = hit_result.get("body")
	var body_is_target: bool = hit_body == spawner._current_target # captured before the catch reassigns _current_target
	var caught: bool = spawner.try_catch_target(hit_body)
	print("6.hitscan_hit: hit=%s body_is_target=%s hit_body=%s caught=%s catch_count %d->%d" % [
		hit_result.get("hit", false), body_is_target, (hit_body.name if hit_body else "<none>"), caught, before_count, spawner._catch_count,
	])

	# 7. Hitscan miss: aim somewhere with nothing in front (straight up).
	var miss_before_count: int = spawner._catch_count
	var miss_ray := RaycastParameters4D.new()
	miss_ray.global_ray_origin = player_head.global_position
	miss_ray.global_ray_direction = Vector4(0, 1, 0, 0)
	miss_ray.collide_with_areas = true
	miss_ray.set_exclude_nodes([player])
	var miss_result: Dictionary = PhysicsServer4D.raycast_physics_objects(miss_ray)
	var miss_caught: bool = spawner.try_catch_target(miss_result.get("body"))
	print("7.hitscan_miss: hit=%s caught=%s catch_count unchanged=%s" % [
		miss_result.get("hit", false), miss_caught, spawner._catch_count == miss_before_count,
	])

	# 8b. Real input pipeline: simulate an actual left mouse click (not a
	# direct _fire()/raycast call) and confirm it reaches hitscan_weapon.gd's
	# _input() handler and registers a catch. This is the exact path that was
	# broken when it used _unhandled_input() - the full-screen Control root's
	# default mouse_filter=STOP silently swallows clicks before they ever
	# reach _unhandled_input, even though _input() (used by player.gd's own
	# mouse-look/rotate_4d) is unaffected by that and kept working, masking
	# the bug.
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	spawner._current_target.global_position = Vector4(0, 1.75, 0, 0)
	await _wait_physics_frames(2)
	var click_before_count: int = spawner._catch_count
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	Input.parse_input_event(click_event)
	await _wait_physics_frames(2)
	print("8a.simulated_left_click: catch_count %d->%d (expect an increment of 1)" % [click_before_count, spawner._catch_count])

	# 8. POI arrow still makes sense: player somewhere on the green floor,
	# identity basis, compare against the same independently-recomputed
	# formula used throughout the earlier verification (now against this
	# scene's actual spawn-area center, which is the orange floor's center -
	# (0,0,0,0), same as before, by design).
	player.global_position = Vector4(3, 1, 7, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	await _wait_physics_frames(3)
	var rel: Vector4 = Vector4.ZERO - player.global_position
	var basis: Projection = player.global_basis
	var expected_angle: float = atan2(rel.dot(basis.x), -rel.dot(basis.z))
	print("8.poi_arrow: expected_angle=%.4f arrow.rotation=%.4f (match=%s)" % [
		expected_angle, poi_arrow.rotation, is_equal_approx(expected_angle, poi_arrow.rotation),
	])
	# 9. Duck row: force a spawn, confirm it lands at PATH_START, and confirm
	# it actually moves along the expected velocity over real physics ticks.
	duck_spawner._spawn_timer_sec = duck_spawner.SPAWN_INTERVAL_SEC
	var ducks_before: int = duck_spawner._ducks.size()
	await _wait_physics_frames(2)
	print("9a.duck_spawns: count %d->%d (expect +1) first_pos=%s (expect PATH_START=%s)" % [
		ducks_before, duck_spawner._ducks.size(),
		(duck_spawner._ducks[0].position if duck_spawner._ducks.size() > 0 else "<none>"), duck_spawner.PATH_START,
	])
	var duck_under_test: Node4D = duck_spawner._ducks[0]
	var pos_before_move: Vector4 = duck_under_test.position
	await _wait_physics_frames(30)
	var pos_after_move: Vector4 = duck_under_test.position
	var actual_velocity: Vector4 = (pos_after_move - pos_before_move) / (30.0 / Engine.physics_ticks_per_second)
	print("9b.duck_moves: actual_velocity=%s expected_velocity=%s (expect closely matching)" % [actual_velocity, duck_spawner._velocity])

	# 10. Duck despawns when hit (via the same try_hit_duck path hitscan_
	# weapon.gd calls after the red target has already missed).
	var duck_count_before_hit: int = duck_spawner._ducks.size()
	var duck_hit: bool = duck_spawner.try_hit_duck(duck_under_test)
	print("10.duck_hit_despawns: hit_registered=%s duck_count %d->%d (expect true, -1)" % [
		duck_hit, duck_count_before_hit, duck_spawner._ducks.size(),
	])

	# 11. Duck despawns silently on reaching the far end (no hit needed) -
	# place one right at PATH_END and step one frame.
	var end_duck: Node4D = duck_spawner.DuckScene.instantiate()
	duck_spawner.add_child(end_duck)
	end_duck.position = duck_spawner.PATH_END
	duck_spawner._ducks.append(end_duck)
	var duck_count_before_end: int = duck_spawner._ducks.size()
	await _wait_physics_frames(2)
	print("11.duck_end_despawns: duck_count %d->%d (expect -1)" % [duck_count_before_end, duck_spawner._ducks.size()])

	# 11b. Solid-fill corner projections: sanity-check they land within the
	# 240x240 viewport (not degenerate/off-screen), for a known player state.
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	await _wait_physics_frames(2)
	for corner in minimap_overlay.ORANGE_FLOOR_CORNERS:
		print("11b.orange_corner_projection: world=%s screen=%s" % [corner, minimap_camera.world_to_viewport(corner)])

	# 12. Minimap camera tracks player x/z/w with a fixed pullback in z and a
	# fixed y (not tracked), and its orientation never changes even as the
	# player rotates.
	player.global_position = Vector4(2.0, 1.0, 6.0, 3.0)
	player.basis = Basis4D.from_zx(0.8) # arbitrary yaw - orientation must NOT follow this.
	await _wait_physics_frames(2)
	var expected_cam_pos := Vector4(2.0, minimap_camera.fixed_height_y, 6.0 + minimap_camera.pullback_z, 3.0)
	print("12a.minimap_tracks_player: camera_pos=%s expected=%s (expect closely matching)" % [
		minimap_camera.global_position, expected_cam_pos,
	])
	var cam_basis_before: Projection = minimap_camera.global_basis
	player.basis = Basis4D.from_zx(-1.5)
	await _wait_physics_frames(2)
	var cam_basis_after: Projection = minimap_camera.global_basis
	print("12b.minimap_orientation_fixed: basis_unchanged=%s (expect true - camera must not rotate with player look)" % [
		cam_basis_before.x.is_equal_approx(cam_basis_after.x) and cam_basis_before.y.is_equal_approx(cam_basis_after.y)
		and cam_basis_before.z.is_equal_approx(cam_basis_after.z) and cam_basis_before.w.is_equal_approx(cam_basis_after.w),
	])

	# 13. Player indicator centered by construction: since the camera tracks
	# the player's x/z/w exactly, world_to_viewport(player position) should
	# land at (or extremely near) the dead center of the 240x240 mini-map
	# viewport, i.e. (120, 120).
	await _wait_physics_frames(2)
	var player_screen_pos: Vector2 = minimap_camera.world_to_viewport(player.global_position)
	print("13.player_centered_on_minimap: screen_pos=%s (expect ~(120,120))" % [player_screen_pos])

	# 14. Trail records and ages/prunes samples.
	print("14a.trail_recording: sample_count=%d (expect > 0 after ~%.1fs of running)" % [
		player_trail.get_trail().size(), player_trail.trail_duration,
	])
	var trail_before_prune: int = player_trail.get_trail().size()
	if trail_before_prune > 0:
		player_trail.get_trail()[0]["age"] = player_trail.trail_duration + 1.0
	await _wait_physics_frames(2)
	print("14b.trail_prunes_stale: count %d->%d (expect a decrease, stale sample pruned)" % [
		trail_before_prune, player_trail.get_trail().size(),
	])

	# 15. Fall-respawn: drop the player far below the death threshold with a
	# distinct position/basis, confirm it's teleported back to the original
	# spawn transform (captured by fall_respawn.gd at _ready(), before this
	# test ever moved the player) with velocity zeroed.
	var expected_spawn_pos: Vector4 = fall_respawn._spawn_position
	var expected_spawn_basis: Projection = fall_respawn._spawn_basis
	player.global_position = Vector4(3, -20, 4, -2)
	player.basis = Basis4D.from_zx(1.2)
	player.linear_velocity = Vector4(0, -15, 0, 0)
	await _wait_physics_frames(2)
	var basis_after: Projection = player.global_basis
	var basis_matches: bool = (
		basis_after.x.is_equal_approx(expected_spawn_basis.x) and basis_after.y.is_equal_approx(expected_spawn_basis.y)
		and basis_after.z.is_equal_approx(expected_spawn_basis.z) and basis_after.w.is_equal_approx(expected_spawn_basis.w)
	)
	print("15.fall_respawn: pos=%s (expect %s) basis_matches=%s velocity=%s (expect zero)" % [
		player.global_position, expected_spawn_pos, basis_matches, player.linear_velocity,
	])

	# 16. angle_off_slice: independently recompute asin(ana_offset/rel.length())
	# for several bearings and confirm BearingUtility4D.compute() matches.
	player.global_position = Vector4(0, 1, 0, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	var angle_cases: Array = [Vector4(5, 1, 0, 2), Vector4(-3, 1, 4, -6), Vector4(0, 1, 10, 0.1)]
	for target_pos in angle_cases:
		var bearing: Dictionary = BearingUtility4D.compute(player, target_pos)
		var case_rel: Vector4 = target_pos - player.global_position
		var expected_slice_angle: float = asin(clampf(case_rel.dot(player.global_basis.w) / case_rel.length(), -1.0, 1.0))
		print("16.angle_off_slice(target=%s): expected=%.5f actual=%.5f (match=%s)" % [
			target_pos, expected_slice_angle, bearing.angle_off_slice, is_equal_approx(expected_slice_angle, bearing.angle_off_slice),
		])

	# 16b. Same, but with genuine slice-rotation applied (xw) so basis.w isn't
	# the trivial (0,0,0,1) - confirms this isn't just correct by coincidence
	# for an unrotated player.
	player.basis = Basis4D.from_xw(0.7)
	await _wait_physics_frames(2)
	var rotated_target := Vector4(3, 1, 2, 1)
	var rotated_bearing: Dictionary = BearingUtility4D.compute(player, rotated_target)
	var rotated_rel: Vector4 = rotated_target - player.global_position
	var rotated_expected: float = asin(clampf(rotated_rel.dot(player.global_basis.w) / rotated_rel.length(), -1.0, 1.0))
	print("16b.angle_off_slice_rotated: expected=%.5f actual=%.5f (match=%s)" % [
		rotated_expected, rotated_bearing.angle_off_slice, is_equal_approx(rotated_expected, rotated_bearing.angle_off_slice),
	])

	# 17. Slice-alignment glow: independently recompute the opacity curve for
	# a few configurations and confirm slice_glow's actual
	# _compute_intensity() matches - 0 at/above 30deg off-slice, 1 at/below
	# the reused epsilon's instantaneous angle, t^2 ease between.
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	var glow_cases: Array = [
		Vector4(0, 1.5, 0, 0), # dead ahead, w=0 exactly -> angle 0 -> full opacity.
		Vector4(0, 1.5, 0, 20), # far off in w -> large angle -> 0 opacity.
		Vector4(0, 1.5, 0, 1.0), # partway off -> should ease between.
	]
	for target_pos in glow_cases:
		spawner._current_target.global_position = target_pos
		await _wait_physics_frames(1)
		var glow_bearing: Dictionary = BearingUtility4D.compute(player, target_pos)
		var rel_length: float = glow_bearing.rel.length()
		var angle_deg: float = absf(rad_to_deg(glow_bearing.angle_off_slice))
		var inner_deg: float = (
			rad_to_deg(asin(clampf(0.25 / rel_length, -1.0, 1.0))) if rel_length > 0.0001 else 0.0
		)
		var expected_opacity: float
		if angle_deg <= inner_deg:
			expected_opacity = 1.0
		elif angle_deg >= 30.0:
			expected_opacity = 0.0
		else:
			var t: float = clampf((30.0 - angle_deg) / (30.0 - inner_deg), 0.0, 1.0)
			expected_opacity = t * t
		var actual_opacity: float = slice_glow._compute_intensity()
		print("17.glow_opacity(target=%s): angle_deg=%.3f inner_deg=%.3f expected=%.4f actual=%.4f (match=%s)" % [
			target_pos, angle_deg, inner_deg, expected_opacity, actual_opacity, is_equal_approx(expected_opacity, actual_opacity),
		])

	# 18. Radar widget: sanity-check the projection sign convention with
	# simple, hand-derivable bearings (identity basis).
	player.global_position = Vector4(0, 1, 0, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	var right_bearing: Dictionary = BearingUtility4D.compute(player, Vector4(5, 1, 0, 0))
	print("18a.radar_right(target 5 units right): right_component=%.2f depth_component=%.2f (expect ~5, ~0)" % [
		right_bearing.right_component, right_bearing.depth_component,
	])
	var ahead_bearing: Dictionary = BearingUtility4D.compute(player, Vector4(0, 1, -5, 0))
	print("18b.radar_ahead(target 5 units ahead/-z): right_component=%.2f depth_component=%.2f (expect ~0, ~-5 -> negative screen offset -> up)" % [
		ahead_bearing.right_component, ahead_bearing.depth_component,
	])
	var ana_bearing: Dictionary = BearingUtility4D.compute(player, Vector4(0, 1, 0, 3))
	print("18c.radar_ana(target +3 in w): ana_offset=%.2f (expect ~3, stem should draw UP per positive=up convention)" % [ana_bearing.ana_offset])

	# Visual check: fresh duck near the midpoint of its path (x=0, on the
	# player's default sightline) alongside the red target, for a clean shot.
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	spawner._current_target.global_position = Vector4(2, 1.5, -1, 1)
	var visible_duck: Node4D = duck_spawner.DuckScene.instantiate()
	duck_spawner.add_child(visible_duck)
	visible_duck.position = Vector4(0, 1.5, -2, 0)
	duck_spawner._ducks.append(visible_duck)
	await _wait_physics_frames(2)
	await _screenshot("gallery_overview.png")

	get_tree().quit()
