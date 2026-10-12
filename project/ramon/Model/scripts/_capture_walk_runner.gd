extends SceneTree
## Three moments of the gait, far enough apart to show different leg positions.
const _AT := {70: "walk_a", 82: "walk_b", 94: "walk_c", 106: "walk_d"}
var _frames := 0
func _initialize() -> void:
	var instance: Node = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	var player: Node4D = instance.get_node_or_null("Player")
	if player != null:
		player.basis = Projection(Vector4(0,0,1,0), Vector4(0,1,0,0), Vector4(-1,0,0,0), Vector4(0,0,0,1))
		player.position = Vector4(-18.0, 3.0, 0.0, 0.0)
func _process(_d) -> bool:
	_frames += 1
	if _AT.has(_frames):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/"))
		var image: Image = root.get_texture().get_image()
		if image != null:
			image.save_png("res://smoke_test_output/%s.png" % _AT[_frames])
			print("SAVED %s" % _AT[_frames])
	return _frames > 110
