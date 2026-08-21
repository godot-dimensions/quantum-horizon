extends Node
## TEMPORARY - visual check of hip_suspension_solver.gd on a real walking
## gait cycle (Steed1, creature_gallery.tscn): a few screenshots spread
## across a cycle, watching for a natural damped bob rather than jitter or
## a visible pop. Wired in as a temporary autoload with
## creature_gallery.tscn set as the main scene.


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
	player.global_position = body.global_position + Vector4(9, 4, -11, 0)
	player.global_basis = Basis4D.looking_at(body.global_position - player.global_position)


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var creature: Node = flat_plane.get_node("Steed1")
	var body: Node4D = creature.get_node("Body")

	for i in range(60):
		await get_tree().physics_frame
		_frame_camera(player, body)
	await _screenshot("hip_suspension_walk_1.png")

	for i in range(40):
		await get_tree().physics_frame
		_frame_camera(player, body)
	await _screenshot("hip_suspension_walk_2.png")

	for i in range(40):
		await get_tree().physics_frame
		_frame_camera(player, body)
	await _screenshot("hip_suspension_walk_3.png")

	print("DONE")
	get_tree().quit()
