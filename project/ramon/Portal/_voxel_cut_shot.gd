extends SceneTree
## Cuts a wall in the voxel-cut test and photographs it close up and at an angle,
## which is the view that exposed every problem with the box approach.

const SCENE_PATH := "res://ramon/Portal/voxel_cut_test.tscn"
const WARMUP_FRAMES := 30

var _scene: Node = null
var _prepared: bool = false
var _frames: int = 0


func _initialize() -> void:
	root.set_size(Vector2i(1600, 900))
	_scene = (load(SCENE_PATH) as PackedScene).instantiate()
	root.add_child(_scene)
	set_current_scene(_scene)


func _process(_delta: float) -> bool:
	if not _prepared:
		_prepared = true
		var builder: Node = _scene.get_node("CutWorld/CutBuilder")
		var wall: Node4D = builder.walls[0] # Far wall.
		var hit := Vector4(0.0, 1.6, -8.0, 0.0)
		if not wall.cut_at(hit):
			printerr("cut refused")
			quit(1)
			return true
		var patch: Node4D = wall.patch
		print("cut in %.0f ms: %d tetrahedra, %d colliders" % [
			patch.build_msec, patch.tetra_count, patch.collider_count])
		_place_camera(wall.global_position + Vector4(0.0, 1.6 - wall.global_position.y, 0.0, 0.0))
		return false

	_frames += 1
	if _frames < WARMUP_FRAMES:
		return false
	var image: Image = root.get_texture().get_image()
	if image != null:
		var path := ProjectSettings.globalize_path("res://ramon/Portal/voxel_cut.png")
		image.save_png(path)
		print("wrote ", path)
	quit(0)
	return true


func _place_camera(target: Vector4) -> void:
	var camera: Node4D = _find_camera(_scene)
	if camera == null:
		printerr("no Camera4D")
		return
	camera.get_parent().remove_child(camera)
	_scene.add_child(camera)
	var position := Vector4(target.x + 2.2, target.y + 0.5, target.z + 3.0, 0.0)
	camera.position = position
	var forward := Vector2(target.x - position.x, target.z - position.z).normalized()
	camera.basis = Basis4D.from_zx(atan2(-forward.x, -forward.y))
	print("camera at ", position)


func _find_camera(node: Node) -> Node4D:
	if node is Camera4D:
		return node
	for child in node.get_children():
		var found := _find_camera(child)
		if found != null:
			return found
	return null
