extends SceneTree

## THE DREAM SHIFTER, PLAYED THROUGH (follow_up/pen_dream_shifter.md): the pillar from the start, its prompt, the talk
## (F, Space, 1), the live shift, the explainer (Space before 5 s does nothing, after it closes it), the big prompt in
## the middle and docked by the Look row, I and the praise, the orb's second talk, and the prompt coming unasked when
## you walk past the orb. A frame at each beat in smoke_test_output/dream_shifter/<look>/.
##
##   lab_run.sh windowed ds_verify res://ramon/chickenpen/discovery/dream_shifter/_verify_shifter_runner.gd [look=dev|art]

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const Guide := preload("res://ramon/chickenpen/discovery/dream_shifter/pen_look_guide_4d.gd")

var _room: Node
var _player: CharacterBody4D
var _rig: Node4D
var _out: String = "res://smoke_test_output/dream_shifter/"
var _fails: int = 0
var _t0: int = 0


class RunnerGuard extends Node:
	func _input(event: InputEvent) -> void:
		if event.has_meta(&"runner"):
			return
		if event is InputEventKey or event is InputEventMouse or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 300000:
		print("SHIFTER: gave up after 300 s")
		return true
	return false


func _check(ok: bool, what: String) -> void:
	print(("  PASS  " if ok else "  FAIL  ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	for i in 100000:
		if Time.get_ticks_msec() >= until:
			break
		await process_frame


func _save(name: String) -> void:
	_tidy_hud()
	await _frames(1)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(_out + name + ".png"))
	print("FRAME %s" % name)


func _place(p: Vector4, yaw: float, pitch: float = -8.0, dist: float = 6.0) -> void:
	_player.global_position = p
	_player.linear_velocity = Vector4.ZERO
	SliceAngles.tilt(_rig, 0.0, 0.0, deg_to_rad(yaw))
	_rig.set("pitch", deg_to_rad(pitch))
	_rig.set("distance", dist)
	_rig.set("_zoom_target", dist)
	_rig.call("_apply")


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	down.set_meta(&"runner", true)
	Input.parse_input_event(down)
	await _frames(2)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	up.set_meta(&"runner", true)
	Input.parse_input_event(up)
	await _frames(2)


func _run() -> void:
	var look_name: String = "dev"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("look="):
			look_name = a.substr(5)
	OS.set_environment("PEN_LOOK", look_name)
	_out += look_name + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	print("SHIFTER (look %s)" % look_name)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	var guard := RunnerGuard.new()
	guard.name = "RunnerGuard"
	root.add_child(guard)
	await _frames(90)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_player = _room.get_node("Player") as CharacterBody4D
	_rig = _player.get_node("CameraRig") as Node4D
	var guide: Node = _room.get_node_or_null("Systems/LookGuide")
	var shifter: Node4D = _room.get_node_or_null("World/DreamShifter") as Node4D
	var look: Node = _room.get_node_or_null("Systems/Look")
	var talk: Node = _room.get_node_or_null("Systems/ShifterTalk")
	_check(guide != null and shifter != null and look != null and talk != null, "the guide, the pillar, the look and the talk are in the pen")
	if guide == null or shifter == null or look == null or talk == null:
		quit(1)
		return
	guide.set("verbose", true)
	var prompt: Node = guide.get_node("LookPromptLayer/LookPrompt")
	var explainer: Node = guide.get_node("LookShowLayer/Explainer")
	await _wait(2.0)
	_quiet_tutor()

	# --- From the start, down the road: the pillar in view ---------------------------------------------------------
	_place(Vector4(24.9, 1.2, 19.6, 0.0), 180.0, -4.0, 5.5)
	await _wait(0.8)
	await _save("01_start_road")
	_place(Vector4(24.9, 1.2, 25.0, 0.0), 160.0, -10.0, 4.5)
	await _wait(1.2)
	await _save("02_walking_up")

	# --- At the pillar: the prompt, F, the talk ----------------------------------------------------------------------
	_place(Vector4(23.2, 1.2, 29.0, 0.0), 90.0, -8.0, 3.6)
	await _wait(1.0)
	await _save("03_at_pillar_prompt")
	var was_dev: bool = bool(look.get("dev"))
	await _key(KEY_F)
	await _wait(1.6)
	_check(bool(talk.call("is_running")), "F started the talk")
	await _save("04_talk_you")
	await _key(KEY_SPACE)
	await _wait(1.6)
	await _save("05_talk_i_am")
	await _key(KEY_SPACE)
	await _wait(2.4)
	await _save("06_talk_question")
	await _key(KEY_1)
	await _wait(2.2)
	await _save("07_talk_check_it_out")
	await _key(KEY_SPACE)
	# --- The shift --------------------------------------------------------------------------------------------------
	await _wait(1.0)
	await _save("08_shift_sweep")
	await _wait(1.0)
	_check(bool(look.get("dev")) != was_dev, "the world shifted (dev %s to %s)" % [str(was_dev), str(look.get("dev"))])
	await _save("09_shift_after")
	await _wait(2.0)
	_check(bool(explainer.call("is_open")), "the explainer opened after the shift")
	await _save("10_explainer_open")
	await _key(KEY_SPACE)
	await _wait(0.4)
	_check(bool(explainer.call("is_open")), "Space before 5 s does not close it")
	await _wait(1.0)
	await _save("11_explainer_dev")
	await _wait(2.2)
	await _save("12_explainer_art")
	await _wait(3.6)
	await _save("13_explainer_all")
	await _wait(2.5)
	await _save("14_explainer_next_place")
	await _key(KEY_SPACE)
	await _wait(0.8)
	_check(not bool(explainer.call("is_open")), "Space after 5 s closes it")
	_check(Guide.seen, "the explainer counts as seen")
	_check(_player.get("input_enabled") == true, "the player can move again")

	# --- Your turn: the prompt, I, the praise ----------------------------------------------------------------------------
	await _wait(0.6)
	_check(bool(prompt.call("showing")), "the big prompt is up")
	await _save("15_prompt_centre")
	await _wait(3.2)
	await _save("16_prompt_docked")
	var before_i: bool = bool(look.get("dev"))
	await _key(KEY_I)
	await _wait(0.9)
	_check(bool(look.get("dev")) != before_i, "I switched the look")
	_check(Guide.praised, "the first press of I was praised")
	await _save("17_praise")
	await _wait(1.6)
	await _save("18_praise_after")
	_check(not bool(prompt.call("showing")), "the prompt went with the switch")

	# --- The orb again -----------------------------------------------------------------------------------------------
	await _wait(4.5)
	_place(Vector4(23.2, 1.2, 29.0, 0.0), 90.0, -8.0, 3.6)
	await _wait(0.8)
	await _key(KEY_F)
	await _wait(1.8)
	await _save("19_talk_again")
	await _key(KEY_3)
	await _wait(1.5)

	# --- The pillar close, in both looks -----------------------------------------------------------------------------------
	_place(Vector4(23.6, 1.2, 30.4, 0.0), 120.0, -2.0, 2.6)
	await _wait(1.2)
	await _save("20_pillar_close_a")
	await _key(KEY_I)
	await _wait(1.2)
	await _save("21_pillar_close_b")

	# --- Walking past without touching it: the prompt comes unasked --------------------------------------------------------
	guide.call("reset")
	_place(Vector4(24.9, 1.2, 27.0, 0.0), 180.0, -6.0, 5.0)
	await _wait(0.6)
	_place(Vector4(24.9, 1.2, 37.5, 0.0), 180.0, -6.0, 5.0)
	await _wait(0.8)
	_check(not bool(prompt.call("showing")), "not yet: 9 m on")
	_place(Vector4(7.3, 1.2, 37.1, 0.0), 90.0, -6.0, 5.0)
	await _wait(0.8)
	_check(bool(prompt.call("showing")), "walked on past the orb, the prompt comes unasked")
	await _wait(3.6)
	await _save("22_prompt_unasked")

	print("SHIFTER: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	quit(0 if _fails == 0 else 1)


## Test panels out of the frames (the murmuration readout, the paths panel, the camera picker, the controls card): at
## 720p and the pen's UI size they cover most of the screen. Only hidden, never changed.
func _tidy_hud() -> void:
	for node in _room.find_children("*", "Control", true, false):
		var s: Script = node.get_script() as Script
		if s == null:
			continue
		var f: String = s.resource_path.get_file()
		if f in ["flock_stats_panel_4d.gd", "pen_paths_panel_4d.gd", "pen_camera_picker_4d.gd", "pen_controls_4d.gd"]:
			(node as Control).visible = false


## The Tutor's opening hints marked as shown, so they do not hold the screen while the hints under test want it.
func _quiet_tutor() -> void:
	var tutor: Node = _room.get_node_or_null("Systems/Tutor")
	if tutor == null:
		return
	var shown: Dictionary = tutor.get("_shown")
	for k in ["move", "ana", "moved", "home", "deliver"]:
		shown[k] = true
	tutor.set("_showing", "")
	var label: Label = _room.get_node_or_null("UI/Hint") as Label
	if label != null:
		label.text = ""
