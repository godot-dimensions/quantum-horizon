extends Node
## TEMPORARY - takes a handful of screenshots through an ACTIVE (never
## halted) walk cycle, spaced out, to see the new gait-scaled swing
## timing in motion rather than judging from one arbitrary frozen
## [HALTED] frame - and to check whether the reported "lean" is a
## genuine per-frame pose issue or was mostly an artifact of judging a
## single freeze-frame.

const OUTPUT_DIR := "res://smoke_test_output/"


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")

	body.select_gait("walk")
	for i in range(150): # 2.5s - past the gait-switch transient.
		await get_tree().physics_frame

	for shot in range(5):
		for i in range(30): # 0.5s between shots.
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		_screenshot("visual_check2_walk_%d" % shot)

	print("DONE")
	get_tree().quit()


func _screenshot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = OUTPUT_DIR + name + ".png"
	img.save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
