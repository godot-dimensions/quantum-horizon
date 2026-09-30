extends SceneTree

## The murmuration in the pen, windowed: what it looks like, whether the 4D shortcut draws
## birds where the 4D engine would, and what it costs a frame. Saves
## res://smoke_test_output/flock_<n>_<view>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/scripts/_capture_flock_runner.gd -- count=300
##
## CALIBRATION. flock_bird.gdshader moves each bird into the camera's frame and cuts it at
## the slice itself instead of going through the engine. Four birds are pinned in a row in
## front of a camera, 0, 0.5, 0.9 and 1.1 of a bird's W depth off the slice, and under each
## a real 4D box (BoxTetraMesh4D) exactly that deep in W at the same w. Drawn right, each
## bird sits over its box, the birds shrink towards the edge of their depth, and the fourth
## bird and box are both gone. Then the same with the slice turned 25 degrees into W.
##
## TIMING. Vsync off, no frame cap (lofting_gotchas.md), and the flock switched on and off
## in alternating blocks of 40 frames, the first 10 of each block thrown away. Not frame by
## frame: the GPU runs a frame or two behind the CPU, so a cost switched on in one frame
## lands in the next ones, and alternate-frame toggling booked the flock a NEGATIVE cost.
## Blocks still beat two separate runs, whose drift (1-2 ms) swamps the difference.

const VIEWS := ["spawn", "below", "far_side", "near", "sequence_0", "sequence_1", "sequence_2", "sequence_3"]

var _room: Node
var _flock: Node4D
var _cam: Camera4D
var _count: int = 300
var _backend: int = 0
var _gpu_usec := PackedFloat64Array()
var _f := 0
var _t := 0.0
var _step := 0
var _view := 0
var _n := 0
var _pending := ""
var _boxes: Array[MeshInstance4D] = []
var _last_usec: int = 0
var _on_times := PackedFloat64Array()
var _off_times := PackedFloat64Array()
var _sim_usec := PackedFloat64Array()
var _flock_on: bool = true
var _block_frame: int = 0
const BLOCK := 40
const SETTLE := 10


func _initialize() -> void:
	root.unfocusable = true
	for arg in OS.get_cmdline_user_args():
		var kv: PackedStringArray = arg.split("=")
		if kv.size() == 2 and kv[0] == "count":
			_count = int(kv[1])
		elif kv.size() == 2 and kv[0] == "backend":
			_backend = int(kv[1])
	_room = load("res://ramon/chickenpen/chickenpen.tscn").instantiate()
	(_room.get_node("World/Flock") as Node4D).set("count", _count)
	(_room.get_node("World/Flock") as Node4D).set("backend", _backend)
	(_room.get_node("World/Flock") as Node4D).set("profile_gpu", true)
	# No debug keys. A test window can still catch keystrokes in the moment before it is
	# made unfocusable, and Ramon typing a "c" opened the cinema over this run (30 Sept).
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	root.add_child(_room)
	current_scene = _room


