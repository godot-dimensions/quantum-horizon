extends SceneTree

## The goat room, walked and photographed in both moods, to
## res://smoke_test_output/goat_room/<nn>_<mood>_<what>.png; checks the cinematic, the slice, the
## turn and E as it goes.
##
##   LabChambers/scripts/lab_run.sh windowed goat_room res://ramon/LabChambers/scripts/_capture_goat_room_runner.gd

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


## Stands the player at x, z looking `face` (0 is -Z); the pitch is the room's own camera pitch
## unless one is given.
func _put(x: float, z: float, face: float, pitch_deg: float = NAN, turn: float = PI) -> void:
	if not is_finite(pitch_deg):
		pitch_deg = float(_g.get("camera_pitch_degrees"))
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(x, 0.05, z, 0.0)
	p.linear_velocity = Vector4.ZERO
	p.set("_facing", face + turn)
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
	var tuner2: Control = _g.get("tuner_room2")
	tuner2.visible = false
	for m in ["dark", "bright"]:
		await _set_mood(m)
		_put(0.0, 15.2, 0.0)
		await _wait(0.3)
		await _shot("entrance")
		_put(0.0, 8.0, 0.0)
		await _wait(0.3)
		await _shot("arrival")
		_put(0.0, 6.4, 0.0)
		await _wait(0.3)
		await _shot("in_the_room")
		_put(-2.6, 2.4, PI * 0.25)
		await _wait(0.3)
		await _shot("lesson")
		_put(3.4, 3.0, -PI * 0.25)
		await _wait(0.3)
		await _shot("screens")
		_put(0.0, -8.2, 0.0)
		await _wait(0.4)
		await _shot("back_door")
		# Room 2, lit by its one big spot: from just inside the door, and from a corner.
		_put(0.0, -15.0, 0.0)
		await _wait(0.4)
		await _shot("room2")
		_put(11.0, -38.0, PI * 0.78)
		await _wait(0.4)
		await _shot("room2_corner")
		_put(0.5, 6.5, 1.107)
		await _wait(0.8)
		await _shot("console")
		_put(-7.6, 3.0, PI * 0.5)
		await _wait(1.0)
		_check(not bool(_g.get("data_panel").get("shown")), "the data waits for the engage key")
		_check(bool(_g.get("prompt").get("shown")), "the key prompt pops up at the panel")
		await _shot("at_the_panel")
		await _key(KEY_E)
		if not bool(_g.get("_desk_open")):
			print("note: the key did not reach the room in this window; toggling directly")
			_g.call("toggle_desk")
		await _wait(0.6)
		_check(bool(_g.get("data_panel").get("shown")), "E brings up the data panel")
		await _shot("desk")
		# The console's screen, close, from high over your shoulder, the panel put aside.
		var rig: Node = (_g.get("player") as Node).get_node("CameraRig")
		_g.get("data_panel").visible = false
		rig.set("_zoom_target", 2.2)
		rig.set("distance", 2.2)
		rig.set("pivot_height", 2.6)
		rig.set("_home_pivot", 2.6)
		rig.set("pitch", deg_to_rad(-38.0))
		rig.call("_apply")
		await _wait(0.6)
		await _shot("console_close")
		var panel: Node = _g.get_node_or_null("ResearchPanel")
		var vp: SubViewport = panel.get("_vp") if panel != null else null
		if vp != null:
			vp.get_texture().get_image().save_png("%spanel_screen_%s.png" % [OUT, _mood])
		_g.get("data_panel").visible = true
		for k in [["_zoom_target", "camera_distance"], ["distance", "camera_distance"], ["pivot_height", "camera_height"], ["_home_pivot", "camera_height"]]:
			rig.set(k[0], _g.get(k[1]))
		_put(0.0, 6.0, 0.0)
		await _wait(1.2)
	tuner.visible = true
	tuner2.visible = true
	await _shot("with_the_sliders")
	tuner.visible = false
	tuner2.visible = false
	# The player: from the front, close, and walking past side on.
	var rig: Node = (_g.get("player") as Node).get_node("CameraRig")
	rig.set("_zoom_target", 3.4)
	rig.set("distance", 3.4)
	rig.set("pivot_height", 1.15)
	rig.set("_home_pivot", 1.15)
	for v in [["player_front", 0.0], ["player_side", PI * 0.5], ["player_back", PI]]:
		_put(3.0, 4.0, -PI * 0.25, -4.0, float(v[1]))
		await _wait(0.8)
		await _shot(String(v[0]))
	rig.set("_zoom_target", float(_g.get("camera_distance")))
	rig.set("pivot_height", float(_g.get("camera_height")))
	rig.set("_home_pivot", float(_g.get("camera_height")))
	_put(-6.0, 5.8, 0.0)
	await _wait(0.6)
	Input.action_press(&"move_right")
	await _wait(0.9)
	for i in 4:
		await _shot("walking_%d" % i)
		await _wait(0.13)
	Input.action_release(&"move_right")
	await _wait(0.6)
	await _set_mood("dark")
	_put(2.6, 5.2, 0.37)
	await _wait(10.0)
	print("loop state: t %.1f touched %.1f looping %s cinematic %s" % [float(sc.get("_t")), float(sc.get("_touched_at")), str(sc.get("_looping")), str(sc.get("cinematic"))])
	_check(bool(sc.get("_looping")), "the goat plays its sequence on its own")
	for i in 3:
		await _wait(3.5)
		await _shot("loop_%d" % i)
	_put(2.6, 5.2, 0.37)
	await _wait(0.4)
	var before: int = int(sc.get("slice_index"))
	for i in 3:
		await _click(MOUSE_BUTTON_WHEEL_UP)
	if int(sc.get("slice_index")) == before:
		print("note: the wheel needs a captured mouse, which this window cannot have; slicing directly")
		for i in 3:
			sc.call("step_slice", 1)
	await _wait(0.8)
	_check(int(sc.get("slice_index")) == 7, "the wheel slices (%d)" % int(sc.get("slice_index")))
	await _shot("sliced")
	# A right drag turns the slice through W: the corner view's plane tilts round the goat.
	sc.call("turn_by", 0.0, 0.7)
	await _wait(0.8)
	await _shot("turned_zw")
	sc.call("turn_by", 0.8, 0.0)
	await _wait(0.8)
	await _shot("turned_both")
	for i in 3:
		await _key(KEY_E)
		await _wait(0.3)
	await _shot("added_balls")
	print("GOAT ROOM %s: %d failed, %.1f s" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size(), (Time.get_ticks_msec() - started) / 1000.0])
	for f in _fails:
		print("  failed: ", f)
	quit(0 if _fails.is_empty() else 1)
