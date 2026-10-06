extends SceneTree
## Crosswise: what it costs (PLAN.md step 72). Vsync off and no frame cap (lofting_gotchas.md:
## vsync makes every timing meaningless), frames timed between process frames with
## Time.get_ticks_usec (follow_up/engine_capabilities.md: Performance.TIME_PROCESS is the worst
## frame of the last second, not this frame), the GPU's own render time beside it.
##
## For each island: the walker on its arrival ring, 1 s to settle, then 3 s of frames: mean, 95th
## percentile and worst. Then a turn into W and back (the frames during it), and a strike on island
## 3's first rock (the frame of the carve and the next). Also the scene's load time.
##
## Run: Crosswise/run.sh windowed perf res://ramon/Crosswise/scripts/_perf_runner.gd

const SCENE := "res://ramon/Crosswise/crosswise.tscn"

var _game: Node
var _walker: CharacterBody4D
var _cam: Node
var _total: float = 0.0
var _t: float = 0.0
var _step: int = 0
var _island: int = 0
var _last_us: int = 0
var _samples: Array = []
var _gpu: Array = []
var _load_start: int = 0
var _strike_at: int = -1


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_load_start = Time.get_ticks_usec()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_game = (load(SCENE) as PackedScene).instantiate()
	_game.set("play_intro", false)
	root.add_child.call_deferred(_game)


func _stats(label: String, values: Array) -> void:
	if values.is_empty():
		print("PERF %s: no samples" % label)
		return
	var v: Array = values.duplicate()
	v.sort()
	var mean: float = 0.0
	for x in v:
		mean += float(x)
	mean /= float(v.size())
	var p95: float = float(v[mini(v.size() - 1, int(v.size() * 0.95))])
	print("PERF %s: mean %.2f ms, 95th %.2f ms, worst %.2f ms (%d frames)" % [label, mean, p95, float(v[v.size() - 1]), v.size()])


func _process(delta: float) -> bool:
	_total += delta
	if _total > 120.0:
		print("PERF FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _game == null or not _game.is_inside_tree():
		return false
	var now: int = Time.get_ticks_usec()
	var frame_ms: float = float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if _walker == null:
		_walker = _game.get("walker")
		_cam = _game.get("camera")
		_walker.set("input_enabled", false)
		print("PERF scene ready in %.0f ms" % (float(now - _load_start) / 1000.0))
		_t = 0.0
		return false
	_t += delta
	match _step:
		0:
			# Place on the next island and settle.
			var info: Dictionary = (_game.call("islands") as Array)[_island]
			_walker.call("place_at", info["spawn"], PI)
			_cam.call("snap_focus")
			_samples.clear()
			_gpu.clear()
			_step = 1
			_t = 0.0
		1:
			if _t > 1.0:
				_step = 2
				_t = 0.0
				_samples.clear()
		2:
			_samples.append(frame_ms)
			_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			if _t > 3.0:
				_stats("island %d" % (_island + 1), _samples)
				_stats("island %d GPU" % (_island + 1), _gpu)
				_island += 1
				_step = 0 if _island < 4 else 3
				_t = 0.0
		3:
			# A turn into W and back, on island 1.
			var info1: Dictionary = (_game.call("islands") as Array)[0]
			_walker.call("place_at", info1["spawn"], PI)
			_cam.call("snap_focus")
			_samples.clear()
			_step = 4
			_t = 0.0
		4:
			if _t > 1.0:
				_cam.call("request_turn")
				_samples.clear()
				_step = 5
				_t = 0.0
		5:
			_samples.append(frame_ms)
			if _t > 0.7:
				_stats("frames during a turn into W", _samples)
				_cam.call("request_turn")
				_step = 6
				_t = 0.0
		6:
			if _t > 1.0:
				# A strike: island 3's first rock.
				_walker.call("place_at", Vector4(0, 1.4, -35.95, 0), PI)
				_cam.call("snap_focus")
				_step = 7
				_t = 0.0
		7:
			if _t > 1.2:
				var rock: Node = (_game.call("plugs") as Array)[0]
				var start: int = Time.get_ticks_usec()
				rock.call("strike", _walker.global_position + Vector4(0, 0.8, 0, 0), _cam.call("slice_rotation"))
				print("PERF strike 1 call: %.2f ms" % (float(Time.get_ticks_usec() - start) / 1000.0))
				_samples.clear()
				_step = 8
				_t = 0.0
		8:
			_samples.append(frame_ms)
			if _samples.size() >= 6:
				print("PERF frames after strike 1: %s" % str(_samples.map(func(x: float) -> String: return "%.2f" % x)))
				var rock2: Node = (_game.call("plugs") as Array)[0]
				rock2.call("strike", _walker.global_position + Vector4(0, 0.8, 0, 0), _cam.call("slice_rotation"))
				_samples.clear()
				_step = 9
		9:
			_samples.append(frame_ms)
			if _samples.size() >= 6:
				print("PERF frames after strike 2 (the shatter): %s" % str(_samples.map(func(x: float) -> String: return "%.2f" % x)))
				# The parts on their own: a carve with no chips (the second rock), then chips alone.
				var rock3: Node = (_game.call("plugs") as Array)[1]
				var edit = ClassDB.instantiate("SphereVoxelEdit4D")
				edit.set("center", Vector4(0, 0, 0, 0))
				edit.set("radius", 3.0)
				edit.set("fill_material", 254)
				var world = rock3.get("_world")
				if world != null:
					world.call("apply_edit", edit)
				_samples.clear()
				_step = 10
		10:
			_samples.append(frame_ms)
			if _samples.size() >= 6:
				print("PERF frames after a carve alone: %s" % str(_samples.map(func(x: float) -> String: return "%.2f" % x)))
				var Fx = load("res://ramon/Crosswise/world/mk_fx_4d.gd")
				Fx.chips(_game, _walker.global_position + Vector4(0, 1, -1, 0), Color(0.55, 0.52, 0.66), _cam.call("slice_rotation"), 9, 0.11, 3.0)
				_samples.clear()
				_step = 11
		11:
			_samples.append(frame_ms)
			if _samples.size() >= 6:
				print("PERF frames after chips alone: %s" % str(_samples.map(func(x: float) -> String: return "%.2f" % x)))
				var Fx2 = load("res://ramon/Crosswise/world/mk_fx_4d.gd")
				Fx2.chips(_game, _walker.global_position + Vector4(0, 1, -1, 0), Color(0.55, 0.52, 0.66), _cam.call("slice_rotation"), 9, 0.11, 3.0)
				_samples.clear()
				_step = 12
		12:
			_samples.append(frame_ms)
			if _samples.size() >= 6:
				print("PERF frames after chips again: %s" % str(_samples.map(func(x: float) -> String: return "%.2f" % x)))
				print("PERF done")
				return true
	return false
