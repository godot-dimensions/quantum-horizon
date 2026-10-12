extends Node
## TEMPORARY - takes a windowed screenshot of the ORIGINAL single-chunk
## terrain4d_test.tscn (untouched by any brick/hash/native work this
## session) to bisect whether a reported gap/spike bug predates this
## session's work or is specific to the hash+brick architecture.

func _ready() -> void:
	for i in range(60):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://smoke_test_output/bisect_terrain4d_test_original.png")
	print("SCREENSHOT_SAVED")
	print("DONE")
	get_tree().quit()
