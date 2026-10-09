extends SceneTree

## BOTANY LAB: frames to look at (section 7's checks), windowed and unfocusable, the player's input off
## and the mouse left free. Frames in smoke_test_output/botany_lab/<set>/.
##
## Args after --: the sets to shoot (default "route").
##   route    the hall's route from straight above (an orthographic camera over the middle), then
##            walked: the door, each junction looking down its branch, each ring, the oak's, the door
##   panels   each pedestal's floating panel from its ring, its pages (E)
##   tilt     a tree turned by a run of drags (both axes), its trunk's lean measured
##   stories  every part of each pedestal's story, a frame in the middle of each
##   door     the back door's sign and its holographic doorway

const SCENE := "res://ramon/Arboretum/botany_lab.tscn"
const OUT := "res://smoke_test_output/botany_lab/"

var _room: Node4D
var _sets: Array = []
var _deadline: int = 0
var _top: Camera4D


func _initialize() -> void:
	root.unfocusable = true
	_deadline = Time.get_ticks_msec() + 240000
	for a in OS.get_cmdline_user_args():
		_sets.append(a)
	if _sets.is_empty():
		_sets = ["route"]
	(func() -> void: _run()).call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > _deadline:
		print("CAPTURE TIMEOUT")
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


func _go(x: float, z: float, yaw_deg: float, pitch_deg: float = -9.0) -> void:
	_room.call("go_to", Vector4(x, 0.05, z, 0.0), deg_to_rad(yaw_deg))
	var rig: Node = (_room.get("player") as Node).get_node_or_null("CameraRig")
	if rig != null:
		rig.set("pitch", deg_to_rad(pitch_deg))
		rig.call("_apply")
	_free_mouse()


func _shoot(set_name: String, name: String) -> void:
	var dir: String = OUT + set_name + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	root.get_texture().get_image().save_png(dir + name + ".png")
	print("CAPTURE shot %s/%s" % [set_name, name])


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
	_free_mouse()


func _player_camera() -> Camera4D:
	return _room.call("camera") as Camera4D


func _run() -> void:
	_room = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_room)
	await _frames(60)
	_free_mouse()
	for s in _sets:
		match String(s):
			"route":
				await _route()
			"panels":
				await _panels()
			"tilt":
				await _tilt()
			"stories":
				await _stories()
			"door":
				await _door()
			"perf":
				await _perf()
	print("CAPTURE done")
	quit(0)


## The route from above, then walked.
func _route() -> void:
	_top = Camera4D.new()
	_top.name = "TopCamera"
	_top.set("rendering_engine_name", "Cross-section")
	_top.set("projection_type", 0)
	_top.set("orthographic_size", 46.0)
	_room.add_child(_top)
	_top.global_position = Vector4(0.0, 11.5, -3.0, 0.0)
	_top.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
	_top.current = true
	_go(0.0, 22.0, 0.0)
	await _frames(30)
	_shoot("route", "r01_from_above")
	_player_camera().current = true
	_top.queue_free()
	for v in [[0.0, 20.0, 0.0, -14.0, "r02_from_the_corridor"], [0.0, 13.6, 30.0, -16.0, "r03_junction_01"], [-3.7, 8.0, 90.0, -12.0, "r04_ring_01"],
			[0.0, 6.4, -30.0, -16.0, "r05_junction_02"], [3.5, 1.0, -90.0, -12.0, "r06_ring_02"], [0.0, -0.6, 30.0, -16.0, "r07_junction_03"],
			[-3.5, -6.0, 90.0, -12.0, "r08_ring_03"], [0.0, -6.6, 0.0, -14.0, "r09_ring_oak"], [5.4, -9.0, 0.0, -14.0, "r10_round_the_oak"],
			[0.6, -19.0, 0.0, -8.0, "r11_back_door"]]:
		_go(float(v[0]), float(v[1]), float(v[2]), float(v[3]))
		await _frames(40)
		_shoot("route", String(v[4]))


