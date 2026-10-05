extends SceneTree

## The research wall painted onto the right-hand wall (look "painted"), straight on, in both moods,
## at a few parts of the story. To res://smoke_test_output/goat_room/painted/.
##
##   CreationLab/scripts/lab_run.sh windowed painted res://ramon/CreationLab/scripts/_capture_painted_wall_runner.gd

const SCENE := "res://ramon/CreationLab/creation_lab.tscn"
const OUT := "res://smoke_test_output/goat_room/painted/"
const Mark := preload("res://ramon/LabKit/lab_mark_4d.gd")

var _g: Node


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


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.0)
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	var sc: Node = _g.get_node("Showcase")
	var room: Node = _g.get_node("GoatRoom")
	var outline: PackedVector2Array = room.get("outline")
	var a: Vector2 = outline[3]
	var e: Vector2 = outline[4]
	var d: Vector2 = (e - a).normalized()
	var inward := Vector2(-d.y, d.x)
	var mid: Vector2 = (a + e) * 0.5
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(cam)
	cam.current = true
	var eye: Vector2 = mid + inward * 4.6
	cam.global_position = Vector4(eye.x, 3.0, eye.y, 0.0)
	cam.global_basis = Mark.basis_looking(cam.global_position, Vector4(mid.x, 3.15, mid.y, 0.0))
	var until: int = Time.get_ticks_msec() + 20000
	while int(sc.get("seq_index")) < 0 and Time.get_ticks_msec() < until:
		await process_frame
	for m in ["dark", "bright"]:
		_g.get_node("Room").call("set_mood", m, true, false)
		for part in [1, 2, 4]:
			while int(sc.get("seq_index")) != part:
				sc.call("skip")
				await _wait(0.05)
			await _wait(2.4)
			await _shot("%s_part%d" % [m, part + 1])
	# The whole wall from further back, the lesson wall in the same frame.
	cam.global_position = Vector4(-2.0, 3.2, 5.5, 0.0)
	cam.global_basis = Mark.basis_looking(cam.global_position, Vector4(1.0, 3.0, -5.0, 0.0))
	await _wait(0.5)
	await _shot("bright_both_walls")
	_g.get_node("Room").call("set_mood", "dark", true, false)
	await _wait(0.6)
	await _shot("dark_both_walls")
	quit(0)
