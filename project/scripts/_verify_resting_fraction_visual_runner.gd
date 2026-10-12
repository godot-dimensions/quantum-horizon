extends Node
## TEMPORARY - A/B screenshot comparison of hip_suspension_solver.gd's
## resting_extension_fraction (current default 0.5333 vs a candidate 0.8)
## on the motion lab's default 4x3 creature, same static pose/camera, to
## check the "legs curled from too much slack" complaint directly rather
## than guessing at a new number. Wired in as a temporary autoload with
## limb_prototype_treadmill.tscn set as the main scene.


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _frame_camera(player: CharacterBody4D, body: Node4D) -> void:
	player.global_basis = Projection()
	player.global_position = body.global_position + Vector4(9, 3, -11, 0)
	player.global_basis = Basis4D.looking_at(body.global_position - player.global_position)


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var body: Node4D = flat_plane.get_node("MotionLabCreature/Body")
	body.halted = true

	for i in range(90):
		await get_tree().physics_frame
	_frame_camera(player, body)
	await get_tree().physics_frame
	_frame_camera(player, body)
	await _screenshot("resting_fraction_0533.png")
	print("at 0.5333: body.position.y=%.4f" % body.position.y)

	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var solver = root.get_node("HipSuspensionSolver")
	solver.resting_extension_fraction = 0.8
	for i in range(90):
		await get_tree().physics_frame
	_frame_camera(player, body)
	await get_tree().physics_frame
	_frame_camera(player, body)
	await _screenshot("resting_fraction_080.png")
	print("at 0.8: body.position.y=%.4f" % body.position.y)

	print("DONE")
	get_tree().quit()
