extends Node
## TEMPORARY - verifies the shooting_gallery.tscn experiment end to end.
## Not part of the shipped scene.

@onready var player: CharacterBody4D = $"../Gallery/FlatPlane/Player"
@onready var player_head: Node4D = $"../Gallery/FlatPlane/Player/PlayerHead"
@onready var spawner: Node4D = $"../Gallery/FlatPlane/GalleryTargetSpawner"
@onready var duck_spawner: Node4D = $"../Gallery/FlatPlane/DuckRowSpawner"
@onready var crosshair: Control = $"../Gallery/Crosshair"
@onready var barrier: StaticBody4D = $"../Gallery/FlatPlane/Barrier"
@onready var fall_respawn: Node = $"../Gallery/FlatPlane/FallRespawn"
@onready var radar_orb_hud: Control = $"../Gallery/RadarOrbHud"
@onready var slice_radar: Control = $"../Gallery/RadarOrbHud/SliceRadar"
@onready var slice_glow: Control = $"../Gallery/SliceAlignmentGlow"
@onready var gun_core: Node4D = $"../Gallery/FlatPlane/Player/PlayerHead/FirstPersonCamera/GunViewmodel/Core"
@onready var hitscan_weapon: Node = $"../Gallery/HitscanWeapon"
@onready var ammo_pips: Node4D = $"../Gallery/FlatPlane/Player/PlayerHead/FirstPersonCamera/GunViewmodel/AmmoPips"
@onready var combat_stats_hud: Control = $"../Gallery/CombatStatsHud"
@onready var projectiles: Node4D = $"../Gallery/FlatPlane/Projectiles"
@onready var w_targeting: Node = $"../Gallery/WTargeting"
@onready var contest_player: Node4D = $"../Gallery/FlatPlane/ContestSequencePlayer"
@onready var contest_results_overlay: Control = $"../Gallery/ContestResultsOverlay"
const BearingUtility4D = preload("res://scripts/bearing_utility_4d.gd")
const PoofEffect4D = preload("res://scripts/poof_effect_4d.gd")
const Projectile4D = preload("res://scripts/projectile_4d.gd")
const PopHoldRetract = preload("res://sandbox/shooting_gallery/contest/archetypes/pop_hold_retract.gd")
const VerticalToss = preload("res://sandbox/shooting_gallery/contest/archetypes/vertical_toss.gd")
const ConstantVelocityCrossing = preload("res://sandbox/shooting_gallery/contest/archetypes/constant_velocity_crossing.gd")

# Comfortably past Projectile4D.MAX_LIFETIME_SEC (3.0s) at 60fps - the hard
# upper bound any single fired shot can take to resolve one way or another.
const SHOT_RESOLUTION_TIMEOUT_FRAMES := 220

func _wait_physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _contest_position_active(pos: Vector4) -> bool:
	for target in contest_player.get_active_targets():
		if target.position.is_equal_approx(pos):
			return true
	return false

