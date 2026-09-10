extends SceneTree

## Renders the chicken with its comb reddened through the ramp texture, to answer the
## one question the data checks cannot: does the colour actually reach the screen.
##
## The per-cell colour array passed every data check and still drew white, so nothing
## short of a picture settles this. Everything here is done at RUNTIME on an
## instantiated copy - the scene file on disk is untouched.
##
## Must run WINDOWED. There is no framebuffer to read back under --headless.

const _OUTPUT: String = "res://smoke_test_output/ramp_color.png"
const _SETTLE_FRAMES: int = 45

var _frames: int = 0
var _done: bool = false


func _initialize() -> void:
	var instance: Node = (load("res://ramon/Model/model.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	var chicken: Node4D = instance.get_node_or_null("Models/Chicken")
	var player: Node4D = instance.get_node_or_null("Player")
	var neck: Node = instance.get_node_or_null("Models/Chicken/NeckHead")
	if chicken == null or player == null or neck == null:
		print("FAILED: scene is not laid out as expected")
		return
	player.position = chicken.position + Vector4(0.0, 1.4, 1.9, 0.0)

	# Its own material, or reddening the comb would redden the body too - they share
	# the feather material in the scene.
	neck.material_override = TetraMaterial4D.new()
	var balls: Array = []
	for child in neck.get_children():
		if child.has_method("get_loft_section"):
			balls.append(child)
	print("neck chain has %d balls" % balls.size())
	# The comb is the last three: head, then the crest above it.
	for index in range(balls.size()):
		balls[index].color = Color(0.85, 0.1, 0.1) if index >= balls.size() - 3 else Color(0.95, 0.93, 0.88)
	neck.use_ball_colors = true


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
