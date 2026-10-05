extends SceneTree

## The pedestal's hologram (kit_showcase hologram, the grid shader's dithered fade), from the front,
## three-quarters and close, in both moods, with the player beside it; then both blue walls from the
## entrance with the sun as it is and turned to -20 degrees (where both walls catch about the same
## light), and the fixed desk and lesson prints. To res://smoke_test_output/goat_room/holo/.
##
##   CreationLab/scripts/lab_run.sh windowed holo res://ramon/CreationLab/scripts/_capture_hologram_runner.gd

const SCENE := "res://ramon/CreationLab/creation_lab.tscn"
const OUT := "res://smoke_test_output/goat_room/holo/"
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")

var _g: Node
var _cam: Camera4D


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


func _look(from: Vector3, to: Vector3) -> void:
	_cam.global_position = Vector4(from.x, from.y, from.z, 0.0)
	_cam.global_basis = Mark.basis_looking(_cam.global_position, Vector4(to.x, to.y, to.z, 0.0))


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.5)
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	var sc: Node = _g.get_node("Showcase")
	print("hologram: ", sc.get_node_or_null("Hologram") != null)
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(2.2, 0.05, 3.2, 0.0)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(_cam)
	_cam.current = true
	for m in ["dark", "bright"]:
		_g.get_node("Room").call("set_mood", m, true, false)
		_look(Vector3(0.0, 2.6, 7.2), Vector3(0.0, 2.3, -1.5))
		await _wait(0.6)
		await _shot("%s_front" % m)
		_look(Vector3(5.2, 3.0, 4.4), Vector3(0.0, 2.2, -1.5))
		await _wait(0.4)
		await _shot("%s_three_quarter" % m)
	_look(Vector3(1.4, 1.6, 3.6), Vector3(0.0, 1.8, -1.5))
	await _wait(0.4)
	await _shot("dark_close")
	# Both walls from the entrance, the sun as it is, then turned to -20 degrees.
	_g.get_node("Room").call("set_mood", "dark", true, false)
	_look(Vector3(0.0, 3.4, 8.4), Vector3(0.0, 3.2, -4.0))
	await _wait(0.5)
	await _shot("walls_sun_as_is")
	var tuner: Control = _g.get("tuner")
	tuner.call("_write_value", "sun_turn", -20.0)
	await _wait(0.6)
	await _shot("walls_sun_minus20")
	var desk: Node = _g.get_node("ResearchPanel")
	(desk.get("_vp") as SubViewport).get_texture().get_image().save_png(OUT + "desk_screen.png")
	for c in _g.get_node("GoatRoom").get_children():
		if c is SubViewport:
			(c as SubViewport).get_texture().get_image().save_png(OUT + "lesson_print.png")
	quit(0)
