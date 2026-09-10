extends SceneTree

## Photographs the Strider in the animation-test scene. Must run WINDOWED.

const _OUTPUT: String = "res://smoke_test_output/strider.png"
const _SETTLE_FRAMES: int = 45
var _frames := 0
var _done := false

func _initialize() -> void:
	var instance: Node = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	var player: Node4D = instance.get_node_or_null("Player")
	if player != null:
		# Yawed 90 degrees for a profile: a quadruped's body plan only reads side-on.
		player.basis = Projection(
			Vector4(0, 0, 1, 0), Vector4(0, 1, 0, 0), Vector4(-1, 0, 0, 0), Vector4(0, 0, 0, 1))
		player.position = Vector4(-8.0, 2.4, 0.0, 0.0)

func _process(_d) -> bool:
	if _done: return true
	_frames += 1
	if _frames < _SETTLE_FRAMES: return false
	_done = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/"))
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("FAILED: no framebuffer"); return true
	image.save_png(_OUTPUT)
	print("SCREENSHOT_SAVED: %s" % ProjectSettings.globalize_path(_OUTPUT))
	return true