func _hide_hud(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		_hide_hud(child)


func _middle() -> Vector4:
	var pos: PackedVector4Array = _flock.call("positions")
	var sum := Vector4.ZERO
	for p in pos:
		sum += p
	return sum / maxf(float(pos.size()), 1.0)


func _aim(view: String) -> void:
	var m: Vector4 = _middle()
	var ground := Vector4(m.x, 0.0, m.z, m.w)
	match view:
		"spawn":
			(_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).make_current()
			return
		"below":
			_cam.global_position = ground + Vector4(14.0, 1.6, 10.0, 0.0)
		"near":
			_cam.global_position = m + Vector4(9.0, -2.0, 7.0, 0.0)
		_:
			_cam.global_position = Vector4(m.x + 55.0, 6.0, m.z + 40.0, m.w)
	_cam.look_at(m)
	_cam.make_current()


func _process(d: float) -> bool:
	_f += 1
	var now: int = Time.get_ticks_usec()
	if _step == 20:
		_time_frame(now)
		_last_usec = now
		return false
	_last_usec = now
	if _pending != "":
		root.get_texture().get_image().save_png("res://smoke_test_output/flock_%d_%s.png" % [_n, _pending])
		print("   saved flock_%d_%s.png" % [_n, _pending])
		_n += 1
		_pending = ""
		return false
	if _f < 30:
		return false
	_t += d
	match _step:
		0:
			_hide_hud(_room.get_node("UI"))
			_flock = _room.get_node("World/Flock") as Node4D
			_cam = Camera4D.new()
			_cam.name = "FlockCamera"
			_cam.set("rendering_engine_name", "Cross-section")
			_cam.set("field_of_view_3d", 0.96)
			_room.add_child(_cam)
			_step = 1
			_t = 0.0
		1:
			# Let the flock settle into its sweep over the roost before looking.
			if _t > 8.0:
				_step = 2
				_t = 0.0
		2:
			_aim(VIEWS[_view])
			var wait: float = 0.3 if VIEWS[_view].begins_with("sequence") else 0.6
			if _t > wait:
				_pending = VIEWS[_view] + ("_gpu" if bool(_flock.call("on_gpu")) else "")
				_view += 1
				_t = 0.0
				if _view >= VIEWS.size():
					_step = 3
		3:
			# Calibration pins birds from the CPU; on the GPU the shader drawing them is the
			# same one, so it is checked on a CPU run.
			if bool(_flock.call("on_gpu")):
				_step = 7
				return false
			_calibrate(0.0)
			_step = 4
			_t = 0.0
		4:
			if _t > 0.3:
				_pending = "calibrate_flat"
				_step = 5
				_t = 0.0
		5:
			_calibrate(deg_to_rad(25.0))
			_step = 6
			_t = 0.0
		6:
			if _t > 0.3:
				_pending = "calibrate_turned"
				_step = 7
				_t = 0.0
		7:
			for box in _boxes:
				box.queue_free()
			_boxes.clear()
			_flock.set("manual", false)
			_flock.call("respawn")
			_aim("far_side")
			if _t > 3.0:
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
				Engine.max_fps = 0
				_step = 20
				_t = 0.0
	return false


## Four pinned birds and four real 4D boxes, 0 / 0.5 / 0.9 / 1.1 of a bird's W depth off
## the slice of a camera up in the empty sky, the camera turned [param turn] into W.
func _calibrate(turn: float) -> void:
	_flock.set("manual", true)
	var depth: float = float(_flock.get("bird_w_radius")) * float(_flock.get("bird_scale"))
	var at := Vector4(0.0, 70.0, 60.0, 0.0)
	_cam.global_position = at
	_cam.global_basis = Basis4D.from_xw(turn)
	_cam.make_current()
	var side: Vector4 = _cam.global_basis * Vector4(1, 0, 0, 0)
	var ahead: Vector4 = _cam.global_basis * Vector4(0, 0, -1, 0)
	var ana: Vector4 = _cam.global_basis * Vector4(0, 0, 0, 1)
	var up := Vector4(0, 1, 0, 0)
	if _boxes.is_empty():
		var mat := TetraMaterial4D.new()
		mat.albedo_color = Color(0.85, 0.2, 0.15)
		for k in 4:
			var box := MeshInstance4D.new()
			var mesh := BoxTetraMesh4D.new()
			mesh.size = Vector4(0.14, 0.14, 0.14, depth * 2.0)
			box.mesh = mesh
			box.material_override = mat
			_room.add_child(box)
			_boxes.append(box)
	var offsets: Array = [0.0, 0.5, 0.9, 1.1]
	var total: int = int(_flock.get("count"))
	for k in total:
		# Everyone else out of sight, far below the ground.
		_flock.call("place", k, Vector4(0.0, -500.0, 0.0, 0.0), Vector4(0, 0, 1, 0))
	for k in 4:
		var spot: Vector4 = at + ahead * 2.6 + side * (-0.9 + 0.6 * float(k)) + ana * (depth * float(offsets[k]))
		_flock.call("place", k, spot + up * 0.22, ahead)
		_boxes[k].global_position = spot - up * 0.18
		_boxes[k].global_basis = Projection.IDENTITY


func _time_frame(now: int) -> void:
	if _last_usec > 0 and _block_frame >= SETTLE:
		var took: float = float(now - _last_usec) / 1000.0
		if _flock_on:
			_on_times.append(took)
			_sim_usec.append(float(_flock.get("last_step_usec")))
			_gpu_usec.append(float(_flock.get("gpu_usec")))
		else:
			_off_times.append(took)
	_block_frame += 1
	if _block_frame >= BLOCK:
		_block_frame = 0
		_flock_on = not _flock_on
		_flock.visible = _flock_on
		_flock.set("manual", not _flock_on)
	if _on_times.size() >= 450 and _off_times.size() >= 450:
		_report()
		quit()


func _report() -> void:
	var on: float = _mean(_on_times)
	var off: float = _mean(_off_times)
	var where: String = "GPU" if bool(_flock.call("on_gpu")) else "CPU"
	print("FLOCK TIMING  %d birds on the %s, 1280x720, vsync off, blocks of %d frames on and off" % [_count, where, BLOCK])
	print("   frame with the flock    %.3f ms   p95 %.3f" % [on, _p95(_on_times)])
	print("   frame without it        %.3f ms   p95 %.3f" % [off, _p95(_off_times)])
	print("   the flock costs         %.3f ms a frame; its step on the CPU %.3f ms, the compute on the GPU %.3f ms" % [on - off, _mean(_sim_usec) / 1000.0, _mean(_gpu_usec) / 1000.0])
	print("   video memory %.0f MB" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	print("CAPTURE FLOCK: done")


func _mean(v: PackedFloat64Array) -> float:
	var s: float = 0.0
	for x in v:
		s += x
	return s / maxf(float(v.size()), 1.0)


func _p95(v: PackedFloat64Array) -> float:
	var sorted := v.duplicate()
	sorted.sort()
	return sorted[int(sorted.size() * 0.95)]
