extends SceneTree

## PathCreator: what `ink_gain` makes the DEV look's marks come out as the sheet's own colours on
## screen, in the dev space's light (path_environment.gd). Big discs of each token at several gains,
## seen from straight above; each disc's middle pixel against the token. Prints the gain that lands
## nearest (by colour distance) for each token, and the white floor's own colour.
##
##   CreationLab/scripts/lab_run.sh windowed pc_colour res://ramon/CreationLab/PathCreator/scripts/_probe_colour_runner.gd

const Draw := preload("res://ramon/CreationLab/PathCreator/render/path_draw.gd")
const Spec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const Env := preload("res://ramon/CreationLab/PathCreator/path_environment.gd")
const Room := preload("res://ramon/CreationLab/LabKit/lab_room_4d.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const GAINS := [0.4, 0.55, 0.7, 0.85, 1.0, 1.2]
const ROLES := ["blue", "cyan", "edge"]


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _run() -> void:
	var r := Node4D.new()
	root.add_child(r)
	var room := Node4D.new()
	room.set_script(Room)
	room.set("start_mood", "bright")
	room.set("mood_overrides", Env.mood_overrides())
	r.add_child(room)
	LabGrid.set_swatch("pc_floor", Color(0.96, 0.965, 0.97), Color(0.86, 0.87, 0.89), Color(0.92, 0.925, 0.93), 1.0)
	var fsize := Vector4(60, 0.5, 60, 30)
	var floor := MeshInstance4D.new()
	floor.mesh = Mats.box_mesh(fsize)
	floor.material_override = LabGrid.material("pc_floor", fsize, Vector4(0, -0.25, 0, 0))
	floor.position = Vector4(0, -0.25, 0, 0)
	r.add_child(floor)
	var discs: Array = []
	for ri in ROLES.size():
		for gi in GAINS.size():
			var b: MeshInstance4D = Draw.box(r, "Disc", Draw.PIVOT, Vector4(1.2, 0.01, 1.2, 30), Vector4(-4.0 + float(gi) * 1.6, 0.012, -2.0 + float(ri) * 1.6, 0))
			Draw.set_param(b, "ring_on", 0.0)
			Draw.set_param(b, "ball_r", 0.5)
			Draw.set_param(b, "col_blue", Spec.TOKENS[ROLES[ri]])
			Draw.set_param(b, "ink_gain", GAINS[gi])
			discs.append([ROLES[ri], GAINS[gi], Vector2(-4.0 + float(gi) * 1.6, -2.0 + float(ri) * 1.6)])
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("projection_type", 0)
	cam.set("orthographic_size", 7.2)
	r.add_child(cam)
	cam.current = true
	cam.global_position = Vector4(0.0, 20.0, -0.4, 0.0)
	cam.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
	await _wait(2.0)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/pathcreator/probe/"))
	img.save_png("res://smoke_test_output/pathcreator/probe/colour.png")
	var best: Dictionary = {}
	for d in discs:
		var sp: Vector2 = cam.call("world_to_viewport", Vector4(d[2].x, 0.02, d[2].y, 0.0))
		var c: Color = img.get_pixelv(Vector2i(sp))
		var t: Color = Spec.TOKENS[d[0]]
		var dist: float = Vector3(c.r - t.r, c.g - t.g, c.b - t.b).length()
		print("%-5s gain %.2f -> %s (token %s), off by %.3f" % [d[0], d[1], c.to_html(false), t.to_html(false), dist])
		if not best.has(d[0]) or dist < float(best[d[0]][1]):
			best[d[0]] = [d[1], dist]
	var fp: Vector2 = cam.call("world_to_viewport", Vector4(4.0, 0.0, 3.0, 0.0))
	print("floor ", img.get_pixelv(Vector2i(fp)).to_html(false))
	print("BEST ", best)
	quit(0)
