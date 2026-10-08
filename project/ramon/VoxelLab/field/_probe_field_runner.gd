extends SceneTree
## Voxel Lab, plan step 67: Andrew's landscape generated round a moving camera, at several load radii,
## with the lab's swap and without (the engine's own way). For each: the camera flies a straight line
## for `fly` seconds at 12 m/s; then the frame times (median, 95th, worst), the chunks, tetrahedra and
## memory, and a frame. Each run opens the field afresh.
##   VoxelLab/run.sh windowed field_probe res://ramon/VoxelLab/field/_probe_field_runner.gd
##   ... -- radii=16,32,48 fly=12

const OUT := "res://smoke_test_output/voxel_lab/field/"
const FIELD := "res://ramon/VoxelLab/field/voxel_field.tscn"

var _runs: Array = []
var _i: int = -1
var _scene: Node
var _t: float = 0.0
var _total: float = 0.0
var _frames: Array = []
var _last_us: int = 0
var _fly: float = 12.0
var _settle: float = 3.0
var _phase: String = "open"


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var radii: Array = [16.0, 24.0, 32.0]
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2 and kv[0] == "radii":
			radii = Array(kv[1].split(",")).map(func(s: String) -> float: return float(s))
		if kv.size() == 2 and kv[0] == "fly":
			_fly = float(kv[1])
	for r in radii:
		_runs.append({"radius": r, "swap": true})
		_runs.append({"radius": r, "swap": false})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_next.call_deferred()


func _next() -> void:
	if _scene != null:
		_scene.queue_free()
		_scene = null
	_i += 1
	if _i >= _runs.size():
		print("FIELD done")
		quit()
		return
	_scene = (load(FIELD) as PackedScene).instantiate()
	var run: Dictionary = _runs[_i]
	root.add_child(_scene)
	var stream: Node = _scene.get("stream")
	# No warm-up: the radius under test from the first frame.
	_scene.set("warm_up", 0.0)
	_scene.set("_age", 99.0)
	stream.set("radius", float(run["radius"]))
	stream.set("swap", bool(run["swap"]))
	# In the air from the start, as before the deck (9 Oct): the survey camera is what flies.
	_scene.call("close_board")
	_scene.call("fly")
	_scene.set("input_enabled", false)
	_t = 0.0
	_frames = []
	_phase = "settle"


func _process(delta: float) -> bool:
	_total += delta
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if _total > 400.0:
		print("FIELD FAIL: timed out in run %d" % _i)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree():
		return false
	_t += delta
	var cam: Camera4D = _scene.get("cam")
	match _phase:
		"settle":
			# Loading round the start point first, then the flight is what is measured.
			if _t > _settle:
				var run0: Dictionary = _runs[_i]
				var arrive: Image = root.get_texture().get_image()
				arrive.save_png(ProjectSettings.globalize_path(OUT + "r%03d_%s_arrive.png" % [int(run0["radius"]), "swap" if bool(run0["swap"]) else "engine"]))
				_phase = "fly"
				_t = 0.0
				_frames = []
		"fly":
			_frames.append(ms)
			cam.global_position += Vector4(0, 0, -float(_scene.get("fly_speed")), 0) * delta
			if _t > _fly:
				_phase = "report"
		"report":
			var run: Dictionary = _runs[_i]
			var st: Dictionary = _scene.get("stream").call("stats")
			var s: Array = _frames.duplicate()
			s.sort()
			var over: int = s.filter(func(x: float) -> bool: return x > 33.3).size()
			print("FIELD radius %3.0f m  %-6s  frames median %5.1f ms  95th %6.1f  worst %7.1f  over 33 ms: %3d of %d  |  chunks %4d (%d drawn, %d waiting)  tetrahedra %8d  ~%5.0f MB" % [
				float(run["radius"]), "swap" if bool(run["swap"]) else "engine", float(s[s.size() / 2]), float(s[int(s.size() * 0.95)]), float(s[-1]),
				over, s.size(), int(st["chunks"]), int(st["shown"]), int(st["waiting"]), int(st["tets"]), float(st["mb"])])
			var image: Image = root.get_texture().get_image()
			image.save_png(ProjectSettings.globalize_path(OUT + "r%03d_%s.png" % [int(run["radius"]), "swap" if bool(run["swap"]) else "engine"]))
			_phase = "next"
			_next.call_deferred()
	return false
