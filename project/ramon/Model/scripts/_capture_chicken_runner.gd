extends SceneTree

## Frames the chicken close up, to check the comb reads red again now that the
## neck chain carries per-ball colour instead of one flat rig colour. Must run
## WINDOWED - there is no framebuffer to read back under --headless.

const _OUTPUT: String = "res://smoke_test_output/chicken.png"
const _SETTLE_FRAMES: int = 45

var _frames: int = 0
var _done: bool = false


func _initialize() -> void:
	var instance: Node = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	var chicken: Node4D = instance.get_node_or_null("Models/Chicken")
	var player: Node4D = instance.get_node_or_null("Player")
	if chicken == null or player == null:
		return
	# The player faces -Z, so standing it at +Z of the chicken looks straight at it.
	player.position = chicken.position + Vector4(0.0, 1.4, 1.9, 0.0)


func _process(_delta: float) -> bool:
	if _done:
		return true
	_frames += 1
	if _frames < _SETTLE_FRAMES:
		return false
	_done = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/"))
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("FAILED: no framebuffer")
		return true
	image.save_png(_OUTPUT)
	print("SCREENSHOT_SAVED: %s" % ProjectSettings.globalize_path(_OUTPUT))
	return true
