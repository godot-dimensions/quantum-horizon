extends SceneTree
## Carves ONE hole and orbits the camera around it at close range.
##
## This is the test that should have been run before calling the lost-faces
## artifact fixed. Every earlier check looked at the wall broadly, or head-on,
## or from angles chosen without a hole in frame. The report is specifically
## "shoot a hole, look from an angle", so this frames one hole and walks around
## it, keeping it centred, at the distance a player actually stands.

const SCENE_PATH := "res://ramon/Portal/portal_test_1.tscn"
const WARMUP := 12
const HOLE := Vector4(0.0, 1.5, -9.0, 0.0)
## Where the camera sits relative to the hole: sideways offset and distance.
const STATIONS := [
	{"offset": Vector4(0.0, 0.35, 3.2, 0.0), "name": "front"},
	{"offset": Vector4(2.2, 0.35, 2.6, 0.0), "name": "right30"},
	{"offset": Vector4(3.4, 0.35, 1.8, 0.0), "name": "right60"},
	{"offset": Vector4(-2.2, 0.35, 2.6, 0.0), "name": "left30"},
	{"offset": Vector4(-3.4, 0.35, 1.8, 0.0), "name": "left60"},
	{"offset": Vector4(0.0, -1.1, 2.4, 0.0), "name": "frombelow"},
	{"offset": Vector4(0.0, 2.0, 2.4, 0.0), "name": "fromabove"},
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
		builder.wall.carve_at(HOLE, 1.35)
		_camera = _find(_scene)
		_camera.get_parent().remove_child(_camera)
		_scene.add_child(_camera)
		_index = 0
		_aim()
		return false

	_frames += 1
	if _frames < WARMUP:
		return false
	_frames = 0
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(ProjectSettings.globalize_path(
			"res://ramon/Portal/orbit_%s.png" % STATIONS[_index].name))
		print("wrote orbit_%s.png" % STATIONS[_index].name)
	_index += 1
	if _index >= STATIONS.size():
		quit(0)
		return true
	_aim()
	return false


## Keeps the hole centred in frame from every station.
func _aim() -> void:
	var position: Vector4 = HOLE + STATIONS[_index].offset
	_camera.position = position
	var forward := Vector2(HOLE.x - position.x, HOLE.z - position.z).normalized()
	_camera.basis = Basis4D.from_zx(atan2(-forward.x, -forward.y))


func _find(n: Node) -> Node4D:
	if n is Camera4D:
		return n
	for c in n.get_children():
		var f := _find(c)
		if f != null:
			return f
	return null
