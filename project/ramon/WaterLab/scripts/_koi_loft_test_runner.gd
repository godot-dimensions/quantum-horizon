extends "res://ramon/WaterLab/scripts/_wl_shots.gd"

## WATER LAB: the lofted koi (life/koi_loft_4d.gd) on its own, beside the hammerhead (life/shark_4d.gd),
## both TRUE 4D. Frames in smoke_test_output/water_lab/koi_loft/:
##   a01-a04  the koi side on, from above at two phases of the wave, close on the head (the gulp);
##   b*       the eight varieties in a column, side on and from above;
##   t*       THE SLICE TURNED: the koi above the shark, both heading +x, the pair turned through W
##            the tank's two ways (x-W, z-W) by 0, 20, 40, 60 and 75 degrees, as tank_4d.gd turns
##            its contents. Both should thin away the same way: the body cut shorter and narrower, the
##            fins first.
## Prints the bake, the tetrahedra and the cost of a pose.

const KoiLoft := preload("res://ramon/WaterLab/life/koi_loft_4d.gd")
const Kit := preload("res://ramon/WaterLab/life/loft_kit.gd")
const Shark := preload("res://ramon/WaterLab/life/shark_4d.gd")
const EelLoft := preload("res://ramon/WaterLab/life/eel_loft_4d.gd")
const CrabLoft := preload("res://ramon/WaterLab/life/crab_loft_4d.gd")
const SeaSchool := preload("res://ramon/WaterLab/seascape/fish_school_4d.gd")

var _world: Node4D
var _cam: Camera4D
var _contents: Node4D
var _koi: Node4D
var _shark: Node4D
var _column: Array = []


func setup() -> void:
	out = "res://smoke_test_output/water_lab/koi_loft/"
	tag = "KOILOFT"
	_world = test_world(Vector4(0.0, 1.6, 3.0, 0.0), Vector4(0.0, 1.4, 0.0, 0.0))
	_cam = _world.get_node("Camera") as Camera4D
	_contents = Node4D.new()
	_contents.name = "Contents"
	_world.add_child(_contents)
	var t0: int = Time.get_ticks_usec()
	_koi = Node4D.new()
	_koi.name = "Koi"
	_koi.set_script(KoiLoft)
	_koi.set("variety", 0)
	_contents.add_child(_koi)
	print("KOILOFT built (or loaded) in %.0f ms: %d tetrahedra, %d meshes" % [(Time.get_ticks_usec() - t0) / 1000.0, int(_koi.get("tets")), int(_koi.get("meshes"))])
	_shark = Node4D.new()
	_shark.name = "Shark"
	_shark.set_script(Shark)
	_shark.set("half_extents", Vector4(30, 30, 30, 30))
	_contents.add_child(_shark)
	_shark.set_process(false)
	# The cost of a pose.
	var t1: int = Time.get_ticks_usec()
	for i in 200:
		_koi.call("pose", Vector4(0, 1.8, 0, 0), Projection.IDENTITY, 0.8, float(i) * 0.1, 0.1, 0.1, 0.5, 0.3, float(i) * 0.03)
	print("KOILOFT pose: %.1f us a koi" % ((Time.get_ticks_usec() - t1) / 200.0))
	step(5, _hold.bind(0.0, 0.0, 0.0))
	step(1, _eye.bind(Vector4(0.0, 1.85, 1.6, 0.0), Vector4(0.0, 1.8, 0.0, 0.0)))
	step(3, nop, "a01_side")
	step(1, _eye.bind(Vector4(0.01, 3.4, 0.0, 0.0), Vector4(0.0, 1.8, 0.0, 0.0)))
	step(3, nop, "a02_above")
	step(1, _hold.bind(1.6, 0.0, 0.0))
	step(3, nop, "a03_above_midswing")
	step(1, _hold.bind(0.6, 0.25, 1.0))
	step(1, _eye.bind(Vector4(0.62, 1.95, 0.55, 0.0), Vector4(0.3, 1.8, 0.0, 0.0)))
	step(3, nop, "a04_head_gulp_spread_bent")
	# The pair, for the turns.
	step(1, _hold.bind(0.8, 0.0, 0.0))
	step(1, _eye.bind(Vector4(0.0, 1.5, 4.6, 0.0), Vector4(0.0, 1.45, 0.0, 0.0)))
	for plane in ["xw", "zw"]:
		for deg in [0, 20, 40, 60, 75]:
			step(1, _turn.bind(plane, float(deg)))
			step(3, nop, "t_%s_%02d" % [plane, deg])
	step(1, _turn.bind("xw", 0.0))
	# The varieties.
	step(1, _lineup)
	step(1, _eye.bind(Vector4(0.0, 1.9, 3.4, 0.0), Vector4(0.0, 1.9, 0.0, 0.0)))
	step(6, nop, "b01_varieties_side")
	step(1, _eye.bind(Vector4(0.01, 5.6, 0.2, 0.0), Vector4(0.0, 1.9, 0.0, 0.0)))
	step(3, nop, "b02_varieties_above")
	# The eel (1.4 m) and the crab (0.34 m) beside the hammerhead, side on, mid-swim and mid-step.
	step(1, _eel_and_crab)
	step(1, _eye.bind(Vector4(0.0, 1.3, 3.2, 0.0), Vector4(0.0, 1.1, 0.0, 0.0)))
	step(6, nop, "c01_eel_crab_side")
	step(1, _eye.bind(Vector4(0.01, 4.0, 0.3, 0.0), Vector4(0.0, 1.1, 0.0, 0.0)))
	step(3, nop, "c02_eel_crab_above")
	step(1, _eye.bind(Vector4(0.9, 0.75, 1.0, 0.0), Vector4(0.9, 0.35, 0.0, 0.0)))
	step(3, nop, "c03_crab_close")
	# The sea's school of sardines (150 lofted fish on the carried flock), in the open: from beside it
	# and close, after it has had a few seconds to gather.
	step(1, _school)
	step(240, _look_at_school.bind(6.0), "d01_school")
	step(60, _look_at_school.bind(2.2), "d02_school_close")
	step(1, _school_turned)
	step(10, _look_at_school.bind(2.2), "d03_school_close_turned_xw_20")


