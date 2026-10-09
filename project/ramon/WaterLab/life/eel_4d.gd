extends Node4D

## WATER LAB: the tank's eel, one European eel 1.4 m long, LOFTED IN 4D (life/eel_loft_4d.gd, round 5;
## until 9 Oct a 3D mesh that a shader shrank off the slice) and swum here, in the water's own frame
## (life/: x along the tank, y up, z to the glass, W). It keeps to your slice: a lofted eel shows only
## within its own half width (5 cm) of it.
##
## WHAT IT DOES (eels by day: they hide in crevices and come out to hunt along the bottom):
##   REST      in the cave under the rock pile (reef_4d.gd cave_mouth), only its head out, its body
##             tucked in an S, breathing (the mouth and gills opening a little).
##   OUT       it slides out forward, then patrols: a long loop low over the sand, round the stones,
##             now and then up the back glass a way and down again.
##   HOME      back at the cave it stops facing out and swims in BACKWARD, tail first, the wave
##             running from tail to head, as eels back into holes.
##
## NO class_name (engine_gotchas.md).

const EelLoft := preload("res://ramon/WaterLab/life/eel_loft_4d.gd")
const Kit := preload("res://ramon/WaterLab/life/loft_kit.gd")

@export var length: float = 1.4
@export var swim_bl: float = 0.35
var half_extents: Vector4 = Vector4(9.2, 2.4, 1.6, 3.5)
var floor_y: float = -2.14
var cave_mouth: Vector4 = Vector4(-3.95, -1.94, -0.55, 0.0)
var cave_out: Vector4 = Vector4(0.0, 0.0, 1.0, 0.0)
var obstacles: Array = []
var ground: Node = null

var eel: Node4D
var cpu_us: float = 0.0
var _frame := Projection.IDENTITY
var _p := Vector4.ZERO
var _h := Vector4(0, 0, 1, 0)
var _v: float = 0.0
var _phase: float = 0.0
var _amp: float = 0.02
var _bend: float = 0.0
var _curl: float = 1.0
var _back: float = 0.0
var _state: String = "rest"
var _state_t: float = 20.0
var _route: Array = []
var _leg: int = 0
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0


func _ready() -> void:
	_rng.seed = 5512
	eel = Node4D.new()
	eel.name = "Eel"
	eel.set_script(EelLoft)
	add_child(eel)
	_h = cave_out
	_frame = Kit.level_frame(_h)
	_p = cave_mouth - cave_out * (length * 0.18)
	_state_t = _rng.randf_range(8.0, 16.0)


