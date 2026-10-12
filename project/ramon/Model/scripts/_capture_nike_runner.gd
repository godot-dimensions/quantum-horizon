extends SceneTree

## Photographs Nike from the two angles the reference photos were taken at: side-on,
## which is where a potbellied pig's proportions actually read, and a low front
## three-quarter, which is the one that shows the snout, the ears and how little
## of the legs there is to see.
##
## A CAMERA OF ITS OWN rather than the scene's player. The player's camera hangs off
## a head node at its own height and carries pitch, so placing the body does not
## place the shot; a bare Camera4D put exactly where the picture wants it does.
## The W column is pinned to the world's fourth axis - Basis4D.looking_at leaves W
## free and will happily choose one that renders a different cross-section.

const _DIR: String = "res://smoke_test_output/"
const _SETTLE: int = 50
const _GAP: int = 22

var _frames: int = 0
var _shot: int = 0
var _camera: Camera4D

# Where to stand, what to look at, what to call it.
var _shots: Array = [
	[Vector4(30.7, 1.25, 3.2, 0.0), Vector4(24.0, 1.1, 3.2, 0.0), "nike_side"],
	[Vector4(29.4, 1.15, 11.0, 0.0), Vector4(24.1, 0.95, 5.2, 0.0), "nike_front"],
	[Vector4(27.1, 3.2, 8.4, 0.0), Vector4(24.0, 1.1, 4.0, 0.0), "nike_above"],
	[Vector4(24.0, 1.15, 14.2, 0.0), Vector4(24.0, 1.0, 5.8, 0.0), "nike_face"],
	# Close on the head - the rolls are too small to judge at whole-animal distance.
	[Vector4(26.8, 1.3, 9.4, 0.0), Vector4(24.05, 0.92, 6.5, 0.0), "nike_head"],
]


func _initialize() -> void:
	var scene: Node = (load("res://ramon/Model/animation_test.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	# Stood well clear of the horse for the photographs. A dark slot across the pig's
	# shoulder survived every change to its geometry, which is the signature of
	# something else in the scene - the horse casts over it from here.
	var nike: Node4D = scene.get_node("Nike")
	nike.position = Vector4(24.0, 0.0, 3.0, 0.0)
	_camera = Camera4D.new()
	# A bare Camera4D defaults to the wireframe canvas, which drew the whole scene as
	# white lines on black and no lofted surface at all. The scene's own cameras set
	# this in the .tscn; one made in code has to say it.
	_camera.rendering_engine_name = "Cross-section"
	# 2.75 is about a 50mm lens: wide enough to hold the animal, long enough that the
	# nearest part of a very round one is not thrown out of proportion.
	_camera.focal_length_3d = 2.75
	_camera.w_fade_distance = 8.0
	scene.add_child(_camera)
	_camera.current = true
	_aim()


## A look-at that leaves the slice alone: aim within XYZ, keep W as the world's.
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
		Vector4(xc.x, xc.y, xc.z, 0.0),
		Vector4(yc.x, yc.y, yc.z, 0.0),
		Vector4(zc.x, zc.y, zc.z, 0.0),
		Vector4(0.0, 0.0, 0.0, 1.0))


func _process(_d) -> bool:
	_frames += 1
	if _frames < _SETTLE + _shot * _GAP:
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_DIR))
	var image: Image = root.get_texture().get_image()
	if image == null:
		print("FAILED: no framebuffer")
		return true
	image.save_png(_DIR + String(_shots[_shot][2]) + ".png")
	print("SCREENSHOT_SAVED: %s" % _shots[_shot][2])
	_shot += 1
	if _shot >= _shots.size():
		return true
	_aim()
	return false
