extends SceneTree

## Renders the TestLimb specifically, by putting the player in front of it rather
## than wherever it was last left. Must run WINDOWED - there is no framebuffer to
## read back under --headless.

const _OUTPUT: String = "res://smoke_test_output/test_limb.png"
const _SETTLE_FRAMES: int = 45

var _frames: int = 0
var _done: bool = false


func _initialize() -> void:
	var instance: Node = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	var limb: Node4D = instance.get_node_or_null("Models/TestLimb")
	var player: Node4D = instance.get_node_or_null("Player")
	if limb == null or player == null:
		return
	# The player faces -Z, so standing it at +Z of the limb looks straight at it.
	player.position = limb.position + Vector4(0.0, 2.0, 7.0, 0.0)


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
