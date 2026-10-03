extends SceneTree

## What the grass costs to draw: GPU and CPU render time with it on and off, in blocks of 90
## frames in an on, off, off, on order (an A/B in plain alternation picks up anything in the
## scene that runs on a period), after the pen's warm-up, from the farm camera at the spawn and
## from low in the field. Video memory with it and without.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/grass/_measure_grass_runner.gd

const ORDER := [true, false, false, true]
const BLOCKS := 12
const FRAMES := 90

var _room: Node
var _grass: Node4D
var _t: float = 0.0
var _phase: int = 0
var _block: int = 0
var _on: Array = [[], []]
var _off: Array = [[], []]
var _frames: int = 0
var _view: int = 0
var _cam: Camera4D
## What the A/B switches: the grass ("enabled", the default) or, with toggle=bits_enabled after
## "--", the leaves and bits on the wind.
var _toggle: String = "enabled"


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://lookout_journal_grassm_test.cfg")
	# After "--": key=value sets a Grass knob before it is ready (as the capture runner does).
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "toggle":
			_toggle = kv[1]
		elif kv.size() == 2:
			_room.get_node("World/Grass").set(kv[0], float(kv[1]))
			print("      grass.%s = %s" % [kv[0], kv[1]])
	root.add_child(_room)
	current_scene = _room


func _mean(a: Array) -> float:
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / maxf(float(a.size()), 1.0)


func _process(d: float) -> bool:
	_t += d
	match _phase:
		0:
			_grass = _room.get_node("World/Grass")
			if _t > 90.0:
				# The grass never came up (a script that failed to load, say): stop, not hang.
				print("GRASS MEASURE FAILED: no grass after 90 s")
				return true
			if _t < 25.0 or not bool(_grass.get("mask_ready")):
				return false
			_phase = 1
			_block = 0
			_grass.set(_toggle, ORDER[0])
		1:
			var vp: RID = root.get_viewport_rid()
			var on: bool = ORDER[_block % 4]
			_frames += 1
			if _frames > 10:
				(_on if on else _off)[0].append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
				(_on if on else _off)[1].append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
			if _frames >= FRAMES:
				_frames = 0
				_block += 1
				if _block >= BLOCKS:
					var label: String = "farm camera at the spawn" if _view == 0 else "low in the field"
					print("      %-26s GPU with grass %.3f ms, without %.3f ms: %+.3f ms   CPU %+.3f ms" % [label, _mean(_on[0]), _mean(_off[0]),
						_mean(_on[0]) - _mean(_off[0]), _mean(_on[1]) - _mean(_off[1])])
					_on = [[], []]
					_off = [[], []]
					_view += 1
					if _view >= 2:
						_grass.set(_toggle, true)
						var vram_on: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
						print("      blades in view %d, grass script %d us a frame, video memory with the scene %.0f MB" % [int(_grass.call("blade_count")),
							int(_grass.get("prerender_usec")), vram_on])
						print("GRASS MEASURE DONE")
						return true
					_cam = Camera4D.new()
					_cam.set("rendering_engine_name", "Cross-section")
					_cam.set("field_of_view_4d", 1.0)
					_room.add_child(_cam)
					_cam.make_current()
					_cam.global_position = Vector4(4.0, 0.9, 8.0, 0.0)
					_cam.global_basis = Basis4D.from_zx(atan2(10.0, 12.0)) * Basis4D.from_yz(-0.05)
					_block = 0
				_grass.set(_toggle, ORDER[_block % 4])
	return false
