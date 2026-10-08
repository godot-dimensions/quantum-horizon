extends SceneTree

## Ramon's water scene, captured through the player's own camera: the door, pier 1 and its turn,
## the set platform level and turned (it should not move while the sea does), pier 2 and its circle
## level and turned (its panel, then its deep picture past the swap), the pole, and the HUD's two
## modes. The slice is turned by setting the camera rig's own angles, as a right drag would.
## Windowed, unfocusable, the player's input off and the mouse free. Frames in
## smoke_test_output/water_ramon/. Prints the scene's open time and any missing piece.

const OUT := "res://smoke_test_output/water_ramon/"
const SCENE := "res://ramon/Water/water4d_test_ramon.tscn"

var _room: Node4D
var _queue: Array = []
var _wait: int = 0
var _deadline: int = 0


var _mode: String = "frames"
## perf with "slow_panels": the wall panels poll their data twice a second instead of ten times,
## to see whether their polling is what makes the slow frames.
var _slow_panels: bool = false
## perf with "variants": the door measured again with the plesiosaur paused, then with the frame
## rate capped at 200, to tell a script cost from the window's own presenting.
var _variants: bool = false
var _perf: Array = []
var _last_us: int = 0


func _initialize() -> void:
	root.unfocusable = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "hud4k" in args:
		_mode = "hud4k"
		DisplayServer.window_set_size(Vector2i(3840, 2160))
	elif "perf" in args:
		_mode = "perf"
		_slow_panels = "slow_panels" in args
		_variants = "variants" in args
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	_deadline = Time.get_ticks_msec() + 240000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	(func() -> void: _open()).call_deferred()


