extends Node
## TEMPORARY - clean visual re-check of hip_suspension_solver.gd with
## wander FROZEN (body.halted=true) so camera framing can't desync from
## an actively-wandering creature between aim and capture - isolates
## whether the earlier odd "body far from legs" screenshot was a real
## solver bug or a test-camera timing artifact (the numerical trace
## already showed clean, stable, orthonormal basis + position throughout
## a real gait cycle, strongly suggesting the latter).

const SETTLE_FRAMES := 90


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
	body.halted = true # Freeze wander - isolates framing from creature motion entirely.

	for i in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	_frame_camera(player, body)
	await get_tree().physics_frame
	_frame_camera(player, body)
	await _screenshot("hip_suspension_clean_1.png")

	for i in range(60):
		await get_tree().physics_frame
	_frame_camera(player, body)
	await get_tree().physics_frame
	_frame_camera(player, body)
	await _screenshot("hip_suspension_clean_2.png")

	print("body.global_position=%s" % body.global_position)
	print("DONE")
	get_tree().quit()
