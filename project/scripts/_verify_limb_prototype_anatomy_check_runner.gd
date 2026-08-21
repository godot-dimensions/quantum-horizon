extends Node
## TEMPORARY - wide, side-on screenshots of the spawn-seeded anatomical
## pose (and again after some real walking) to judge the bend shape against
## the horse-anatomy reference (humerus+radius+cannon front,
## femur+tibia+cannon back). Not part of the shipped scene - wired in as a
## temporary autoload with limb_prototype_treadmill.tscn set as the main
## scene.


func _screenshot(image_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/" + image_name)


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var flat_plane: Node4D = scene.get_node("FlatPlane")
	var player: CharacterBody4D = flat_plane.get_node("Player")
	var body: Node4D = flat_plane.get_node("Body")

	body.speed = 0.0 # Freeze wander so the framing stays put for a clean side-on shot.
	player.global_basis = Projection()

	# 3/4 angled view (combines X and Z offset) so both the front/back leg
	# separation (X) and left/right separation (Z) show up as distinct
	# screen positions, avoiding the edge-on degenerate case a pure-axis
	# camera risks (confirmed necessary earlier this session).
	player.global_position = body.global_position + Vector4(9, 5, -11, 0)
	player.global_basis = Basis4D.looking_at(body.global_position - player.global_position)
	await get_tree().physics_frame
	await _screenshot("limb_prototype_anatomy_spawn_3q.png")

	# Let it settle/walk a bit, re-aim each frame since body still moves a
	# little within its small confined range.
	for i in range(120):
		await get_tree().physics_frame
		player.global_position = body.global_position + Vector4(9, 5, -11, 0)
		player.global_basis = Basis4D.looking_at(body.global_position - player.global_position)
	await _screenshot("limb_prototype_anatomy_walking_3q.png")

	print("DONE")
	get_tree().quit()
