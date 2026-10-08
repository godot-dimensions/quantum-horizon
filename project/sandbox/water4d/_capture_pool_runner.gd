extends SceneTree

## Shots of the pool room from the places that show each piece off.
##
##   godot --path project --rendering-method forward_plus --resolution 1280x720 \
##       --script res://sandbox/water4d/_capture_pool_runner.gd
##
## The last pair is the one that matters: the same spot with the slice turned 40 degrees.
## If the water looks the same in both, the pool is a texture and not a 4D field.

const SCENE := "res://sandbox/water4d/pool_room.tscn"
const SETTLE := 1.1

var _root: Node = null
var _player: Node4D = null
var _camera: Camera4D = null
var _water: Node4D = null
var _held: float = 0.0
var _frames: int = 0
var _stage: int = 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load(SCENE) as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		_player = _root.get_node("Player") as Node4D
		_camera = _root.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D
		_water = _root.get_node("Water") as Node4D
		return false

	_held += delta
	if _held < SETTLE:
		return false
	_held = 0.0

	match _stage:
		0:
			# Standing at the near doorway, looking down the walkway.
			_place(Vector4(-6.0, 1.9, 0.0, 0.0), 0.55, -0.50)
			_stage += 1
		1:
			_shoot("walkway")
			# Mid-span, turned toward the pillar and looking down into the water.
			_place(Vector4(-2.0, 1.9, 0.0, 0.0), 2.30, -0.34)
			_stage += 1
		2:
			_shoot("pillar")
			_stage += 1
		3:
			_shoot("slice_flat")
			# The rotation point's own turn, done the way the room does it.
			var b: Projection = Basis4D.from_xw(deg_to_rad(40.0)) * _player.global_basis
			b.y = Vector4(0.0, 1.0, 0.0, 0.0)
			_player.global_basis = Basis4D.orthonormalized(b)
			_stage += 1
		_:
			_shoot("slice_turned")
			quit(0)
			return true
	return false


## The orbit rig owns the camera angles, so set THEM - writing the body basis would be
## overwritten on its next frame. A positive pitch here swings the camera up and over, which
## is what lets you look down into the pool.
func _place(where: Vector4, yaw: float, pitch: float) -> void:
	_player.global_position = where
	var rig := _root.get_node("Player/CameraRig") as Node4D
	rig.set("yaw", yaw)
	rig.set("pitch", pitch)
	rig.set("distance", 13.0)


func _shoot(tag: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png("user://pool_%s.png" % tag)
	print("  %-14s player at %s" % [tag, _player.global_position])
