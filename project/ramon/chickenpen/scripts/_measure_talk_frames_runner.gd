extends SceneTree

## Where the cinema's frame time goes, slide by slide: every frame's time and GPU time,
## labelled with the slide and the tenth of it that was on stage, the spikes listed with
## what had just happened, and a summary per tenth of a slide.
##
## WINDOWED, VSYNC OFF, NO FRAME CAP. The dummy renderer of --headless draws nothing and so
## costs nothing, and with vsync on every number is a multiple of the 60 Hz beat
## (follow_up/lofting_gotchas.md). Nothing is saved as a picture: a screenshot stalls the
## frame it is taken in.
##
## Args after --:
##   via=pen        go in through the pen's door the way a player does (default: the cinema
##                  on its own, which is quicker and isolates the room)
##   fast=<s>       the shared act length (default: the scene's own, 16 s, the real pace)
##   tag=<name>     names the output file (default "run")
##   until=<act>    stop once that act of part one has finished (0 to 5), for a short run
## Writes res://smoke_test_output/theatre_perf/frames_<tag>.tsv and prints the summary.

const OUT_DIR := "res://smoke_test_output/theatre_perf"
const ROMAN := ["I", "II", "III", "IV", "V", "VI"]
const ROMAN_TWO := ["VII", "VIII", "IX"]
## A frame this much slower than the median of its own tenth is a spike, if it is also past
## the floor: a hitch has to be both unusual and long to be one anybody sees.
const SPIKE_RATIO := 2.5
const SPIKE_FLOOR_MS := 25.0

var _via_pen := false
var _fast := -1.0
var _tag := "run"
var _until := 99

var _pen: Node
var _root: Node
var _show: Node
var _two: Node
var _seat: Node
var _player: CharacterBody4D
var _primer: Node

var _f := 0
var _stage := "load"
var _stage_t := 0.0
var _sat := false
var _last_us := 0
var _start_us := 0
var _label := ""
var _rows: Array = []
var _events: Array[String] = []
var _show_built := -1
var _two_built := -1
var _goat_baked := false
var _act_seen := -2
var _moment_seen := -2
var _skip_next := false


func _initialize() -> void:
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		if a == "via=pen":
			_via_pen = true
		elif a.begins_with("fast="):
			_fast = float(a.substr(5))
		elif a.begins_with("tag="):
			_tag = a.substr(4)
		elif a.begins_with("until="):
			_until = int(a.substr(6))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var t0: int = Time.get_ticks_usec()
	if _via_pen:
		_pen = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
		root.add_child(_pen)
		current_scene = _pen
		print("the pen took %.0f ms to build" % ((Time.get_ticks_usec() - t0) / 1000.0))
		_stage = "pen"
	else:
		_root = load("res://ramon/chickenpen/theatre/theatre.tscn").instantiate()
		root.add_child(_root)
		current_scene = _root
		print("the cinema took %.0f ms to instantiate and enter the tree" % ((Time.get_ticks_usec() - t0) / 1000.0))
		_stage = "found"


