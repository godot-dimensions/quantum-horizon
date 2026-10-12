extends SceneTree

## Renders model.tscn and saves a screenshot, so the built geometry can be looked
## at without opening the editor. Must run WINDOWED (no --headless) - there is no
## framebuffer to read back otherwise. Run with:
##   godot...console.exe --path project --script res://ramon/Model/scripts/_capture_loft_runner.gd

const _OUTPUT_DIR: String = "res://smoke_test_output/"
const _SETTLE_FRAMES: int = 45

var _frames: int = 0
var _done: bool = false


func _initialize() -> void:
	var packed: PackedScene = load("res://ramon/Model/model.tscn")
	if packed == null:
		print("FAILED: model.tscn did not load")
		return
	root.add_child(packed.instantiate())


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	# The 4D cross-section pipeline resolves over several frames, and the sky and
	# tonemapper need a moment besides, so capturing on frame 1 gets a grey plate.
	if _frames < _SETTLE_FRAMES:
		return false
	_done = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_OUTPUT_DIR))
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("FAILED: no framebuffer to capture")
		return true
	var path: String = _OUTPUT_DIR + "loft_model.png"
	var error: int = image.save_png(path)
	if error != OK:
		print("FAILED: save_png returned %d" % error)
		return true
	print("SCREENSHOT_SAVED: %s (%dx%d)" % [ProjectSettings.globalize_path(path), image.get_width(), image.get_height()])
	return true
