extends Node
## TEMPORARY - dense screenshot sequence (every 0.2s) across one full
## walk cycle (4.0s + a bit), to directly SEE whether the leg motion
## looks evenly staggered or bunched into a burst - a reported symptom
## that contradicts the clean, evenly-1.0s-staggered state-transition
## timeline already measured numerically (_verify_motion_lab_stagger_
## timeline_runner.gd). If the timeline is right, this should show
## exactly one leg's pose changing at a time, evenly spread across all
## ~21 frames, not a cluster.

const OUTPUT_DIR := "res://smoke_test_output/"
const FRAME_COUNT := 22
const FRAME_SPACING_SEC := 0.2


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: Control = get_tree().current_scene
	var root: Node = scene.get_node("FlatPlane/MotionLabCreature")
	var body: Node = root.get_node("Body")

	body.select_gait("walk")
	for i in range(90): # 1.5s - past the initial gait-switch transient, into steady state.
		await get_tree().physics_frame

	var frames_per_shot: int = int(FRAME_SPACING_SEC * 60.0)
	for shot in range(FRAME_COUNT):
		for i in range(frames_per_shot):
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		_screenshot("dense_%02d" % shot)

	print("DONE")
	get_tree().quit()


func _screenshot(name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = OUTPUT_DIR + name + ".png"
	img.save_png(path)
	print("saved %s" % path)
