extends "res://ramon/QuantumRange/scripts/range_experiment.gd"

## 05 CHICKEN SKEET (Ramon, 5 Oct: "would be fun to shoot some flying chickens too"): skeet with the pen's
## chickens. Two trap houses stand downrange, left and right; F calls PULL and a bird flies out on an arc
## across the range. The way of playing: TRACKING AND INTERCEPTING, through W in stage C: a bird that swings
## through W on its way across is in your slice only for part of its flight, longest at the top of its
## swing. Step there and wait for it.
##
##   A  pull           single birds, arcs in your slice
##   B  doubles        two at a time, one from each house
##   C  through W      single birds swinging 1.5 m ana or kata at the top of the arc: step to meet them
##   D  the flock      six in a burst, mixed
##
## A bird you miss lands and is gone; nothing is lost but the bird.

const CHICKEN := "res://ramon/QuantumRange/scripts/targets/target_chicken.gd"
const Build := preload("res://ramon/QuantumRange/carried/scripts/chamber_build.gd")

const HOUSE_X := 8.4
const HOUSE_DIST := 12.5
const G := -7.0
const FLIGHT := 2.6

var hit_birds: int = 0
var launched: int = 0
var _pulls: Array = []
## Birds called but not out yet: [seconds left, house, W at the top].
var _pending: Array = []
## Every bird out this stage: [target, outcome] (outcome "" while it flies, then "hit" or "miss").
var _birds: Array = []
var _waiting: bool = true


func _init() -> void:
	id = "skeet"
	number = 5
	title = "Chicken Skeet"
	short = "Skeet"
	tagline = "Pull."
	headline = "Something that flies through W\nis in your slice for a moment."
	explain = "A bird swinging through W crosses your slice for part of its flight, longest at the top of its swing: step to where it will be and wait."
	w_load = "HIGH"
	glyph = "chicken"
	stages = [
		{"title": "Pull", "line": "Press F to pull. Hit the bird\nin the air.", "par": 16.0},
		{"title": "Doubles", "line": "Two at a time, one from each house.", "par": 18.0},
		{"title": "Through W", "line": "These swing through W at the top of\nthe arc. Step there and wait for it.", "par": 24.0},
		{"title": "The flock", "line": "Six in a burst. Pull when ready.", "par": 14.0},
	]


func begin(i: int) -> void:
	if i == 0:
		hit_birds = 0
		launched = 0
		_houses()
	_birds = []
	_pending = []
	_waiting = true
	# Each pull: a list of birds, [house (-1 left, 1 right), W at the top of the swing, delay].
	match i:
		0:
			_pulls = [[[-1, 0.0, 0.0]], [[1, 0.0, 0.0]], [[-1, 0.0, 0.0]], [[1, 0.0, 0.0]]]
		1:
			_pulls = [[[-1, 0.0, 0.0], [1, 0.0, 0.25]], [[1, 0.0, 0.0], [-1, 0.0, 0.25]], [[-1, 0.0, 0.0], [1, 0.0, 0.0]]]
		2:
			_pulls = [[[-1, 1.5, 0.0]], [[1, -1.5, 0.0]], [[-1, -1.2, 0.0]], [[1, 1.6, 0.0]]]
		3:
			_pulls = [[[-1, 0.0, 0.0], [1, 0.0, 0.2], [-1, 1.2, 0.5], [1, -1.2, 0.7], [-1, 0.0, 1.0], [1, 0.0, 1.2]]]


## The two trap houses: white boxes with a dark mouth, low on each side of the range.
func _houses() -> void:
	var props: Node4D = d.get("props")
	if props == null:
		return
	for side in [-1.0, 1.0]:
		# As near as the birds that leave it (ahead() brings every distance in by NEARER).
		var z: float = Layout.STAND.z - HOUSE_DIST * NEARER
		Build.box(props, "Trap", Vector3(side * HOUSE_X, 0.6, z), Vector3(1.6, 1.2, 1.6), "range_counter", true)
		Build.box(props, "TrapMouth", Vector3(side * (HOUSE_X - 0.81), 0.75, z), Vector3(0.04, 0.5, 0.9), "range_screen", false)


## F: pull.
func action() -> void:
	if _pulls.is_empty() or not _waiting:
		return
	var pull: Array = _pulls.pop_front()
	_waiting = false
	for b in pull:
		_pending.append([float(b[2]), int(b[0]), float(b[1])])
	d.get("sfx").call("play", "wings", 1.0, -2.0)


func _launch(side: int, w_top: float) -> void:
	var start: Vector4 = ahead(float(side) * (HOUSE_X - 1.0), 1.3, HOUSE_DIST + randf_range(-0.5, 0.5), 0.0)
	# Across to the far side and up: it reaches the middle at the top of its arc.
	var vx: float = -float(side) * (HOUSE_X * 2.0 - 2.0) / FLIGHT
	var vy: float = -G * FLIGHT * 0.5 + randf_range(-0.4, 0.6)
	var vz: float = randf_range(-0.8, 0.8)
	var t: Node4D = d.spawn(CHICKEN, start)
	launched += 1
	t.set("path", func(_tt: Node4D, a: float) -> Vector4:
		var p: Vector4 = start + Vector4(vx * a, vy * a + 0.5 * G * a * a, vz * a, 0.0)
		# Through W: out to w_top at the top of the arc, back to the room's slice as it lands.
		p.w = w_top * sin(PI * clampf(a / FLIGHT, 0.0, 1.0))
		return p)
	_birds.append([t, ""])


func tick(_i: int, dt: float) -> String:
	for q in _pending:
		q[0] = float(q[0]) - dt
	while not _pending.is_empty() and float(_pending[0][0]) <= 0.0:
		var q: Array = _pending.pop_front()
		_launch(int(q[1]), float(q[2]))
	var flying: int = 0
	for b in _birds:
		if not String(b[1]).is_empty():
			continue
		var obj = b[0]
		if not is_instance_valid(obj):
			b[1] = "miss"
			continue
		var t: Node4D = obj
		if not bool(t.get("alive")):
			# Decided the moment it ends: shot down, or landed.
			b[1] = "miss" if bool(t.get("expired")) else "hit"
			if b[1] == "hit":
				hit_birds += 1
			continue
		if t.global_position.y < 0.15 and float(t.get("age")) > 0.5:
			t.call("leave")
			b[1] = "miss"
			continue
		flying += 1
	if flying == 0 and _pending.is_empty():
		_waiting = true
	return "done" if _pulls.is_empty() and _pending.is_empty() and flying == 0 else "run"


func progress(_i: int) -> Vector2:
	var hit: int = 0
	for b in _birds:
		if String(b[1]) == "hit":
			hit += 1
	return Vector2(hit, _birds.size() + _pending.size() + _count_left())


func _count_left() -> int:
	var n: int = 0
	for p in _pulls:
		n += (p as Array).size()
	return n


func keys() -> Array:
	return [["F", "Pull"]]


func extra_rows() -> Array:
	return [["Birds hit", "%d of %d" % [hit_birds, launched]]]
