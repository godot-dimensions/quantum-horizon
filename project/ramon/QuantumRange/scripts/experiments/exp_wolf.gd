extends "res://ramon/QuantumRange/scripts/range_experiment.gd"

## 06 WOLF RUN (Ramon, 6 Oct: "I like it"): holodeck wolves running the range; tag the one with the red
## collar. The way of playing: TRACKING AND INTERCEPTING a runner that turns, leaps and leaves your slice,
## the one thing the other five do not ask (Incoming comes straight at you; skeet flies an arc you can
## read). The pen's wolf is known for running out of the slice; here that is the game.
##
##   A  on the run         one wolf at a time, curving across the range in your slice: lead it
##   B  out of the slice   their runs swing out through W, past the two metres you can step, and back in,
##                         and leap the bars on the way: meet them where they come back, or turn after them
##   C  the pack           three run together and cross over; only the red collar counts, a green one is
##                         a penalty
##   D  the chase          a wolf after a chicken: tag it before it catches the bird. A caught chicken is
##                         carried off (counted); hitting the chicken is a penalty
##
## A wolf you do not tag runs its route again, so a stage ends when every red collar is tagged. Every
## wolf is the pen's, in rigid pieces (range_wolf.gd, targets/target_wolf.gd).

const WOLF := "res://ramon/QuantumRange/scripts/targets/target_wolf.gd"
const CHICKEN := "res://ramon/QuantumRange/scripts/targets/target_chicken.gd"
const Build := preload("res://ramon/QuantumRange/carried/scripts/chamber_build.gd")

## The chicken's size here: a real bird beside the wolf (the skeet's is a big comic one).
const BIRD_SIZE := 0.38

var tagged: int = 0
var chickens_caught: int = 0
var chickens_saved: int = 0
var _queue: Array = []        # [[seconds after the last was dealt with, spawner Callable], ...]
var _live: Array = []         # wolves (and chickens) under way, untyped (they are freed)
var _wait: float = 0.0
var _total: int = 0
var _done: int = 0
var _tagged_stage: int = 0
var _chase: Array = []        # [[wolf, chicken, resolved], ...]


func _init() -> void:
	id = "wolf"
	number = 6
	title = "Wolf Run"
	short = "Wolf"
	tagline = "Keep it in your sights."
	headline = "A runner through W is only\nsometimes in your slice."
	explain = "A wolf's run turns, leaps and swings out through W. Track it, meet it where it comes back, tag the red collar."
	w_load = "HIGH"
	glyph = "wolf"
	stages = [
		{"title": "On the run", "line": "Tag the red collar. It turns:\nlead it.", "par": 24.0},
		{"title": "Out of the slice", "line": "Their runs swing out through W\nand leap the bars. Watch the radar.", "par": 34.0},
		{"title": "The pack", "line": "Only the red collar. A green one\nis a penalty.", "par": 30.0},
		{"title": "The chase", "line": "Tag the wolf before it catches\nthe chicken. Don't hit the bird.", "par": 30.0},
	]


## A point on the floor downrange (y 0), `x` across, `dist` out, `w` through W.
func floor_at(x: float, dist: float, w: float = 0.0) -> Vector4:
	var p: Vector4 = ahead(x, 0.0, dist, w)
	p.y = 0.0
	return p


func begin(i: int) -> void:
	if i == 0:
		tagged = 0
		chickens_caught = 0
		chickens_saved = 0
	_live = []
	_chase = []
	_wait = 0.0
	_done = 0
	_tagged_stage = 0
	match i:
		0:
			_queue = [[0.6, _run_a.bind(1.0, 10.0)], [1.0, _run_a.bind(-1.0, 13.0)], [1.0, _run_a.bind(1.0, 16.0)]]
		1:
			_bars()
			_queue = [[0.6, _run_b.bind(1.0, 3.0)], [1.0, _run_b.bind(-1.0, -3.2)], [1.0, _run_b.bind(1.0, -3.0)]]
		2:
			_queue = [[0.6, _pack.bind(1.0, 0)], [1.2, _pack.bind(-1.0, 1)]]
		3:
			_queue = [[0.6, _chase_one.bind(1.0, 11.0)], [1.4, _chase_one.bind(-1.0, 14.0)], [1.4, _chase_one.bind(1.0, 12.0)]]
	_total = _queue.size() if i != 2 else 2


## Two holodeck bars across the floor, for B's leaps (white, like the counter: furniture of the room).
func _bars() -> void:
	var props: Node4D = d.get("props")
	if props == null:
		return
	for x in [-4.0, 4.0]:
		var z: float = floor_at(0.0, 13.0).z
		Build.box(props, "Bar", Vector3(x, 0.8, z), Vector3(0.12, 0.1, 6.0), "range_top", false)
		for dz in [-3.0, 3.0]:
			Build.box(props, "BarPost", Vector3(x, 0.4, z + dz), Vector3(0.1, 0.8, 0.1), "range_top", false)


## A: across the range and back on a curve, `side` the way it starts, `dist` metres out.
func _run_a(side: float, dist: float) -> void:
	var r: Array = [{"run": floor_at(-3.0 * side, dist - 2.5), "speed": 6.2}, {"run": floor_at(3.5 * side, dist + 1.5), "speed": 6.2},
		{"run": floor_at(9.0 * side, dist), "speed": 6.2}, {"run": floor_at(4.0 * side, dist + 4.0), "speed": 6.2},
		{"run": floor_at(-3.5 * side, dist + 2.0), "speed": 6.2}, {"run": floor_at(-9.0 * side, dist), "speed": 6.2}]
	_wolf(floor_at(-9.5 * side, dist), r)


