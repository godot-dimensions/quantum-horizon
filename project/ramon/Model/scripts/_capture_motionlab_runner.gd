extends SceneTree
## Photographs Trym's Motion Lab creature, to compare its body plan against the
## Strider's. Must run WINDOWED.
const _OUTPUT := "res://smoke_test_output/motion_lab.png"
var _frames := 0
var _done := false
func _initialize() -> void:
	var inst: Node = (load("res://sandbox/limb_prototype/limb_prototype_treadmill.tscn") as PackedScene).instantiate()
	root.add_child(inst)
func _process(_d) -> bool:
	if _done: return true
	_frames += 1
	if _frames < 150: return false   # let it take a few strides
	_done = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/"))
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("FAILED: no framebuffer"); return true
	image.save_png(_OUTPUT)
	print("SCREENSHOT_SAVED: %s" % ProjectSettings.globalize_path(_OUTPUT))
	return true
