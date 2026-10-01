extends SceneTree

## What the Lookout costs: the viewport's own measured render time on the CPU and the GPU,
## the scripts' process time, and video memory - each the mean (and 95th percentile) of 240
## frames after a settling pause. NOT the frame delta: Godot smooths it, so 240 deltas came
## back identical to the microsecond. Video memory, for the pen alone and for the pen with
## the Lookout, at the spawn point, up in the cab looking at the farm, and in the balloon
## over the flock. Run it twice: -- scene=pen and -- scene=lookout.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_measure_lookout_runner.gd -- scene=lookout

const TEST_BOOK := "user://lookout_journal_measure_test.cfg"

var _scene: String = "lookout"
var _room: Node
var _lookout: Node
var _t: float = 0.0
var _step: int = 0
var _samples: Array = []
var _label: String = ""


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("scene="):
			_scene = arg.substr(6)
	var path: String = "res://ramon/chickenpen/chickenpen.tscn" if _scene == "pen" else "res://ramon/chickenpen/chickenpen_lookout.tscn"
	if _scene == "profile":
		path = "res://ramon/chickenpen/chickenpen_lookout.tscn"
	if _scene == "profile_pen":
		path = "res://ramon/chickenpen/chickenpen.tscn"
		_scene = "profile"
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_room = load(path).instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	_lookout = _room.get_node_or_null("Systems/Lookout")
	if _lookout != null:
		_lookout.set("journal_path", TEST_BOOK)
	root.add_child(_room)
	current_scene = _room
	# -- off=<node path>: that piece asleep from the first frame, for the warm-up hunt.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("off="):
			_off_path = arg.substr(4)
	if _off_path != "":
		_switch_off.call_deferred()


var _off_path: String = ""


func _switch_off() -> void:
	var node: Node = _room.get_node_or_null(_off_path)
	if node != null:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		print("      (asleep from the start: %s)" % _off_path)


func _measure(label: String) -> void:
	_label = label
	_samples.clear()
	_cpu.clear()
	_gpu.clear()
	_script.clear()


var _cpu: Array = []
var _gpu: Array = []
var _script: Array = []


func _stats(values: Array) -> Vector2:
	var sorted: Array = values.duplicate()
	sorted.sort()
	var mean: float = 0.0
	for v in sorted:
		mean += float(v)
	mean /= maxf(float(sorted.size()), 1.0)
	return Vector2(mean, float(sorted[int(sorted.size() * 0.95)]) if not sorted.is_empty() else 0.0)


func _report() -> void:
	var cpu: Vector2 = _stats(_cpu)
	var gpu: Vector2 = _stats(_gpu)
	var script: Vector2 = _stats(_script)
	var vram: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	print("      %-8s %-22s render cpu %.2f (p95 %.2f)  gpu %.2f (p95 %.2f)  scripts %.2f (p95 %.2f) ms   video memory %.0f MB" % [
		_scene, _label, cpu.x, cpu.y, gpu.x, gpu.y, script.x, script.y, vram])


func _process(d: float) -> bool:
	_t += d
	if _label != "":
		var vp: RID = root.get_viewport_rid()
		_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		_script.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_samples.append(d)
		if _samples.size() >= 240:
			_report()
			_label = ""
			_step += 1
			_t = 0.0
		return false
	if _scene == "profile":
		return _profile()
	match _step:
		0:
			if _t > 5.0:
				_measure("spawn")
		1:
			if _lookout == null:
				print("MEASURE DONE")
				return true
			_lookout.get("journal").call("set_flag", "approached", true)
			_lookout.get("journal").call("set_flag", "met_wren", true)
			var player := _room.get_node("Player") as Node4D
			player.global_position = (_lookout.get("tower") as Node4D).call("ladder_foot") + Vector4(0, 0.05, 0.3, 0)
			_lookout.get("station").call("climb")
			_step = 2
			_t = 0.0
		2:
			if _t > 5.0:
				var station: Node = _lookout.get("station")
				station.set("yaw", 2.6)
				station.set("pitch", -0.3)
				_measure("cab, the farm")
		3:
			var station: Node = _lookout.get("station")
			station.call("climb_down")
			_step = 4
			_t = 0.0
		4:
			if _t > 3.5:
				var balloon: Node = _lookout.get("balloon")
				balloon.call("set_ready", true, true)
				balloon.call("board")
				balloon.set("ride_time", 60.0)
				_step = 5
				_t = 0.0
		5:
			if _t > 1.5:
				_lookout.get("station").call("look_along", Vector4(0.0, 0.1, -1.0, 0.0))
				_measure("balloon, in the flock")
		6:
			var balloon: Node = _lookout.get("balloon")
			balloon.set("ride_time", 118.0)
			_step = 7
			_t = 0.0
		7:
			if _t > 1.5:
				_measure("balloon, the marsh")
		8:
			if FileAccess.file_exists(TEST_BOOK):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_BOOK))
			print("MEASURE DONE")
			return true
	return false


## -- scene=profile: the Lookout's pieces switched off one at a time, at the spawn point,
## to find which costs what.
const PIECES := ["World/AnaOwl", "World/AnaHeron", "World/Balloon", "World/AnaMarsh", "World/Wren", "World/WrenFacing",
	"UI/Journal", "UI/WrenTag", "UI/WrenBox", "Systems/WrenDriver", "Systems/WrenTalk", "Systems/Lookout"]
var _piece: int = -1


func _profile() -> bool:
	if _t < 4.0:
		return false
	if OS.get_cmdline_user_args().has("time"):
		return _profile_time()
	if _piece >= 0 and _piece < PIECES.size():
		var node: Node = _room.get_node_or_null(String(PIECES[_piece]))
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	_piece += 1
	if _piece > PIECES.size():
		print("MEASURE DONE")
		return true
	_measure("all on" if _piece == 0 else "less " + String(PIECES[_piece - 1]))
	_t = 3.0
	return false


var _round: int = -1


## The same view, measured again and again: a cost that falls away is warming up, not the
## steady state.
func _profile_time() -> bool:
	_round += 1
	if _round >= (2 if _off_path != "" else 6):
		print("MEASURE DONE")
		return true
	_measure("spawn, round %d (%.0f s in)" % [_round, float(Time.get_ticks_msec()) / 1000.0])
	_t = 3.0
	return false
