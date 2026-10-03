extends SceneTree

## What each piece of the Lookout costs to draw and to keep: for each, the GPU and CPU render
## time with it hidden against with it shown (shown, hidden, shown, 120 frames each, after the
## pen's warm-up), and then the video memory each frees when it is removed, one by one.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_measure_pieces_runner.gd

const PIECES := [
	["the tower", ["World/LookoutSite/Lookout"]],
	["the owl's tree", ["World/OwlTree"]],
	["the owl", ["World/AnaOwl"]],
	["the balloon", ["World/Balloon"]],
	["the marsh", ["World/AnaMarsh"]],
	["the heron", ["World/AnaHeron"]],
	["the kata wood", ["World/KataWood"]],
	["the chipmunks", ["World/Chipmunk0", "World/Chipmunk1", "World/Chipmunk2"]],
	["Wren", ["World/LookoutSite/Wren"]],
]
const FRAMES := 120

var _room: Node
var _t: float = 0.0
var _piece: int = -1
var _block: int = 0
var _cpu: Array = [[], [], []]
var _gpu: Array = [[], [], []]
var _phase: int = 0
var _free_at: int = 0
var _vram_before: float = 0.0
var _wait: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_pieces_test.cfg")
	root.add_child(_room)
	current_scene = _room


func _nodes(i: int) -> Array:
	var out: Array = []
	for path in PIECES[i][1]:
		var n: Node = _room.get_node_or_null(String(path))
		if n != null:
			out.append(n)
	return out


func _show(i: int, on: bool) -> void:
	for n in _nodes(i):
		(n as Node4D).visible = on


func _mean(a: Array) -> float:
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / maxf(float(a.size()), 1.0)


func _vram() -> float:
	return Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0


func _process(d: float) -> bool:
	_t += d
	if _phase == 0:
		if _t < 25.0:
			return false
		_phase = 1
		_piece = 0
		_block = 0
		print("      piece             GPU shown  hidden  -> costs     CPU shown  hidden  -> costs")
		return false
	if _phase == 1:
		var vp: RID = root.get_viewport_rid()
		(_gpu[_block] as Array).append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		(_cpu[_block] as Array).append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		if (_gpu[_block] as Array).size() >= FRAMES:
			_block += 1
			_show(_piece, _block != 1)
			if _block >= 3:
				var gs: float = (_mean(_gpu[0]) + _mean(_gpu[2])) * 0.5
				var cs: float = (_mean(_cpu[0]) + _mean(_cpu[2])) * 0.5
				print("      %-16s  %.3f  %.3f  %+.3f ms       %.3f  %.3f  %+.3f ms" % [String(PIECES[_piece][0]), gs, _mean(_gpu[1]), gs - _mean(_gpu[1]), cs, _mean(_cpu[1]), cs - _mean(_cpu[1])])
				_cpu = [[], [], []]
				_gpu = [[], [], []]
				_block = 0
				_piece += 1
				if _piece >= PIECES.size():
					_phase = 2
					_piece = 0
					# Its systems hold the pieces; asleep, they do not reach for freed ones.
					_room.get_node("Systems/Lookout").process_mode = Node.PROCESS_MODE_DISABLED
					print("      video memory freed by removing each (MB):")
		return false
	if _phase == 2:
		if _wait > 0:
			_wait -= 1
			if _wait == 0:
				print("      %-16s  %6.1f MB" % [String(PIECES[_piece][0]), _vram_before - _vram()])
				_piece += 1
			return false
		if _piece >= PIECES.size():
			print("      what is left of the Lookout's systems and HUD: the rest of the scene is the pen")
			print("PIECES DONE")
			return true
		_vram_before = _vram()
		for n in _nodes(_piece):
			(n as Node).free()
		_wait = 8
	return false
