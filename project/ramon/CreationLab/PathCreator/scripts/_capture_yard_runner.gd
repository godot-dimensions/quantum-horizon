extends SceneTree

## PathCreator's yard (graphs/yard.tres, the Figma's B1 field map) drawn on the dev space's floor:
## from straight above at the sheet's framing, beside the sheet's own export; from the player at
## the entry; close up on the choice and on the hut's arrival; in the WALK look; and the frame time
## with the whole yard on screen. To res://smoke_test_output/pathcreator/yard/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_yard res://ramon/CreationLab/PathCreator/scripts/_capture_yard_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/yard/"
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")

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


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _shot(what: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


func _top(cx: float, cz: float, height_m: float) -> void:
	_cam.set("projection_type", 0)
	_cam.set("orthographic_size", height_m)
	_cam.global_position = Vector4(cx, 30.0, cz, 0.0)
	_cam.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(3.0)
	var net: Node = _g.get_node("YardNetwork")
	var notes: PackedStringArray = net.call("notes")
	_check(notes.is_empty(), "the yard graph is sound %s" % str(notes))
	var boxes: int = 0
	for c in net.get_children():
		if c is MeshInstance4D:
			boxes += 1
	print("yard boxes: %d" % boxes)
	# From the player at the entry, looking in.
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(-24.5, 0.05, -34.0, 0.0)
	p.set("_facing", -PI * 0.5)
	var rig: Node = p.get_node_or_null("CameraRig")
	if rig != null:
		rig.set("yaw", -PI * 0.5)
		rig.call("_apply")
	await _wait(1.0)
	await _shot("player_entry")
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	p.visible = false
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(_cam)
	_cam.current = true
	# The whole yard, framed as the sheet frames it (46 x 30 m and a margin).
	_top(0.0, -35.0, 33.0)
	await _wait(0.6)
	await _shot("top_yard")
	# Close: the equal choice and its two turns; the hut's arrival and frame.
	_top(-17.0, -34.0, 9.0)
	await _wait(0.3)
	await _shot("top_choice")
	_top(-12.0, -41.0, 9.0)
	await _wait(0.3)
	await _shot("top_hut")
	_top(-5.0, -40.0, 14.0)
	await _wait(0.3)
	await _shot("top_survey_curve")
	# The WALK look.
	_g.call("set_look", "walk")
	await _wait(0.3)
	_top(0.0, -35.0, 33.0)
	await _wait(0.3)
	await _shot("top_yard_walk")
	_g.call("set_look", "dev")
	# The player's view down the corridor, perspective, a little above.
	_cam.set("projection_type", 1)
	_cam.global_position = Vector4(-19.0, 2.4, -30.0, 0.0)
	_cam.global_basis = Mark.basis_looking(_cam.global_position, Vector4(-8.0, 0.0, -30.0, 0.0))
	await _wait(0.3)
	await _shot("corridor_view")
	# Cost with the whole yard on screen.
	_top(0.0, -35.0, 33.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var on_ms: float = await _frame_ms()
	net.visible = false
	var off_ms: float = await _frame_ms()
	net.visible = true
	print("frame with the yard's paths %.3f ms, without %.3f ms" % [on_ms, off_ms])
	print("YARD %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)


func _frame_ms() -> float:
	await _wait(0.5)
	var n: int = 0
	var t0: int = Time.get_ticks_usec()
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		n += 1
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(maxi(n, 1))
