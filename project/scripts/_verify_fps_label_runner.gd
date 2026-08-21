extends Node
## TEMPORARY - confirms InfoLabel actually gets a live "FPS: N" suffix
## appended every frame, and that it changes frame to frame (proving
## it's a real live read, not a static string).

func _ready() -> void:
	await get_tree().process_frame
	_run()


func _run() -> void:
	var scene: Control = get_tree().current_scene
	var info_label: Label = scene.get_node("InfoLabel")

	for i in range(5):
		await get_tree().process_frame
		print("frame %d: InfoLabel.text = %s" % [i, info_label.text])

	print("DONE")
	get_tree().quit()
