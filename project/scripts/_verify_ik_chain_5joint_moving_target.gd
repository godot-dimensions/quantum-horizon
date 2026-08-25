extends Node
## TEMPORARY - the gameplay-relevant question the static settle-and-measure
## tests can't answer: does the 5-joint chain visibly keep up with a
## CONTINUOUSLY moving target, or does it lag behind? Drives a separate
## visible marker (NOT the player - the player sits fixed as an external
## camera instead, since using the player as both the moving target and the
## screenshot camera would make it impossible to see any lag) back and forth
## on a fast triangle-wave path (sharp velocity reversals at each end - the
## "fast repositioning" moments this test is specifically checking) and
## logs the marker-to-effector distance continuously through the whole
## motion, not just at rest. Not part of the shipped scene - wired in as a
## temporary autoload with single_joint_test.tscn set as the main scene.

const SPEED := 8.0 # units/sec - fast relative to slew_time_constant_sec (0.35s): in one time constant the marker covers ~2.8 units, a large fraction of the chain's own reach.
const HALF_WIDTH := 3.0
const PATH_CENTER := Vector4(0, 3, 4, 0)
const TOTAL_TIME_SEC := 3.0


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


## Constant-speed back-and-forth: sharp direction reversal at each end,
## unlike a sine wave (which eases through zero velocity at the ends) - the
## reversal is exactly the "fast repositioning" moment worth stress-testing.
func _triangle_x(t: float) -> float:
	var period: float = 4.0 * HALF_WIDTH / SPEED
	var phase: float = fposmod(t, period) / period
	if phase < 0.5:
		return -HALF_WIDTH + (phase / 0.5) * (2.0 * HALF_WIDTH)
	return HALF_WIDTH - ((phase - 0.5) / 0.5) * (2.0 * HALF_WIDTH)


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var ik_chain: Node = flat_plane.get_node("IKChain")

	# Fixed external observer, not the moving target - see file header.
	player.global_basis = Projection()
	player.global_position = Vector4(0, 5, -6, 0)
	player.global_basis = Basis4D.looking_at(PATH_CENTER - player.global_position)

	var marker := Node4D.new()
	flat_plane.add_child(marker)
	var marker_mesh := MeshInstance4D.new()
	var marker_shape := OrthoplexTetraMesh4D.new()
	marker_shape.size = Vector4(0.5, 0.5, 0.5, 0.5)
	marker_mesh.mesh = marker_shape
	var marker_material := TetraMaterial4D.new()
	marker_material.albedo_color = Color(1, 1, 1, 1)
	marker_mesh.material_override = marker_material
	marker.add_child(marker_mesh)

	ik_chain.target = marker
	for joint in ik_chain.joints:
		joint.global_basis = Projection()

	var period: float = 4.0 * HALF_WIDTH / SPEED
	print("1.period=%.3fs speed=%.2f half_width=%.2f total_time=%.2fs" % [period, SPEED, HALF_WIDTH, TOTAL_TIME_SEC])

	var total_frames: int = int(TOTAL_TIME_SEC * 60.0)
	var max_distance: float = 0.0
	var max_distance_time: float = 0.0
	var screenshot_done_mid: bool = false
	var screenshot_done_reversal: bool = false
	for frame in range(total_frames):
		var t: float = frame / 60.0
		var x: float = _triangle_x(t)
		marker.global_position = Vector4(PATH_CENTER.x + x, PATH_CENTER.y, PATH_CENTER.z, PATH_CENTER.w)
		await get_tree().physics_frame

		var effector_pos: Vector4 = ik_chain._end_effector_position()
		var distance: float = (effector_pos - marker.global_position).length()
		if distance > max_distance:
			max_distance = distance
			max_distance_time = t

		if frame % 3 == 0:
			print("t=%.3fs marker_x=%.3f distance=%.4f" % [t, x, distance])

		# One screenshot mid-swing (marker moving fast through the center,
		# away from either reversal) and one right at the first reversal
		# (t = period/2, where the direction sign-flips) - together these
		# should show whether the hand visibly trails the marker or stays on
		# top of it.
		if not screenshot_done_mid and t >= period * 0.25:
			screenshot_done_mid = true
			await _screenshot("ik_chain_5joint_moving_midswing.png")
		if not screenshot_done_reversal and t >= period * 0.5:
			screenshot_done_reversal = true
			await _screenshot("ik_chain_5joint_moving_at_reversal.png")

	print("2.max_distance=%.4f at t=%.3fs (period=%.3fs, so this is %.2f periods in)" % [
		max_distance, max_distance_time, period, max_distance_time / period,
	])
	print("DONE")
	get_tree().quit()
