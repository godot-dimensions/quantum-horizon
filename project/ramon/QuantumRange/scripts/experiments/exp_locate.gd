extends "res://ramon/QuantumRange/scripts/range_experiment.gd"

## 01 LOCATE & ALIGN: find a target in a slice you cannot see, line yourself up with it, shoot. The
## range's first idea and its most important tool, the radar. The way of playing: NAVIGATING W.
##
##   A  in your slice      three cores straight ahead: the gun, the crosshair, a shot
##   B  step through W     one core at a time, 0.7 to 1.8 m ana or kata: follow the radar's stem with
##                         Q and E until the edges glow, then shoot
##   C  too far to step    cores 4 to 6 m off in W, beyond the bay's 2 m: each has a cyan ring hanging
##                         on the line to it; turn your slice (right mouse button) until the core shows
##                         in its ring
##   D  drifting           cores drifting between slices: go to them, or wait for them to come to you

const PIP := "res://ramon/QuantumRange/scripts/targets/target_pip.gd"
const RING := "res://ramon/QuantumRange/scripts/targets/target_ring.gd"

var _left: Array = []
var _total: int = 0
var _done: int = 0


func _init() -> void:
	id = "locate"
	number = 1
	title = "Locate & Align"
	short = "Locate"
	tagline = "Find it in W, line up, shoot."
	headline = "Aiming in 4D starts with\nfinding the slice."
	explain = "A core can sit where your slice does not reach. The radar's stem shows how far through W; a step or a turn of the slice brings it in."
	w_load = "HIGH"
	glyph = "locate"
	stages = [
		{"title": "In your slice", "line": "Three cores, straight ahead.\nClick to shoot.", "par": 8.0},
		{"title": "Step through W", "line": "Each core is in another slice. Follow\nthe radar's stem: E ana, Q kata.", "par": 18.0},
		{"title": "Too far to step", "line": "These are beyond the bay's 2 m of W.\nHold the right mouse button: turn your\nslice until the core is in its ring.", "par": 32.0},
		{"title": "Drifting", "line": "These drift through W. Go to them,\nor wait for one to come to you.", "par": 24.0},
	]


func begin(i: int) -> void:
	_done = 0
	_left = []
	match i:
		0:
			for p in [Vector3(-2.6, 1.9, 12.0), Vector3(0.0, 2.5, 14.0), Vector3(2.6, 1.7, 12.0)]:
				d.spawn(PIP, ahead(p.x, p.y, p.z))
			_total = 3
		1:
			_left = [Vector4(-1.6, 2.0, 11.0, 1.0), Vector4(1.8, 1.7, 12.0, -1.4), Vector4(0.0, 2.6, 14.0, 1.8), Vector4(-2.4, 1.6, 10.0, -0.7)]
			_total = _left.size()
			_next_one()
		2:
			# Each ring hangs on the line from your eye to its core, 10 m out, so turning your slice to
			# the core puts the core in the middle of its ring.
			var eye: Vector4 = (d.get("player").get("camera") as Node4D).global_position
			for c in [Vector4(-3.0, 2.2, 24.0, 4.5), Vector4(2.5, 2.8, 26.0, -5.0), Vector4(0.0, 1.8, 28.0, 6.0)]:
				var core: Vector4 = ahead(c.x, c.y, c.z, c.w)
				var to: Vector4 = core - eye
				var ring: Vector4 = eye + to * (10.0 / to.length())
				d.spawn(RING, core, {"ring_at": ring - core})
			_total = 3
		3:
			for k in 3:
				var phase: float = float(k) * 2.1
				var base: Vector4 = ahead(-3.0 + 3.0 * float(k), 1.8 + 0.4 * float(k), 15.0 + 1.5 * float(k), 0.0)
				var t: Node4D = d.spawn(PIP, base + Vector4(0, 0, 0, 2.2 * sin(phase)))
				# Swinging through W between 2.2 m ana and kata, a little across too, each in its own time.
				t.set("path", func(_tt: Node4D, age: float) -> Vector4:
					return base + Vector4(sin(age * 0.5 + phase) * 1.2, 0.0, 0.0, 2.2 * sin(age * 0.55 + phase)))
			_total = 3


func _next_one() -> void:
	if _left.is_empty():
		return
	var p: Vector4 = _left.pop_front()
	d.spawn(PIP, ahead(p.x, p.y, p.z, p.w))


func tick(i: int, _dt: float) -> String:
	var n: int = d.alive_count()
	if i == 1:
		_done = _total - _left.size() - n
		if n == 0 and not _left.is_empty():
			_next_one()
			return "run"
		return "done" if n == 0 and _left.is_empty() else "run"
	_done = _total - n
	return "done" if n == 0 else "run"


func progress(_i: int) -> Vector2:
	return Vector2(_done, _total)


func keys() -> Array:
	return []