## The koi at the middle, heading +x, the shark below it; the wave at `phase`, a turn's `bend`, the
## pectorals' `spread` (and the mouth open with it).
func _hold(phase: float, bend: float, spread: float) -> void:
	var f: Projection = Kit.frame_for(Vector4(1, 0, 0, 0), Projection(Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, 0, 1)))
	_koi.call("pose", Vector4(0.0, 1.8, 0.0, 0.0), f, 0.8, phase, 0.1, bend, spread, spread, phase)
	_shark.set("p", Vector4(0.0, 0.9, 0.0, 0.0))
	_shark.set("frame", _shark.call("_frame_for", Vector4(1.0, 0.0, 0.0, 0.0)))
	_shark.set("_phase", phase)
	_shark.set("_amp", 1.0)
	_shark.call("_pose")


## The pair turned through W as the tank turns its contents (about the pair's middle).
func _turn(plane: String, deg: float) -> void:
	var a: float = deg_to_rad(deg)
	var b: Projection = Basis4D.from_xw(a) if plane == "xw" else Basis4D.from_zw(a)
	var mid := Vector4(0.0, 1.35, 0.0, 0.0)
	_contents.basis = b
	_contents.position = mid - b * mid


func _lineup() -> void:
	_koi.visible = false
	_shark.visible = false
	var f: Projection = Kit.frame_for(Vector4(1, 0, 0, 0), Projection(Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(1, 0, 0, 0), Vector4(0, 0, 0, 1)))
	for v in 8:
		var k := Node4D.new()
		k.set_script(KoiLoft)
		k.set("variety", v)
		k.set("long_fins", v % 3 == 1)
		k.set("pattern_seed", 0.13 + 0.29 * float(v))
		_contents.add_child(k)
		k.call("pose", Vector4((float(v % 2) - 0.5) * 1.1, 0.5 + float(v) * 0.38, 0.0, 0.0), f, 0.8, float(v), 0.06, 0.0, 0.3, 0.0, 0.0)
		_column.append(k)


func _eye(at: Vector4, look: Vector4) -> void:
	aim(_cam, at, look)


func _eel_and_crab() -> void:
	for k in _column:
		(k as Node4D).visible = false
	_shark.visible = true
	_hold(0.8, 0.0, 0.0)
	_koi.visible = false
	var eel := Node4D.new()
	eel.set_script(EelLoft)
	_contents.add_child(eel)
	eel.call("pose", Vector4(-0.2, 1.75, 0.0, 0.0), Kit.level_frame(Vector4(1, 0, 0, 0)), 1.4, 1.3, 0.085, 0.0, 0.0, 0.0)
	print("KOILOFT eel: %d tetrahedra, %d meshes" % [int(eel.get("tets")), int(eel.get("meshes"))])
	var crab := Node4D.new()
	crab.set_script(CrabLoft)
	_contents.add_child(crab)
	crab.call("pose", Vector4(0.9, 0.0, 0.0, 0.0), Kit.level_frame(Vector4(0, 0, 1, 0)), 0.34, 1.0, 1.0, 0.6, 0.5, 0.0)
	print("KOILOFT crab: %d tetrahedra, %d meshes" % [int(crab.get("tets")), int(crab.get("meshes"))])


var _sea_school: Node4D


func _school() -> void:
	_contents.basis = Projection.IDENTITY
	_contents.position = Vector4.ZERO
	for c in _contents.get_children():
		(c as Node4D).visible = false
	_sea_school = Node4D.new()
	_sea_school.set_script(SeaSchool)
	_sea_school.position = Vector4(0.0, 4.5, -4.0, 0.0)
	_contents.add_child(_sea_school)


## The camera `d` metres from the school's middle, level with it, on its +z side.
func _look_at_school(d: float) -> void:
	var m: Vector4 = _sea_school.call("middle")
	aim(_cam, Vector4(m.x + 0.3, m.y + 0.2, m.z + d, 0.0), m)


func _school_turned() -> void:
	var m: Vector4 = _sea_school.call("middle")
	var b: Projection = Basis4D.from_xw(deg_to_rad(20.0))
	_contents.basis = b
	_contents.position = m - b * m
