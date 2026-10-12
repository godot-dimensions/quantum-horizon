extends SceneTree
## Voxel Lab, round 2 (9 Oct): the floor routes from above, to check them as a plan (straight runs,
## right angles, the one 45 degree turn, nothing crossing a pedestal). A camera high over the hall,
## then over the gallery, looking straight down, the ceilings hidden. Frames to
## smoke_test_output/voxel_lab/routes/.
##   VoxelLab/run.sh windowed routes res://ramon/VoxelLab/scripts/_capture_routes_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/routes/"
const SHOTS := [["hall", Vector4(0, 34, 0, 0)], ["gallery", Vector4(0, 26, -23.5, 0)]]

var _scene: Node
var _cam: Camera4D
var _t: float = 0.0
var _i: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _process(delta: float) -> bool:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or _scene.get("player") == null:
		return false
	_scene.get("player").set("input_enabled", false)
	_t += delta
	if _cam == null:
		if _t < 3.0 or bool(_scene.get("loading")):
			return false
		# The ceilings out of the way: every mesh above 7.5 m that is not a light is hidden.
		for m in _scene.find_children("*", "MeshInstance4D", true, false):
			var mi: MeshInstance4D = m
			if mi.global_position.y > 7.5 and not String(mi.get_path()).contains("Lights"):
				mi.visible = false
		_cam = Camera4D.new()
		_cam.rendering_engine_name = "Cross-section"
		_scene.add_child(_cam)
		_cam.global_basis = Basis4D.from_yz(-PI * 0.5)
		_cam.set("field_of_view_4d", 1.15)
		_t = 0.0
	if _t > 1.2 and _i < SHOTS.size():
		var shot: Array = SHOTS[_i]
		_cam.global_position = shot[1]
		_cam.make_current()
		if _t > 2.4:
			var image: Image = root.get_texture().get_image()
			image.save_png(ProjectSettings.globalize_path(OUT + String(shot[0]) + ".png"))
			print("ROUTES saved %s" % String(shot[0]))
			_i += 1
			_t = 1.2
	if _i >= SHOTS.size():
		print("ROUTES done")
		return true
	return false
