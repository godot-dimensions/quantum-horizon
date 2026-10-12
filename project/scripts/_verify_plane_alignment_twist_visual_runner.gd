extends Node
## TEMPORARY - visual verification of the plane-alignment twist: static
## pose first, then a real gait cycle, feature OFF vs ON, same camera
## framing each time (reusing _verify_limb_prototype_anatomy_check_runner.gd's
## own 3/4-angle screenshot pattern). Wired in as a temporary autoload with
## creature_gallery.tscn set as the main scene.

const SCREENSHOT_DIR := "res://smoke_test_output/"


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(SCREENSHOT_DIR + image_name)


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _set_twist(creature: Node, enabled: bool) -> void:
	for leg_name in ["FL", "FR", "BL", "BR"]:
		var ik_chain = creature.get_node("Body/LimbAnchor%s/IKChain" % leg_name)
		ik_chain.enable_plane_alignment_twist = enabled
		ik_chain.joint_hinge_min_deg = Array([], TYPE_FLOAT, "", null)
		ik_chain.joint_hinge_max_deg = Array([], TYPE_FLOAT, "", null)


func _frame_camera(player: CharacterBody4D, body: Node4D) -> void:
	player.global_basis = Projection()
	player.global_position = body.global_position + Vector4(9, 5, -11, 0)
	player.global_basis = Basis4D.looking_at(body.global_position - player.global_position)


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var creature: Node = flat_plane.get_node("Steed1")
	var body: Node4D = creature.get_node("Body")

	body.halted = true # Freeze wander so framing stays put for a clean comparison.
	_frame_camera(player, body)
	await get_tree().physics_frame

	_set_twist(creature, false)
	for i in range(30):
		await get_tree().physics_frame
	_frame_camera(player, body)
	await _screenshot("twist_static_OFF.png")

	_set_twist(creature, true)
	for i in range(30):
		await get_tree().physics_frame
	_frame_camera(player, body)
	await _screenshot("twist_static_ON.png")

	body.halted = false
	_set_twist(creature, false)
	for i in range(60):
		await get_tree().physics_frame
		_frame_camera(player, body)
	await _screenshot("twist_gait_OFF.png")

	_set_twist(creature, true)
	for i in range(60):
		await get_tree().physics_frame
		_frame_camera(player, body)
	await _screenshot("twist_gait_ON.png")

	print("DONE")
	get_tree().quit()
