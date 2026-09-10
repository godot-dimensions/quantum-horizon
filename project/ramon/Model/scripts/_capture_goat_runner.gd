extends SceneTree

## Photographs the goat side-on, which is the view that shows whether the proportions
## read as a goat rather than a generic quadruped: the leg-to-body ratio, the sweep of
## the horns, and the line from rump to withers to skull.
##
## The player faces -Z, so a side view needs the body yawed 90 degrees rather than
## just moved - hence the basis. Must run WINDOWED; there is no framebuffer headless.

const _OUTPUT: String = "res://smoke_test_output/goat.png"
const _SETTLE_FRAMES: int = 45

var _frames: int = 0
var _done: bool = false


func _initialize() -> void:
	var instance: Node = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	var goat: Node4D = instance.get_node_or_null("Models/Goat")
	var player: Node4D = instance.get_node_or_null("Player")
	if goat == null or player == null:
		print("FAILED: scene is not laid out as expected")
		return
	# Yaw -90 degrees so the player's -Z gaze points along +X, giving a profile from
	# the side the other animals are NOT on: the chicken then sits far behind the goat
	# rather than in front of it, and the dinosaur is behind the camera entirely.
	player.basis = Projection(
		Vector4(0, 0, 1, 0), Vector4(0, 1, 0, 0), Vector4(-1, 0, 0, 0), Vector4(0, 0, 0, 1))
	player.position = goat.position + Vector4(-7.0, 2.4, 0.4, 0.0)


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
