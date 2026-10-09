extends "res://ramon/WaterLab/scripts/_wl_shots.gd"

## WATER LAB: the koi on their own, before the tank: a school in the open over a grey floor, then one
## koi held still beside the camera so its shape, its wave and its colours can be read. Frames in
## smoke_test_output/water_lab/koi/. "perf" times 40 koi.

const School := preload("res://ramon/WaterLab/life/koi_school_4d.gd")

var _world: Node4D
var _school: Node4D
var _cam: Camera4D


func setup() -> void:
	out = "res://smoke_test_output/water_lab/koi/"
	tag = "KOI"
	_world = test_world(Vector4(0.0, 1.7, 4.6, 0.0), Vector4(0.0, 1.3, 0.0, 0.0))
	_cam = _world.get_node("Camera") as Camera4D
	_school = Node4D.new()
	_school.name = "Koi"
	_school.set_script(School)
	_school.set("half_extents", Vector4(3.2, 1.1, 1.3, 1.0))
	_school.set("floor_height", 0.0)
	_school.position = Vector4(0.0, 1.3, 0.0, 0.0)
	_world.add_child(_school)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "perf" in args:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		_school.set("count", 40)
		_school.call("respawn")
		step(60, nop)
		step(1, perf_start.bind("koi_40"))
		step(240, nop)
		step(1, perf_end)
		return
	step(40, nop, "01_school")
	step(45, nop, "02_school_later")
	step(45, nop, "03_school_later")
	# One koi still, side on, a metre and a half away, then from above and from the front.
	step(1, _pose_one.bind(0, 0.0, Vector4.ZERO, Vector4(0.0, 0.0, 1.0, 0.0)))
	step(1, func() -> void: aim(_cam, Vector4(1.2, 1.35, 0.0, 0.0), Vector4(0.0, 1.3, 0.0, 0.0)))
	step(3, nop, "04_kohaku_side")
	step(1, _pose_one.bind(0, 0.10, Vector4.ZERO, Vector4(0.0, 0.0, 1.0, 0.0)))
	step(3, nop, "05_kohaku_beating")
	step(1, func() -> void: aim(_cam, Vector4(0.01, 2.6, 0.0, 0.0), Vector4(0.0, 1.3, 0.0, 0.0)))
	step(3, nop, "06_kohaku_above")
	for v in [1, 2, 3, 4, 6]:
		step(1, _pose_one.bind(v, 0.06, Vector4.ZERO, Vector4(0.0, 0.0, 1.0, 0.0)))
		step(3, nop, "07_variety_%d_above" % v)
	step(1, func() -> void: aim(_cam, Vector4(0.0, 1.35, 1.3, 0.0), Vector4(0.0, 1.3, 0.0, 0.0)))
	step(1, _pose_one.bind(0, 0.03, Vector4.ZERO, Vector4(0.0, 0.0, 1.0, 0.0), 1.0, 1.0))
	step(3, nop, "08_front_gulp_spread")
	step(1, func() -> void: aim(_cam, Vector4(1.2, 1.35, 0.0, 0.0), Vector4(0.0, 1.3, 0.0, 0.0)))
	step(1, _pose_one.bind(0, 0.04, Vector4.ZERO, Vector4(0.0, 0.0, 1.0, 0.0), 0.0, 0.0, 0.3))
	step(3, nop, "09_turn_bend")
	# Off the slice through W: the cut shrinks it.
	step(1, _pose_one.bind(0, 0.04, Vector4(0.0, 0.0, 0.0, 0.10), Vector4(0.0, 0.0, 1.0, 0.0)))
	step(3, nop, "10_w_0_10")


## Koi 0 held at `at`, heading `h`, with variety `v`, the tail at `amp` and the rest as given; the
## others sent far off.
func _pose_one(v: int, amp: float, at: Vector4, h: Vector4, spread: float = 0.1, gulp: float = 0.0, bend: float = 0.0) -> void:
	_school.set_process(false)
	var herd: Node = _school.get("herd")
	var n: int = int(_school.get("count"))
	for i in n:
		herd.call("write", i, Vector4(0, -50, 0, 0), Vector4(0, 0, 1, 0), Vector4(1, 0, 0, 0), Color(0, 0, 0, 0), Vector4(0, 0, 0, 0))
	var right := Vector4(h.z, 0.0, -h.x, 0.0).normalized()
	herd.call("write", 0, at, h, right, Color(float(v) / 16.0, 0.37, spread, gulp), Vector4(1.3, amp, 0.75, bend))
	herd.call("upload")
