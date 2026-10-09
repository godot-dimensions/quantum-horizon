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
	_go(0.0, 23.2, 180.0)
	var p: Node4D = _room.get("player")
	p.set("input_enabled", true)
	await _frames(4)
	print("COMPARE the doorway back %s" % ("starts the way back" if bool(_room.get("_leaving")) else "DID NOT trigger"))
	print("COMPARE done")
	quit(0)
