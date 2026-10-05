extends SceneTree

## Round three: the path ends (arrows sliding under the line) and the corner ball at the first
## crossroad, close and over time; the story's radius, that it plays once and stops, that a click and
## the arrow keys start and step it; the bigger research page; the pedestal's text on its right; the
## black palette (B). To res://smoke_test_output/goat_room/round3/.
##
##   LabChambers/scripts/lab_run.sh windowed round3 res://ramon/LabChambers/scripts/_capture_round3_runner.gd

const SCENE := "res://ramon/LabChambers/creation_lab.tscn"
const OUT := "res://smoke_test_output/goat_room/round3/"
const Mark := preload("res://ramon/LabKit/lab_mark_4d.gd")

var _g: Node
var _cam: Camera4D
var _fails: Array = []


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
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _look(from: Vector4, to: Vector4) -> void:
	_cam.global_position = from
	_cam.global_basis = Mark.basis_looking(from, to)


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


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	var p: CharacterBody4D = _g.get("player")
	await _wait(4.0)
	var sc: Node = _g.get_node("Showcase")
	# Out in the corridor the story waits.
	p.global_position = Vector4(0.0, 0.05, 12.5, 0.0)
	await _wait(3.0)
	_check(int(sc.get("seq_index")) < 0, "the story waits while you are out of range")
	_check(not bool((_g.get("tuner") as Control).visible), "the dev panel starts hidden")
	# Near: it starts.
	p.global_position = Vector4(0.0, 0.05, 6.0, 0.0)
	var until: int = Time.get_ticks_msec() + 15000
	while int(sc.get("seq_index")) < 0 and Time.get_ticks_msec() < until:
		await process_frame
	_check(int(sc.get("seq_index")) >= 0, "coming near the pedestal starts the story")
	# The arrow keys step it.
	var before: int = int(sc.get("seq_index"))
	await _key(KEY_RIGHT)
	await _wait(0.2)
	_check(int(sc.get("seq_index")) == before + 1, "the right arrow goes on a part (%d to %d)" % [before, int(sc.get("seq_index"))])
	await _key(KEY_LEFT)
	await _wait(0.2)
	_check(int(sc.get("seq_index")) == before, "the left arrow goes back (%d)" % int(sc.get("seq_index")))
	# To the last part, and let it run out: it stops and stays stopped.
	while int(sc.get("seq_index")) != 4:
		sc.call("skip")
		await _wait(0.05)
	var t_end: int = Time.get_ticks_msec() + 14000
	while int(sc.get("seq_index")) >= 0 and Time.get_ticks_msec() < t_end:
		await process_frame
	_check(int(sc.get("seq_index")) < 0, "after its last part the story stops")
	await _wait(10.0)
	_check(int(sc.get("seq_index")) < 0, "and stays stopped (10 s later)")
	await _shot("story_stopped_player_view")
	sc.call("skip")
	await _wait(0.4)
	_check(int(sc.get("seq_index")) == 0, "a click starts it again from its first part")
	# The desk's pop-up: open it, step with the arrows and a click.
	p.global_position = Vector4(-7.6, 0.05, 3.0, 0.0)
	var rig: Node = p.get_node("CameraRig")
	rig.set("yaw", PI * 0.5)
	rig.call("_apply")
	await _wait(0.8)
	_g.call("toggle_desk")
	await _wait(0.6)
	var dp: Node = _g.get("data_panel")
	var s0: int = int(dp.get("step_sel"))
	await _key(KEY_RIGHT)
	await _wait(0.2)
	_check(int(dp.get("step_sel")) == (s0 + 1) % 4, "with the data open the right arrow picks the next step")
	await _shot("about_step_2")
	await _key(KEY_RIGHT)
	await _wait(0.3)
	await _shot("about_step_3")
	_g.call("toggle_desk")
	await _wait(0.4)
	# Room 2: no text.
	p.global_position = Vector4(0.0, 0.05, -24.0, 0.0)
	await _wait(0.6)
	_check(not bool(_g.get("presenter").get("active")), "no story text in Room 2")
	await _shot("room2_no_text")
	p.global_position = Vector4(0.0, 0.05, 12.5, 0.0)
	await _wait(0.3)
	# Its own camera now.
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(_cam)
	_cam.current = true
	for i in 4:
		_look(Vector4(1.4, 2.6, 6.6, 0), Vector4(0.6, 0.0, 3.3, 0))
		await _wait(0.33)
		await _shot("crossroad_%d" % i)
	for i in 3:
		_look(Vector4(4.2, 2.8, 5.8, 0), Vector4(5.6, 0.0, 3.1, 0))
		await _wait(0.4)
		await _shot("pad_end_%d" % i)
	# The research page straight on, and the pedestal's text on its right.
	_look(Vector4(-4.2, 1.9, 5.6, 0), Vector4(-8.6, 0.9, 2.8, 0))
	await _wait(0.4)
	await _shot("desk_black")
	_look(Vector4(-1.8, 4.2, 4.0, 0), Vector4(-8.5, 4.2, -5.0, 0))
	await _wait(0.4)
	await _shot("lesson_ladder")
	_look(Vector4(1.6, 4.6, 3.0, 0), Vector4(10.0, 4.6, 3.0, 0))
	await _wait(0.6)
	await _shot("research_wall")
	_look(Vector4(6.2, 1.2, -1.5, 0), Vector4(0.0, 0.5, -1.5, 0))
	await _wait(0.4)
	await _shot("pedestal_right_side")
	# B: the black palette.
	_look(Vector4(0.0, 3.0, 8.4, 0), Vector4(0.0, 1.6, -3.0, 0))
	await _wait(0.4)
	await _shot("palette_grey")
	await _key(KEY_B)
	await _wait(0.6)
	_check(String(load("res://ramon/LabChambers/kit/kit_style.gd").palette) == "black", "B turns the palette black")
	await _shot("palette_black")
	_look(Vector4(0.5, 9.4, 4.5, 0), Vector4(0.5, 0.0, -1.0, 0))
	await _wait(0.4)
	await _shot("palette_black_above")
	_look(Vector4(-1.8, 4.2, 4.0, 0), Vector4(-8.5, 4.2, -5.0, 0))
	await _wait(0.4)
	await _shot("palette_black_lesson")
	await _key(KEY_B)
	await _wait(0.4)
	print("ROUND3 %s: %d failed, %.1f s" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size(), (Time.get_ticks_msec() - started) / 1000.0])
	for f in _fails:
		print("  failed: ", f)
	quit(0 if _fails.is_empty() else 1)
