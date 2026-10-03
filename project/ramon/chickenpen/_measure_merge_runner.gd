extends SceneTree

## What moving the Lookout and the grass into the pen costs: the whole frame of a scene from the
## farm camera at the spawn, after the pen's warm-up - GPU and CPU render time, the scripts, video
## memory - and how long from loading it to the grass being up (the mask and the painted ground
## are built after load). It compared chickenpen.tscn with the inherited chickenpen_lookout.tscn
## before the two were merged (3 Oct); scene= picks any scene.
## Gives up after 120 s.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/_measure_merge_runner.gd -- scene=res://ramon/chickenpen/chickenpen.tscn

const FRAMES := 900

var _room: Node
var _path: String = "res://ramon/chickenpen/chickenpen.tscn"
var _t: float = 0.0
var _load_msec: int = 0
var _ready_msec: int = -1
var _gpu: Array = []
var _cpu: Array = []
var _script: Array = []
var _started: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scene="):
			_path = arg.substr(6)
	_started = Time.get_ticks_msec()
	_room = load(_path).instantiate()
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout != null:
		lookout.set("journal_path", "user://lookout_journal_merge_test.cfg")
	root.add_child(_room)
	current_scene = _room
	_load_msec = Time.get_ticks_msec() - _started


func _process(d: float) -> bool:
	_t += d
	if _t > 120.0:
		print("MERGE MEASURE FAIL: timed out")
		return true
	var grass: Node = _room.get_node_or_null("World/Grass")
	if _ready_msec < 0 and (grass == null or bool(grass.get("mask_ready"))):
		_ready_msec = Time.get_ticks_msec() - _started
	if _t < 25.0:
		return false
	var vp: RID = root.get_viewport_rid()
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
	_script.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	if _gpu.size() < FRAMES:
		return false
	print("      %s" % _path.get_file())
	print("      loaded in %d ms, grass up at %s" % [_load_msec, ("%d ms" % _ready_msec) if grass != null else "(no grass)"])
	print("      GPU %.3f ms   render CPU %.3f ms   process %.3f ms   video memory %.0f MB" % [_mean(_gpu), _mean(_cpu), _mean(_script),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	print("MERGE MEASURE DONE")
	if FileAccess.file_exists("user://lookout_journal_merge_test.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://lookout_journal_merge_test.cfg"))
	return true


func _mean(a: Array) -> float:
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / maxf(float(a.size()), 1.0)
