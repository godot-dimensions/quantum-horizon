extends "res://ramon/WaterLab/scripts/_wl_shots.gd"

## WATER LAB: the hammerhead on its own: side on, from above (the hammer), from the front, three
## quarters, and mid-swing. Frames in smoke_test_output/water_lab/shark/.

const Shark := preload("res://ramon/WaterLab/life/shark_4d.gd")

var _world: Node4D
var _shark: Node4D
var _cam: Camera4D


func setup() -> void:
	out = "res://smoke_test_output/water_lab/shark/"
	tag = "SHARK"
	_world = test_world(Vector4(0.0, 1.6, 4.0, 0.0), Vector4(0.0, 1.2, 0.0, 0.0))
	_cam = _world.get_node("Camera") as Camera4D
	_shark = Node4D.new()
	_shark.name = "Shark"
	_shark.set_script(Shark)
	_shark.set("half_extents", Vector4(30, 30, 30, 30))
	_world.add_child(_shark)
	step(5, _hold.bind(0.0))
	step(1, _eye.bind(Vector4(0.0, 1.25, 3.6, 0.0)))
	step(3, nop, "01_side")
	step(1, _eye.bind(Vector4(0.01, 4.2, 0.0, 0.0)))
	step(3, nop, "02_above")
	step(1, _eye.bind(Vector4(2.6, 1.3, 0.0, 0.0)))
	step(3, nop, "03_front")
	step(1, _eye.bind(Vector4(1.8, 1.9, 2.4, 0.0)))
	step(3, nop, "04_three_quarter")
	step(1, _hold.bind(1.6))
	step(1, _eye.bind(Vector4(0.01, 4.2, 0.0, 0.0)))
	step(3, nop, "05_above_midswing")
	step(1, _hold.bind(3.2))
	step(3, nop, "06_above_otherswing")


## Held at the middle, heading +x, the swim's phase at `phase`.
func _hold(phase: float) -> void:
	_shark.set_process(false)
	_shark.set("p", Vector4(0.0, 1.2, 0.0, 0.0))
	_shark.set("frame", _shark.call("_frame_for", Vector4(1.0, 0.0, 0.0, 0.0)))
	_shark.set("_phase", phase)
	_shark.set("_amp", 1.0)
	_shark.call("_pose")


func _eye(at: Vector4) -> void:
	aim(_cam, at, Vector4(0.0, 1.2, 0.0, 0.0))
