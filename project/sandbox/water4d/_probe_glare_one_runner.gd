extends SceneTree

## Blown-out share of the sea for ONE setting, in a process of its own.
##
##   godot --path project --rendering-method forward_plus --resolution 900x520 \
##       --script res://sandbox/water4d/_probe_glare_one_runner.gd -- <setting>
##
## WHY ONE PER PROCESS. The multi-row version of this walked through its settings inside a
## single run, and every row came back higher than the one before it whatever the row did -
## the sea evolves, the clouds drift and the foam accumulates while the probe works, so row
## order was worth more than the variable under test. Switching the sky's ambient off read as
## MORE glare, which is how a documented, real contributor got written off as "no effect".
##
## A fresh process per setting starts every measurement from the same scene at the same age.
## Slower, and the only version whose rows can be compared with each other.

const SETTLE_FRAMES := 40
const SAMPLES := 30

var _root: Node = null
var _water: Node = null
var _camera: Camera4D = null
var _frames: int = 0
var _taken: int = 0
var _blown: float = 0.0
var _setting: String = "baseline"


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_setting = args[0]


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_root = (load("res://sandbox/water4d/pool_room.tscn") as PackedScene).instantiate()
		root.add_child(_root)
		current_scene = _root
		return false
	if _frames == 4:
		_water = _root.get_node_or_null(^"Water")
		var creature: Node4D = _root.get_node_or_null(^"Plesiosaur") as Node4D
		_camera = Camera4D.new()
		_camera.rendering_engine_name = "Cross-section"
		_root.add_child(_camera)
		_camera.current = true
		if creature != null:
			creature.position = Vector4(7.0, -10.5, 15.0, 0.0)
		var eye := Vector4(0.0, 1.9, 1.65, 0.0)
		_camera.position = eye
		_camera.basis = Basis4D.looking_at(Vector4(7.0, -10.5, 15.0, 0.0) - eye)
		_apply()
		return false
	if _frames < SETTLE_FRAMES:
		return false

	_measure(root.get_texture().get_image())
	_taken += 1
	if _taken < SAMPLES:
		return false
	root.get_texture().get_image().save_png("user://one_%s.png" % _setting)
	print("RESULT %-18s %6.2f" % [_setting, _blown / float(SAMPLES)])
	quit(0)
	return true


func _apply() -> void:
	var env := _root.get_node_or_null(^"Environment") as WorldEnvironment4D
	var sun := _root.get_node_or_null(^"Sun") as DirectionalLight4D
	var material: ShaderMaterial = _water.get(&"_material")
	# Baseline is the state BEFORE any of this session's changes, so every row is measured
	# against what the user was actually looking at when they called it blinding.
	_water.set(&"light_response", 1.0)
	_water.set(&"specular_strength", 0.35)
	_water.set(&"roughness", 0.08)
	match _setting:
		"baseline":
			pass
		"sky_0.10":
			env.ambient_light_sky_contribution = 0.10
		"sky_0.00":
			env.ambient_light_sky_contribution = 0.0
		"specular_0":
			_water.set(&"specular_strength", 0.0)
		"foam_0":
			material.set_shader_parameter(&"foam_opacity", 0.0)
		"response_0.45":
			_water.set(&"light_response", 0.45)
		"sun_0.40":
			sun.light_energy = 0.4


func _measure(frame: Image) -> void:
	var data: PackedByteArray = frame.get_data()
	var width: int = frame.get_width()
	var first_row: int = int(float(frame.get_height()) * 0.18)
	var blown: int = 0
	var total: int = 0
	for y in range(first_row, frame.get_height()):
		for x in range(0, width, 2):
			var i: int = (y * width + x) * 4
			if i + 2 >= data.size():
				continue
			total += 1
			if (0.2126 * float(data[i]) + 0.7152 * float(data[i + 1])
					+ 0.0722 * float(data[i + 2])) / 255.0 > 0.90:
				blown += 1
	_blown += 100.0 * float(blown) / maxf(float(total), 1.0)
