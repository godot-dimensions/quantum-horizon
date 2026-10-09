extends Node4D

## WATER LAB: the tank's eel, one European eel 1.4 m long, drawn by life/eel.gdshader through a slice
## herd and swum here, in the water's own frame (life/: x along the tank, y up, z to the glass, W).
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

const Herd := preload("res://ramon/WaterLab/shared/slice_herd_4d.gd")
const KoiMesh := preload("res://ramon/WaterLab/life/koi_mesh.gd")
const SHADER := preload("res://ramon/WaterLab/life/eel.gdshader")

@export var length: float = 1.4
@export var swim_bl: float = 0.35
var half_extents: Vector4 = Vector4(9.2, 2.4, 1.6, 3.5)
var floor_y: float = -2.14
var cave_mouth: Vector4 = Vector4(-3.95, -1.94, -0.55, 0.0)
var cave_out: Vector4 = Vector4(0.0, 0.0, 1.0, 0.0)
var obstacles: Array = []
var ground: Node = null

var herd: Node4D
var cpu_us: float = 0.0
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
	herd = Node4D.new()
	herd.name = "EelHerd"
	herd.set_script(Herd)
	herd.set("mesh", build_mesh())
	herd.set("shader", SHADER)
	herd.set("w_radius", 0.06)
	herd.set("count", 1)
	add_child(herd)
	_h = cave_out
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
		var ww: float = _rng.randf_range(-0.1, 0.1)
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
	want.w += -_p.w * 0.6
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
	_p.y = maxf(_p.y, _floor(_p.x, _p.z, _p.w) + 0.08)


func _floor(x: float, z: float, w: float) -> float:
	return float(ground.call("height_at", x, z, w)) if ground != null else floor_y


func _draw() -> void:
	var right := Vector4(_h.z, 0.0, -_h.x, 0.0)
	right = right.normalized() if right.length() > 0.05 else Vector4(1, 0, 0, 0)
	var breathe: float = 0.5 + 0.5 * sin(_t * 2.2)
	herd.call("write", 0, _p, _h, right, Color(_back, _curl, breathe, 0.0), Vector4(_phase, _amp, length, _bend))
	herd.call("upload")


func bench_row() -> Array:
	return ["Eel", "1", "%.3f ms" % (cpu_us / 1000.0), "1", "bent on the GPU"]


# -- its shape ----------------------------------------------------------------------------------------------

## One body length, snout at z = +0.5: a round body flattening toward the tail, one fin along the back
## and the belly that meets round the tail tip, small pectorals, small eyes.
static func build_mesh() -> ArrayMesh:
	var b: Object = KoiMesh.Builder.new()
	var rings: int = 72
	var sides: int = 14
	var first: int = -1
	var tip: int = b.vertex(Vector3(0.0, -0.002, 0.5), Vector3(0, 0, 1), Vector2(0.0, 0.0), Vector2(0.5, 0.0), 0.0, 0.0)
	for k in rings:
		var s: float = 0.004 + 0.992 * float(k) / float(rings - 1)
		var r: float = _radius(s)
		var flat: float = smoothstep(0.4, 1.0, s)
		for j in sides:
			var a: float = TAU * float(j) / float(sides)
			var p := Vector3(cos(a) * r * (1.0 - 0.55 * flat), sin(a) * r * (1.0 + 0.25 * flat), 0.5 - s)
			var idx: int = b.vertex(p, Vector3(cos(a), sin(a), 0.0).normalized(), Vector2(s, 0.0), Vector2(0.0, 0.0), s, 0.0)
			if k == 0 and j == 0:
				first = idx
	for j in sides:
		b.tri(tip, first + (j + 1) % sides, first + j)
	for k in rings - 1:
		var r0: int = first + k * sides
		var r1: int = r0 + sides
		for j in sides:
			var j1: int = (j + 1) % sides
			b.tri(r0 + j, r0 + j1, r1 + j1)
			b.tri(r0 + j, r1 + j1, r1 + j)
	# The long fin: up from the back and down from the belly, as one sheet each.
	for up in [1.0, -1.0]:
		var s0: float = 0.33 if up > 0.0 else 0.42
		var grid: Array = []
		for i in 4:
			var u: float = float(i) / 3.0
			var row: Array = []
			for j in 40:
				var s: float = lerpf(s0, 0.998, float(j) / 39.0)
				var r: float = _radius(s) * (1.0 + 0.25 * smoothstep(0.4, 1.0, s))
				var h: float = 0.016 * smoothstep(s0, s0 + 0.12, s) * (1.0 - 0.3 * smoothstep(0.9, 1.0, s))
				row.append(b.vertex(Vector3(0.0, up * (r * 0.9 + u * h), 0.5 - s), Vector3(1, 0, 0), Vector2(s, 1.0), Vector2(u, s * up), s, 0.0))
			grid.append(row)
		b.sheet(grid)
	# The pectorals.
	for side in [-1.0, 1.0]:
		var root := Vector3(side * 0.024, -0.008, 0.5 - 0.12)
		var grid2: Array = []
		for i in 3:
			var u: float = float(i) / 2.0
			var row2: Array = []
			for j in 3:
				var v: float = float(j) / 2.0 - 0.5
				row2.append(b.vertex(root + Vector3(side * u * 0.03, -u * 0.008, -u * 0.01 + v * 0.016 * (0.4 + u)), Vector3(0, 1, 0), Vector2(0.12, 2.0), Vector2(u, side), 0.12, 1.0))
			grid2.append(row2)
		b.sheet(grid2)
		# The eye.
		var c := Vector3(side * 0.016, 0.012, 0.5 - 0.035)
		var grid3: Array = []
		for i in 5:
			var th: float = PI * float(i) / 4.0
			var row3: Array = []
			for j in 7:
				var ph: float = TAU * float(j) / 6.0
				var dir := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
				var look := Vector3(side * dir.y, dir.x, dir.z)
				row3.append(b.vertex(c + look * 0.006, look, Vector2(0.035, 3.0), Vector2(dir.y, side), 0.035, 1.0))
			grid3.append(row3)
		b.sheet(grid3, true)
	return b.commit()


static func _radius(s: float) -> float:
	var head: float = sqrt(clampf(s / 0.07, 0.0, 1.0))
	var tail: float = 1.0 - smoothstep(0.5, 1.0, s) * 0.88
	return 0.034 * head * tail
