extends SceneTree

## The lab player's run and stop (kit_run_gait_4d.gd), filmed side on by a camera that tracks it:
## frames through a run cycle, then frames of the stop as the key is let go; prints how far a planted
## foot slides (it should not), the run's step rate and the flight time. Also a walk (ALT). To
## res://smoke_test_output/goat_room/run/.
##
##   LabChambers/scripts/lab_run.sh windowed run res://ramon/LabChambers/scripts/_capture_run_runner.gd

const SCENE := "res://ramon/LabChambers/creation_lab.tscn"
const OUT := "res://smoke_test_output/goat_room/run/"
const Mark := preload("res://ramon/LabKit/lab_mark_4d.gd")

var _g: Node
var _cam: Camera4D
var _p: CharacterBody4D


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _shot(what: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")


func _track() -> void:
	var x: float = _p.global_position.x
	_cam.global_position = Vector4(x, 1.05, 8.75, 0.0)
	_cam.global_basis = Mark.basis_looking(_cam.global_position, Vector4(x, 0.95, 5.2, 0.0))


## Runs for `seconds` with `key` held (none for a plain run), photographing every `every` seconds
## after `settle` seconds, then lets go and photographs the stop. Prints the foot slip.
func _pass(tag: String, key: Key, seconds: float, every: float, settle: float) -> void:
	_p.global_position = Vector4(-7.8, 0.05, 5.2, 0.0)
	_p.linear_velocity = Vector4.ZERO
	var rig: Node = _p.get_node("CameraRig")
	rig.set("yaw", 0.0)
	rig.call("_apply")
	for i in 20:
		_track()
		await process_frame
	if key != KEY_NONE:
		var e := InputEventKey.new()
		e.keycode = key
		e.physical_keycode = key
		e.pressed = true
		Input.parse_input_event(e)
	Input.action_press(&"move_right")
	var avatar: Node4D = _p.get_node("Avatar")
	var gait: Node = _p.get_node("Gait")
	var t: float = 0.0
	var last: int = Time.get_ticks_msec()
	var next_shot: float = settle
	var n: int = 0
	var slip_max: float = 0.0
	var plant_at := Vector4.INF
	var air_frames: int = 0
	var frames: int = 0
	while t < seconds:
		await process_frame
		var now: int = Time.get_ticks_msec()
		t += float(now - last) / 1000.0
		last = now
		_track()
		# A foot is planted while its sole is on the floor: how far does it move meanwhile?
		var ankle: Node4D = avatar.get("ankle_left")
		var ap: Vector4 = ankle.global_position
		var sole_y: float = ap.y - _p.global_position.y
		if t > settle:
			frames += 1
			var down_l: bool = sole_y < 0.135
			var down_r: bool = ((avatar.get("ankle_right") as Node4D).global_position.y - _p.global_position.y) < 0.135
			if not down_l and not down_r:
				air_frames += 1
			if down_l:
				if plant_at == Vector4.INF:
					plant_at = ap
				slip_max = maxf(slip_max, Vector2(ap.x - plant_at.x, ap.z - plant_at.z).length())
			else:
				plant_at = Vector4.INF
		if t >= next_shot and n < 12:
			await _shot("%s_%02d" % [tag, n])
			n += 1
			next_shot += every
	print("%s: speed %.2f m/s, blend %.2f, planted foot slides at most %.3f m, both feet up %.0f%% of frames" % [tag, float(gait.get("speed")), float(gait.get("run_blend")), slip_max, 100.0 * float(air_frames) / maxf(float(frames), 1.0)])
	Input.action_release(&"move_right")
	if key != KEY_NONE:
		var u := InputEventKey.new()
		u.keycode = key
		u.physical_keycode = key
		Input.parse_input_event(u)
	# The stop.
	var ts: float = 0.0
	last = Time.get_ticks_msec()
	var k: int = 0
	while ts < 1.0:
		await process_frame
		var now2: int = Time.get_ticks_msec()
		ts += float(now2 - last) / 1000.0
		last = now2
		_track()
		if ts >= float(k) * 0.07 and k < 12:
			await _shot("%s_stop_%02d" % [tag, k])
			k += 1


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	(_g.get_node("Showcase") as Node4D).visible = false
	_p = _g.get("player")
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_cam.set("field_of_view_4d", 40.0)
	_g.add_child(_cam)
	_cam.current = true
	await _pass("run", KEY_NONE, 4.0, 0.045, 1.3)
	await _pass("walk", KEY_ALT, 4.0, 0.08, 1.5)
	quit(0)
