extends Node
## TEMPORARY - verifies the shooting_gallery.tscn experiment end to end.
## Not part of the shipped scene.

@onready var player: CharacterBody4D = $"../Gallery/FlatPlane/Player"
@onready var player_head: Node4D = $"../Gallery/FlatPlane/Player/PlayerHead"
@onready var spawner: Node4D = $"../Gallery/FlatPlane/GalleryTargetSpawner"
@onready var poi_arrow: Control = $"../Gallery/PoiArrow"
@onready var crosshair: Control = $"../Gallery/Crosshair"
@onready var barrier: StaticBody4D = $"../Gallery/FlatPlane/Barrier"

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
		var in_w: bool = absf(pos.w) <= 20.01
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
	await _screenshot("gallery_overview.png")

	get_tree().quit()
