extends Node
## TEMPORARY - verifies sandbox/sky/sky_test.tscn end to end. Not part of
## the shipped scene.

@onready var player: CharacterBody4D = $"../SkyTest/FlatPlane/Player"
@onready var player_head: Node4D = $"../SkyTest/FlatPlane/Player/PlayerHead"
@onready var camera: Node4D = $"../SkyTest/FlatPlane/Player/PlayerHead/FirstPersonCamera"
@onready var sky: Node4D = $"../SkyTest/FlatPlane/Player/PlayerHead/FirstPersonCamera/Sky"
@onready var shell: MeshInstance4D = $"../SkyTest/FlatPlane/Player/PlayerHead/FirstPersonCamera/Sky/Shell"
@onready var sun_disc: Node4D = $"../SkyTest/FlatPlane/Player/PlayerHead/FirstPersonCamera/Sky/SunDisc"
@onready var sun_visual: MeshInstance4D = $"../SkyTest/FlatPlane/Player/PlayerHead/FirstPersonCamera/Sky/SunDisc/Visual"
@onready var ground: StaticBody4D = $"../SkyTest/FlatPlane/Ground"
@onready var ground_collision: CollisionShape4D = $"../SkyTest/FlatPlane/Ground/CollisionShape"
@onready var ground_mesh: MeshInstance4D = $"../SkyTest/FlatPlane/Ground/Mesh"
@onready var mountains: MeshInstance4D = $"../SkyTest/FlatPlane/Mountains"

func _wait_physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func _wait_process_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)

## Reads the actual rendered pixel color at normalized viewport coordinates
## (0-1 each axis) - a direct check of what's actually on screen, not just
## what a node's own material property is set to (a material can be set
## correctly and still not be what's actually rendered, e.g. if backface
## culling or a missing environment/background is showing through instead).
func _sample_pixel(fraction_x: float, fraction_y: float) -> Color:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var x: int = clampi(int(img.get_width() * fraction_x), 0, img.get_width() - 1)
	var y: int = clampi(int(img.get_height() * fraction_y), 0, img.get_height() - 1)
	return img.get_pixel(x, y)

## Same dot-product-per-axis transform as sky.gd's own _process() - an
## independent regression check of the implementation. Deliberately does
## NOT add any mesh-centering correction: sun_disc.position is meant to be
## the clean semantic "how aligned is the sun" value; only its Visual
## child's own fixed local offset centers the mesh around it (see sky.gd's
## class comment on why folding that into sun_disc itself was a real bug).
func _expected_local_offset(camera_basis: Projection) -> Vector4:
	var sun_world_offset: Vector4 = sky.SUN_DIRECTION * sky.SUN_DISTANCE
	return Vector4(
		sun_world_offset.dot(camera_basis.x),
		sun_world_offset.dot(camera_basis.y),
		sun_world_offset.dot(camera_basis.z),
		sun_world_offset.dot(camera_basis.w),
	)

func _ready() -> void:
	await get_tree().process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run()

