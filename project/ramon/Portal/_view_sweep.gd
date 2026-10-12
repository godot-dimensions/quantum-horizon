extends SceneTree
## Renders the chunked wall from many viewpoints, hunting the lost-faces
## artifact.
##
## Every previous attempt to pin this down used one or two head-on shots, which
## is exactly the view most likely to hide it: geometry that is being culled or
## mis-sliced tends to vanish only from certain angles, heights or w positions.
## This sweeps all three so the artifact has nowhere to hide.

const SCENE_PATH := "res://ramon/Portal/portal_test_1.tscn"
const WARMUP := 10

## position, yaw, and w - deliberately including steep and grazing angles, and
## viewpoints off the room's centre line.
const VIEWS := [
	{"pos": Vector4(0.0, 1.9, -3.4, 0.0), "yaw": 0.0, "name": "head_on"},
	{"pos": Vector4(4.5, 1.9, -3.0, 0.0), "yaw": -0.7, "name": "oblique_right"},
	{"pos": Vector4(-4.5, 1.9, -3.0, 0.0), "yaw": 0.7, "name": "oblique_left"},
	{"pos": Vector4(5.5, 1.2, -6.5, 0.0), "yaw": -1.25, "name": "grazing"},
	{"pos": Vector4(0.0, 3.6, -3.0, 0.0), "yaw": 0.0, "name": "high"},
	{"pos": Vector4(0.0, 0.35, -3.0, 0.0), "yaw": 0.0, "name": "low"},
	{"pos": Vector4(0.0, 1.9, -3.4, 5.0), "yaw": 0.0, "name": "w5"},
	{"pos": Vector4(0.0, 1.9, -3.4, 10.5), "yaw": 0.0, "name": "w10"},
]

var _scene: Node = null
var _camera: Node4D = null
var _index: int = -1
var _frames: int = 0


func _initialize() -> void:
	root.set_size(Vector2i(1280, 720))
	_scene = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_scene)
	set_current_scene(_scene)


func _process(_delta: float) -> bool:
	if _index < 0:
		var builder: Node = _scene.get_node("ChunkWorld/ChunkBuilder")
		var wall: Node4D = builder.wall
		# A few holes, including one straddling a chunk boundary.
		wall.carve_at(Vector4(-2.0, 1.8, -8.0, 0.0), 0.9)
		wall.carve_at(Vector4(2.1, 1.4, -8.0, 0.0), 0.9)
		_camera = _find(_scene)
		_camera.get_parent().remove_child(_camera)
		_scene.add_child(_camera)
		_index = 0
		_apply_view()
		return false

	_frames += 1
	if _frames < WARMUP:
		return false
	_frames = 0
	var image: Image = root.get_texture().get_image()
	if image != null:
		var view: Dictionary = VIEWS[_index]
		image.save_png(ProjectSettings.globalize_path("res://ramon/Portal/view_%s.png" % view.name))
		print("wrote view_%s.png" % view.name)
	_index += 1
	if _index >= VIEWS.size():
		quit(0)
		return true
	_apply_view()
	return false


func _apply_view() -> void:
	var view: Dictionary = VIEWS[_index]
	_camera.position = view.pos
	_camera.basis = Basis4D.from_zx(view.yaw)


func _find(n: Node) -> Node4D:
	if n is Camera4D:
		return n
	for c in n.get_children():
		var f := _find(c)
		if f != null:
			return f
	return null
