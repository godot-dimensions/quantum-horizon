extends SceneTree
## Voxel Lab, plan steps 31 and 74: what the room costs. Vsync off; the player stood at each station in
## turn for a few seconds, the frame times kept (median, 95th, worst), with the GPU's own time per
## frame; then every specimen's chunk meshes, tetrahedra and memory, and the room's total. Then ten cuts
## at the bench with the swap and ten without, their worst frames.
##   VoxelLab/run.sh windowed perf res://ramon/VoxelLab/scripts/_perf_room_runner.gd

const Cutter := preload("res://ramon/VoxelLab/specimen/vl_cutter.gd")
const Specimen := preload("res://ramon/VoxelLab/specimen/vl_specimen_4d.gd")

const SPOTS := [["entrance", Vector4(0, 0.05, 21, 0), 0.0], ["shelf", Vector4(6.2, 0.05, 5.4, 0), deg_to_rad(-90.0)],
	["block", Vector4(0, 0.05, 3.0, 0), 0.0], ["column", Vector4(-5.1, 0.05, -5.0, 0), deg_to_rad(90.0)],
	["gallery", Vector4(0, 0.05, -17.0, 0), 0.0], ["terrain", Vector4(0, 0.05, -23.5, 0), deg_to_rad(90.0)],
	["ladder", Vector4(4.4, 0.05, -23.5, 0), deg_to_rad(-90.0)]]

var _scene: Node
var _t: float = 0.0
var _total: float = 0.0
var _i: int = -1
var _frames: Array = []
var _gpu: Array = []
var _last_us: int = 0
var _phase: String = "wait"
var _cuts_left: int = 0
var _bench: Node


func _initialize() -> void:
	root.unfocusable = true
	Specimen.debug_spikes = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _ready_all() -> bool:
	for s in _scene.get("stations"):
		var ex: Node = s.get("exhibit")
		if ex == null or not bool(ex.call("is_ready")):
			return false
	return true


func _process(delta: float) -> bool:
	_total += delta
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if _total > 300.0:
		print("PERF FAIL: timed out in %s" % _phase)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree() or _scene.get("player") == null:
		return false
	_scene.get("player").set("input_enabled", false)
	_t += delta
	match _phase:
		"wait":
			if _ready_all() and _t > 3.0 and not bool(current_scene.get("loading")):
				print("PERF room ready after %.1f s" % _total)
				_report_memory()
				_phase = "spots"
				_next_spot()
			elif _t > 120.0:
				print("PERF FAIL: the room's specimens never all got ready")
				return true
		"spots":
			if _t > 1.5:
				_frames.append(ms)
				_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			if _t > 5.5:
				_print_spot(String(SPOTS[_i][0]))
				_next_spot()
		"bench":
			if _t > 0.8:
				_bench = _scene.get_node("HeroBench")
				_scene.call("sit", _bench)
				_phase = "cuts"
				_cuts_left = 20
				_t = 0.0
		"cuts":
			if _t > 0.6 and _cuts_left > 0:
				_t = 0.0
				var sp: Node = _bench.call("specimen")
				sp.set("swap", _cuts_left > 10)
				_bench.set("tool", ["ball", "block", "drill"][_cuts_left % 3])
				_bench.set("size_index", 1 + _cuts_left % 2)
				var h: Dictionary = _bench.call("aim_at_screen", Vector2(520 + (_cuts_left * 23) % 240, 270 + (_cuts_left * 37) % 140))
				if not h.is_empty():
					_bench.call("cut_here")
				_cuts_left -= 1
			elif _cuts_left <= 0 and _t > 2.0:
				var recs: Array = _bench.get("records")
				for swap in [true, false]:
					var worst: Array = []
					var lat: Array = []
					for r in recs:
						if bool(r.get("swap", true)) == swap:
							worst.append(float(r["worst_ms"]))
							lat.append(float(r["latency_ms"]))
					worst.sort()
					lat.sort()
					if not worst.is_empty():
						print("PERF cuts %-7s %2d: worst frame median %.1f ms, worst %.1f ms; on screen after median %.0f ms, slowest %.0f ms" % [
							"swap" if swap else "engine", worst.size(), float(worst[worst.size() / 2]), float(worst[-1]), float(lat[lat.size() / 2]), float(lat[-1])])
				print("PERF done")
				return true
	return false


func _next_spot() -> void:
	_i += 1
	_frames = []
	_gpu = []
	_t = 0.0
	if _i >= SPOTS.size():
		_phase = "bench"
		_scene.call("go_to", Vector4(0, 0.05, 3.0, 0), 0.0)
		return
	_scene.call("go_to", SPOTS[_i][1], float(SPOTS[_i][2]))


func _print_spot(nm: String) -> void:
	var s: Array = _frames.duplicate()
	s.sort()
	var g: Array = _gpu.duplicate()
	g.sort()
	if s.is_empty():
		return
	print("PERF at %-9s frame median %5.2f ms, 95th %5.2f, worst %6.2f  |  GPU median %5.2f ms" % [nm, float(s[s.size() / 2]), float(s[int(s.size() * 0.95)]), float(s[-1]),
		float(g[g.size() / 2]) if not g.is_empty() else 0.0])


func _report_memory() -> void:
	var total: int = 0
	var chunks: int = 0
	for s in _scene.get("stations"):
		var ex: Node = s.get("exhibit")
		var list: Array = []
		for k in ["specimen", "spare"]:
			if ex.get(k) != null:
				list.append([k, ex.get(k)])
		if ex.get("top_spec") != null:
			list.append(["top", ex.get("top_spec")])
		if ex.get("extras") != null:
			for e in ex.get("extras"):
				list.append(["extra", e])
		for pair in list:
			var sp: Node = pair[1]
			var n: int = int(sp.call("tets"))
			var c: int = (sp.call("chunk_nodes") as Array).size()
			total += n
			chunks += c
			print("PERF %-9s %-8s %4d chunk meshes  %8d tetrahedra  ~%4.0f MB" % [String(s.name), String(pair[0]), c, n, float(n) * 1.25 / 1024.0])
	print("PERF all specimens: %d chunk meshes, %d tetrahedra, ~%.0f MB of video memory" % [chunks, total, float(total) * 1.25 / 1024.0])
