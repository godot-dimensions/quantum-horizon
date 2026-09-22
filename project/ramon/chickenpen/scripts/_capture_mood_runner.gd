extends SceneTree

## Photographs the pen's lighting from three angles: into the sun, across it, and away
## from it. One shot is not enough to judge a mood - a dawn that looks good facing the sun
## can be flat with it behind you, and the shaded side is where a cool ambient earns its
## place or does not.

const _DIR: String = "res://smoke_test_output/"
var _camera: Camera4D
var _f: int = 0
var _shot: int = 0
var _shots: Array = [
	[Vector4(-15.0, 2.6, 11.0, 0.0), Vector4(2.0, 1.4, -6.0, 0.0), "mood_into_sun"],
	[Vector4(-16.0, 3.2, -10.0, 0.0), Vector4(0.0, 1.0, -9.0, 0.0), "mood_across"],
	[Vector4(13.0, 2.8, -20.0, 0.0), Vector4(-1.0, 1.2, -6.0, 0.0), "mood_with_sun"],
	[Vector4(0.0, 1.6, -8.0, 0.0), Vector4(-14.0, 14.0, 1.7, 0.0), "mood_zenith"],
]


func _initialize() -> void:
	var scene: Node = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var clouds: Resource = scene.get_node("World/Environment").get("cloud_material")
	if clouds != null:
		clouds.set("animation_enabled", false)
		clouds.set("evolution_speed", 0.0)
		clouds.set("wind_velocity", Vector4.ZERO)
	_camera = Camera4D.new()
	_camera.rendering_engine_name = "Cross-section"
	_camera.focal_length_3d = 2.2
	_camera.w_fade_distance = 10.0
	scene.add_child(_camera)
	_camera.current = true
	_aim()


func _aim() -> void:
	var from: Vector4 = _shots[_shot][0]
	var to: Vector4 = _shots[_shot][1]
	var gap: Vector4 = to - from
	var forward: Vector3 = Vector3(gap.x, gap.y, gap.z).normalized()
	var zc: Vector3 = -forward
	var xc: Vector3 = Vector3(0.0, 1.0, 0.0).cross(zc)
	if xc.length_squared() < 0.000001:
		xc = Vector3(1.0, 0.0, 0.0)
	xc = xc.normalized()
	var yc: Vector3 = zc.cross(xc)
	_camera.position = from
	_camera.basis = Projection(
		Vector4(xc.x, xc.y, xc.z, 0.0), Vector4(yc.x, yc.y, yc.z, 0.0),
		Vector4(zc.x, zc.y, zc.z, 0.0), Vector4(0.0, 0.0, 0.0, 1.0))


func _process(_d) -> bool:
	_f += 1
	if _f < 40 + _shot * 16:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_DIR))
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(_DIR + String(_shots[_shot][2]) + ".png")
		print("SAVED %s" % _shots[_shot][2])
	_shot += 1
	if _shot >= _shots.size():
		return true
	_aim()
	return false