# Firing no longer resolves hit-or-miss on the same frame - a projectile has
# to actually travel there first. A fixed-frame wait is the wrong tool for
# that: too short and it checks before the shot lands, too long and it can
# overshoot short-lived side effects (e.g. the poof effect's own 0.4s
# lifetime) that already came and went while waiting. Instead, connect to
# CombatEvents.shot_fired *before* firing (so there's no race with a signal
# that already fired) and poll until it actually emits.
func _fire_and_await_resolution(fire_action: Callable) -> bool:
	var resolved: Array = [false]
	var on_shot := func(_hit: bool) -> void: resolved[0] = true
	CombatEvents.shot_fired.connect(on_shot)
	fire_action.call()
	var frames_waited := 0
	while not resolved[0] and frames_waited < SHOT_RESOLUTION_TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames_waited += 1
	CombatEvents.shot_fired.disconnect(on_shot)
	return resolved[0]

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
	var cycle_next_events: Array = InputMap.action_get_events(&"cycle_target_next")
	var cycle_prev_events: Array = InputMap.action_get_events(&"cycle_target_prev")
	var toggle_mode_events: Array = InputMap.action_get_events(&"toggle_target_mode")
	print("1c.cycle_target_next button_index=%s (expect 4/wheel-up)" % [cycle_next_events[0].button_index])
	print("1d.cycle_target_prev button_index=%s (expect 5/wheel-down)" % [cycle_prev_events[0].button_index])
	print("1e.toggle_target_mode button_index=%s (expect 3/middle-click)" % [toggle_mode_events[0].button_index])

	# 2. Node paths resolve (all @onready vars non-null).
	print("2.paths: player=%s player_head=%s spawner=%s crosshair=%s barrier=%s" % [
		player != null, player_head != null, spawner != null, crosshair != null, barrier != null,
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
	player.basis = Projection()
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
	player.basis = Projection()
	# Also reset any head pitch a stray real mouse-motion event may have
	# accumulated (windowed runs receive real OS input; headless doesn't) -
	# both the live basis and the underlying _head_pitch it's derived from,
	# since the next real mouse event would otherwise silently reapply the
	# stale pitch and re-break the "aimed dead ahead" assumption below.
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
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
	player.basis = Projection()
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
	spawner._current_target.global_position = Vector4(0, 1.75, 0, 0)
	await _wait_physics_frames(2)
	var click_before_count: int = spawner._catch_count
	# Firing now spawns a traveling projectile rather than resolving instantly -
	# wait for it to actually resolve (not a fixed guess at travel time)
	# before checking whether the catch registered.
	var click_resolved: bool = await _fire_and_await_resolution(func() -> void:
		var click_event := InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		Input.parse_input_event(click_event)
	)
	print("8a.simulated_left_click: resolved=%s catch_count %d->%d (expect true, an increment of 1)" % [
		click_resolved, click_before_count, spawner._catch_count,
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
	player.basis = Projection()
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
	player.basis = Projection()
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
	player.basis = Projection()
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

	# 19. Radar auto-scales with window size: resize the actual OS window to
	# a much larger "fullscreen-like" resolution and confirm the widget's
	# rect and derived ellipse radius/scale grow proportionally, not staying
	# pinned to whatever they were at the original window size.
	# _ellipse_radius_x no longer exists as a stored field - Aaron's radar
	# rewrite now derives the ellipse radius purely from `size` inside
	# _draw() each frame (radii.x = size.x * 0.5 * ellipse_margin_ratio), so
	# recompute the same way here rather than reading internal state.
	var original_window_size: Vector2i = get_window().size
	var size_before: Vector2 = slice_radar.size
	var radius_before: float = size_before.x * 0.5 * 0.9
	get_window().size = Vector2i(1920, 1080)
	await _wait_physics_frames(3)
	var size_after: Vector2 = slice_radar.size
	var radius_after: float = size_after.x * 0.5 * 0.9
	var width_ratio: float = size_after.x / size_before.x
	var expected_ratio: float = 1920.0 / float(original_window_size.x)
	print("19.radar_autoscale: size_before=%s size_after=%s width_ratio=%.4f expected_ratio=%.4f (match=%s) radius_before=%.2f radius_after=%.2f radius_grew=%s" % [
		size_before, size_after, width_ratio, expected_ratio, is_equal_approx(width_ratio, expected_ratio),
		radius_before, radius_after, radius_after > radius_before,
	])
	await _screenshot("gallery_radar_fullscreen_size.png")
	get_window().size = original_window_size
	await _wait_physics_frames(3)

	# 20. Gun viewmodel: core rotates continuously (isoclinic xy+zw), and
	# firing pulses the spin rate, which then decays back toward base speed.
	print("20a.gun_core_resolves: %s" % [gun_core != null])
	var basis_t0: Projection = gun_core.global_basis
	await _wait_physics_frames(10)
	var basis_t1: Projection = gun_core.global_basis
	var rotated: bool = not (
		basis_t0.x.is_equal_approx(basis_t1.x) and basis_t0.y.is_equal_approx(basis_t1.y)
		and basis_t0.z.is_equal_approx(basis_t1.z) and basis_t0.w.is_equal_approx(basis_t1.w)
	)
	print("20b.gun_core_spins_continuously: basis_changed=%s (expect true)" % [rotated])

	var speed_before_pulse: float = gun_core._speed_multiplier
	# Connect before firing (not after) so there's no race with a signal that
	# might already have fired by the time we start waiting for it.
	var shot20_resolved: Array = [false]
	var on_shot20 := func(_hit: bool) -> void: shot20_resolved[0] = true
	CombatEvents.shot_fired.connect(on_shot20)
	hitscan_weapon._fire() # exercises the real fire path, not just calling pulse() in isolation.
	var speed_just_after_fire: float = gun_core._speed_multiplier
	await _wait_physics_frames(30)
	var speed_after_settling: float = gun_core._speed_multiplier
	print("20c.gun_core_pulse_on_fire: before=%.3f just_after=%.3f (expect ~%.1f) after_settling=%.3f (expect closer to 1.0 than just_after)" % [
		speed_before_pulse, speed_just_after_fire, gun_core.pulse_speed_multiplier, speed_after_settling,
	])
	# This test only cares about the pulse decay above, but the shot it fired
	# is still out there somewhere - drain it now so it can't resolve in the
	# background later and corrupt a subsequent section's clean baseline.
	var frames20 := 0
	while not shot20_resolved[0] and frames20 < SHOT_RESOLUTION_TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames20 += 1
	CombatEvents.shot_fired.disconnect(on_shot20)
	print("20c2.drain_diagnostic: resolved=%s frames_taken=%d projectiles_in_flight=%d" % [
		shot20_resolved[0], frames20, projectiles.get_child_count(),
	])

	# 20d. The xw component of the isoclinic spin needs the mesh's own
	# w-extent to actually swing away from w=0 for the cross-section effect
	# to be visible at all - but that swing has to land somewhere. xw
	# redirects it into x (open space beside the viewmodel) instead of z
	# (where Barrel/Stock physically sit) - an earlier version of this
	# script used zw, which put that same swing directly into z and clipped
	# straight through them (confirmed by watching the render, not just the
	# basis-changed check). The core is now a 600-cell (no parametric
	# "size" property - get_vertices() is the only generic way to find its
	# actual local extent), so find its own most w-extreme local vertex
	# directly, track it through real rotation frames, and confirm: its
	# global x-offset swings through a meaningful range (the effect is
	# still genuinely happening), while its z-offset stays small throughout
	# (nothing is clipping into the neighboring gun parts anymore).
	var core_vertices: PackedVector4Array = gun_core.mesh.get_vertices()
	var local_extreme_vertex: Vector4 = Vector4.ZERO
	var max_local_w: float = 0.0
	for v in core_vertices:
		if absf(v.w) > max_local_w:
			max_local_w = absf(v.w)
			local_extreme_vertex = v
	var x_offsets: Array = []
	var z_offsets: Array = []
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection()
	for i in 40:
		var global_vertex: Vector4 = gun_core.global_position + (gun_core.global_basis * local_extreme_vertex)
		x_offsets.append(absf(global_vertex.x - gun_core.global_position.x))
		z_offsets.append(absf(global_vertex.z - gun_core.global_position.z))
		if i % 10 == 0:
			await _screenshot("gallery_gun_core_spin_%d.png" % i)
		await _wait_physics_frames(1)
	var max_x_offset: float = x_offsets.max()
	var max_z_offset: float = z_offsets.max()
	print("20d.gun_core_w_swing: local_extreme_vertex=%s max_abs_x_offset=%.3f (expect a meaningful fraction of extreme_vertex.w) max_abs_z_offset=%.3f (expect small, no more clipping into barrel/stock)" % [
		local_extreme_vertex, max_x_offset, max_z_offset,
	])

	# 21. Glow pulse: confirm the core's material brightens right after
	# firing then eases back down in sync with the existing speed-multiplier
	# decay. No Environment/bloom check here - that approach was tried and
	# reverted (see gun_core_rotator.gd's doc comment: it blew out the whole
	# screen), so the glow is now just a safe, capped color lerp.
	await _wait_physics_frames(2)
	var color_before_pulse: Color = gun_core.material_override.albedo_color
	gun_core.pulse()
	await _wait_physics_frames(2)
	var color_just_after_pulse: Color = gun_core.material_override.albedo_color
	await _wait_physics_frames(60)
	var color_after_settling: Color = gun_core.material_override.albedo_color
	# Green channel differs most between base (0.25) and hot (0.8) - just-
	# after should spike well above both the before and settled values.
	print("21b.glow_pulses_with_fire: green_before=%.3f green_just_after=%.3f (expect higher) green_after_settling=%.3f (expect back down near green_before)" % [
		color_before_pulse.g, color_just_after_pulse.g, color_after_settling.g,
	])

	# 22. Poof effect: fire a real shot that hits the target, confirm a poof
	# effect spawns as a child of the spawner, its particles genuinely move,
	# and it self-destructs after its own lifetime.
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection()
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
	spawner._current_target.global_position = Vector4(0, 1.75, 0, 0)
	await _wait_physics_frames(2)
	print("21c.pre_22_diagnostic: projectiles_in_flight_before_firing=%d (expect 0)" % [projectiles.get_child_count()])
	# As in test 8a, the shot resolves once the projectile actually reaches
	# the target, not on the frame it's fired - check for the poof right as
	# that happens, not after a guessed delay (which could easily overshoot
	# the poof's own short 0.4s lifetime and find nothing).
	var shot22_resolved: bool = await _fire_and_await_resolution(func() -> void: hitscan_weapon._fire())
	var poof_node: Node = null
	for child in spawner.get_children():
		if child.get_script() == PoofEffect4D:
			poof_node = child
			break
	print("22a.poof_spawns_on_hit: shot_resolved=%s poof_found=%s particle_count=%s (expect true, true, 10)" % [
		shot22_resolved, poof_node != null, (poof_node.get_child_count() if poof_node != null else -1),
	])
	if poof_node != null:
		var particle_pos_before: Vector4 = poof_node.get_child(0).position
		await _wait_physics_frames(5)
		var particle_pos_after: Vector4 = poof_node.get_child(0).position
		print("22b.poof_particles_move: moved=%s" % [not particle_pos_before.is_equal_approx(particle_pos_after)])
	await _wait_physics_frames(30) # LIFETIME_SEC=0.4s -> ~24 physics frames at 60fps, plus margin.
	var poof_still_exists: bool = poof_node != null and is_instance_valid(poof_node) and poof_node.is_inside_tree()
	print("22c.poof_self_destructs: still_exists_after_lifetime=%s (expect false)" % [poof_still_exists])

	# 23. Radar orb HUD: resolves, sits at its lowered anchor by default,
	# rises toward raised_anchor while rotate_4d (right-click) is held,
	# settles back down on release. slice_radar and the glass dome overlay
	# are both plain full-rect children of radar_orb_hud, so checking this
	# node's own position/size is sufficient - they ride along for free,
	# with no separate tracking logic to verify on their end.
	print("23a.radar_orb_resolves: %s" % [radar_orb_hud != null])
	await _wait_physics_frames(20) # Let it settle at its default (lowered) pose.
	var viewport_size: Vector2 = get_viewport().size
	var expected_lowered_center: Vector2 = viewport_size * radar_orb_hud.lowered_anchor
	var actual_center_lowered: Vector2 = radar_orb_hud.position + radar_orb_hud.size * 0.5
	print("23b.radar_orb_lowered_by_default: center=%s expected=%s (match=%s) slice_radar_size=%s (expect matching radar_orb_hud.size=%s)" % [
		actual_center_lowered, expected_lowered_center, actual_center_lowered.is_equal_approx(expected_lowered_center),
		slice_radar.size, radar_orb_hud.size,
	])
	# Exponential decay never fully reaches its target - after 30 frames at
	# raise_speed=8.0 (0.5s), exp(-8*0.5)=~1.8% of the travel distance is
	# still left, so allow a tolerance proportional to that travel distance
	# rather than a fixed pixel amount, since this needs to hold regardless
	# of viewport size (headless test viewports are tiny; real windows aren't).
	var travel_distance: float = (viewport_size * (radar_orb_hud.raised_anchor - radar_orb_hud.lowered_anchor)).length()
	var settle_tolerance: float = maxf(travel_distance * 0.05, 1.0)
	Input.action_press(&"rotate_4d")
	await _wait_physics_frames(30)
	await _screenshot("gallery_radar_orb_raised.png")
	Input.action_release(&"rotate_4d")
	var expected_raised_center: Vector2 = viewport_size * radar_orb_hud.raised_anchor
	var actual_center_raised: Vector2 = radar_orb_hud.position + radar_orb_hud.size * 0.5
	print("23c.radar_orb_raises_on_hold: center=%s expected=%s (match=%s)" % [
		actual_center_raised, expected_raised_center, actual_center_raised.distance_to(expected_raised_center) < settle_tolerance,
	])
	await _wait_physics_frames(30) # Same reasoning, but settling back down after release.
	var actual_center_settled: Vector2 = radar_orb_hud.position + radar_orb_hud.size * 0.5
	print("23d.radar_orb_lowers_on_release: center=%s expected=%s (match=%s)" % [
		actual_center_settled, expected_lowered_center, actual_center_settled.distance_to(expected_lowered_center) < settle_tolerance,
	])

	# Visual check: fresh duck near the midpoint of its path (x=0, on the
	# player's default sightline) alongside the red target, for a clean shot,
	# plus a fresh poof burst right at the moment of the screenshot.
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection()
	spawner._current_target.global_position = Vector4(2, 1.5, -1, 1)
	var visible_duck: Node4D = duck_spawner.DuckScene.instantiate()
	duck_spawner.add_child(visible_duck)
	visible_duck.position = Vector4(0, 1.5, -2, 0)
	duck_spawner._ducks.append(visible_duck)
	var visible_poof := Node4D.new()
	visible_poof.set_script(PoofEffect4D)
	spawner.add_child(visible_poof)
	visible_poof.global_position = Vector4(0.3, 1.6, -1.5, 0)
	await _wait_physics_frames(2)
	await _screenshot("gallery_overview.png")

	# 24. Ammo pips: drain the rest of the magazine directly (bypassing the
	# weapon so this doesn't fire real shots/emit stats), confirm firing while
	# empty is a genuine no-op (no CombatEvents signal at all), then confirm
	# reload (the "reload" action, bound to G) restores pips progressively
	# over its window rather than all at once.
	print("24a.ammo_pips_resolves: %s magazine_size=%d spent_so_far=%d (expect some already spent from earlier real-fire tests)" % [
		ammo_pips != null, ammo_pips.MAGAZINE_SIZE, ammo_pips._spent_count,
	])
	while ammo_pips.can_fire():
		ammo_pips.consume_round()
	print("24b.ammo_drained: can_fire=%s spent_count=%d (expect false, %d)" % [
		ammo_pips.can_fire(), ammo_pips._spent_count, ammo_pips.MAGAZINE_SIZE,
	])

	var empty_fire_signal_count: Array = [0]
	var on_test_shot_fired := func(_hit: bool) -> void: empty_fire_signal_count[0] += 1
	CombatEvents.shot_fired.connect(on_test_shot_fired)
	hitscan_weapon._fire()
	await _wait_physics_frames(2)
	print("24c.firing_while_empty_is_noop: shot_fired_emitted=%s (expect false) spent_count_unchanged=%s" % [
		empty_fire_signal_count[0] > 0, ammo_pips._spent_count == ammo_pips.MAGAZINE_SIZE,
	])
	CombatEvents.shot_fired.disconnect(on_test_shot_fired)

	await _press_action(&"reload")
	await _wait_physics_frames(40) # ~0.67s of a 1.3s reload window - partial only.
	var spent_mid_reload: int = ammo_pips._spent_count
	print("24d.reload_is_progressive: reloading=%s spent_count=%d (expect strictly between 0 and %d, i.e. neither instant nor untouched)" % [
		ammo_pips._reloading, spent_mid_reload, ammo_pips.MAGAZINE_SIZE,
	])
	await _wait_physics_frames(90) # comfortably past the remainder of the 1.3s window.
	print("24e.reload_completes: can_fire=%s spent_count=%d (expect true, 0)" % [
		ammo_pips.can_fire(), ammo_pips._spent_count,
	])

	# Tests 8a, 20c, and 22 each already drained their own shot's resolution
	# before moving on, so nothing should still be in flight here - confirms
	# there's no stray background resolution left to corrupt the clean
	# hits/misses baseline the next section relies on.
	print("24f.no_stray_projectiles: projectiles_in_flight=%d (expect 0)" % [projectiles.get_child_count()])

	# 25. Stats HUD: with a fresh full magazine from test 24e, fire one
	# guaranteed hit (reusing test 6/22's exact hit setup) and one guaranteed
	# miss (reusing test 7's straight-up aim), confirming the HUD's internal
	# hits/misses counters - and therefore its on-screen label - track the
	# real fire path via CombatEvents, independent of any specific gun. Ammo
	# is consumed the instant _fire() is called either way, but hits/misses
	# only update once the projectile actually resolves - checked explicitly
	# below, right after firing and again only once resolution is confirmed.
	print("25a.combat_stats_hud_resolves: %s" % [combat_stats_hud != null])
	var hits_before: int = combat_stats_hud._hits
	var misses_before: int = combat_stats_hud._misses

	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
	spawner._current_target.global_position = Vector4(0, 1.75, 0, 0)
	await _wait_physics_frames(2)

	var spent_before_hit_shot: int = ammo_pips._spent_count
	var hit_shot_resolved: Array = [false]
	var on_hit_shot := func(_hit: bool) -> void: hit_shot_resolved[0] = true
	CombatEvents.shot_fired.connect(on_hit_shot)
	hitscan_weapon._fire()
	print("25b0.ammo_immediate_stats_delayed: spent_count %d->%d (expect +1, checked the instant _fire() returns) hits_still_unchanged=%s (expect true - resolution hasn't happened yet)" % [
		spent_before_hit_shot, ammo_pips._spent_count, combat_stats_hud._hits == hits_before,
	])
	var frames25b := 0
	while not hit_shot_resolved[0] and frames25b < SHOT_RESOLUTION_TIMEOUT_FRAMES:
		await get_tree().physics_frame
		frames25b += 1
	CombatEvents.shot_fired.disconnect(on_hit_shot)
	print("25b.stats_track_hit: resolved=%s hits %d->%d (expect true, +1) misses unchanged=%s" % [
		hit_shot_resolved[0], hits_before, combat_stats_hud._hits, combat_stats_hud._misses == misses_before,
	])

	var hits_before_miss: int = combat_stats_hud._hits
	var misses_before_miss: int = combat_stats_hud._misses
	player.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	# _fire() always rays along the camera's own forward (-global_basis.z),
	# so to make the real fire path miss, pitch player_head itself steeply
	# via the same Basis4D.from_yz the mouse-look controller uses (matching
	# its own pitch clamp bound), rather than manufacturing a raycast by hand.
	player_head.basis = Basis4D.from_yz(1.5)
	await _wait_physics_frames(2)
	# Steeply up: nothing there, resolves by hitting the MAX_LIFETIME_SEC cap.
	# Steeply down: resolves quickly against the floor (not a catchable
	# target, so still a miss) - either way, wait for the actual resolution.
	var miss_resolved: bool = await _fire_and_await_resolution(func() -> void: hitscan_weapon._fire())
	print("25c.stats_track_miss: resolved=%s misses %d->%d (expect true, +1) hits unchanged=%s" % [
		miss_resolved, misses_before_miss, combat_stats_hud._misses, combat_stats_hud._hits == hits_before_miss,
	])
	print("25c2.miss_projectile_cleaned_up: projectiles_in_flight=%d (expect 0, despawned once resolved)" % [projectiles.get_child_count()])
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0

	var total_fired: int = combat_stats_hud._hits + combat_stats_hud._misses
	var expected_accuracy: float = (100.0 * combat_stats_hud._hits / total_fired) if total_fired > 0 else 0.0
	var label_text: String = combat_stats_hud.label.text
	print("25d.stats_label_reflects_state: label=%s expected_accuracy=%.0f%% (expect label to contain hits=%d, misses=%d, that accuracy)" % [
		label_text, expected_accuracy, combat_stats_hud._hits, combat_stats_hud._misses,
	])

	var elapsed_before: float = combat_stats_hud._elapsed_sec
	await _wait_physics_frames(30)
	print("25e.stats_timer_advances: elapsed %.2f->%.2f (expect increase)" % [elapsed_before, combat_stats_hud._elapsed_sec])

	await _screenshot("gallery_ammo_stats_hud.png")

	# 26. Tunneling avoidance: a fast projectile's one-tick travel segment can
	# easily be longer than a target's own hitbox - if hit detection only
	# checked the position *after* moving, anything that was only ever
	# "between" two ticks would never register. Prove the real implementation
	# doesn't have that hole by placing a target exactly at the midpoint of a
	# single tick's travel (nowhere near either the pre-tick or post-tick
	# position) and confirming it still resolves as a hit.
	var tick_delta: float = 1.0 / Engine.physics_ticks_per_second
	var fast_speed: float = 600.0
	var tick_travel: float = fast_speed * tick_delta
	var tunnel_origin := Vector4(0, 1.5, 5, 0)
	var tunnel_direction := Vector4(0, 0, -1, 0)
	spawner._current_target.global_position = tunnel_origin + tunnel_direction * (tick_travel * 0.5)
	print("26a.tunnel_setup: tick_travel=%.3f target_pos=%s pre_tick_pos=%s post_tick_pos=%s (target strictly between the two, at neither)" % [
		tick_travel, spawner._current_target.global_position, tunnel_origin, tunnel_origin + tunnel_direction * tick_travel,
	])

	var tunnel_result: Array = [null, null] # [hit, hit_body]
	var tunnel_projectile := Node4D.new()
	tunnel_projectile.set_script(Projectile4D)
	tunnel_projectile.speed = fast_speed
	tunnel_projectile.direction = tunnel_direction
	tunnel_projectile.exclude_nodes = [player]
	tunnel_projectile.on_resolved = func(hit: bool, hit_body: Object, _global_point: Vector4) -> void:
		tunnel_result[0] = hit
		tunnel_result[1] = hit_body
	projectiles.add_child(tunnel_projectile)
	tunnel_projectile.global_position = tunnel_origin
	# The target's z=0 never coincides with any single tick's *endpoint*
	# (those land on z=5, -5, -15, ... - always tick_travel apart), so a
	# resolution within the first few ticks can only mean the segment check
	# caught it mid-flight, regardless of exactly which tick that happens on -
	# a few frames of margin doesn't weaken the proof.
	var tunnel_frames := 0
	while tunnel_result[0] == null and tunnel_frames < 10:
		await get_tree().physics_frame
		tunnel_frames += 1
	print("26b.tunneling_avoided: resolved=%s hit=%s hit_body_is_target=%s ticks_taken=%d (expect true, true, true - caught mid-segment despite a %.1f-unit jump per tick)" % [
		tunnel_result[0] != null, tunnel_result[0], tunnel_result[1] == spawner._current_target, tunnel_frames, tick_travel,
	])
	if tunnel_result[0] == null and is_instance_valid(tunnel_projectile):
		print("26c.tunnel_diagnostic: still unresolved - projectile_pos=%s" % [tunnel_projectile.global_position])

	# 27. W-targeting, single-target scene: force a clean single-target
	# scenario (no ducks) with the target already sitting exactly on the
	# current slice, so the fallback formula's projection term is exactly
	# zero and cycling should produce a true no-op realign - this is the
	# case the fallback path (not the cross-product path) is exercised by.
	w_targeting._selected_target = null # Stop any prior tracking before hand-setting state below.
	for duck in duck_spawner._ducks:
		duck.queue_free()
	duck_spawner._ducks.clear()
	duck_spawner._spawn_timer_sec = 0.0 # Prevent its own auto-spawn timer from adding an uninvited duck mid-test.
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection()
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
	spawner._current_target.global_position = Vector4(0, 1.75, 0, 0) # Same x=0, w=0 line as player - already on slice.
	await _wait_physics_frames(2)

	var basis_before_single: Projection = player.global_basis
	w_targeting._cycle(1)
	# _target_ana_direction/the secondary highlight are only solved inside
	# _physics_process now (continuous tracking, not a one-shot solve in
	# _cycle itself) - give it a tick to run before reading them. The primary
	# highlight is still set synchronously in _cycle, so that one doesn't need it.
	await _wait_physics_frames(2)
	print("27a.single_target_selected: selected_is_target=%s highlighted_is_target=%s (expect true, true)" % [
		w_targeting._selected_target == spawner._current_target, slice_radar.highlighted_object == spawner._current_target,
	])
	print("27a2.single_target_no_secondary: secondary=%s (expect null - fallback path, no neighbor pairing)" % [slice_radar.secondary_highlighted_object])
	print("27b.single_target_noop_direction: target_n=%s (expect ~(0,0,0,1), unchanged from current)" % [w_targeting._target_ana_direction])
	await _wait_physics_frames(30)
	print("27c.single_target_noop_applied: basis_w=%s convergence_dot=%.6f (expect ~(0,0,0,1), ~1.0 - unmoved)" % [
		player.global_basis.w, player.global_basis.w.dot(w_targeting._target_ana_direction),
	])
	print("27d.single_target_basis_unchanged: x=%s y=%s z=%s w=%s (expect all true - no roll/drift from a no-op realign)" % [
		player.global_basis.x.is_equal_approx(basis_before_single.x), player.global_basis.y.is_equal_approx(basis_before_single.y),
		player.global_basis.z.is_equal_approx(basis_before_single.z), player.global_basis.w.is_equal_approx(basis_before_single.w),
	])

	# 28. W-targeting, ducks-in-a-row scene: hand-place 3 ducks at known
	# points along the fixed duck path and verify the solved ana-direction
	# for a specific selection matches an independently hand-computed cross
	# product, then confirm the player's orientation actually eases into it.
	duck_spawner._spawn_timer_sec = 0.0 # Same reasoning as test 27 - keep the list exactly the 3 ducks placed below.
	var w_duck0: Node4D = duck_spawner.DuckScene.instantiate()
	duck_spawner.add_child(w_duck0)
	w_duck0.position = duck_spawner.PATH_START + (duck_spawner.PATH_END - duck_spawner.PATH_START) * 0.3
	duck_spawner._ducks.append(w_duck0)
	var w_duck1: Node4D = duck_spawner.DuckScene.instantiate()
	duck_spawner.add_child(w_duck1)
	w_duck1.position = duck_spawner.PATH_START + (duck_spawner.PATH_END - duck_spawner.PATH_START) * 0.5
	duck_spawner._ducks.append(w_duck1)
	var w_duck2: Node4D = duck_spawner.DuckScene.instantiate()
	duck_spawner.add_child(w_duck2)
	w_duck2.position = duck_spawner.PATH_START + (duck_spawner.PATH_END - duck_spawner.PATH_START) * 0.7
	duck_spawner._ducks.append(w_duck2)

	w_targeting._selected_target = null # Start the cycle sequence below fresh, not continuing from test 27's leftover selection.
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection()
	await _wait_physics_frames(2)

	# List order is [gallery target, w_duck0, w_duck1, w_duck2] - 3 cycles
	# from a fresh selection lands on w_duck1, the hand-computed case below.
	w_targeting._cycle(1)
	w_targeting._cycle(1)
	w_targeting._cycle(1)
	await _wait_physics_frames(2)
	print("28a.multi_target_selected: selected_is_duck1=%s" % [w_targeting._selected_target == w_duck1])

	var rel_a: Vector4 = w_duck1.position - player.global_position
	var rel_b: Vector4 = w_duck2.position - player.global_position # "next" neighbor.
	var a3 := Vector3(rel_a.x, rel_a.z, rel_a.w)
	var b3 := Vector3(rel_b.x, rel_b.z, rel_b.w)
	var expected_cross: Vector3 = a3.cross(b3)
	var expected_n: Vector4 = Vector4(expected_cross.x, 0.0, expected_cross.y, expected_cross.z).normalized()
	print("28b.multi_target_cross_product: solved=%s expected=%s (match=%s)" % [
		w_targeting._target_ana_direction, expected_n, w_targeting._target_ana_direction.is_equal_approx(expected_n),
	])

	await _wait_physics_frames(60) # Comfortably past the ~0.4s realign window.
	print("28c.multi_target_realign_converges: basis_w=%s expected=%s convergence_dot=%.6f (expect matching, ~1.0)" % [
		player.global_basis.w, expected_n, player.global_basis.w.dot(expected_n),
	])
	print("28d.multi_target_highlight: highlighted_is_duck1=%s" % [slice_radar.highlighted_object == w_duck1])
	print("28d2.multi_target_secondary_highlight: secondary_is_duck2=%s" % [slice_radar.secondary_highlighted_object == w_duck2])
	await _screenshot("gallery_w_targeting_highlight.png")

	# 28f. Continuous tracking: now that it's settled, move BOTH the primary
	# (duck1) and secondary (duck2) to new positions - simulating what
	# actually happens as ducks keep drifting along their path after being
	# selected - and confirm the slice keeps re-solving and re-easing to
	# follow them, rather than staying frozen at the direction solved in 28c
	# (the reported bug: a moving target quietly drifting back out of the
	# slice because the realign only ever ran once, at the moment of cycling).
	w_duck1.position += Vector4(0.0, 0.0, 0.0, 0.6)
	w_duck2.position += Vector4(0.0, 0.0, 0.0, -0.4)
	var rel_a_moved: Vector4 = w_duck1.position - player.global_position
	var rel_b_moved: Vector4 = w_duck2.position - player.global_position
	var a3_moved := Vector3(rel_a_moved.x, rel_a_moved.z, rel_a_moved.w)
	var b3_moved := Vector3(rel_b_moved.x, rel_b_moved.z, rel_b_moved.w)
	var expected_cross_moved: Vector3 = a3_moved.cross(b3_moved)
	var expected_n_moved: Vector4 = Vector4(expected_cross_moved.x, 0.0, expected_cross_moved.y, expected_cross_moved.z).normalized()
	if expected_n_moved.dot(expected_n) < 0.0: # Same sign-correction the real solve applies, for a fair comparison.
		expected_n_moved = -expected_n_moved
	await _wait_physics_frames(60)
	print("28f.continuous_tracking_follows_movement: solved=%s expected=%s basis_w=%s convergence_dot=%.6f (expect solved and basis_w both matching the NEW expected direction, ~1.0 - not frozen at 28c's stale one)" % [
		w_targeting._target_ana_direction, expected_n_moved, player.global_basis.w, player.global_basis.w.dot(expected_n_moved),
	])

	# 28g. Degenerate-neighbor fallback with multiple targets active: put the
	# gallery target back onto the same line as the ducks, and the player
	# exactly on that line extended, so the selected duck and BOTH its list-
	# neighbors are collinear with the player - neither should produce a
	# usable cross product, so this must fall back to the same single-target-
	# style formula as test 27, not silently accept a near-zero direction.
	w_targeting._selected_target = null # Stop tracking duck1 before hand-setting a new scenario.
	spawner._current_target.global_position = duck_spawner.PATH_START + (duck_spawner.PATH_END - duck_spawner.PATH_START) * 0.1
	player.global_position = duck_spawner.PATH_START - (duck_spawner.PATH_END - duck_spawner.PATH_START)
	player.basis = Projection()
	await _wait_physics_frames(2)
	w_targeting._cycle(1) # index 0 - gallery target (now also on the line).
	w_targeting._cycle(1) # index 1 - w_duck0 - both neighbors collinear with player.
	await _wait_physics_frames(2)
	var a_hat_28g: Vector4 = w_duck0.position - player.global_position
	a_hat_28g.y = 0.0
	a_hat_28g = a_hat_28g.normalized()
	print("28g.degenerate_neighbors_fallback: selected_is_duck0=%s target_n_dot_a_hat=%.6f (expect true, ~0.0 - fell back to a valid horizontal direction orthogonal to the target, not a leftover degenerate cross product)" % [
		w_targeting._selected_target == w_duck0, w_targeting._target_ana_direction.dot(a_hat_28g),
	])

	# 29. Sign-stability regression: reported after a real playtest - a x b's
	# sign is an arbitrary artifact of a x b's order, and naively using it as
	# whichever sign the cross product produced can demand a near-180-degree
	# "shortest path" from the player's current ana-direction. That's not
	# just a jarring flip: right at the antipodal point, the bisector
	# construction in _rotor_from_to is numerically unstable, which is
	# exactly what was observed - a violently jittering camera stuck
	# oscillating between two orientations, unable to be reasoned about or
	# turned out of. Reproduce it deliberately by starting from the ana-
	# direction on the OPPOSITE side of this pair's natural (uncorrected)
	# cross product, and confirm the realign still converges smoothly, via
	# the corrected (shorter) direction instead.
	w_targeting._selected_target = null # Stop test 28g's tracking before hand-setting a new scenario.
	for duck in duck_spawner._ducks:
		duck.queue_free()
	duck_spawner._ducks.clear()
	duck_spawner._spawn_timer_sec = 0.0
	var s_duck_a: Node4D = duck_spawner.DuckScene.instantiate()
	duck_spawner.add_child(s_duck_a)
	s_duck_a.position = duck_spawner.PATH_START + (duck_spawner.PATH_END - duck_spawner.PATH_START) * 0.5
	duck_spawner._ducks.append(s_duck_a)
	var s_duck_b: Node4D = duck_spawner.DuckScene.instantiate()
	duck_spawner.add_child(s_duck_b)
	s_duck_b.position = duck_spawner.PATH_START + (duck_spawner.PATH_END - duck_spawner.PATH_START) * 0.7
	duck_spawner._ducks.append(s_duck_b)

	player.global_position = Vector4(0, 1, 7, 0)
	# Deliberately the "wrong side" ana-direction for this pair's natural
	# cross product (a 180-degree zw flip from identity, built explicitly
	# rather than via a rotation constructor, so which side is "wrong" isn't
	# left to a sign convention this test would otherwise have to guess at).
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 0, 0, -1))
	await _wait_physics_frames(2)

	var pre_cycle_n: Vector4 = player.global_basis.w
	w_targeting._cycle(1) # gallery target
	w_targeting._cycle(1) # s_duck_a, paired with s_duck_b
	await _wait_physics_frames(2)
	print("29a.sign_corrected_toward_current: dot=%.4f (expect >= 0 - corrected to the near side, not a ~180-degree flip)" % [
		w_targeting._target_ana_direction.dot(pre_cycle_n),
	])
	await _wait_physics_frames(60)
	var post_n: Vector4 = player.global_basis.w
	print("29b.sign_stability_converges: convergence_dot=%.6f target=%s actual=%s (expect ~1.0, matching - no indefinite jitter)" % [
		post_n.dot(w_targeting._target_ana_direction), w_targeting._target_ana_direction, post_n,
	])

	# 30. Single/dual mode toggle (middle-click, toggle_target_mode): with the
	# same s_duck_a/s_duck_b pairing still active from test 29, toggling to
	# single mode should drop the neighbor pairing entirely (the definitive
	# signal is the secondary highlight clearing, since a fallback-formula
	# result is still orthogonal to the primary target regardless of mode, so
	# that alone wouldn't distinguish them) - then toggling back to dual
	# should restore the pairing.
	print("30a.starts_in_dual_mode: dual_mode=%s secondary_is_duck_b=%s (expect true, true)" % [
		w_targeting._dual_mode, slice_radar.secondary_highlighted_object == s_duck_b,
	])

	var toggle_event := InputEventMouseButton.new()
	toggle_event.button_index = MOUSE_BUTTON_MIDDLE
	toggle_event.pressed = true
	Input.parse_input_event(toggle_event)
	await _wait_physics_frames(30) # Let it re-solve and settle in single mode.
	print("30b.middle_click_toggles_to_single: dual_mode=%s secondary=%s (expect false, null - dropped even though s_duck_b is still a perfectly good neighbor)" % [
		w_targeting._dual_mode, slice_radar.secondary_highlighted_object,
	])

	var toggle_event2 := InputEventMouseButton.new()
	toggle_event2.button_index = MOUSE_BUTTON_MIDDLE
	toggle_event2.pressed = true
	Input.parse_input_event(toggle_event2)
	await _wait_physics_frames(30)
	print("30c.middle_click_toggles_back_to_dual: dual_mode=%s secondary_is_duck_b=%s (expect true, true - pairing restored)" % [
		w_targeting._dual_mode, slice_radar.secondary_highlighted_object == s_duck_b,
	])

	# 31. Contest movement archetypes, tested in isolation (each attached to
	# a fresh throwaway Node4D, no ContestSequencePlayer involved) - confirms
	# each behaves correctly and emits `expired` at the right time,
	# independent of how ContestSequencePlayer wires them up.
	var pop_test_target := Node4D.new()
	spawner.add_child(pop_test_target)
	pop_test_target.position = Vector4(5, 5, 5, 5)
	var pop_behavior := Node.new()
	pop_behavior.set_script(PopHoldRetract)
	pop_behavior.hold_duration_sec = 0.2
	pop_test_target.add_child(pop_behavior)
	var pop_expired: Array = [false]
	pop_behavior.expired.connect(func() -> void: pop_expired[0] = true)
	await _wait_physics_frames(6) # ~0.1s - before the 0.2s hold elapses.
	print("31a.pop_hold_stays_in_place: pos=%s expired_yet=%s (expect unchanged position, false)" % [pop_test_target.position, pop_expired[0]])
	await _wait_physics_frames(12) # past 0.2s total.
	print("31a2.pop_hold_expires: expired=%s (expect true)" % [pop_expired[0]])
	pop_test_target.queue_free()

	var toss_test_target := Node4D.new()
	spawner.add_child(toss_test_target)
	toss_test_target.position = Vector4(0, 1.0, 0, 0)
	var toss_behavior := Node.new()
	toss_behavior.set_script(VerticalToss)
	toss_behavior.flight_duration_sec = 0.4
	toss_behavior.toss_height = 2.0
	toss_test_target.add_child(toss_behavior)
	var toss_expired: Array = [false]
	toss_behavior.expired.connect(func() -> void: toss_expired[0] = true)
	await _wait_physics_frames(12) # ~0.2s - the arc's midpoint.
	print("31b.vertical_toss_peaks_near_midpoint: height_offset=%.3f (expect close to toss_height=2.0)" % [toss_test_target.position.y - 1.0])
	await _wait_physics_frames(15) # past 0.4s total.
	print("31b2.vertical_toss_expires: expired=%s final_y=%.3f (expect true, back near 1.0)" % [toss_expired[0], toss_test_target.position.y])
	toss_test_target.queue_free()

	var cross_test_target := Node4D.new()
	spawner.add_child(cross_test_target)
	cross_test_target.position = Vector4(-1.0, 1.5, 0, 0)
	var cross_behavior := Node.new()
	cross_behavior.set_script(ConstantVelocityCrossing)
	cross_behavior.velocity = Vector4(2.0, 0, 0, 0)
	cross_behavior.travel_distance = 1.0
	cross_test_target.add_child(cross_behavior)
	var cross_expired: Array = [false]
	cross_behavior.expired.connect(func() -> void: cross_expired[0] = true)
	await _wait_physics_frames(3) # ~0.05s -> traveled ~0.1 units, well short of 1.0.
	print("31c.constant_velocity_moves: x=%.3f expired_yet=%s (expect x > -1.0, false)" % [cross_test_target.position.x, cross_expired[0]])
	await _wait_physics_frames(30) # comfortably past 1.0/2.0=0.5s.
	print("31c2.constant_velocity_expires: expired=%s x=%.3f (expect true, ~0.0 = -1.0 + 1.0 traveled)" % [cross_expired[0], cross_test_target.position.x])
	cross_test_target.queue_free()

	# 32. ContestSequencePlayer pair-sequencing, using a small synthetic
	# sequence built directly here (not the real 5-pair one) - fast and fully
	# deterministic. Confirms: events spawn at pair-relative times (not a
	# global clock), the next pair doesn't start until every event in the
	# current one has resolved, and both a hit and a timeout count as
	# "resolved" the same way.
	var test_event_a := ContestSpawnEvent.new()
	test_event_a.archetype = ContestSpawnEvent.Archetype.POP_HOLD_RETRACT
	test_event_a.spawn_delay_sec = 0.0
	test_event_a.spawn_position = Vector4(10, 10, 10, 10) # Distinctive - not near anything else.
	test_event_a.hold_duration_sec = 0.2

	var test_event_b := ContestSpawnEvent.new()
	test_event_b.archetype = ContestSpawnEvent.Archetype.POP_HOLD_RETRACT
	test_event_b.spawn_delay_sec = 0.15
	test_event_b.spawn_position = Vector4(11, 10, 10, 10)
	test_event_b.hold_duration_sec = 0.2

	var test_pair_1 := ContestPair.new()
	test_pair_1.events = [test_event_a, test_event_b]

	var test_event_c := ContestSpawnEvent.new()
	test_event_c.archetype = ContestSpawnEvent.Archetype.POP_HOLD_RETRACT
	test_event_c.spawn_delay_sec = 0.0
	test_event_c.spawn_position = Vector4(12, 10, 10, 10)
	test_event_c.hold_duration_sec = 5.0 # Long - resolved via a hit below, not a timeout.

	var test_pair_2 := ContestPair.new()
	test_pair_2.events = [test_event_c]

	var test_sequence := ContestSequence.new()
	test_sequence.pairs = [test_pair_1, test_pair_2]

	contest_player.sequence = test_sequence
	var test_sequence_completed: Array = [false]
	var on_test_sequence_completed := func() -> void: test_sequence_completed[0] = true
	contest_player.sequence_completed.connect(on_test_sequence_completed)
	contest_player.start()

	await _wait_physics_frames(2)
	print("32a.pair1_first_event_spawns_immediately: active_count=%d (expect 1)" % [contest_player.get_active_targets().size()])

	await _wait_physics_frames(10) # ~0.17s - past event_b's 0.15s delay.
	print("32b.pair1_second_event_spawns_after_delay: active_count=%d (expect 2)" % [contest_player.get_active_targets().size()])

	print("32c.pair2_not_started_early: pair2_active=%s (expect false)" % [_contest_position_active(Vector4(12, 10, 10, 10))])

	await _wait_physics_frames(20) # comfortably past both events' 0.2s hold.
	print("32d.pair2_starts_after_pair1_fully_resolves: pair2_active=%s active_count=%d (expect true, 1)" % [
		_contest_position_active(Vector4(12, 10, 10, 10)), contest_player.get_active_targets().size(),
	])

	# Resolve pair 2's only event via a hit (not a timeout) - confirms
	# try_hit_target() advances the sequence exactly like an expiry does.
	var pair2_target: Node4D = contest_player.get_active_targets()[0]
	var hit_resolved: bool = contest_player.try_hit_target(pair2_target)
	await _wait_physics_frames(2)
	print("32e.hit_resolves_and_completes_sequence: hit_resolved=%s sequence_completed=%s active_count=%d (expect true, true, 0)" % [
		hit_resolved, test_sequence_completed[0], contest_player.get_active_targets().size(),
	])
	contest_player.sequence_completed.disconnect(on_test_sequence_completed)

	# 33. The REAL authored sequence (contest_sequence_01.tres) - a
	# structural sanity check (does it load with the right shape) rather
	# than simulating the whole ~20+ second playthrough, since test 32
	# already covers the sequencing LOGIC with a fast synthetic sequence.
	var real_sequence: ContestSequence = load("res://sandbox/shooting_gallery/contest/sequences/contest_sequence_01.tres")
	print("33a.real_sequence_loads: loaded=%s pair_count=%d (expect true, 5)" % [
		real_sequence != null, real_sequence.pairs.size() if real_sequence != null else -1,
	])
	var total_events: int = 0
	for pair in real_sequence.pairs:
		total_events += pair.events.size()
	print("33b.real_sequence_event_count: total=%d (expect 10)" % [total_events])

	var pair2_events: Array = real_sequence.pairs[1].events
	var pair2_has_toss := false
	var pair2_has_w3_companion := false
	for event in pair2_events:
		if event.archetype == ContestSpawnEvent.Archetype.VERTICAL_TOSS:
			pair2_has_toss = true
		if is_equal_approx(event.spawn_position.w, 3.0):
			pair2_has_w3_companion = true
	print("33c.pair2_toss_plus_w3_companion: has_toss=%s has_w3_companion=%s (expect true, true)" % [pair2_has_toss, pair2_has_w3_companion])

	var pair4_events: Array = real_sequence.pairs[3].events
	print("33d.pair4_opposite_w_sides: w_values=%s (expect [3, -3] in some order)" % [
		[pair4_events[0].spawn_position.w, pair4_events[1].spawn_position.w],
	])

	var pair5_events: Array = real_sequence.pairs[4].events
	var pair5_has_pure_lateral := false
	var pair5_has_combined_drift := false
	for event in pair5_events:
		if is_equal_approx(event.velocity.w, 0.0) and not is_equal_approx(event.velocity.x, 0.0):
			pair5_has_pure_lateral = true
		if not is_equal_approx(event.velocity.w, 0.0) and not is_equal_approx(event.velocity.x, 0.0):
			pair5_has_combined_drift = true
	print("33e.pair5_pure_aim_plus_combined_drift: has_pure_lateral=%s has_combined_drift=%s (expect true, true)" % [pair5_has_pure_lateral, pair5_has_combined_drift])

	# 34. hitscan_weapon.gd's 3rd try-fallback (after the free-mode spawner
	# and duck row) actually reaches contest targets: restart the synthetic
	# sequence from test 32 fresh, reposition its first target directly in
	# front of the player, and fire a real shot at it through the full
	# weapon path (projectile travel, resolution, stats). Extend its hold
	# well past the ~0.5-0.6s a projectile actually takes to arrive - the
	# original 0.2s (fine for test 32's instant direct-call checks) would
	# let it retract before a real fired shot ever reaches it.
	test_event_a.hold_duration_sec = 3.0
	contest_player.start()
	await _wait_physics_frames(2)
	var contest_shot_target: Node4D = contest_player.get_active_targets()[0]
	contest_shot_target.position = Vector4(0, 1.75, 0, 0)
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection()
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
	await _wait_physics_frames(2)
	var hits_before_contest_shot: int = combat_stats_hud._hits
	var contest_shot_resolved: bool = await _fire_and_await_resolution(func() -> void: hitscan_weapon._fire())
	print("34a.hitscan_reaches_contest_target: resolved=%s hits %d->%d (expect true, +1)" % [
		contest_shot_resolved, hits_before_contest_shot, combat_stats_hud._hits,
	])

	# 35. w_targeting/slice_radar correctly see contest targets as
	# trackable/drawable, same as the free-mode spawner and duck row - pair
	# 1's second event (test_event_b) is still active at this point (only
	# event_a was just resolved above).
	var remaining_contest_targets: Array = contest_player.get_active_targets()
	print("35a.w_targeting_includes_contest_targets: remaining_count=%d included=%s" % [
		remaining_contest_targets.size(),
		remaining_contest_targets.size() > 0 and w_targeting._get_active_targets().has(remaining_contest_targets[0]),
	])

	# 36. Results overlay: resolve the rest of the synthetic sequence and
	# confirm the overlay shows, with the existing stats HUD's own
	# hits/misses/accuracy/time - not a second, separately-tracked copy of
	# the same numbers. Manually emitting CombatEvents.shot_fired alongside
	# each direct try_hit_target() call here stands in for the real weapon
	# path already proven correct in test 34, so the stats snapshot below is
	# meaningful without needing to fly a real projectile at every target.
	for target in contest_player.get_active_targets().duplicate():
		contest_player.try_hit_target(target)
		CombatEvents.shot_fired.emit(true)
	await _wait_physics_frames(5)
	for target in contest_player.get_active_targets().duplicate():
		contest_player.try_hit_target(target)
		CombatEvents.shot_fired.emit(true)
	await _wait_physics_frames(5)

	print("36a.results_overlay_visible: visible=%s" % [contest_results_overlay.visible])
	print("36b.results_overlay_summary_matches_hud: text=%s (expect it to contain Hits: %d and Misses: %d)" % [
		contest_results_overlay.summary_label.text, combat_stats_hud._hits, combat_stats_hud._misses,
	])
	await _screenshot("gallery_contest_results_overlay.png")
	contest_results_overlay.visible = false # Don't obscure the final free-mode visual check below.

	# Visual check: fire a normal-speed shot and catch it partway through its
	# flight (not yet resolved) so the projectile itself is actually visible
	# in the screenshot, alongside the ammo/stats HUD.
	player.global_position = Vector4(0, 1, 7, 0)
	player.basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
	spawner._current_target.global_position = Vector4(0, 1.75, 0, 0)
	await _wait_physics_frames(2)
	await _press_action(&"reload") # top up ammo in case this shot would otherwise misfire empty.
	await _wait_physics_frames(90)
	hitscan_weapon._fire()
	await _wait_physics_frames(15) # partway through the flight, well before it resolves.
	await _screenshot("gallery_projectile_in_flight.png")

	get_tree().quit()
