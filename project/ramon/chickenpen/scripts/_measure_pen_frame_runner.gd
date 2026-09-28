extends SceneTree

## What a frame of the pen actually costs, drawn, from the spawn point with nobody moving.
##
## WINDOWED, NOT HEADLESS. The headless renderer never builds a 3D proxy, and building those
## proxies was 67% of the frame in Trym's measurement - a headless timing would report the
## one cost this is here to catch as zero. Run it with a real window:
##
##   godot --path project --resolution 1280x720 --script res://ramon/chickenpen/scripts/_measure_pen_frame_runner.gd
##
## Same settings as Trym's harness so the two can be read side by side: 1280x720, vsync off,
## no frame cap, a discarded warm-up. Absolute numbers are this machine's; the ratios travel.
##
## PHYSICS TICKS PER FRAME IS REPORTED ON PURPOSE. Godot's max_physics_steps_per_frame
## defaults to 8, and a frame slow enough to owe more than eight ticks gets exactly eight.
## Reading 8.0 here means the frame is pinned against that cap, not that physics is the
## cost - which is what his 8.0 ticks at 146 ms meant.
##
## Optional arguments after `--`:
##   norock=1   strip the voxel rock's colliders before measuring, to see what they cost
##   frames=N   how many frames to measure (default 300)

const SCENE := "res://ramon/chickenpen/chickenpen.tscn"
const WARMUP := 150

var _room: Node
var _frames: int = 300
var _norock: bool = false
var _f: int = 0
var _last: int = 0
var _times: PackedFloat64Array = []
var _ticks_this_frame: int = 0
var _ticks: PackedInt32Array = []
var _proc: float = 0.0
var _phys: float = 0.0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=")
		if kv.size() == 2 and kv[0] == "frames":
			_frames = int(kv[1])
		elif kv.size() == 2 and kv[0] == "norock":
			_norock = kv[1] == "1"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_room = load(SCENE).instantiate()
	root.add_child(_room)
	current_scene = _room
	physics_frame.connect(func() -> void: _ticks_this_frame += 1)


func _strip_rock() -> int:
	var rock: Node = _room.get_node_or_null("World/MiningRock")
	if rock == null:
		return 0
	var n: int = 0
	var stack: Array = [rock]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CollisionObject4D:
			(node as CollisionObject4D).process_mode = Node.PROCESS_MODE_DISABLED
			node.get_parent().remove_child(node)
			node.queue_free()
			n += 1
			continue
		stack.append_array(node.get_children())
	return n


func _process(_d: float) -> bool:
	_f += 1
	var now: int = Time.get_ticks_usec()
	if _f == WARMUP and _norock:
		print("   stripped %d collision objects from the rock" % _strip_rock())
	if _f > WARMUP:
		_times.append(float(now - _last) / 1000.0)
		_ticks.append(_ticks_this_frame)
		_proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	_ticks_this_frame = 0
	_last = now
	if _f >= WARMUP + _frames:
		_report()
		quit()
		return true
	return false


func _report() -> void:
	var sorted: PackedFloat64Array = _times.duplicate()
	sorted.sort()
	var total: float = 0.0
	for t in _times:
		total += t
	var mean: float = total / _times.size()
	var tick_total: int = 0
	for t in _ticks:
		tick_total += t
	var n: int = _times.size()
	print("   frames %d%s" % [n, "   (rock colliders stripped)" if _norock else ""])
	print("   mean %.2f ms   (%.1f fps)" % [mean, 1000.0 / mean])
	print("   p50 %.2f   p95 %.2f   p99 %.2f   worst %.2f ms" % [sorted[n / 2], sorted[int(n * 0.95)], sorted[int(n * 0.99)], sorted[n - 1]])
	print("   physics ticks per frame %.2f   (Godot caps it at %d)" % [float(tick_total) / n, Engine.max_physics_steps_per_frame])
	print("   script time per frame: process %.2f ms, physics %.2f ms" % [_proc / n, _phys / n])
