extends Node4D

## WATER LAB, THE SEA: more life under the pier (Ramon, 9 Oct, round 4: "a few more fish or creatures
## using the assets already developed ... a small grouping or clump of around three creatures moving
## together ... an eel presence, the shark moving closer to the surface at times ... make the view
## downward feel a little more populated ... believable and not overcrowded").
##
##   THE HAMMERHEADS  three of the tank's lofted hammerheads (life/shark_4d.gd), a third again bigger,
##                    cruising together: a leader on a slow wandering loop round the platform (9 to
##                    19 m from its middle: the followers, up to 2.6 m to its sides, pass a metre or
##                    two off the platform's foot and never under it), the
##                    other two holding loose stations off its flanks; their depth a long swell
##                    between `depth_range` (4.5 m and 0.8 m) under the surface, so now and then they
##                    come up near it. (The sea is dark below three metres or so: 6 m and 1.5 m at
##                    first, and the frames of 9 Oct never caught one.)
##   THE EELS         two of the tank's eels, lofted in 4D (life/eel_loft_4d.gd, round 5), two metres long,
##                    winding slowly round the pole just under the surface (under a metre and a half:
##                    deeper, the dark water hid them in the frames of 9 Oct), on and off its far side.
##
## The sharks are posed as the showcase poses one (their own _process off, `p` and `frame` set, _pose
## called); the eels likewise (their pieces posed by EelLoft.pose). In the seascape's own frame (its
## root). NO class_name.

const Shark := preload("res://ramon/WaterLab/life/shark_4d.gd")
const EelLoft := preload("res://ramon/WaterLab/life/eel_loft_4d.gd")
const Kit := preload("res://ramon/WaterLab/life/loft_kit.gd")

## The loop's middle (x, z) and size; the pole (x, z) the eels wind round.
var loop_centre := Vector2(26.0, 0.0)
var loop_radius := Vector2(14.0, 12.0)
var pole := Vector2(32.0, -11.0)
@export var shark_scale: float = 1.35
@export var shark_speed: float = 1.6
@export var depth_range := Vector2(0.8, 4.5)

var _sharks: Array = []
var _eels: Array = []
var _eel_frames: Array = []
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
const OFFSETS := [Vector3(0.0, 0.0, 0.0), Vector3(-3.0, -0.8, 2.6), Vector3(-4.2, 0.6, -2.4)]


func _ready() -> void:
	_rng.randomize()
	_t = _rng.randf() * 200.0
	for i in 3:
		var s := Node4D.new()
		s.name = "Hammerhead%d" % i
		s.set_script(Shark)
		s.set("half_extents", Vector4(200, 200, 200, 200))
		add_child(s)
		s.set_process(false)
		var k: float = shark_scale * (1.0 - 0.08 * float(i))
		s.basis = Projection(Vector4(k, 0, 0, 0), Vector4(0, k, 0, 0), Vector4(0, 0, k, 0), Vector4(0, 0, 0, k))
		_sharks.append({"node": s, "k": k, "phase": _rng.randf() * TAU})
	for e in 2:
		var eel := Node4D.new()
		eel.name = "Eel%d" % e
		eel.set_script(EelLoft)
		add_child(eel)
		_eels.append(eel)
		_eel_frames.append(Projection.IDENTITY)


## Where the leader is at time t (the seascape's frame): a slow wandering loop, its depth a long swell.
func _leader(t: float) -> Vector4:
	var a: float = t * shark_speed / ((loop_radius.x + loop_radius.y) * 0.5)
	var x: float = loop_centre.x + cos(a) * loop_radius.x + 4.0 * sin(a * 2.3)
	var z: float = loop_centre.y + sin(a) * loop_radius.y + 3.0 * cos(a * 1.7)
	var depth: float = lerpf(depth_range.x, depth_range.y, 0.5 + 0.5 * sin(t * 0.045))
	return Vector4(x, -depth, z, 0.0)


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)
	_t += dt
	var p0: Vector4 = _leader(_t)
	var p1: Vector4 = _leader(_t + 0.5)
	var ahead: Vector4 = (p1 - p0).normalized()
	var right := Vector4(ahead.z, 0.0, -ahead.x, 0.0).normalized()
	for i in _sharks.size():
		var sh: Dictionary = _sharks[i]
		var s: Node4D = sh["node"]
		var o: Vector3 = OFFSETS[i]
		var wander := Vector4(sin(_t * 0.21 + float(i)) * 0.6, sin(_t * 0.17 + float(i) * 2.0) * 0.3, 0.0, 0.0)
		var at: Vector4 = p0 + ahead * o.x + Vector4(0.0, o.y, 0.0, 0.0) + right * o.z + wander
		var k: float = sh["k"]
		sh["phase"] = float(sh["phase"]) + TAU * 0.7 * dt
		s.set("p", at / k)
		s.set("frame", s.call("_frame_for", ahead))
		s.set("_phase", sh["phase"])
		s.set("_amp", 0.7)
		s.call("_pose")
	# The eels round the pole, a few metres down, one each way.
	for e in 2:
		var dir: float = 1.0 if e == 0 else -1.0
		var a: float = _t * 0.12 * dir + float(e) * 2.4
		var r: float = 3.2 + 0.6 * sin(_t * 0.3 + float(e))
		var at2 := Vector4(pole.x + cos(a) * r, -0.7 - 0.4 * float(e) + 0.25 * sin(_t * 0.5 + float(e)), pole.y + sin(a) * r, 0.0)
		var h := Vector4(-sin(a) * dir, 0.0, cos(a) * dir, 0.0)
		var f: Projection = Kit.level_frame(h) if _eel_frames[e] == Projection.IDENTITY else Kit.frame_for(h, _eel_frames[e])
		_eel_frames[e] = f
		(_eels[e] as Node4D).call("pose", at2, f, 2.0, _t * TAU * 0.7, 0.07, dir * 0.25, 0.0, 0.0)
