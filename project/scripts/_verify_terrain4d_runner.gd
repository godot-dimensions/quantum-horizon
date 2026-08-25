extends Node
## TEMPORARY - verifies sandbox/terrain4d/terrain4d_test.tscn end to end.
## Not part of the shipped scene.

@onready var rig: Node4D = $"../Scene/World/TerrainRig"
@onready var terrain: StaticBody4D = $"../Scene/World/TerrainRig/Terrain"
@onready var camera: Camera4D = $"../Scene/World/OverheadCamera"
@onready var voxel_hover: Node = $"../Scene/World/VoxelHover"
@onready var hover_outline: MeshInstance4D = $"../Scene/World/TerrainRig/Terrain/HoverOutline"

func _wait_process_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)

func _sample_pixel(fraction_x: float, fraction_y: float) -> Color:
	var img := get_viewport().get_texture().get_image()
	var x: int = clampi(int(img.get_width() * fraction_x), 0, img.get_width() - 1)
	var y: int = clampi(int(img.get_height() * fraction_y), 0, img.get_height() - 1)
	return img.get_pixel(x, y)

## Holds `button` down, feeds `steps` mouse-motion events each moving by
## `delta`, then releases - mirrors real click-drag input.
func _drag(button: MouseButton, delta: Vector2, steps: int) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	for i in steps:
		var motion := InputEventMouseMotion.new()
		motion.relative = delta
		Input.parse_input_event(motion)
		await get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.button_index = button
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame

func _ready() -> void:
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run()

