extends SceneTree

## One honest look at the whole room, from a camera of its own.
##
##   godot --path project --rendering-method forward_plus --resolution 1280x720 \
##       --script res://sandbox/water4d/_capture_pool_overview_runner.gd
##
## The player's orbit rig is the right camera to PLAY with and the wrong one to inspect with:
## it sits a few metres behind a body that is standing on the walkway, so every shot is taken
## from inside the thing being judged, and a railing fills the frame whether it is open or
## solid. Several rounds of guessing yaw angles through it told me nothing. A free camera
## above the room answers "what does this room look like" in one frame.

const SCENE := "res://sandbox/water4d/pool_room.tscn"
const SETTLE := 1.2

## Each shot: a name, where the camera sits, and where it points.
const SHOTS := [
	["above", Vector4(0.0, 26.0, 26.0, 0.0), Vector4(0.0, 0.0, 0.0, 0.0)],
	["along", Vector4(-26.0, 6.0, 0.0, 0.0), Vector4(6.0, 0.0, 0.0, 0.0)],
	["rail", Vector4(-4.0, 3.2, 7.0, 0.0), Vector4(4.0, 0.3, 0.0, 0.0)],
	["turned", Vector4(0.0, 26.0, 26.0, 0.0), Vector4(0.0, 0.0, 0.0, 0.0)],
]

var _root: Node = null
var _camera: Camera4D = null
var _frames: int = 0
var _held: float = 0.0
var _index: int = 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load(SCENE) as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		return false
	if _frames == 2:
		_camera = Camera4D.new()
		_camera.name = "OverviewCamera"
		_camera.rendering_engine_name = "Cross-section"
		_root.add_child(_camera)
		_camera.current = true
		_aim(0)
		return false

	_held += delta
	if _held < SETTLE:
		return false
	_held = 0.0

	var image: Image = root.get_texture().get_image()
	image.save_png("user://poolview_%s.png" % SHOTS[_index][0])
	print("  %-8s from %s" % [SHOTS[_index][0], SHOTS[_index][1]])
	_index += 1
	if _index >= SHOTS.size():
		quit(0)
		return true
	_aim(_index)
	return false


func _aim(index: int) -> void:
	var from: Vector4 = SHOTS[index][1]
	var at: Vector4 = SHOTS[index][2]
	_camera.position = from
	_camera.basis = Basis4D.looking_at(at - from)
	# The last shot is the same view with the slice turned, which is what shows whether the
	# room is closed through W or merely looks closed from straight on.
	if SHOTS[index][0] == "turned":
		_camera.basis = Basis4D.orthonormalized(
				Basis4D.from_xw(deg_to_rad(42.0)) * _camera.basis)
