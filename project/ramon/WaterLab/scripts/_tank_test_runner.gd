extends "res://ramon/WaterLab/scripts/_wl_shots.gd"

## WATER LAB: the tank on its own, before the room: from the front at walking height (the opening
## shot), close at the glass (the koi should come), from low (the surface from below), from above
## (through the surface), and through a turned slice. Frames in smoke_test_output/water_lab/tank/.

const Tank := preload("res://ramon/WaterLab/tank/tank_4d.gd")

var _world: Node4D
var _tank: Node4D
var _cam: Camera4D


func setup() -> void:
	out = "res://smoke_test_output/water_lab/tank/"
	tag = "TANK"
	_world = test_world(Vector4(-5.0, 3.6, 11.0, 0.0), Vector4(0.0, 3.0, 0.0, 0.0))
	_cam = _world.get_node("Camera") as Camera4D
	_tank = Node4D.new()
	_tank.name = "Tank"
	_tank.set_script(Tank)
	_world.add_child(_tank)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "perf" in args:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		step(90, nop)
		step(1, perf_start.bind("tank_front"))
		step(240, nop)
		step(1, perf_end)
		return
	step(60, nop, "01_entering")
	step(1, _eye.bind(Vector4(0.0, 3.4, 8.5, 0.0), Vector4(0.0, 3.1, 0.0, 0.0)))
	step(30, nop, "02_front")
	step(1, _eye.bind(Vector4(1.0, 3.0, 4.0, 0.0), Vector4(1.0, 3.0, 0.0, 0.0)))
	step(240, nop, "03_at_glass_after_8s")
	step(1, _eye.bind(Vector4(-2.0, 2.4, 4.2, 0.0), Vector4(-1.0, 4.8, 0.0, 0.0)))
	step(10, nop, "04_surface_from_below")
	step(1, _eye.bind(Vector4(0.0, 8.5, 4.5, 0.0), Vector4(0.0, 3.0, 0.0, 0.0)))
	step(10, nop, "05_from_above")
	step(1, _eye.bind(Vector4(-4.0, 3.2, 6.0, 0.0), Vector4(-4.0, 1.6, 0.0, 0.0)))
	step(10, nop, "06_sand_caustics")
	# A turned slice: the camera turned 30 degrees into W about the vertical (zw), as a right drag.
	step(1, _turned.bind(Vector4(0.0, 3.4, 8.5, 0.0), 30.0))
	step(10, nop, "07_slice_turned_30")


func _eye(eye: Vector4, look: Vector4) -> void:
	aim(_cam, eye, look)
	if _tank.has_method("set_viewer"):
		_tank.call("set_viewer", eye)


func _turned(eye: Vector4, deg: float) -> void:
	aim(_cam, eye, Vector4(0.0, 3.1, 0.0, 0.0))
	_cam.global_basis = _cam.global_basis * Basis4D.from_zw(deg_to_rad(deg))
