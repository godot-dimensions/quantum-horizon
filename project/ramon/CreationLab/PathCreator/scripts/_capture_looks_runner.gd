extends SceneTree

## PathCreator's looks (PLAN.md steps 38-39, 52): the yard's choice and its turns from above, four
## ways: library 07, library 06 (F5), mixed (only the primary route's chevrons from 06, the builder's
## L), and the WALK look (F6). One sheet. To res://smoke_test_output/pathcreator/looks/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_looks res://ramon/CreationLab/PathCreator/scripts/_capture_looks_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/looks/"


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


func _grab() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _run() -> void:
	var g: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(g)
	current_scene = g
	await _wait(3.0)
	for c in g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	(g.get("player") as Node4D).visible = false
	var net: Node = g.get_node("YardNetwork")
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("projection_type", 0)
	cam.set("orthographic_size", 12.0)
	g.add_child(cam)
	cam.current = true
	cam.global_position = Vector4(-14.0, 30.0, -34.0, 0.0)
	cam.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
	var looks: Array = [["library 07", "07", {}, "dev"], ["library 06", "06", {}, "dev"], ["mixed: A from 06", "07", {"A": "06"}, "dev"],
		["WALK look", "07", {}, "walk"]]
	var tiles: Array = []
	for lk in looks:
		net.set("default_library", lk[1])
		net.set("libraries", lk[2])
		g.call("set_look", lk[3])
		await _wait(0.6)
		var img: Image = await _grab()
		img.save_png(OUT + "%s.png" % String(lk[0]).replace(" ", "_").replace(":", ""))
		tiles.append(img)
	var w: int = tiles[0].get_width()
	var h: int = tiles[0].get_height()
	var sheet := Image.create_empty(w * 2 + 8, h * 2 + 8, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.09, 0.12))
	for i in tiles.size():
		var t: Image = tiles[i]
		t.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(t, Rect2i(0, 0, w, h), Vector2i((i % 2) * (w + 8), (i / 2) * (h + 8)))
	sheet.save_png(OUT + "looks_sheet.png")
	print("LOOKS saved (07, 06, mixed, walk)")
	quit(0)
