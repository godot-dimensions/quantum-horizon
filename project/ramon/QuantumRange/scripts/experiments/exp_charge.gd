extends "res://ramon/QuantumRange/scripts/range_experiment.gd"

## 02 CHARGE & BREAK: read the target before you shoot. Red takes a quick shot; amber only breaks under a
## charged one (hold until the ring round the crosshair is full, release). The way of playing: READING
## AND DISCIPLINE. W stays out of the way until stage C.
##
##   A  charge        three amber blocks: learn the hold and the release
##   B  two steps     armoured cores: a charge cracks the casing, a tap takes the core it hid
##   C  charge, step  armoured cores in other slices: hold the charge while you step to them (it keeps)
##   D  read fast     a timed mix: red cores that blink out after two seconds (tap them), amber blocks
##                    that stay (charge them)

const PIP := "res://ramon/QuantumRange/scripts/targets/target_pip.gd"
const BLOCK := "res://ramon/QuantumRange/scripts/targets/target_block.gd"
const ARMOURED := "res://ramon/QuantumRange/scripts/targets/target_armoured.gd"

var _total: int = 0
var _queue: Array = []
var _t: float = 0.0
var _resolved: int = 0
var _spawned: Array = []


func _init() -> void:
	id = "charge"
	number = 2
	title = "Charge & Break"
	short = "Charge"
	tagline = "Read the target, then choose the shot."
	headline = "Colour and build say\nhow to shoot."
	explain = "Red takes a quick shot. Amber breaks only under a charged one, and the crosshair turns amber over it. Wasted shots are counted."
	w_load = "LOW"
	glyph = "charge"
	stages = [
		{"title": "Charge", "line": "Amber takes a charged shot. Hold until\nthe ring is full, then release.", "par": 10.0},
		{"title": "Two steps", "line": "Charge to crack the casing,\nthen a quick shot for the core.", "par": 14.0},
		{"title": "Charge, then step", "line": "These are in other slices. Hold your\ncharge while you step to them.", "par": 22.0},
		{"title": "Read fast", "line": "Red blinks out in two seconds: tap it.\nAmber stays: charge it.", "par": 26.0},
	]


func begin(i: int) -> void:
	_resolved = 0
	_t = 0.0
	_spawned = []
	_queue = []
	match i:
		0:
			for p in [Vector3(-2.6, 1.8, 11.0), Vector3(0.0, 2.3, 12.5), Vector3(2.6, 1.7, 11.0)]:
				_spawned.append(d.spawn(BLOCK, ahead(p.x, p.y, p.z)))
		1:
			for p in [Vector3(-2.4, 1.9, 10.5), Vector3(0.2, 2.4, 12.0), Vector3(2.6, 1.7, 10.5)]:
				_spawned.append(d.spawn(ARMOURED, ahead(p.x, p.y, p.z)))
		2:
			for p in [Vector4(-2.2, 1.9, 11.0, 1.2), Vector4(0.4, 2.3, 12.5, -1.6), Vector4(2.6, 1.7, 10.5, 0.8)]:
				_spawned.append(d.spawn(ARMOURED, ahead(p.x, p.y, p.z, p.w)))
		3:
			# A fixed sequence: [seconds in, family, place]. Pips live two seconds.
			_queue = [[0.5, BLOCK, Vector3(-3.0, 2.0, 12.0)], [1.2, PIP, Vector3(1.5, 1.7, 10.0)], [3.0, PIP, Vector3(-1.0, 2.6, 11.0)],
				[4.2, BLOCK, Vector3(3.0, 2.2, 13.0)], [5.4, PIP, Vector3(0.0, 1.8, 9.5)], [7.0, PIP, Vector3(-2.6, 1.6, 10.5)],
				[8.0, BLOCK, Vector3(0.6, 2.8, 14.0)], [9.6, PIP, Vector3(2.4, 2.4, 11.0)], [11.2, PIP, Vector3(-0.8, 1.9, 9.0)]]
	_total = _queue.size() if i == 3 else _spawned.size()


func tick(i: int, dt: float) -> String:
	_t += dt
	if i == 3:
		while not _queue.is_empty() and _t >= float(_queue[0][0]):
			var q: Array = _queue.pop_front()
			var p: Vector3 = q[2]
			var t: Node4D = d.spawn(q[1], ahead(p.x, p.y, p.z), {"lifetime": 2.2} if String(q[1]) == PIP else {})
			_spawned.append(t)
	var live: int = 0
	for t in _spawned:
		if is_instance_valid(t) and bool(t.get("alive")):
			live += 1
	_resolved = _spawned.size() - live
	if i == 3:
		return "done" if _queue.is_empty() and live == 0 else "run"
	return "done" if live == 0 else "run"


func progress(_i: int) -> Vector2:
	return Vector2(_resolved, _total)
