extends SceneTree

## BOTANY LAB, THE SECOND ROOM (plan step 76): opened, waited for (its board), looked at, measured.
## Windowed and unfocusable, the player's input off and the mouse left free. Frames in
## smoke_test_output/botany_lab/compare/. Prints the build's numbers, the frame times (vsync off) and
## whether the way back works.

const SCENE := "res://ramon/Arboretum/botany_lab/compare/botany_compare.tscn"
const OUT := "res://smoke_test_output/botany_lab/compare/"

var _room: Node4D
var _deadline: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_deadline = Time.get_ticks_msec() + 240000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	(func() -> void: _run()).call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("COMPARE TIMEOUT")
		quit(2)
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _free_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p: Node = _room.get("player")
	if p != null:
		p.set("input_enabled", false)


func _go(x: float, z: float, yaw_deg: float, pitch_deg: float = -10.0, w: float = 0.0) -> void:
	_room.call("go_to", Vector4(x, 0.05, z, w), deg_to_rad(yaw_deg))
	var rig: Node = (_room.get("player") as Node).get_node_or_null("CameraRig")
	if rig != null:
		rig.set("pitch", deg_to_rad(pitch_deg))
		rig.call("_apply")
	_free_mouse()


func _shoot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("COMPARE shot " + name)


func _measure(label: String, frames: int = 150) -> void:
	var times: Array = []
	var last: int = Time.get_ticks_usec()
	for i in frames:
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	print("COMPARE perf %-22s frame median %.2f ms, 95%% %.2f ms" % [label, times[times.size() / 2], times[int(times.size() * 0.95)]])


func _run() -> void:
	var t0: int = Time.get_ticks_msec()
	_room = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_room)
	await _frames(10)
	_shoot("c00_board")
	var waited: int = 0
	while not bool(_room.call("ready_to_visit")) and waited < 2400:
		await process_frame
		waited += 1
	print("COMPARE ready after %.1f s (%d frames): %s" % [(Time.get_ticks_msec() - t0) / 1000.0, waited, str(_room.get("stats"))])
	while _room.get("_board") != null and waited < 3000:
		await process_frame
		waited += 1
	_free_mouse()
	if "round2" in OS.get_cmdline_user_args():
		await _round2()
		print("COMPARE done")
		quit(0)
		return
	if "round3" in OS.get_cmdline_user_args():
		await _round3()
		print("COMPARE done")
		quit(0)
		return
	_go(0.0, 19.0, 0.0, -12.0)
	await _frames(30)
	_shoot("c01_from_the_door")
	await _measure("from the door")
	_go(-1.2, 3.0, 90.0, -14.0)
	await _frames(30)
	_shoot("c02_blocky_from_its_ring")
	_go(1.2, -2.2, -90.0, -14.0)
	await _frames(30)
	_shoot("c03_smooth_from_its_ring")
	await _measure("at the smooth ring")
	_go(-1.2, 3.0, 90.0, -14.0, 0.6)
	await _frames(30)
	_shoot("c04_blocky_w_0_6")
	_go(1.2, -2.2, -90.0, -14.0, 0.6)
	await _frames(30)
	_shoot("c05_smooth_w_0_6")
	_go(0.0, -17.0, 180.0, -12.0)
	await _frames(30)
	_shoot("c06_from_the_far_end")
	_go(-1.6, 7.4, 135.0, -16.0)
	await _frames(40)
	_shoot("c07_panel_blocky")
	_go(-15.0, -2.0, -90.0, 8.0)
	await _frames(30)
	_shoot("c08_left_wall_page")
	_go(15.0, -2.0, 90.0, 8.0)
	await _frames(30)
	_shoot("c09_right_wall_page")
	# The way back: into the near doorway.
	_go(0.0, 23.7, 180.0)
	var p: Node4D = _room.get("player")
	p.set("input_enabled", true)
	await _frames(4)
	print("COMPARE the doorway back %s" % ("starts the way back" if bool(_room.get("_leaving")) else "DID NOT trigger"))
	print("COMPARE done")
	quit(0)


## Round 3 (section 9, steps 48-54): one land split by the walkway: down the cut from the door and from
## its middle, a bank's cut face close, the horizon at the far end, back toward the door, turned 45 degrees,
## and a gust with the leaves down the cut; frame times at the door and the middle.
func _round3() -> void:
	for v in [[0.0, 19.0, 0.0, -4.0, "r3_01_from_the_door"], [0.0, 6.0, 0.0, -2.0, "r3_02_down_the_cut"], [-0.6, 0.0, 90.0, -8.0, "r3_03_blocky_bank"],
			[0.6, 0.0, -90.0, -8.0, "r3_04_smooth_bank"], [0.0, -12.0, 0.0, 6.0, "r3_05_horizon"], [0.0, -17.0, 180.0, -6.0, "r3_06_back_to_the_door"]]:
		_go(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
		await _frames(40)
		_shoot(String(v[4]))
		if String(v[4]) == "r3_01_from_the_door":
			await _measure("r3 from the door")
		if String(v[4]) == "r3_02_down_the_cut":
			await _measure("r3 down the cut")
	_go(0.0, 6.0, 0.0, -2.0)
	_room.call("turn_by", deg_to_rad(45.0), 0.0)
	await _frames(30)
	_shoot("r3_07_turned_45")
	_room.call("level")
	var w: Node = _room.get_node_or_null("Wind")
	if w != null:
		w.set("gust_speed", 10.0)
		w.call("gust", 0.6, 7.0, 1.0)
	await _frames(60)
	_shoot("r3_08_gust")


## Round 2 (section 8, steps 22 and 26): both lands turned through W, each side from its ring, level and
## at 30, 60 and 90 degrees in both planes; then the gust (G), frames from before it to its passing.
func _round2() -> void:
	for side in [["blocky", -1.2, 3.0, 90.0], ["smooth", 1.2, -2.2, -90.0]]:
		_go(float(side[1]), float(side[2]), float(side[3]), -14.0)
		for plane in [["xw", 1.0, 0.0], ["zw", 0.0, 1.0]]:
			for deg in [0, 30, 60, 90]:
				_room.call("level")
				var a: float = deg_to_rad(float(deg))
				_room.call("turn_by", -a * float(plane[1]), a * float(plane[2]))
				await _frames(12)
				_shoot("t_%s_%s_%02d" % [side[0], plane[0], deg])
		_room.call("level")
	# The gust: from the middle of the path, looking along the room so both sides are in the picture.
	_go(0.0, 12.0, 0.0, -8.0)
	await _frames(30)
	_shoot("g00_before")
	var k := InputEventKey.new()
	k.keycode = KEY_G
	k.physical_keycode = KEY_G
	k.pressed = true
	Input.parse_input_event(k)
	var up := InputEventKey.new()
	up.keycode = KEY_G
	up.physical_keycode = KEY_G
	Input.parse_input_event(up)
	var w: Node = _room.get_tree().get_first_node_in_group("arb_wind")
	print("COMPARE wind node %s, gusting %s" % [str(w), str(w.get("_gust_on")) if w != null else "-"])
	for i in 8:
		await _frames(30)
		_shoot("g%02d_gust_%0.1fs" % [i + 1, float(i + 1) * 0.5])
		if w != null:
			print("COMPARE gust front %.2f, on %s" % [float(w.get("gust_front")), str(w.get("_gust_on"))])
