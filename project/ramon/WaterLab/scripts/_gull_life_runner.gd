extends "res://ramon/WaterLab/scripts/_wl_shots.gd"

## WATER LAB: the gull test bed (gull/gull_test.tscn) live: the bed wide, then one gull followed
## through a landing (approach, flare, down on the rail, looking round, the take-off), frames at each
## change of state and a few beats after; the plinth gull close in each pose; then the script time of
## 6 and of 30 gulls. Frames in smoke_test_output/water_lab/gull_life/.

const BED := "res://ramon/WaterLab/gull/gull_test.tscn"

var _bed: Node4D
var _cam: Camera4D
var _harbour: Node4D
var _track: Node4D = null
var _last_state: String = ""
var _pending: Array = []
var _n: int = 0
var _side := Vector4(-0.9, 0.35, 1.9, 0.0)
var _proc: Array = []
var _proc_name: String = ""


func setup() -> void:
	out = "res://smoke_test_output/water_lab/gull_life/"
	tag = "GULLS"
	deadline_ms = 240000
	_bed = (load(BED) as PackedScene).instantiate()
	root.add_child(_bed)
	current_scene = _bed
	step(30, _ready_bed)
	step(90, nop, "00_bed_wide")
	step(1, _wide.bind(Vector4(6.0, 3.2, 9.0, 0.0), Vector4(0.0, 2.0, 0.0, 0.0)))
	step(3, nop, "00_bed_rails")
	step(1, _start_landing)
	# The landing plays out under the tracking in _process; this waits for it.
	step(1500, nop)
	step(1, _stop_tracking)
	for pose in ["glide", "flap", "flare", "folded"]:
		step(1, _plinth.bind(pose))
		step(20, nop, "%s_plinth_%s" % ["50" if pose == "glide" else "5%d" % ["glide", "flap", "flare", "folded"].find(pose), pose])
	step(1, _wide.bind(Vector4(0.0, 9.0, 18.0, 0.0), Vector4(0.0, 3.0, 0.0, 0.0)))
	step(1, _measure.bind("6 gulls"))
	step(240, nop)
	step(1, _measured)
	step(1, _count.bind(30))
	step(60, nop)
	step(1, _measure.bind("30 gulls"))
	step(240, nop, "60_thirty_gulls")
	step(1, _measured)


func _ready_bed() -> void:
	_cam = _bed.get("cam")
	_harbour = _bed.get("harbour")
	# The bed's own camera control off: this runner aims it.
	_bed.set_process(false)
	_bed.set_process_unhandled_input(false)
	_wide(Vector4(-9.0, 6.0, 13.0, 0.0), Vector4(0.0, 2.0, 0.0, 0.0))


func _wide(eye: Vector4, look: Vector4) -> void:
	aim(_cam, eye, look)


## Gull 0 sent in to land on the free rail perch nearest the middle of the camera's side, from 16 m
## downwind; it sits 4 s and leaves.
func _start_landing() -> void:
	var gulls: Array = _harbour.get("gulls")
	var g: Node4D = gulls[0]
	_harbour.call("release", g)
	var best: Dictionary = {}
	for pr in _harbour.get("perches"):
		if pr["taken"] == null and (pr["pos"] as Vector4).z > 0.0:
			if best.is_empty() or absf((pr["pos"] as Vector4).x) < absf((best["pos"] as Vector4).x):
				best = pr
	best["taken"] = g
	best["stay_min"] = 4.0
	best["stay_max"] = 4.0
	var at: Vector4 = best["pos"]
	g.set("perch", best)
	g.set("p", at + Vector4(-17.0, 4.5, 3.0, 0.0))
	g.set("forward", Vector4(1.0, 0.0, 0.0, 0.0))
	g.set("speed", 8.0)
	g.set("_fold", 0.0)
	g.set("_final", false)
	g.set("_state_t", 0.0)
	g.set("state", "approach")
	_track = g
	_last_state = ""
	print("GULLS landing on ", at)


func _stop_tracking() -> void:
	print("GULLS tracked gull ended in state ", _track.get("state") if _track != null else "-")
	_track = null


func _plinth(pose: String) -> void:
	var m: Node4D = _bed.get("model")
	m.set("forced", pose)
	var at: Vector4 = m.global_position
	aim(_cam, at + Vector4(0.75, 0.3, 0.85, 0.0), at)


## Script time per frame (the process monitor; frame times are vsync's in a window).
func _measure(nm: String) -> void:
	_proc = []
	_proc_name = nm


func _measured() -> void:
	var s: Array = _proc.duplicate()
	s.sort()
	if s.is_empty():
		return
	print("GULLS PERF %s: %d frames, process median %.2f ms, 95th %.2f ms" % [_proc_name, s.size(), s[s.size() / 2], s[mini(int(s.size() * 0.95), s.size() - 1)]])
	_proc_name = ""


func _count(n: int) -> void:
	_harbour.call("set_count", n)


func _process(d: float) -> bool:
	if not _proc_name.is_empty():
		_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	if _track != null and is_instance_valid(_track):
		var at: Vector4 = _track.global_position
		aim(_cam, at + _side, at)
		var s: String = String(_track.get("state"))
		if s != _last_state:
			_last_state = s
			var now: int = Time.get_ticks_msec()
			var beats: Array = {"approach": [0, 1500, 3000, 4500], "flare": [0, 250, 600], "perched": [100, 1500, 3000], "takeoff": [80, 350, 800, 1500], "roam": [300]}.get(s, [])
			for b in beats:
				_pending.append([now + int(b), s])
		var t: int = Time.get_ticks_msec()
		for p in _pending.duplicate():
			if t >= int(p[0]):
				_pending.erase(p)
				_n += 1
				var nm: String = "%02d_%s_%d" % [_n, String(p[1]), int(p[0]) % 100000]
				root.get_texture().get_image().save_png(out + nm + ".png")
				print("GULLS shot ", nm, "  y %.2f  speed %.1f" % [_track.global_position.y, float(_track.get("speed"))])
	return super(d)
