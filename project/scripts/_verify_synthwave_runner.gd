extends Node
## TEMPORARY - deep debug pass for the reported sky-gradient bug: pitch moves
## the gradient the WRONG way, yaw and 4D rotation visibly do (or don't)
## affect it in ways that don't match hand-derived expectations. Drives pure,
## isolated single-axis rotations (yaw-only, pitch-only, 4D-only) and prints
## both the raw camera basis and the computed local_up uniform value at each
## step, plus samples an actual rendered pixel - to find the real
## discrepancy instead of continuing to theorize. Not part of the shipped
## scene. Wired in as a temporary autoload with synthwave_test.tscn set as
## the main scene.


func _sample_pixel(fraction_x: float, fraction_y: float) -> Color:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var x: int = clampi(int(img.get_width() * fraction_x), 0, img.get_width() - 1)
	var y: int = clampi(int(img.get_height() * fraction_y), 0, img.get_height() - 1)
	return img.get_pixel(x, y)


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
	var camera: Node4D = scene.get_node("Player/PlayerHead/FirstPersonCamera")
	var sky: Node = scene.get_node("Player/PlayerHead/FirstPersonCamera/Sky")

	print("1.nodes_resolve: player=%s player_head=%s camera=%s sky=%s" % [
		player != null, player_head != null, camera != null, sky != null,
	])

	player.global_position = Vector4(0, 1, 0, 0)

	# --- Pure pitch sweep, no yaw, no 4D rotation. ---
	print("--- PITCH SWEEP (player.basis=identity throughout) ---")
	for i in range(7):
		var pitch: float = -0.9 + i * 0.3 # -0.9 .. 0.9
		player.global_basis = Projection()
		player_head.basis = Basis4D.from_yz(pitch)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var cam_basis: Projection = camera.global_basis
		var mid_pixel: Color = await _sample_pixel(0.5, 0.3)
		var center_pixel: Color = await _sample_pixel(0.5, 0.5)
		# Screen CENTER specifically: this ray's local direction is exactly
		# (0,0,-1) regardless of FOV (no off-center geometry assumptions
		# needed), so its true world elevation is exactly sin(pitch) - a
		# hard, low-assumption prediction independent of anything about this
		# custom camera's projection specifics.
		print("pitch=%.2f cam_basis.y=%s cam_basis.z=%s local_up=%s mid_pixel=%s center_pixel=%s (expect center_pixel to trend darker/toward zenith as pitch increases - sin(pitch)=%.3f)" % [
			pitch, cam_basis.y, cam_basis.z, sky._debug_local_up, mid_pixel, center_pixel, sin(pitch),
		])
	await _screenshot("debug_pitch_sweep_last.png")

	# --- Pure yaw sweep, pitch fixed at a moderate upward angle so the sky
	# (not just ground) fills the sampled pixel. ---
	print("--- YAW SWEEP (pitch fixed at 0.3, only player.basis yaws) ---")
	player_head.basis = Basis4D.from_yz(0.3)
	for i in range(5):
		var yaw: float = i * (PI / 4.0) # 0 .. PI
		player.global_basis = Basis4D.from_zx(yaw)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var cam_basis: Projection = camera.global_basis
		var mid_pixel: Color = await _sample_pixel(0.5, 0.3)
		print("yaw=%.2f cam_basis.y=%s mid_pixel=%s (expect cam_basis.y and mid_pixel BOTH constant across this whole sweep - pure yaw doesn't tilt up at all)" % [
			yaw, cam_basis.y, mid_pixel,
		])

	# --- Pure 4D (xw-plane) rotation, pitch fixed, no yaw. ---
	print("--- 4D XW SWEEP (pitch fixed at 0.3, only player.basis xw-rotates) ---")
	player.global_basis = Projection()
	player_head.basis = Basis4D.from_yz(0.3)
	for i in range(5):
		var xw_angle: float = i * (PI / 4.0)
		player.global_basis = Basis4D.from_xw(xw_angle)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var cam_basis: Projection = camera.global_basis
		var mid_pixel: Color = await _sample_pixel(0.5, 0.3)
		print("xw=%.2f cam_basis.y=%s mid_pixel=%s (expect BOTH constant - an xw rotation doesn't touch the y axis at all)" % [
			xw_angle, cam_basis.y, mid_pixel,
		])

	# --- Star-panning visual check: same pitch (looking well up, into the
	# starfield), two very different yaw angles. If stars are now genuinely
	# world-fixed, the pattern should be visibly DIFFERENT between these two
	# shots (a different slice of the celestial sphere in view); if they're
	# still camera-rigid, the two screenshots would be pixel-identical.
	player.global_basis = Projection()
	player_head.basis = Basis4D.from_yz(0.9)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _screenshot("star_pan_yaw0.png")

	player.global_basis = Basis4D.from_zx(PI / 2.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _screenshot("star_pan_yaw90.png")

	# Same check at a NORMAL forward-ish viewing angle (not deep zenith,
	# where the first check showed no stars at all - either they're genuinely
	# absent there, or the gradient's t never climbs high enough at that
	# angle to cross the star-visibility threshold; this angle is where the
	# very first working screenshot showed a clearly star-filled sky).
	player.global_basis = Projection()
	player_head.basis = Basis4D.from_yz(-0.1)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _screenshot("normal_view_yaw0.png")

	player.global_basis = Basis4D.from_zx(PI / 2.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _screenshot("normal_view_yaw90.png")

	print("DONE")
	get_tree().quit()