## B: across, out through W to `w_out` (beyond your two metres), back in, over both bars.
func _run_b(side: float, w_out: float) -> void:
	var z: float = 13.0
	var r: Array = [
		{"run": floor_at(-6.6 * side, z), "speed": 6.4},
		{"leap": floor_at(-1.6 * side, z), "height": 1.0},
		{"run": floor_at(1.6 * side, z, w_out), "speed": 6.4},
		{"leap": floor_at(6.6 * side, z, 0.0), "height": 1.0},
		{"run": floor_at(9.5 * side, z - 2.0), "speed": 6.0},
		# The far leg, out through W past your two metres: meet it as it comes back, or turn after it.
		{"run": floor_at(8.5 * side, z + 5.0, w_out), "speed": 6.0},
		{"run": floor_at(-8.5 * side, z + 5.0, w_out), "speed": 6.0},
		{"run": floor_at(-9.5 * side, z - 2.0), "speed": 6.0},
	]
	_wolf(floor_at(-10.0 * side, z), r)


## C: three abreast, crossing over as they run; the red one in place `red_at` (0 left, 1 middle).
func _pack(side: float, red_at: int) -> void:
	var dist: float = 12.0
	for k in 3:
		var lane: float = float(k - 1) * 2.0
		var cross: float = -lane
		var r: Array = [{"run": floor_at(-4.0 * side, dist + lane), "speed": 6.0}, {"run": floor_at(1.0 * side, dist + cross), "speed": 6.0},
			{"run": floor_at(9.0 * side, dist + lane * 0.5), "speed": 6.0}, {"run": floor_at(3.0 * side, dist + 5.0 + cross), "speed": 6.0},
			{"run": floor_at(-3.0 * side, dist + 5.0 + lane), "speed": 6.0}, {"run": floor_at(-9.0 * side, dist + lane * 0.5), "speed": 6.0}]
		_wolf(floor_at(-10.0 * side, dist + lane), r, "red" if k == red_at else "green", 0.12 * float(k))


## D: a chicken legging it across, a wolf after it.
func _chase_one(side: float, dist: float) -> void:
	var start: Vector4 = floor_at(-5.0 * side, dist)
	start.y = 1.05 * BIRD_SIZE
	var bird: Node4D = d.spawn(CHICKEN, start, {"size": BIRD_SIZE, "friendly": true, "running": true, "lifetime": 9.0})
	bird.set("path", func(_t: Node4D, a: float) -> Vector4:
		return start + Vector4(3.1 * side * a, 0.0, 1.1 * sin(a * 2.2), 0.0))
	var exit: Vector4 = floor_at(-10.0 * side, dist + 8.0)
	var wolf: Node4D = _wolf(floor_at(-10.5 * side, dist + 1.0), [{"pounce": bird}, {"run": exit, "speed": 6.5}], "red", 0.0, false)
	_chase.append([wolf, bird, false])


## A wolf on `route`; untagged, it runs it again (`loop`). A red one counts when it is tagged.
func _wolf(at: Vector4, route: Array, collar: String = "red", delay: float = 0.0, again: bool = true) -> Node4D:
	var w: Node4D = d.spawn(WOLF, at, {"route": route, "collar": collar, "loop": again, "delay": delay})
	if collar == "red":
		w.connect("destroyed", func(_t: Node4D) -> void:
			tagged += 1
			_tagged_stage += 1)
	_live.append(w)
	return w


func tick(i: int, dt: float) -> String:
	# The next one comes when the last is dealt with (or straight away, the first).
	var reds: int = 0
	for obj in _live:
		if is_instance_valid(obj) and bool(obj.get("alive")) and String(obj.get("collar")) == "red":
			reds += 1
	if i == 3:
		for c in _chase:
			if bool(c[2]):
				continue
			# Untyped: a wolf that is dealt with is freed.
			var w = c[0]
			var b = c[1]
			if is_instance_valid(w) and bool(w.get("caught")):
				chickens_caught += 1
				c[2] = true
				_done += 1
				d.get("hud").call("toast", "THE WOLF GOT THE CHICKEN", Color(1.0, 0.45, 0.4), 1.4)
			elif not is_instance_valid(w) or not bool(w.get("alive")):
				# Tagged in time, or it never got there: the bird is saved, and runs on and away.
				chickens_saved += 1
				if is_instance_valid(b) and bool(b.get("alive")):
					b.set("lifetime", float(b.get("age")) + 2.5)
				c[2] = true
				_done += 1
		reds = 0
		for c in _chase:
			if not bool(c[2]):
				reds += 1
	if reds == 0 and not _queue.is_empty():
		_wait += dt
		if _wait >= float(_queue[0][0]):
			_wait = 0.0
			var q: Array = _queue.pop_front()
			(q[1] as Callable).call()
			# Just sent one: the stage goes on (the count above was taken before it came).
			return "run"
	# Wolves of a dealt-with pack go: the greens leave once their red is tagged.
	if i == 2 and reds == 0:
		for obj in _live:
			if is_instance_valid(obj) and bool(obj.get("alive")) and String(obj.get("collar")) == "green":
				obj.call("leave")
	return "done" if _queue.is_empty() and reds == 0 else "run"


func progress(i: int) -> Vector2:
	if i == 3:
		return Vector2(_done, 3)
	return Vector2(mini(_tagged_stage, _total), _total)


func extra_rows() -> Array:
	return [["Chickens saved", "%d of %d" % [chickens_saved, chickens_saved + chickens_caught]]]
