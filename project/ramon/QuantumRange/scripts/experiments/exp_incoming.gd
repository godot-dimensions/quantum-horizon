extends "res://ramon/QuantumRange/scripts/range_experiment.gd"

## 04 INCOMING: drones fly in along painted lanes towards the firing line; hit them before they cross it.
## A drone that crosses costs a point; in strict mode (T) it stops the round, and R starts the stage
## again. The way of playing: REACTING UNDER PRESSURE, with W as the twist: some lanes begin in another
## slice, and the drone fades into yours on its way in.
##
##   A  lanes            three lanes in your slice, one slow drone at a time
##   B  from another     drones that start 2.5 m ana or kata and come into your slice halfway down
##      slice            (the radar shows which lane)
##   C  mixed            red drones, an amber heavy (charge it) and green friendlies (let them through:
##                       shooting one is a penalty)
##   D  hold the line    a faster, closer-spaced wave of all three
##
## The lanes are painted into the floor as cyan chevrons (cyan: anything about W, and the way things
## come at you).

const DRONE := "res://ramon/QuantumRange/scripts/targets/target_drone.gd"
const Build := preload("res://ramon/QuantumRange/carried/scripts/chamber_build.gd")
const LabGrid := preload("res://ramon/QuantumRange/carried/LabKit/lab_grid.gd")
const Style := preload("res://ramon/QuantumRange/scripts/range_style.gd")

const LANES := [-4.5, 0.0, 4.5]
const FAR := 32.0
## Where a drone counts as having crossed the line: this many metres short of the counter.
const NEAR := 3.0

var crossed: int = 0
var _crossed_stage: int = 0
var _queue: Array = []
var _drones: Array = []
var _t: float = 0.0
var _total: int = 0
var _fail: String = ""


func _init() -> void:
	id = "incoming"
	number = 4
	title = "Incoming"
	short = "Incoming"
	tagline = "Hold the line."
	headline = "Things that move through W\narrive from nowhere."
	explain = "A drone that starts in another slice is invisible until it reaches yours; the radar sees it coming. Crossings are counted against you."
	w_load = "MEDIUM"
	glyph = "incoming"
	has_strict = true
	stages = [
		{"title": "Lanes", "line": "Hit each drone before it crosses\nthe line. T turns on strict mode.", "par": 22.0},
		{"title": "From another slice", "line": "These start in other slices and come\ninto yours. Watch the radar.", "par": 22.0},
		{"title": "Mixed", "line": "Amber: charge it. Green is friendly:\nlet it through.", "par": 26.0},
		{"title": "Hold the line", "line": "Faster, closer together.\nAll three kinds.", "par": 26.0},
	]


func begin(i: int) -> void:
	if i == 0:
		crossed = 0
		_lanes()
	_crossed_stage = 0
	_drones = []
	_t = 0.0
	_fail = ""
	# [seconds in, lane, kind, speed m/s, start w]
	match i:
		0:
			_queue = [[0.5, 1, "red", 3.0, 0.0], [5.5, 0, "red", 3.0, 0.0], [10.0, 2, "red", 3.0, 0.0], [14.0, 1, "red", 3.4, 0.0], [17.5, 0, "red", 3.4, 0.0]]
		1:
			_queue = [[0.5, 2, "red", 3.0, 2.5], [5.0, 0, "red", 3.0, -2.5], [9.0, 1, "red", 3.2, 2.5], [12.5, 2, "red", 3.2, -2.5], [16.0, 0, "red", 3.4, 2.5]]
		2:
			_queue = [[0.5, 1, "red", 3.2, 0.0], [3.0, 0, "friendly", 3.0, 0.0], [5.0, 2, "heavy", 2.4, 0.0], [8.0, 1, "red", 3.4, 2.0],
				[10.5, 0, "heavy", 2.4, 0.0], [12.0, 2, "friendly", 3.0, 0.0], [14.0, 1, "red", 3.6, -2.0]]
		3:
			_queue = [[0.3, 0, "red", 4.4, 0.0], [1.5, 2, "red", 4.4, 2.0], [2.7, 1, "friendly", 4.0, 0.0], [3.9, 0, "heavy", 3.0, 0.0],
				[5.1, 2, "red", 4.6, -2.0], [6.3, 1, "red", 4.6, 0.0], [7.5, 0, "friendly", 4.2, 2.0], [8.7, 2, "heavy", 3.2, 0.0], [9.9, 1, "red", 4.8, 0.0]]
	_total = _queue.size()


## The three lanes painted into the floor: long strips of chevrons running in towards you.
func _lanes() -> void:
	var props: Node4D = d.get("props")
	if props == null:
		return
	for x in LANES:
		var len: float = FAR - NEAR
		var mid_z: float = Layout.STAND.z - (FAR + NEAR) * 0.5
		var strip: MeshInstance4D = Build.box(props, "Lane", Vector3(x, 0.006, mid_z), Vector3(1.1, 0.012, len), "range_lane", false)
		LabGrid.set_chevrons(strip.material_override as TetraMaterial4D, 1.0, Style.glow("w"), 1.6, 1.6, 0.0, Vector2(0.0, 1.0))


func tick(_i: int, dt: float) -> String:
	_t += dt
	while not _queue.is_empty() and _t >= float(_queue[0][0]):
		var q: Array = _queue.pop_front()
		_launch(int(q[1]), String(q[2]), float(q[3]), float(q[4]))
	var live: int = 0
	for e in _drones:
		# Untyped first: a drone that was shot down is freed, and a typed variable will not take it.
		var obj = e[0]
		if not is_instance_valid(obj) or not bool(obj.get("alive")):
			continue
		var t: Node4D = obj
		if t.global_position.z >= Layout.STAND.z - NEAR:
			# Across the line: a friendly is fine, anything else counts.
			if String(t.get("family")) != "drone_friendly":
				crossed += 1
				_crossed_stage += 1
				d.get("hud").call("toast", "CROSSED THE LINE", Color(1.0, 0.45, 0.4), 1.4)
				if bool(d.get("strict")):
					_fail = "A drone crossed the line"
					t.call("leave")
					return "fail"
			t.call("leave")
			continue
		live += 1
	return "done" if _queue.is_empty() and live == 0 else "run"


func _launch(lane: int, kind: String, speed: float, w0: float) -> void:
	var x: float = LANES[lane]
	var from: Vector4 = ahead(x, 2.0, FAR, w0)
	var to: Vector4 = ahead(x, 1.6, NEAR - 0.5, 0.0)
	var len: float = from.distance_to(to)
	var t: Node4D = d.spawn(DRONE, from, {"kind": kind})
	# Straight in along its lane; one that starts in another slice reaches yours halfway down.
	t.set("path", func(_tt: Node4D, age: float) -> Vector4:
		var k: float = minf(age * speed / len, 1.2)
		var p: Vector4 = from.lerp(to, k)
		p.w = w0 * maxf(0.0, 1.0 - k * 2.0)
		p.y += sin(age * 2.0) * 0.12
		return p)
	_drones.append([t])


func fail_reason() -> String:
	return _fail


func progress(_i: int) -> Vector2:
	var resolved: int = 0
	for e in _drones:
		if not is_instance_valid(e[0]) or not bool((e[0] as Node).get("alive")):
			resolved += 1
	return Vector2(resolved, _total)


func keys() -> Array:
	return [["T", "Strict mode"]]


func extra_rows() -> Array:
	return [["Crossed the line", str(crossed)]]
