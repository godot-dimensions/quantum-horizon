extends SceneTree

## BOTANY LAB, round 3 (section 9, steps 30-31): the flower room (flowers/flower_room.tscn), windowed and
## unfocusable, the player's input off and the mouse free. Frames in
## smoke_test_output/botany_lab/flower_room/, and its frame times (vsync off; the GPU's measured render
## time and the frame's).
##
## Args after --: the sets ("frames", "perf"; default both).

const SCENE := "res://ramon/Arboretum/botany_lab/flowers/flower_room.tscn"
const OUT := "res://smoke_test_output/botany_lab/flower_room/"

var _room: Node4D
var _deadline: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_deadline = Time.get_ticks_msec() + 300000
	(func() -> void: _run()).call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("FLOWER ROOM TIMEOUT")
		quit(2)
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _go(x: float, z: float, yaw_deg: float, pitch_deg: float = -8.0, dist: float = -1.0) -> void:
	_room.call("go_to", Vector4(x, 0.05, z, 0.0), deg_to_rad(yaw_deg))
	var rig: Node = (_room.get("player") as Node).get_node_or_null("CameraRig")
	if rig != null:
		rig.set("pitch", deg_to_rad(pitch_deg))
		if dist > 0.0:
			rig.set("distance", dist)
			rig.set("_zoom_target", dist)
		rig.call("_apply")


func _run() -> void:
	var sets: Array = Array(OS.get_cmdline_user_args())
	if sets.is_empty():
		sets = ["frames", "perf"]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var t0: int = Time.get_ticks_msec()
	var ps: PackedScene = load(SCENE)
	_room = ps.instantiate()
	root.add_child(_room)
	current_scene = _room
	for i in 600:
		await process_frame
		if bool(_room.call("ready_to_visit")):
			break
	print("FLOWER ROOM ready in %d ms: %s" % [Time.get_ticks_msec() - t0, JSON.stringify(_room.get("stats"))])
	await _frames(10)
	await _shot("00_board")
	# The board closes on its own once the labels are printed (and fades): wait for it, bounded.
	for i in 900:
		if _room.get("_board") == null:
			break
		await process_frame
	print("FLOWER ROOM board closed after %d ms" % (Time.get_ticks_msec() - t0))
	await _frames(30)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var p: Node = _room.get("player")
	if p != null:
		p.set("input_enabled", false)
	if "frames" in sets:
		await _views()
	if "perf" in sets:
		await _perf()
	print("FLOWER ROOM done")
	quit(0)


func _views() -> void:
	# In through the door, the room ahead.
	_go(0.0, 5.4, 0.0, -6.0)
	await _shot("01_entering")
	# From the middle, each wall (yaw 0 faces -z, the north wall).
	for v in [["02_north", 0.0], ["03_east", -90.0], ["04_west", 90.0], ["05_south", 180.0]]:
		_go(0.0, 0.0, float(v[1]), -4.0, 3.0)
		await _shot(String(v[0]))
	# A pocket close: the north wall's row B, left of middle.
	_go(-1.2, -6.4, 0.0, 4.0, 2.2)
	await _shot("06_pockets_close")
	_go(3.6, -7.0, 0.0, -14.0, 2.0)
	await _shot("07_row_a_close")
	# Turned through W: 30 and 60 degrees (sideways drags).
	_go(-1.2, -6.4, 0.0, 4.0, 2.2)
	_room.call("turn_by", deg_to_rad(30.0), 0.0)
	await _frames(3)
	await _shot("08_turned_30")
	_room.call("turn_by", deg_to_rad(30.0), 0.0)
	await _frames(3)
	await _shot("09_turned_60")
	_room.call("level")
	await _frames(3)
	# Up the wall: the trailing row, the wisteria, the frame against the sky.
	_go(0.0, -3.0, 0.0, 28.0, 3.0)
	await _shot("10_up_the_wall")
	# A gust.
	_go(0.0, 2.0, 0.0, -2.0, 3.0)
	_room.call("gust")
	await _frames(40)
	await _shot("11_gust")
	# Corner climbers.
	_go(-6.5, -6.5, 45.0, 2.0, 3.0)
	await _shot("12_corner")
	print("FLOWER ROOM butterflies sitting %d of %d perches" % [int(_room.get("_flies").call("sitting")), int(_room.get("_flies").call("perches_count"))])


func _perf() -> void:
	var vp: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for v in [["middle_north", 0.0, 0.0, 0.0], ["middle_east", 0.0, 0.0, -90.0], ["door", 0.0, 7.6, 0.0], ["close_north", -1.2, -6.4, 0.0]]:
		_go(float(v[1]), float(v[2]), float(v[3]), -4.0, 3.0)
		await _frames(30)
		var n: int = 120
		var gpu: float = 0.0
		var frame: float = 0.0
		var worst: float = 0.0
		var last: int = Time.get_ticks_usec()
		for i in n:
			await process_frame
			var now: int = Time.get_ticks_usec()
			var dt: float = (now - last) / 1000.0
			last = now
			frame += dt
			worst = maxf(worst, dt)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		print("FLOWER ROOM PERF %-13s frame %.2f ms (worst %.1f)  gpu %.2f ms  shown pockets %s  shown tets %d" % [v[0], frame / n, worst, gpu / n,
			str(_room.get("stats").get("shown_pockets", -1)), int(_room.call("shown_tets"))])
