extends SceneTree
## Voxel Lab, plan step 67, as the open world is now (9 Oct: built once round the deck, flown as a bird):
## for each built radius, with the lab's swap and without (the engine's own way), what building it costs
## behind the board (seconds, chunks, tetrahedra, memory, the ground's height map), then the frame times
## while the bird circles over it for `fly` seconds, turning the slice as it goes. Each run opens the
## field afresh. sea=0 hides the sea, to measure what it costs. Vsync off; no frame is saved while
## measuring (a screenshot stalls its own frame).
##   VoxelLab/run.sh windowed field_probe res://ramon/VoxelLab/field/_probe_field_runner.gd
##   ... -- radii=32,40,48 fly=12 sea=1

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
var _sea: bool = true
var _phase: String = "open"


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var radii: Array = [40.0]
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=")
		if kv.size() == 2 and kv[0] == "radii":
			radii = Array(kv[1].split(",")).map(func(s: String) -> float: return float(s))
		if kv.size() == 2 and kv[0] == "sea":
			_sea = kv[1] != "0"
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
	stream.set("radius", float(run["radius"]) / float(stream.get("voxel")))
	stream.set("swap", bool(run["swap"]))
	if not _sea and _scene.get("water") != null:
		(_scene.get("water") as Node4D).visible = false
	_t = 0.0
	_frames = []
	_phase = "build"


func _process(delta: float) -> bool:
	_total += delta
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	if _total > 600.0:
		print("FIELD FAIL: timed out in run %d" % _i)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree():
		return false
	_t += delta
	var run: Dictionary = _runs[_i] if _i < _runs.size() else {}
	match _phase:
		"build":
			if not bool(_scene.get("loading")) and _t > 1.0:
				var st: Dictionary = _scene.get("stream").call("stats")
				print("FIELD radius %3.0f m  %-6s  built in %5.1f s  |  chunks %4d  tetrahedra %8d  ~%5.0f MB  |  ground mapped in %5.0f ms" % [
					float(run["radius"]), "swap" if bool(run["swap"]) else "engine", float(_scene.get("build_seconds")),
					int(st["chunks"]), int(st["tets"]), float(st["mb"]), float(_scene.get("height_map_ms"))])
				_scene.get("player").global_position = _scene.call("helm_spot")
				_phase = "take_off"
				_t = 0.0
		"take_off":
			if _t > 0.5:
				_scene.call("fly")
				_scene.get("bird").set("drive", {"turn": 0.35, "slice": Vector2(0.05, 0.0), "pitch": -0.05})
				_phase = "fly"
				_t = 0.0
				_frames = []
		"fly":
			# The take-off's first second is the camera easing in: measured from after it.
			if _t > 1.0:
				_frames.append(ms)
			if _t > _fly + 1.0:
				_phase = "report"
		"report":
			var s: Array = _frames.duplicate()
			s.sort()
			var over: int = s.filter(func(x: float) -> bool: return x > 16.7).size()
			print("FIELD radius %3.0f m  %-6s  flying: frames median %5.2f ms  95th %6.2f  worst %7.2f  over 16.7 ms: %3d of %d  |  slice %.0f°" % [
				float(run["radius"]), "swap" if bool(run["swap"]) else "engine", float(s[s.size() / 2]), float(s[int(s.size() * 0.95)]), float(s[-1]),
				over, s.size(), float(_scene.get("bird").call("slice_degrees"))])
			var image: Image = root.get_texture().get_image()
			image.save_png(ProjectSettings.globalize_path(OUT + "r%03d_%s_flying.png" % [int(run["radius"]), "swap" if bool(run["swap"]) else "engine"]))
			_phase = "next"
			_next.call_deferred()
	return false
