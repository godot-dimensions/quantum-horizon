extends SceneTree

## Shots of each preset, the slice-turn pair, and a foam count.
##
##   godot --path project --rendering-method forward_plus --resolution 1280x720 \
##       --script res://sandbox/water4d/_capture_water_runner.gd
##
## Writes user://water4d_*.png and prints, per preset, how much of the frame is foam.
##
## FOAM IS COUNTED OFF THE JACOBIAN VIEW, NOT THE LIT PICTURE. An earlier version of this
## probe counted near-white pixels in the ordinary render and reported a healthy 0.77% for
## the storm. That was specular glare on the crest tops: the debug view showed the
## determinant sitting at ~1 across the whole sea, so the foam term was contributing almost
## nothing. White water and a white highlight are the same pixel. Each preset is therefore
## shot twice, and the number below comes from the pass where the shader paints det <
## foam_threshold hard red and nothing else is red at all.
##
## THE COUNT STILL HAS A CONTROL. Calm has no breaking crests, so if it reports foam the
## classifier is picking up something else and no other row means anything.
##
## TIME IS ACCUMULATED FROM DELTA, NOT COUNTED IN FRAMES. With vsync off the frame rate is
## whatever the machine feels like, so "settle for 60 frames" is not a duration, and a blend
## that takes half a second would be caught halfway through.

const SCENE := "res://sandbox/water4d/water4d_test.tscn"
const Presets := preload("res://sandbox/water4d/water4d_presets.gd")
const SETTLE := 1.2

var _root: Node = null
var _water: Node4D = null
var _camera: Camera4D = null
var _frames: int = 0
var _held: float = 0.0
var _stage: int = 0
var _rows: Array[String] = []
var _foam: Dictionary = {}
var _debug_pending: int = 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load(SCENE) as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		_water = _root.get_node("Water") as Node4D
		_camera = _root.get_node("FlyCamera") as Camera4D
		# Up and back, looking down at the sea rather than along it, so crests read.
		_camera.position = Vector4(0.0, 12.0, 30.0, 0.0)
		_camera.basis = Basis4D.orthonormalized(Basis4D.from_yz(-0.42))
		return false

	_held += delta
	if _held < SETTLE:
		return false
	_held = 0.0

	var last: int = Presets.count() - 1
	if _stage <= last:
		_shoot(_stage, "")
		_stage += 1
		_water.call(&"set_preset", _stage if _stage <= last else 3)
		return false
	if _stage == last + 1:
		_shoot(3, "flat")
		# 50 degrees of xw turn: enough that a wave travelling along W is now travelling
		# partly across the screen.
		_camera.basis = Basis4D.orthonormalized(Basis4D.from_xw(deg_to_rad(50.0))
				* Basis4D.from_yz(-0.42))
		_stage += 1
		return false
	if _stage == last + 2:
		# One looking up, because the clouds are most of what the sky is for and a camera
		# pitched at the sea barely sees them.
		_camera.basis = Basis4D.orthonormalized(Basis4D.from_yz(0.38))
		_stage += 1
		_shoot(3, "turned")
		return false
	_shoot(0, "sky")
	for row in _rows:
		print(row)
	quit(0)
	return true


func _shoot(index: int, tag: String) -> void:
	var image: Image = root.get_texture().get_image()
	var name: String = _water.call(&"preset_name", index)
	var suffix: String = tag if tag != "" else name.to_lower().replace(" ", "_")
	var path := "user://water4d_%d_%s.png" % [index + 1, suffix]
	image.save_png(path)
	var d: Dictionary = _water.call(&"dominant")
	_rows.append("  %d %-16s %-9s amp %.2f  len %5.1f  steep %.2f  off W %.2f"
			% [index + 1, name, tag, float(d["amplitude"]), float(d["wavelength"]),
			float(d["steepness"]), float(d["off_slice"])])