func _process(delta: float) -> bool:
	_f += 1
	_stage_t += delta
	var now: int = Time.get_ticks_usec()
	var dt_ms: float = (now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	match _stage:
		"pen":
			# Let the pen settle (its grass, its first draws) before the door, so what is
			# measured is the door and not the pen arriving.
			if _stage_t > 6.0:
				var crossing: Node = _pen.get_node_or_null("Crossing")
				if crossing == null:
					print("MEASURE FAIL: no Crossing in the pen")
					quit(1)
					return true
				var t0: int = Time.get_ticks_usec()
				crossing.call("go")
				print("the door (Crossing.go) took %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
				_root = crossing.get("_theatre")
				_events.append("door")
				_go("found")
			return false
		"found":
			if _root == null:
				print("MEASURE FAIL: no cinema")
				quit(1)
				return true
			_show = _root.get_node("Show")
			_two = _root.get_node("PartTwo")
			_seat = _root.get_node("UI/Seat")
			_player = _root.get_node("Player") as CharacterBody4D
			_primer = _show.get_node_or_null("Primer")
			if _fast > 0.0:
				_show.set("act_seconds", _fast)
				_two.set("moment_seconds", _fast * 1.1)
			_start_us = now
			_go("walk")
			return false

	if _start_us == 0:
		return false
	var t_s: float = (now - _start_us) / 1000000.0
	_watch_events()
	_label = _label_now()

	if _stage == "walk":
		# Walked to the middle of the aisle (by hand: physics off, so his keys cannot move it),
		# then sat down as soon as the chair offers itself.
		if _stage_t > 1.0 and _player.is_physics_processing():
			var stage4: Node4D = _root.get_node("Stage") as Node4D
			var top: Vector4 = stage4.get("aisle_to")
			var foot: Vector4 = stage4.get("aisle_from")
			_player.set_physics_process(false)
			_player.global_position = Vector4(0.0, lerpf(top.y, foot.y, 0.5) + 0.18,
				lerpf(top.z, foot.z, 0.5), 0.0)
		if not _sat and bool(_seat.call("is_offering")):
			_sat = true
			_seat.call("sit")
			_events.append("sat")
		if _sat:
			_go("talk")
		elif _stage_t > 60.0:
			print("MEASURE FAIL: the chair never offered itself in 60 s")
			quit(1)
			return true

	if not _skip_next and dt_ms > 0.0:
		var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		var cpu_draw: float = RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		_rows.append([_f, t_s, dt_ms, gpu, cpu_draw, _label,
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
			",".join(_events)])
	_skip_next = false
	_events.clear()

	if _stage == "talk":
		var act: int = int(_show.call("current_act"))
		if act > _until or bool(_show.call("is_over")) and _stage_t > 3.0 and not bool(_two.call("is_running")):
			_finish()
			return true
		if _stage_t > 600.0:
			print("MEASURE FAIL: the talk had not ended after 600 s")
			_finish()
			return true
	return false


func _go(stage: String) -> void:
	_stage = stage
	_stage_t = 0.0


## What is on stage: "arrive", "seated", a slide and its tenth ("I.3"), part two's ("VIII.6"),
## or "end".
func _label_now() -> String:
	if _two != null and bool(_two.call("is_running")):
		var m: int = int(_two.call("current_moment"))
		if m >= 0 and m < ROMAN_TWO.size():
			var span: float = float(_two.call("_length", m))
			var tenth: int = clampi(int(float(_two.get("_phase")) / maxf(span, 0.01) * 10.0), 0, 9)
			return "%s.%d" % [ROMAN_TWO[m], tenth]
		return "two-end"
	var act: int = int(_show.call("current_act"))
	if act >= 0 and act < ROMAN.size():
		var span1: float = float(_show.call("_length", act))
		var tenth1: int = clampi(int(float(_show.get("_phase")) / maxf(span1, 0.01) * 10.0), 0, 9)
		return "%s.%d" % [ROMAN[act], tenth1]
	if act >= ROMAN.size():
		return "end"
	return "seated" if _sat else "arrive"


## What just happened that could cost a frame: an exhibit built, a goat stage baked, a slide
## or moment begun. Written onto the frame that follows it.
func _watch_events() -> void:
	var sb: int = int(_show.get("_built"))
	if sb != _show_built:
		if _show_built >= 0:
			_events.append("built1:%d" % sb)
		_show_built = sb
	var tb: int = int(_two.get("_built"))
	if tb != _two_built:
		if _two_built >= 0:
			_events.append("built2:%d" % tb)
		_two_built = tb
	var goat: Node = _two.get("_goat") as Node
	if goat != null and not _goat_baked and goat.has_method("is_baked") and bool(goat.call("is_baked")):
		_goat_baked = true
		_events.append("goat-baked")
	var act: int = int(_show.call("current_act"))
	if act != _act_seen:
		_act_seen = act
		_events.append("act:%d" % act)
	if bool(_two.call("is_running")):
		var m: int = int(_two.call("current_moment"))
		if m != _moment_seen:
			_moment_seen = m
			_events.append("moment:%d" % m)


func _finish() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var path: String = "%s/frames_%s.tsv" % [OUT_DIR, _tag]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_line("frame\tt_s\tdt_ms\tgpu_ms\tcpu_draw_ms\tlabel\tobjects\tdraws\tprims\tevents")
	for r in _rows:
		file.store_line("%d\t%.3f\t%.2f\t%.2f\t%.2f\t%s\t%d\t%d\t%d\t%s" % r)
	file.close()
	print("\n%d frames written to %s" % [_rows.size(), path])

	# Per label, in the order they came.
	var order: Array[String] = []
	var by: Dictionary = {}
	for r in _rows:
		var label: String = r[5]
		if not by.has(label):
			by[label] = []
			order.append(label)
		by[label].append(r)
	print("\nlabel     frames   median   p95     worst   gpu-med  gpu-worst  objects  draws")
	var medians: Dictionary = {}
	for label in order:
		var dts: Array = []
		var gpus: Array = []
		var objects := 0
		var draws := 0
		for r in by[label]:
			dts.append(r[2])
			gpus.append(r[3])
			objects = maxi(objects, r[6])
			draws = maxi(draws, r[7])
		dts.sort()
		gpus.sort()
		var med: float = dts[dts.size() / 2]
		medians[label] = med
		print("%-8s %6d %8.2f %7.2f %8.1f %8.2f %9.1f %8d %6d" % [label, dts.size(), med,
			dts[mini(dts.size() - 1, int(dts.size() * 0.95))], dts[-1], gpus[gpus.size() / 2], gpus[-1],
			objects, draws])
	print("\nspikes (over %.1fx their tenth's median and over %.0f ms):" % [SPIKE_RATIO, SPIKE_FLOOR_MS])
	var spikes := 0
	for r in _rows:
		var med2: float = medians[r[5]]
		if r[2] > SPIKE_FLOOR_MS and r[2] > med2 * SPIKE_RATIO:
			spikes += 1
			print("  frame %6d  t %7.2f s  %7.1f ms (gpu %5.1f)  %-8s %s" % [r[0], r[1], r[2], r[3], r[5], r[9]])
	print("%d spikes" % spikes)
	print("video memory at the end %.0f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	quit()
