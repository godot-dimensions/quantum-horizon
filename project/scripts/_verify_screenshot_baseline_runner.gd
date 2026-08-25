extends Node
## TEMPORARY - isolates whether a plain screenshot of the existing
## treadmill scene (no shrub added at all) is fast right now, to
## determine whether a just-observed screenshot stall is specific to
## adding shrub geometry or a broader issue with this run/session.

const OUTPUT_DIR := "res://smoke_test_output/"


func _ready() -> void:
	for i in range(90):
		await get_tree().physics_frame
	print("90 physics frames done at %.3f" % (Time.get_ticks_usec() / 1_000_000.0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("before frame_post_draw at %.3f" % (Time.get_ticks_usec() / 1_000_000.0))
	await RenderingServer.frame_post_draw
	print("after frame_post_draw at %.3f" % (Time.get_ticks_usec() / 1_000_000.0))
	var img: Image = get_viewport().get_texture().get_image()
	print("got image at %.3f" % (Time.get_ticks_usec() / 1_000_000.0))
	img.save_png(OUTPUT_DIR + "baseline_screenshot.png")
	print("saved at %.3f" % (Time.get_ticks_usec() / 1_000_000.0))
	print("DONE")
	get_tree().quit()