func _run() -> void:
	await _wait_physics_frames(5)

	# 1. Basic resolution.
	print("1a.nodes_resolve: sky=%s shell=%s sun_disc=%s (expect all true)" % [sky != null, shell != null, sun_disc != null])
	print("1b.shell_pinned_at_w0: sky_position=%s (expect (0,0,0,0))" % [sky.position])
	print("1c.shell_mesh_huge: shell_size=%s (expect all components 400)" % [shell.mesh.size])
	print("1d.shell_material_set: has_material=%s (expect true)" % [shell.material_override != null])
	print("1e.sun_visual_mesh_set: mesh_matches_cylinder=%s (expect true)" % [sun_visual.mesh == sky.CylinderIcoMesh])
	print("1f.sun_visual_carries_its_own_fixed_w_correction: visual_position=%s (expect a nonzero w offset here, NOT on sun_disc itself)" % [sun_visual.position])

	# 2. Non-occlusion visual check - look down at the ground with the sky
	# in place, per the explicit "confirm this before moving on" requirement.
	# This print records the setup; the actual confirmation is the
	# screenshot itself, reviewed by eye.
	player.global_position = Vector4(0, 1, 0, 0)
	player.global_basis = Projection()
	player_head.basis = Basis4D.from_yz(-0.8) # Pitch down toward the ground.
	player._head_pitch = -0.8
	await _wait_process_frames(3)
	await _screenshot("sky_occlusion_check.png")
	print("2a.occlusion_screenshot_taken: see sky_occlusion_check.png - confirm the orange ground plane is visible, not hidden behind the shell")

	# 3. Elevation -> tint mapping, at the fixed SUN_DIRECTION.
	var expected_elevation_t: float = clampf(sky.SUN_DIRECTION.y * 0.5 + 0.5, 0.0, 1.0)
	var actual_elevation_t: float = sky.get_elevation_t()
	print("3a.elevation_t: expected=%.4f actual=%.4f (match=%s)" % [
		expected_elevation_t, actual_elevation_t, is_equal_approx(expected_elevation_t, actual_elevation_t),
	])
	var expected_tint: Color = sky.NIGHT_COLOR.lerp(sky.DAY_COLOR, expected_elevation_t)
	await _wait_process_frames(2)
	var actual_tint: Color = shell.material_override.albedo_color
	print("3b.shell_tint_matches_elevation: expected=%s actual=%s (match=%s)" % [
		expected_tint, actual_tint, expected_tint.is_equal_approx(actual_tint),
	])

	# 4. Sun disc local position - identity camera basis first (SUN_
	# DIRECTION has zero w by construction, so it should already read as
	# in-slice, local w ~ 0, at this orientation).
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
	player.global_basis = Projection()
	await _wait_process_frames(2)
	var expected_identity: Vector4 = _expected_local_offset(camera.global_basis)
	var actual_identity: Vector4 = sun_disc.position
	print("4a.sun_disc_position_identity: expected=%s actual=%s (match=%s)" % [
		expected_identity, actual_identity, expected_identity.is_equal_approx(actual_identity),
	])
	print("4b.sun_in_slice_at_identity: local_w=%.4f (expect ~0 - SUN_DIRECTION.w is 0 by construction)" % [actual_identity.w])

	# 5. Rotate the slice (zw plane) - the sun's local w should drift away
	# from 0, and the disc's actual position should track the new basis
	# exactly, confirming it goes off-slice via ordinary cross-section rules,
	# not any special-cased visibility check.
	player.global_basis = Basis4D.from_zw(PI / 2.0)
	await _wait_process_frames(2)
	var expected_rotated: Vector4 = _expected_local_offset(camera.global_basis)
	var actual_rotated: Vector4 = sun_disc.position
	print("5a.sun_disc_position_rotated: expected=%s actual=%s (match=%s)" % [
		expected_rotated, actual_rotated, expected_rotated.is_equal_approx(actual_rotated),
	])
	print("5b.sun_off_slice_after_rotation: local_w=%.4f (expect clearly nonzero, not ~0 anymore)" % [actual_rotated.w])

	# Visual check - back to identity, looking straight ahead.
	player.global_basis = Projection()
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
	await _wait_process_frames(2)
	await _screenshot("sky_forward_view.png")

	# 6. Actually sample a rendered pixel from the backdrop region (top of
	# frame, above the ground/horizon line) - the screenshot alone only
	# shows what a human eye judges as color; this confirms numerically
	# whether the shell is rendering its own material AT ALL (as opposed to
	# an unset default background/clear color showing through an entirely
	# unrendered, backface-culled shell - the actual bug this caught).
	# Checks hue/shape, not exact magnitude: Godot's default tonemapping
	# applies to the whole framebuffer regardless of this material's own
	# "unshaded" render mode, so the sampled value is consistently darker
	# than the raw Color() by some uniform curve, not a 1:1 readback -
	# confirmed by hand (dividing each sampled channel by the expected
	# channel gives ~0.72-0.73 across all three, i.e. one shared scale
	# factor, not three independent ones - a tonemap signature, not noise).
	var expected_pixel_tint: Color = sky.NIGHT_COLOR.lerp(sky.DAY_COLOR, sky.get_elevation_t())
	var sampled_backdrop: Color = await _sample_pixel(0.5, 0.1)
	var is_neutral_grey: bool = (
		absf(sampled_backdrop.r - sampled_backdrop.g) < 0.02 and absf(sampled_backdrop.g - sampled_backdrop.b) < 0.02
	)
	var hue_matches: bool = sampled_backdrop.b > sampled_backdrop.g and sampled_backdrop.g > sampled_backdrop.r
	print("6a.rendered_backdrop_pixel: expected_hue_direction≈%s sampled=%s is_neutral_grey=%s (expect false) hue_matches_b_gt_g_gt_r=%s (expect true - confirms the shell's own blue-ish tint is genuinely what's rendering, not a flat default background)" % [
		expected_pixel_tint, sampled_backdrop, is_neutral_grey, hue_matches,
	])

	# 7. Mountains - world-space (NOT camera-parented), a large non-uniform
	# OrthoplexTetraMesh4D, and the ground plane extended to the same
	# x/z/w radius.
	print("7a.mountains_world_space: parent=%s (expect FlatPlane, not Sky/the camera)" % [mountains.get_parent().name])
	print("7b.mountains_mesh_size: size=%s (expect (300, 50, 300, 300) - wide in x/z/w, flat in y)" % [mountains.mesh.size])
	# Position (0,0,0,0), NOT (0,25,0,0): an orthoplex's L1 "budget" is
	# shared across all 4 axes, so its WIDEST x/z/w cross-section is at its
	# own vertical CENTER, not at its own y-extreme. Centering it at y=0
	# (ground level) puts that wide horizon ring exactly at the ground,
	# tapering to a modest peak above (y=+25) with the lower half (y=-25
	# to 0) safely buried - a real mountain profile, wide base narrowing
	# to a peak. Centering at y=25 instead (an earlier mistake) put the
	# WIDE ring floating at mid-air height, pinching to a single point at
	# both y=0 (the "base") and y=50 (the "peak") - a floating lens, not a
	# mountain range with a base on the ground.
	print("7c.mountains_position: position=%s (expect (0, 0, 0, 0) - centered at ground level so the wide x/z/w ring sits there, not floating mid-air)" % [mountains.position])
	print("7d.mountains_winding_flipped: basis=%s (expect a -1 on exactly one spatial column, same backface-culling fix already proven on the skybox shell)" % [mountains.basis])
	print("7e.ground_extended_to_same_radius: shape_size=%s mesh_size=%s (expect both (300, 1, 300, 300), matching the mountains' own 300-wide x/z/w radius)" % [
		ground_collision.shape.size, ground_mesh.mesh.size,
	])

	# Visual check - standing near the origin, looking at the mountains
	# rather than straight down an axis (which points at a single
	# orthoplex vertex, not a broad face) - a diagonal view shows one of
	# the octahedron's flat diagonal faces instead, reading as a proper
	# mountain wall/slope.
	player.global_position = Vector4(0, 1, 0, 0)
	player.global_basis = Basis4D.from_zx(PI / 4.0)
	player_head.basis = Basis4D.from_yz(0.15) # Slight upward tilt to see the sloped face rise into the sky.
	player._head_pitch = 0.15
	await _wait_process_frames(3)
	await _screenshot("sky_mountains_view.png")
	print("7f.mountains_screenshot_taken: see sky_mountains_view.png - confirm a mountain silhouette reads clearly against the sky, ground still extends out to meet it, no gap/void")

	# Sample a pixel where the mountain's own flat grey-blue should be
	# rendering (not the sky's blue, not a culled-shell-style default grey)
	# - same rendering-confirmation technique as check 6, adapted: mountain
	# grey (0.35, 0.38, 0.45) has a much flatter b/r ratio than the sky's
	# blue (whether raw or tonemapped, consistently >1.7); confirming a
	# LOWER ratio here rules out "this is just more sky" as well as "this
	# is the culled/default background."
	var sampled_mountain: Color = await _sample_pixel(0.5, 0.55)
	var mountain_b_over_r: float = sampled_mountain.b / sampled_mountain.r if sampled_mountain.r > 0.001 else 0.0
	print("7g.rendered_mountain_pixel: sampled=%s b_over_r=%.3f (expect notably flatter than the sky's own ~1.7+ ratio, and not the culled-shell default grey (0.298,0.298,0.298))" % [
		sampled_mountain, mountain_b_over_r,
	])

	# 8. Diagnostic: sky_forward_view.png showed a solid BLACK band above
	# the mountain's own silhouette, where blue sky was expected instead -
	# isolate whether the skybox itself regressed, or whether this is
	# specific to how the mountain and skybox interact. Look straight UP
	# (clear of the mountain's own 50-unit ceiling entirely from any
	# horizontal position within its 150-unit radius), where nothing but
	# the skybox shell should ever be visible.
	player.global_position = Vector4(0, 1, 0, 0)
	player.global_basis = Projection()
	player_head.basis = Basis4D.from_yz(-1.55) # Near-vertical, looking straight up.
	player._head_pitch = -1.55
	await _wait_process_frames(3)
	await _screenshot("sky_straight_up.png")
	var sampled_up: Color = await _sample_pixel(0.5, 0.5)
	print("8a.straight_up_pixel: sampled=%s (expect the sky's own blue-ish tint, NOT black/void - isolates a skybox regression from a mountain-specific gap)" % [sampled_up])

	# 8b. Decisive isolation: the 45-degree diagonal view ALSO showed solid
	# black above the mountain's silhouette, ruling out "only exact-vertex
	# viewing directions are affected." Move the player well OUTSIDE the
	# mountain's own 150-unit world-space radius (mountain is world-fixed;
	# the skybox is camera-parented, so it's always exactly 200 units away
	# in every direction regardless of where the player physically stands),
	# then look AWAY from the mountain entirely - nothing else could
	# possibly be in view here but the skybox shell.
	player.global_position = Vector4(220, 1, 0, 0)
	player.global_basis = Projection() # Facing -z, i.e. tangent to/away from the mountain's own center, not toward it.
	player_head.basis = Basis4D.from_yz(0.0)
	player._head_pitch = 0.0
	await _wait_process_frames(3)
	await _screenshot("sky_far_from_mountain.png")
	var sampled_far: Color = await _sample_pixel(0.5, 0.3)
	print("8b.far_from_mountain_pixel: sampled=%s (expect the sky's blue-ish tint - if this is ALSO black, the bug is in the skybox/mountain interaction generally, not specific to being near the mountain)" % [sampled_far])

	print("DONE")
