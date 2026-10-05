extends SceneTree

## The goat room after the "one room, one style" pass: both blue walls straight on (the live 4D
## Basics text and the research wall on the first wall on the right), the two together from the
## entrance, the loft builder on the floating desk, the "About the tool" panel, the smaller title card,
## the tuner's SUN section (and that its turn moves the key light), and the live lesson text naming
## the chicken after 2. To res://smoke_test_output/goat_room/batch/.
##
##   LabChambers/scripts/lab_run.sh windowed batch res://ramon/LabChambers/scripts/_capture_room_batch_runner.gd

const SCENE := "res://ramon/LabChambers/goat_room.tscn"
const OUT := "res://smoke_test_output/goat_room/batch/"
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


func _look(from: Vector3, to: Vector3) -> void:
	_cam.global_position = Vector4(from.x, from.y, from.z, 0.0)
	_cam.global_basis = Mark.basis_looking(_cam.global_position, Vector4(to.x, to.y, to.z, 0.0))


func _hud(on: bool) -> void:
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = on


func _save_vp(vp: SubViewport, what: String) -> void:
	if vp != null:
		vp.get_texture().get_image().save_png(OUT + what + ".png")
		print("screen ", what)


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.5)
	for nm in ["tuner", "tuner_room2"]:
		(_g.get(nm) as Control).visible = false
	_g.get_node("Room").call("set_mood", "dark", true, false)
	var sc: Node = _g.get_node("Showcase")
	var room: Node = _g.get_node("GoatRoom")
	var outline: PackedVector2Array = room.get("outline")
	_check(String((room.get("edge_codes") as Dictionary).get(4, "")) == "blue" and not (room.get("edge_codes") as Dictionary).has(3), "the blue wall is the first wall on the right")
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(_cam)
	_cam.current = true
	_hud(false)
	# Both walls from the entrance.
	_look(Vector3(0.0, 3.4, 8.4), Vector3(0.0, 3.2, -4.0))
	await _wait(0.6)
	await _shot("entrance_both_walls")
	# The research wall straight on (edge 4, x = 10, facing -x).
	var a4: Vector2 = outline[4]
	var e4: Vector2 = outline[5]
	var m4: Vector2 = (a4 + e4) * 0.5
	_look(Vector3(m4.x - 7.5, 4.45, m4.y), Vector3(m4.x, 4.45, m4.y))
	await _wait(0.8)
	await _shot("research_wall_straight")
	# The lesson straight on (edge 1).
	var a1: Vector2 = outline[1]
	var e1: Vector2 = outline[2]
	var d1: Vector2 = (e1 - a1).normalized()
	var in1 := Vector2(-d1.y, d1.x)
	var m1: Vector2 = (a1 + e1) * 0.5
	var eye1: Vector2 = m1 + in1 * 7.0
	_look(Vector3(eye1.x, 4.4, eye1.y), Vector3(m1.x, 4.4, m1.y))
	await _wait(0.6)
	await _shot("lesson_goat")
	var live_vp: SubViewport = null
	for c in room.get_children():
		if c is SubViewport and String(c.name).begins_with("LiveText"):
			live_vp = c
	_check(live_vp != null, "the lesson is printed live")
	_save_vp(live_vp, "lesson_print_goat")
	# The floating desk's loft builder screen.
	_save_vp((_g.get_node("ResearchPanel") as Node).get("_vp"), "desk_loft_builder_a")
	await _wait(2.6)
	_save_vp((_g.get_node("ResearchPanel") as Node).get("_vp"), "desk_loft_builder_b")
	var desk: Node4D = _g.get_node("ResearchPanel")
	var fwd: Vector4 = desk.global_basis * Vector4(0, 0, 1, 0)
	var dp: Vector4 = desk.global_position + fwd * 2.6
	_look(Vector3(dp.x, 2.4, dp.z), Vector3(desk.global_position.x, 1.0, desk.global_position.z))
	await _wait(0.4)
	await _shot("desk_close")
	# The player's own view: the title card, the about panel, the tuner's SUN section.
	_cam.current = false
	_hud(true)
	var p: CharacterBody4D = _g.get("player")
	var rig: Node = p.get_node("CameraRig")
	p.global_position = Vector4(0.8, 0.05, 5.5, 0.0)
	rig.set("yaw", -0.4)
	rig.call("_apply")
	var until: int = Time.get_ticks_msec() + 20000
	while int(sc.get("seq_index")) < 0 and Time.get_ticks_msec() < until:
		await process_frame
	while int(sc.get("seq_index")) != 1:
		sc.call("skip")
		await _wait(0.05)
	await _wait(2.2)
	await _shot("title_card_and_callout")
	p.global_position = Vector4(-7.6, 0.05, 3.0, 0.0)
	rig.set("yaw", PI * 0.5)
	rig.call("_apply")
	await _wait(1.0)
	if not bool(_g.get("_desk_open")):
		_g.call("toggle_desk")
	await _wait(0.8)
	await _shot("about_the_tool")
	_g.call("toggle_desk")
	var tuner: Control = _g.get("tuner")
	tuner.visible = true
	var key: Node4D = _g.get_node("Room").get("_key")
	var before: Projection = key.basis if key != null else Projection.IDENTITY
	tuner.call("_write_value", "sun_turn", 120.0)
	await _wait(0.4)
	var after: Projection = key.basis if key != null else Projection.IDENTITY
	_check(key != null and before.z.distance_to(after.z) > 0.05, "the tuner's sun turn moves the key light")
	await _shot("tuner_sun")
	tuner.visible = false
	# 2: the chicken; the lesson names it.
	_g.call("pick", 1)
	await _wait(3.6)
	_cam.current = true
	_hud(false)
	_look(Vector3(eye1.x, 4.4, eye1.y), Vector3(m1.x, 4.4, m1.y))
	await _wait(0.5)
	await _shot("lesson_chicken")
	_save_vp(live_vp, "lesson_print_chicken")
	print("BATCH %s: %d failed, %.1f s" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size(), (Time.get_ticks_msec() - started) / 1000.0])
	for f in _fails:
		print("  failed: ", f)
	quit(0 if _fails.is_empty() else 1)
