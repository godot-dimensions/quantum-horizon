extends SceneTree

## The 4D pocket watch face-on, first at the depth of its middle hands and then a short step
## along W either way - three pictures, three different times, one watch.
## Windowed. Writes res://smoke_test_output/watch_<w>.png

const SCENE := "res://ramon/chickenpen/playable_world.tscn"
const STEPS := [-0.16, 0.0, 0.16]

var _room: Node
var _cam: Camera4D
var _f: int = 0


func _initialize() -> void:
	_room = load(SCENE).instantiate()
	root.add_child(_room)
	current_scene = _room


func _process(_d: float) -> bool:
	_f += 1
	var watch := _room.get_node_or_null("World/Pickups/PocketWatch") as Node4D
	if watch == null:
		print("no watch")
		quit()
		return true
	watch.set_process(false)
	watch.basis = Projection.IDENTITY
	if _cam == null:
		_cam = Camera4D.new()
		_cam.rendering_engine_name = "Cross-section"
		_room.add_child(_cam)
		_cam.current = true
	var step: int = clampi((_f - 60) / 20, 0, STEPS.size() - 1)
	var at: Vector4 = watch.global_position + Vector4(0.0, 0.0, 0.0, STEPS[step])
	_cam.global_position = at + Vector4(0.0, 0.05, 1.05, 0.0)
	_cam.look_at(at)
	if _f >= 60 and (_f - 60) % 20 == 15:
		var tag: String = "%+.2f" % STEPS[step]
		root.get_texture().get_image().save_png("res://smoke_test_output/watch_%s.png" % tag)
		print("   saved watch_%s.png" % tag)
		if step == STEPS.size() - 1:
			quit()
			return true
	return false