## Each pedestal's floating panel, from its ring, then its pages.
func _panels() -> void:
	for i in 4:
		var panel: Node4D = _room.get_node_or_null("Panel%02d" % (i + 1)) as Node4D
		if panel == null:
			print("CAPTURE no Panel%02d" % (i + 1))
			continue
		var st: Node4D = _room.get_node_or_null("Station%02d" % (i + 1)) as Node4D
		var pp: Vector4 = panel.global_position
		var sp: Vector4 = st.global_position
		# Stand back from the panel on the spine side, looking at it and the pedestal behind.
		var away := Vector2(pp.x - sp.x, pp.z - sp.z).normalized()
		var at := Vector2(pp.x, pp.z) + away * 2.6
		var yaw: float = rad_to_deg(atan2(away.x, away.y))
		_go(at.x, at.y, yaw, -14.0)
		await _frames(60)
		_shoot("panels", "p%02d_face" % (i + 1))
		for k in 2:
			_key(KEY_E)
			await _frames(20)
			_shoot("panels", "p%02d_page_%d" % [i + 1, k + 1])
		panel.set("page_index", -1)
		panel.call("_read")


## A tree turned by a run of drags, and how far its trunk leans from upright.
func _tilt() -> void:
	var st: Node = _room.get_node_or_null("Station02")
	_go(3.5, 1.0, -90.0, -10.0)
	await _frames(60)
	for k in 30:
		st.call("turn_by", 0.02, 0.015)
		await _frames(1)
	await _frames(20)
	_shoot("tilt", "t01_after_drags")
	var slice: Node4D = st.get("_slice_node") as Node4D
	var up: Vector4 = (slice.global_basis * Vector4(0, 1, 0, 0)) if slice != null else Vector4.ZERO
	print("CAPTURE tilt: the tree's up after 30 drags (%.3f, %.3f, %.3f, %.3f), its lean %.2f degrees" % [up.x, up.y, up.z, up.w, rad_to_deg(acos(clampf(up.normalized().dot(Vector4(0, 1, 0, 0)), -1.0, 1.0)))])
	st.call("reset_view")
	await _frames(30)
	_shoot("tilt", "t02_reset")


## Every part of each pedestal's story, a frame in the middle of each.
func _stories() -> void:
	var rings := [[-3.7, 8.0, 90.0], [3.5, 1.0, -90.0], [-3.5, -6.0, 90.0], [0.0, -7.6, 0.0]]
	for i in 4:
		var st: Node = _room.get_node_or_null("Station%02d" % (i + 1))
		var r: Array = rings[i]
		_go(float(r[0]), float(r[1]), float(r[2]), -12.0)
		await _frames(30)
		var seqs: Array = st.call("sequences")
		# The room's own story playing (it starts as you arrive) would fight these frames: the room is
		# paused while each part is held at 60% of its length, as the guided tour holds it.
		_room.set_process(false)
		# Its own story started as the runner walked up (the room plays it on arrival): end it, or it
		# drives the tree on its own timeline over these frames.
		if int(st.get("seq_index")) >= 0 or bool(st.get("armed")):
			st.call("_finish")
		st.call("begin_cinematic")
		for k in seqs.size():
			var length: float = float(seqs[k]["length"])
			for f in 4:
				st.call("play", k, length * 0.6)
				await _frames(1)
			_shoot("stories", "s%02d_%d_%s" % [i + 1, k + 1, String(seqs[k]["key"])])
		st.call("end_cinematic")
		_room.set_process(true)


## What the hall costs (vsync off; frame times between process_frame signals, as the Arboretum's
## perf runner measures): the views of the Arboretum's baseline (follow_up/arboretum.md section 7) that
## still exist here.
func _perf() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for v in [["door", 0.0, 14.0, 0.0], ["at_01", -3.7, 8.0, 90.0], ["at_02", 3.5, 1.0, -90.0], ["at_03", -3.5, -6.0, 90.0], ["at_oak", 0.0, -7.6, 0.0], ["back_door", 0.0, -19.0, 0.0]]:
		_go(float(v[1]), float(v[2]), float(v[3]), -10.0)
		await _frames(40)
		var times: Array = []
		var last: int = Time.get_ticks_usec()
		for i in 150:
			await process_frame
			var now: int = Time.get_ticks_usec()
			times.append((now - last) / 1000.0)
			last = now
		times.sort()
		print("CAPTURE perf %-10s frame median %.2f ms, 95%% %.2f ms" % [v[0], times[75], times[142]])
	Engine.max_fps = 60


## The back door's sign and its doorway.
func _door() -> void:
	_go(0.0, -18.0, 0.0, -2.0)
	await _frames(40)
	_shoot("door", "d01_sign_and_door")
	_go(0.0, -20.4, 0.0, 2.0)
	await _frames(40)
	_shoot("door", "d02_close")
