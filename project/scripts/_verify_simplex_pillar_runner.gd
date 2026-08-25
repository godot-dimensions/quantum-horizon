extends Node
## TEMPORARY - verifies simplex_pillar_test.tscn end to end: upright
## silhouette (not the flat "arrow" cross-section seen edge-on in the 8x8
## grid test), and actual visible rotation between two frames. Not part of
## the shipped scene. Wired in as a temporary autoload with
## simplex_pillar_test.tscn set as the main scene.


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
	var monument: Node = scene.get_node("Rig/Monument")
	var camera: Node = scene.get_node("HoverCamera")
	print("1.nodes_resolve: monument=%s camera=%s (expect both true)" % [monument != null, camera != null])
	print("2.ring_child_count: %d (expect ring_count+1=9, 8 simplices + pillar)" % [monument.get_child_count()])

	for i in 40:
		await get_tree().physics_frame

	print("3.spin_angle_after_40_physics_frames: %.4f rad (expect > 0)" % [monument._spin_angle])
	await _screenshot("simplex_pillar_frame_a.png")

	for i in 120:
		await get_tree().physics_frame

	print("4.spin_angle_after_120_more_physics_frames: %.4f rad (expect visibly larger than frame_a's)" % [monument._spin_angle])
	await _screenshot("simplex_pillar_frame_b.png")

	print("DONE")
	get_tree().quit()
