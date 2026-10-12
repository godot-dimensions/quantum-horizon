extends SceneTree
## Photographs one opening from close range and at an angle, which is where the
## "inverted normals" look around a hole shows up. Distance shots hide it.

const CHAMBER_PATH := "res://ramon/Portal/portal_test_2.tscn"
const WARMUP_FRAMES := 30

var _chamber: Node = null
var _prepared: bool = false
var _frames: int = 0


func _initialize() -> void:
	root.set_size(Vector2i(1600, 900))
	_chamber = (load(CHAMBER_PATH) as PackedScene).instantiate()
	root.add_child(_chamber)
	set_current_scene(_chamber)


func _process(_delta: float) -> bool:
	if not _prepared:
		_prepared = true
		var builder: Node = _chamber.get_node("ChamberWorld/ChamberBuilder")
		var link: Node = _chamber.get_node("ChamberWorld/PortalLink")
		link.place(builder.surfaces[0], Vector4(-8.0, 1.4, 0.0, 0.0), &"blue")
		link.place(builder.surfaces[1], Vector4(8.0, 1.4, 0.0, 0.0), &"yellow")
		link.blue._apply_openness(1.0)
		link.yellow._apply_openness(1.0)
		_place_camera(link.blue.global_position)
		return false

	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	var image: Image = root.get_texture().get_image()
	if image != null:
		var path := ProjectSettings.globalize_path("res://ramon/Portal/hole_closeup.png")
		image.save_png(path)
		print("wrote ", path)
	quit(0)
	return true


## Oblique and close: 2.6 m out and 2.0 m to the side, at eye height.
func _place_camera(hole: Vector4) -> void:
	var camera: Node4D = _find_camera(_chamber)
	if camera == null:
		printerr("no Camera4D")
		return
	camera.get_parent().remove_child(camera)
	_chamber.add_child(camera)
	var position := Vector4(hole.x + 2.6, hole.y + 0.4, hole.z + 2.0, 0.0)
	camera.position = position
	var forward := Vector2(hole.x - position.x, hole.z - position.z).normalized()
	camera.basis = Basis4D.from_zx(atan2(-forward.x, -forward.y))
	print("camera at ", position, " looking at ", hole)


func _find_camera(node: Node) -> Node4D:
	if node is Camera4D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null
