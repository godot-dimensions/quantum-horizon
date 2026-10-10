extends SceneTree
## Voxel Lab, round 6 (#60): the sign over the gallery door, "HOW A WORLD IS / MADE", in two lines, seen from
## the hall as you walk up to it and from right under it. Frames to smoke_test_output/voxel_lab/sign/.
##   VoxelLab/run.sh windowed sign res://ramon/VoxelLab/scripts/_probe_sign_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/sign/"

var _scene: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("SIGN saved %s" % name)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 90.0:
		print("SIGN FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or _scene.get("player") == null:
		return false
	_scene.get("player").set("input_enabled", false)
	_t += delta
	match _step:
		0:
			if _t > 2.0 and not bool(_scene.get("loading")):
				var sign: Node = _scene.get_node_or_null("Hall/GallerySign")
				print("SIGN %s title %s" % ["PASS" if sign != null and String(sign.get("title")).contains("\n") else "FAIL",
					str(String(sign.get("title")).split("\n")) if sign != null else "missing"])
				_scene.call("go_to", Vector4(0.0, 0.05, -4.0, 0.0), 0.0)
				_step = 1
				_t = 0.0
		1:
			if _t > 1.5:
				_save("sign_from_hall")
				_scene.call("go_to", Vector4(0.0, 0.05, -11.0, 0.0), 0.0)
				_step = 2
				_t = 0.0
		2:
			if _t > 1.5:
				_save("sign_close")
				print("SIGN done")
				return true
	return false