func _open() -> void:
	var t0: int = Time.get_ticks_usec()
	_room = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_room)
	print("WATER opened in %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	_wait = 60
	match _mode:
		"hud4k":
			_step(10, _go(0.8, 0.0, -90), "")
			_step(30, _press_p, "")
			_step(5, _nop, "4k_01_readout_and_toast")
			_step(10, _tab, "4k_02_light_mode")
			_step(5, _tab, "")
			_step(5, _tab, "")
		"perf":
			for spot in [["door", 0.8, 0.0, -90.0], ["platform", 24.3, -13.5, 0.0], ["pier2_circle", 27.5, 24.0, -90.0]]:
				_step(30, _go(float(spot[1]), float(spot[2]), float(spot[3])), "")
				if _slow_panels:
					_step(1, _slow, "")
				_step(1, _measure_start.bind(String(spot[0])), "")
				_step(150, _nop, "")
				_step(1, _measure_end, "")
			if _variants:
				_step(10, _go(0.8, 0.0, -90.0), "")
				_step(1, _rigid_seams, "")
				_step(30, _measure_start.bind("rigid_seams"), "")
				_step(150, _nop, "")
				_step(1, _measure_end, "")
				_step(1, _pause_creature, "")
				_step(30, _measure_start.bind("no_creature"), "")
				_step(150, _nop, "")
				_step(1, _measure_end, "")
				_step(1, _cap_fps, "")
				_step(30, _measure_start.bind("capped_200"), "")
				_step(150, _nop, "")
				_step(1, _measure_end, "")
		_:
			_plan()


func _step(wait: int, f: Callable, shot: String = "") -> void:
	_queue.append([wait, f, shot])


func _rig() -> Node:
	var p: Node = _room.get("player")
	return p.get_node_or_null("CameraRig") if p != null else null


func _go(x: float, z: float, yaw_deg: float) -> Callable:
	return func() -> void:
		var p: Node = _room.get("player")
		_room.call("go_to", Vector4(x, float(_room.get("deck_height")) + 0.05, z, 0.0), deg_to_rad(yaw_deg))
		if p != null:
			p.set("input_enabled", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _turn(xw_deg: float, zw_deg: float = 0.0) -> Callable:
	return func() -> void:
		var r: Node4D = _rig() as Node4D
		if r != null:
			# The pen's rig holds the slice in its ground basis: the same tilt of the world the old
			# rig's two angles meant (the pen's slice_angles_4d.gd builds it the same way).
			var yaw: float = float(r.get("yaw"))
			r.set("_homing", 0.0)
			r.basis = Basis4D.from_xw(deg_to_rad(xw_deg)) * Basis4D.from_zw(deg_to_rad(zw_deg)) * Basis4D.from_zx(yaw)
			r.call("_apply")


func _pitch(deg: float) -> Callable:
	return func() -> void:
		var r: Node = _rig()
		if r != null:
			r.set("pitch", deg_to_rad(deg))
			r.call("_apply")


func _tab() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_TAB
		e.physical_keycode = KEY_TAB
		e.pressed = down
		Input.parse_input_event(e)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _nop() -> void:
	pass


func _rigid_seams() -> void:
	var s: Node = _room.get_node_or_null("SeaLife/Plesiosaur/Swimmer")
	if s != null:
		s.set("blend_joints", false)


func _pause_creature() -> void:
	var s: Node = _room.get_node_or_null("SeaLife")
	if s != null:
		s.process_mode = Node.PROCESS_MODE_DISABLED


func _cap_fps() -> void:
	Engine.max_fps = 200


func _slow() -> void:
	for p in _room.find_children("*", "Node4D", true, false):
		if p.get("poll_hz") != null:
			p.set("poll_hz", 2.0)


var _measuring: String = ""


func _measure_start(nm: String) -> void:
	_measuring = nm
	_perf.clear()
	_last_us = Time.get_ticks_usec()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _measure_end() -> void:
	_perf.sort()
	if not _perf.is_empty():
		print("WATER PERF %-14s frame median %.2f ms, 95%% %.2f ms, GPU %.2f ms" % [_measuring, _perf[_perf.size() / 2], _perf[int(_perf.size() * 0.95)],
				RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())])
	_measuring = ""


func _press_p() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_P
		e.physical_keycode = KEY_P
		e.pressed = down
		Input.parse_input_event(e)
	var p: Node = _room.get("player")
	if p != null:
		p.set("input_enabled", false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _check() -> void:
	for nm in ["Door1", "Door2", "Pier1", "PlatformSet", "Pier2", "Pole", "SeaFloor", "Player", "SeaLife", "PanelSource", "Water", "Paths/Pier1", "Paths/Pier2"]:
		print("WATER %s %s" % ["has" if _room.get_node_or_null(nm) != null else "MISSING", nm])
	var deep: Node = _room.get("_pier2_deep")
	print("WATER pier 2 deep picture: ", "made" if deep != null else "MISSING")
	for net in ["Paths/Pier1", "Paths/Pier2"]:
		var n: Node = _room.get_node_or_null(net)
		if n != null and n.has_method("acceptance"):
			print("WATER %s acceptance: %s" % [net, str(n.call("acceptance"))])


func _plan() -> void:
	_step(1, _check)
	_step(10, _go(0.8, 0.0, -90), "01_door")
	_step(30, _go(7.0, 0.0, -90), "02_along_pier1")
	_step(30, _go(12.5, 0.0, -90), "03_platform_way_in")
	_step(40, _go(18.5, 0.0, -90), "05_on_platform")
	_step(20, _pitch(-38.0), "05b_platform_pages_from_above")
	_step(5, _pitch(-12.0), "")
	_step(20, _turn(30.0), "06_platform_turned_30")
	_step(20, _turn(60.0), "07_platform_turned_60")
	_step(20, _turn(0.0), "")
	_step(20, _go(23.0, 0.0, 90), "08_platform_looking_back")
	_step(20, _turn(35.0), "09_platform_back_turned_35")
	_step(20, _turn(0.0, 0.0), "")
	_step(30, _go(8.0, 1.0, 0), "10_pole_from_pier1")
	_step(30, _go(4.0, 0.0, 90), "10b_door1_from_pier")
	_step(30, _go(0.8, 24.0, -90), "11_pier2_door")
	_step(30, _go(8.0, 24.0, -90), "12_pier2_circle_ahead")
	_step(30, _go(12.5, 24.0, -90), "13_pier2_on_circle")
	_step(20, _turn(20.0), "14_pier2_turned_20")
	_step(20, _turn(40.0), "15_pier2_turned_40")
	_step(20, _turn(70.0), "16_pier2_turned_70")
	_step(20, _turn(0.0), "")
	_step(20, _pitch(-38.0), "16b_pier2_page_from_above")
	_step(5, _pitch(-12.0), "")
	_step(20, _go(5.0, 24.0, 90), "17_door2_from_pier")
	# The PIERS sliders' rebuild: pier 1 longer and wider, then back.
	_step(10, _go(0.8, 0.0, -90), "")
	_step(5, _resize.bind(22.0, 5.0), "")
	_step(40, _nop, "17b_pier1_rebuilt_22m_5m")
	_step(5, _resize.bind(14.0, 3.4), "")
	_step(40, _nop, "")
	_step(10, _go(0.8, 0.0, -90), "")
	_step(30, _tab, "18_hud_light_mode")
	_step(20, _tab, "19_hud_hidden")
	_step(5, _tab, "")
	_step(20, _press_p, "20_after_p")
	_step(20, _press_p, "21_after_p_again")


func _resize(length: float, width: float) -> void:
	_room.set("pier1_length", length)
	_room.set("pier1_width", width)
	_room.call("rebuild_piers")
	print("WATER rebuilt pier 1 at %.0f x %.1f m: %s" % [length, width, "platform at x %.1f" % _room.call("platform_centre").x])


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("WATER TIMEOUT")
		quit(2)
		return true
	if not _measuring.is_empty():
		var now: int = Time.get_ticks_usec()
		_perf.append((now - _last_us) / 1000.0)
		_last_us = now
	if _wait > 0:
		_wait -= 1
		return false
	if _queue.is_empty():
		print("WATER done")
		quit()
		return true
	var s: Array = _queue[0]
	if s.size() < 4:
		s.append(true)
		(s[1] as Callable).call()
		return false
	if int(s[0]) > 0:
		s[0] = int(s[0]) - 1
		return false
	_queue.pop_front()
	if not String(s[2]).is_empty():
		root.get_texture().get_image().save_png(OUT + String(s[2]) + ".png")
		print("WATER shot ", s[2])
	return false