func _process(delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	var dt: float = minf(delta, 0.05)
	_t += dt
	_state_t -= dt
	match _state:
		"rest":
			_amp = lerpf(_amp, 0.015, dt)
			_curl = lerpf(_curl, 1.0, dt * 0.5)
			_bend = lerpf(_bend, 0.04 * sin(_t * 0.4), dt)
			_phase += TAU * 0.25 * dt
			if _state_t <= 0.0:
				_state = "out"
				_route = _patrol()
				_leg = 0
		"out":
			_curl = lerpf(_curl, 0.0, dt * 0.8)
			_back = lerpf(_back, 0.0, dt * 3.0)
			_swim_to(_route[_leg], dt, false)
			if (_p - (_route[_leg] as Vector4)).length() < 0.35:
				_leg += 1
				if _leg >= _route.size():
					_state = "home"
		"home":
			# In front of the cave, facing out.
			var front: Vector4 = cave_mouth + cave_out * (length * 0.55)
			if (_p - front).length() > 0.25:
				_swim_to(front, dt, false)
			else:
				_state = "backing"
		"backing":
			# Tail first into the cave: the wave runs the other way.
			_back = lerpf(_back, 1.0, dt * 2.0)
			_h = _h.lerp(cave_out, 1.0 - exp(-3.0 * dt)).normalized()
			var inside: Vector4 = cave_mouth - cave_out * (length * 0.18)
			var to: Vector4 = inside - _p
			_v = minf(0.12, to.length() * 0.6)
			_p += to.normalized() * _v * dt if to.length() > 0.01 else Vector4.ZERO
			_amp = lerpf(_amp, 0.06, dt * 2.0)
			_phase -= TAU * 1.2 * dt
			_bend = lerpf(_bend, 0.0, dt * 2.0)
			if to.length() < 0.04:
				_state = "rest"
				_back = 0.0
				_state_t = _rng.randf_range(20.0, 40.0)
	_draw()
	cpu_us = lerpf(cpu_us, float(Time.get_ticks_usec() - t0), 0.05)


## The patrol: low over the sand along the tank and back, round the stones, now and then up the back.
func _patrol() -> Array:
	var y: float = floor_y + 0.25
	var out: Array = [cave_mouth + cave_out * 1.0 + Vector4(0, 0.05, 0, 0)]
	var xs: Array = [-1.0, 2.5, 6.0, 8.2, 5.0, 1.0, -3.0, -6.5, -8.3, -6.0]
	for i in xs.size():
		var x: float = float(xs[i])
		var z: float = -0.6 if i < 4 else 0.9
		var zz: float = z + _rng.randf_range(-0.3, 0.3)
		# On your slice (the old eel strayed 0.1 m off it, which a lofted eel 5 cm deep does not survive).
		var ww: float = 0.0
		var yy: float = _floor(x, zz, ww) + 0.25 + (1.6 if i == 3 and _rng.randf() < 0.6 else 0.0)
		out.append(Vector4(x, yy, zz, ww))
	out.append(cave_mouth + cave_out * 1.2)
	return out


func _swim_to(target: Vector4, dt: float, _backward: bool) -> void:
	var to: Vector4 = target - _p
	var want: Vector4 = to.normalized() if to.length() > 0.001 else _h
	# Round the stones.
	for ob in obstacles:
		var d: Vector4 = _p + _h * length * 0.4 - (ob[0] as Vector4)
		var r: float = float(ob[1]) + 0.25
		if d.length() < r and d.length() > 0.001:
			want += d.normalized() * (r - d.length()) / r * 2.0
	want.w += -_p.w * 2.0
	want = want.normalized()
	var rate: float = 1.1
	var cosang: float = clampf(_h.dot(want), -1.0, 1.0)
	var ang: float = acos(cosang)
	var before: Vector4 = _h
	if ang > 0.0005:
		var perp: Vector4 = want - _h * cosang
		if perp.length() > 0.0001:
			_h = (_h * cos(minf(ang, rate * dt)) + perp.normalized() * sin(minf(ang, rate * dt))).normalized()
	var right := Vector4(_h.z, 0.0, -_h.x, 0.0)
	right = right.normalized() if right.length() > 0.05 else Vector4(1, 0, 0, 0)
	var turn: float = (_h - before).dot(right) / maxf(dt, 0.0001)
	_bend = lerpf(_bend, clampf(turn * 0.22, -0.3, 0.3), 1.0 - exp(-4.0 * dt))
	_v = lerpf(_v, swim_bl * length, 1.0 - exp(-1.5 * dt))
	_amp = lerpf(_amp, 0.085, 1.0 - exp(-2.0 * dt))
	_phase += TAU * (0.6 + 1.6 * _v / length) * dt
	_p += _h * _v * dt
	_p.w = move_toward(_p.w, 0.0, dt * 0.2)
	_p.y = maxf(_p.y, _floor(_p.x, _p.z, _p.w) + 0.08)


func _floor(x: float, z: float, w: float) -> float:
	return float(ground.call("height_at", x, z, w)) if ground != null else floor_y


func _draw() -> void:
	_frame = Kit.frame_for(_h, _frame)
	eel.call("pose", _p, _frame, length, _phase, _amp, _bend, _back, _curl)


func bench_row() -> Array:
	return ["Eel", "1", "%.3f ms" % (cpu_us / 1000.0), str(int(eel.get("meshes"))), "4D loft, 12 pieces"]