func _run() -> void:
	await _wait_process_frames(3)

	# 1. Noise4D: deterministic, and bounded to [-1, 1] by construction.
	var noise_a := Noise4D.new(7)
	var noise_b := Noise4D.new(7)
	var sample_point := Vector4(1.3, -0.7, 2.1, 0.4)
	var value_a: float = noise_a.fractal_noise(sample_point, 3, 0.5, 2.0)
	var value_b: float = noise_b.fractal_noise(sample_point, 3, 0.5, 2.0)
	print("1a.noise_deterministic: a=%.6f b=%.6f (expect equal)" % [value_a, value_b])
	print("1b.noise_in_range: value=%.6f (expect within [-1,1])" % [value_a])
	var different_point := Vector4(5.9, 3.2, -4.1, 1.8)
	var value_c: float = noise_a.fractal_noise(different_point, 3, 0.5, 2.0)
	print("1c.noise_varies_by_point: value_a=%.6f value_c=%.6f (expect different)" % [value_a, value_c])

	# 2. Dual contouring output sanity.
	var result: Dictionary = terrain.get_last_result()
	var tet_count: int = result.tet_count
	var active_cell_count: int = result.active_cell_count
	print("2a.tet_count_positive: tet_count=%d (expect > 0)" % [tet_count])
	print("2b.active_cell_count_positive: active_cell_count=%d (expect > 0)" % [active_cell_count])
	print("2c.tet_vertex_array_sizes: indices=%d normals=%d expected=%d (match=%s)" % [
		result.tet_vertex_indices.size(), result.tet_vertex_normals.size(), tet_count * 4,
		result.tet_vertex_indices.size() == tet_count * 4 and result.tet_vertex_normals.size() == tet_count * 4,
	])
	print("2c2.unique_vertex_count_matches_active_cells: %d (expect == active_cell_count %d)" % [
		result.unique_vertex_positions.size(), active_cell_count,
	])

	# 2d. The mesh should be a CLOSED chunk now (top surface + side walls +
	# bottom), not just the bare top surface - confirm vertices exist near
	# the bottom and near a side wall, not only clustered near the top.
	var min_y := INF
	var max_abs_x := 0.0
	for p in result.unique_vertex_positions:
		min_y = minf(min_y, p.y)
		max_abs_x = maxf(max_abs_x, absf(p.x))
	var expected_bottom_y: float = terrain.bounds_min_y + terrain.boundary_margin_vertical
	var expected_wall_x: float = terrain.bounds_half_extent_horizontal - terrain.boundary_margin_horizontal
	print("2d.mesh_has_bottom_and_walls: min_y=%.2f (expect near %.2f) max_abs_x=%.2f (expect near %.2f)" % [
		min_y, expected_bottom_y, max_abs_x, expected_wall_x,
	])

	# 3. Built mesh + collision.
	var mesh: ArrayTetraMesh4D = terrain.mesh_instance.mesh
	var vertex_count: int = mesh.get_vertices().size()
	var cell_index_count: int = mesh.get_simplex_cell_indices().size()
	print("3a.mesh_nonempty: vertices=%d cell_indices=%d (expect both > 0)" % [vertex_count, cell_index_count])
	var max_index := -1
	for idx in mesh.get_simplex_cell_indices():
		max_index = maxi(max_index, idx)
	print("3b.cell_indices_in_range: max_index=%d vertex_count=%d (expect max_index < vertex_count)" % [max_index, vertex_count])

	var shape: ConcaveMeshShape4D = terrain.collision_shape.shape
	print("3c.collision_shape_built: is_concave_mesh=%s simplex_cells=%d (expect true, > 0)" % [
		shape is ConcaveMeshShape4D, shape.get_simplex_cells().size() if shape != null else 0,
	])

	# 4. Collision-shape correctness, verified directly via raycast against
	# ConcaveMeshShape4D.raycast_intersects() - this exercises the shape's
	# own real per-tetrahedron geometry, independent of any character body.
	#
	# NOTE: this scene has no walking player (per the strategy-camera
	# redesign), so there's nothing to "settle" on the terrain to test - see
	# [[project-quantum-horizon]] memory for the separately-discovered,
	# pre-existing CharacterBody4D/concave-collision engine gap that made
	# that kind of test invalid anyway.
	var expected_surface_y: float = terrain.find_surface_y(0.0, 0.0, 0.0)
	var ray_hit: Dictionary = shape.raycast_intersects(Vector4(0, 8, 0, 0), Vector4(0, -1, 0, 0), 20.0, false)
	var ray_hit_y: float = (8.0 - float(ray_hit.get("distance", -1.0))) if ray_hit.get("hit", false) else -999.0
	print("4a.expected_surface_y_analytic: %.3f" % [expected_surface_y])
	print("4b.raycast_hit: %s" % [ray_hit])
	print("4c.raycast_hit_y_vs_analytic: %.3f expected=%.3f diff=%.3f (expect small diff - confirms the collision shape's real geometry matches the density field)" % [
		ray_hit_y, expected_surface_y, absf(ray_hit_y - expected_surface_y),
	])

	# 5. Camera orbits a fixed pivot, looking at it from wherever azimuth/
	# elevation currently place it.
	print("5a.camera_position: %s" % [camera.global_position])
	print("5b.camera_is_current: %s (expect true)" % [camera.current])
	await _screenshot("terrain4d_view_before_rotation.png")

	# 6. Right-drag rotates the TERRAIN in the 4D (xw/zw) planes only - the
	# y-column must stay untouched, and left-drag must NOT affect it at all
	# now (3D viewing moved entirely to the camera - see section 7/8).
	var rig_basis_before: Projection = rig.basis
	await _drag(MOUSE_BUTTON_RIGHT, Vector2(40, 0), 10)
	var rig_basis_after_right: Projection = rig.basis
	print("6a.rig_basis_after_right_drag: %s" % [rig_basis_after_right])
	print("6b.right_drag_preserves_y_column: %s (expect true - xw/zw never touch y)" % [
		rig_basis_after_right.y.is_equal_approx(rig_basis_before.y),
	])
	print("6c.right_drag_changed_basis: %s (expect true)" % [not rig_basis_after_right.x.is_equal_approx(rig_basis_before.x)])
	await _screenshot("terrain4d_view_after_right_drag.png")

	await _drag(MOUSE_BUTTON_LEFT, Vector2(-40, 40), 10)
	var rig_basis_after_left: Projection = rig.basis
	print("6d.left_drag_does_not_touch_terrain_rig: %s (expect true - 3D viewing is camera-only now)" % [
		rig_basis_after_left.x.is_equal_approx(rig_basis_after_right.x)
		and rig_basis_after_left.y.is_equal_approx(rig_basis_after_right.y)
		and rig_basis_after_left.z.is_equal_approx(rig_basis_after_right.z)
		and rig_basis_after_left.w.is_equal_approx(rig_basis_after_right.w),
	])

	# 7. Left-drag orbits the CAMERA instead: azimuth changes freely, and the
	# camera stays pointed at the same fixed pivot throughout.
	var camera_pos_before: Vector4 = camera.position
	await _drag(MOUSE_BUTTON_LEFT, Vector2(60, 0), 15)
	var camera_pos_after_azimuth: Vector4 = camera.position
	print("7a.azimuth_drag_moved_camera: %s (expect true)" % [not camera_pos_after_azimuth.is_equal_approx(camera_pos_before)])
	print("7b.azimuth_drag_kept_same_distance_from_pivot: before=%.4f after=%.4f (expect equal)" % [
		(camera_pos_before - camera.look_at_target).length(), (camera_pos_after_azimuth - camera.look_at_target).length(),
	])
	await _screenshot("terrain4d_view_after_azimuth_drag.png")

	# 8. Elevation clamps at both ends - can never go past straight-down or
	# down to/past the horizon (the actual "upside-down" fix). Drag WAY past
	# each limit and confirm it settles exactly at the clamp, not beyond.
	await _drag(MOUSE_BUTTON_LEFT, Vector2(0, -400), 20)
	var elevation_at_min: float = camera._elevation
	print("8a.elevation_clamped_at_min: %.4f expected=%.4f (expect equal)" % [
		rad_to_deg(elevation_at_min), camera.min_elevation_deg,
	])
	print("8b.camera_still_above_pivot_height: %s (expect true - never crosses to below/level with the pivot)" % [
		camera.position.y > camera.look_at_target.y,
	])
	await _drag(MOUSE_BUTTON_LEFT, Vector2(0, 400), 40)
	var elevation_at_max: float = camera._elevation
	print("8c.elevation_clamped_at_max: %.4f expected=%.4f (expect equal)" % [
		rad_to_deg(elevation_at_max), camera.max_elevation_deg,
	])
	print("8d.camera_never_dips_below_horizon: %s (expect true)" % [
		camera.position.y >= camera.look_at_target.y,
	])
	await _screenshot("terrain4d_view_near_horizon.png")

	# 9. Voxel hover outline - reset the rig and camera to known state, then
	# drive the hover script directly with the exact screen position of a
	# point already confirmed to be on the surface (the raycast hit from
	# section 4), via update_hover_at() rather than Input.warp_mouse() - the
	# latter doesn't reliably relocate the OS cursor in this automated
	# window (confirmed: get_viewport().get_mouse_position() didn't reflect
	# the warp afterward, even though a direct raycast using the exact same
	# target ray succeeds - the hover FEATURE was never broken, only this
	# test's way of simulating mouse input was unreliable).
	rig.basis = Projection()
	camera._azimuth = deg_to_rad(camera.initial_azimuth_deg)
	camera._elevation = deg_to_rad(camera.initial_elevation_deg)
	camera._apply_orbit()
	await _wait_process_frames(2)
	# Checked immediately after the call, with no awaited frame in between -
	# this node's own _process() runs every frame using whatever the REAL
	# mouse happens to be at (irrelevant here), which would otherwise
	# overwrite this result a frame or two later.
	var known_surface_point := Vector4(0.0, terrain.find_surface_y(0.0, 0.0, 0.0), 0.0, 0.0)
	var target_screen_pos: Vector2 = camera.world_to_viewport(known_surface_point)
	voxel_hover.update_hover_at(target_screen_pos)
	print("9a.hover_outline_visible: %s (expect true)" % [hover_outline.visible])
	var outline_mesh: ArrayWireMesh4D = hover_outline.mesh
	var outline_vertex_count: int = outline_mesh.get_vertices().size() if outline_mesh != null else 0
	print("9b.hover_outline_vertex_count: %d (expect > 0)" % [outline_vertex_count])
	print("9c.hover_dual_cube_id: %d (expect >= 0)" % [voxel_hover._last_dual_cube_id])
	await _screenshot("terrain4d_view_hover_outline.png")

	print("DONE")
	get_tree().quit()
