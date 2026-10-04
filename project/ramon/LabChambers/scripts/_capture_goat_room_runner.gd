extends SceneTree

## The goat room, walked and photographed in both moods, to
## res://smoke_test_output/goat_room/<nn>_<mood>_<what>.png; checks the cinematic, the slice, the
## turn and E as it goes.
##
##   CreationLab/scripts/lab_run.sh windowed goat_room res://ramon/LabChambers/scripts/_capture_goat_room_runner.gd

const SCENE := "res://ramon/LabChambers/goat_room.tscn"
const OUT := "res://smoke_test_output/goat_room/"

var _g: Node
var _n: int = 0
var _fails: Array = []
var _mood: String = "dark"


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(what: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s%02d_%s_%s.png" % [OUT, _n, _mood, what])
	print("shot ", what)
	_n += 1


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _put(x: float, z: float, face: float, pitch_deg: float = 4.0) -> void:
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(x, 0.05, z, 0.0)
	p.linear_velocity = Vector4.ZERO
	p.set("_facing", face + PI)
	var rig: Node = p.get_node_or_null("CameraRig")
	rig.set("yaw", face)
	rig.set("pitch", deg_to_rad(pitch_deg))
	rig.call("_apply")


func _click(button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var u := InputEventMouseButton.new()
	u.button_index = button
	Input.parse_input_event(u)
	await process_frame


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var u := InputEventKey.new()
	u.keycode = code
	u.physical_keycode = code
	Input.parse_input_event(u)
	await process_frame


func _set_mood(m: String) -> void:
	_mood = m
	_g.get_node("Room").call("set_mood", m, true, false)
	await _wait(0.6)


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(5.0)
	var sc: Node = _g.get_node("Showcase")
	var tuner: Control = _g.get("tuner")
	tuner.visible = false
	for m in ["dark", "bright"]:
		await _set_mood(m)
		_put(0.0, 15.2, 0.0, 6.0)
		await _wait(0.3)
		await _shot("entrance")
		_put(0.0, 8.0, 0.0, 2.0)
		await _wait(0.3)
		await _shot("arrival")
		_put(0.0, 4.0, 0.0, 0.0)
		await _wait(0.3)
		await _shot("in_the_room")
		_put(-1.0, 3.5, PI * 0.25, 2.0)
		await _wait(0.3)
		await _shot("lesson")
		_put(1.0, 3.5, -PI * 0.25, 2.0)
		await _wait(0.3)
		await _shot("screens")
		_put(-5.8, 6.0, 0.29, -2.0)
		await _wait(1.0)
		_check(bool(_g.get("data_panel").get("shown")), "the data panel comes up at the desk")
		await _shot("desk")
		_put(0.0, 6.0, 0.0, 0.0)
		await _wait(1.2)
	tuner.visible = true
	await _shot("with_the_sliders")
	tuner.visible = false
	await _set_mood("dark")
	_put(0.0, 3.4, 0.0, 2.0)
	await _wait(10.0)
	_check(bool(sc.get("_looping")), "the goat plays its sequence on its own")
	for i in 3:
		await _wait(3.5)
		await _shot("loop_%d" % i)
	_put(0.0, 4.6, 0.0, 2.0)
	await _wait(0.4)
	for i in 3:
		await _click(MOUSE_BUTTON_WHEEL_UP)
	await _wait(0.8)
	_check(int(sc.get("slice_index")) == 7, "the wheel slices (%d)" % int(sc.get("slice_index")))
	await _shot("sliced")
	for i in 3:
		await _key(KEY_E)
		await _wait(0.3)
	await _shot("added_balls")
	print("GOAT ROOM %s: %d failed, %.1f s" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size(), (Time.get_ticks_msec() - started) / 1000.0])
	for f in _fails:
		print("  failed: ", f)
	quit(0 if _fails.is_empty() else 1)
