extends SceneTree

## The path system's first light: paths added to the goat room's floor at run time, seen from above
## and from a player's height: the four styles, a curve, a loop, and two copies of one path moved
## through W (one half out of the slice, one wholly out), to check the strip shows the right way up
## and that W really hides its marks. Prints each strip's tetrahedra. To
## res://smoke_test_output/goat_room/paths_probe/.
##
##   CreationLab/scripts/lab_run.sh windowed paths_probe res://ramon/CreationLab/scripts/_probe_paths_runner.gd

const SCENE := "res://ramon/CreationLab/creation_lab.tscn"
const OUT := "res://smoke_test_output/goat_room/paths_probe/"
const Path := preload("res://ramon/CreationLab/kit/kit_path_4d.gd")
const Pivot := preload("res://ramon/CreationLab/kit/kit_pivot_4d.gd")
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


func _path(at: Vector3, style: String, pts: Array, closed: bool = false) -> Node4D:
	var p := Node4D.new()
	p.set_script(Path)
	p.set("style", style)
	var arr := PackedVector4Array()
	for q in pts:
		arr.append(q)
	p.set("points", arr)
	p.set("closed", closed)
	p.position = Vector4(at.x, at.y, at.z, 0.0)
	_g.add_child(p)
	return p


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.0)
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	(_g.get_node("Showcase") as Node4D).visible = false
	# Four styles side by side, running away from the entrance.
	var x0: float = -7.5
	for st in ["arrows", "zebra", "dots", "line"]:
		var p: Node4D = _path(Vector3(x0, 0.0, 0.0), st, [Vector4(0, 0, 7.5, 0), Vector4(0.6, 0, 5.0, 0), Vector4(-0.6, 0, 2.5, 0), Vector4(0, 0, 0, 0)])
		if st == "dots":
			p.set("spacing", 0.7)
		if st == "line":
			p.set("spacing", 2.0)
		x0 += 2.4
	# A loop, and a pivot ball in it.
	var loop: Node4D = Node4D.new()
	loop.set_script(Path)
	loop.set("shape", "circle")
	loop.set("radius", 1.4)
	loop.set("style", "zebra")
	loop.set("width", 0.35)
	loop.set("spacing", 0.6)
	loop.position = Vector4(5.0, 0.0, 5.5, 0.0)
	_g.add_child(loop)
	var piv := Node4D.new()
	piv.set_script(Pivot)
	piv.position = Vector4(5.0, 0.0, 5.5, 0.0)
	_g.add_child(piv)
	# One path, three times: at our W, half out (0.45), wholly out (1.4).
	var wx: float = 3.6
	for wv in [0.0, 0.45, 1.4]:
		var p2: Node4D = _path(Vector3(wx, 0.0, 0.0), "arrows", [Vector4(0, 0, 3.5, 0), Vector4(0, 0, 0, 0)])
		p2.set("width", 0.9)
		p2.position.w = wv
		wx += 1.4
	await _wait(1.0)
	for c in _g.get_children():
		if c.get_script() == Path:
			var m: ArrayTetraMesh4D = (c.get("_strip") as MeshInstance4D).mesh
			print("%s: %.1f m, %d tetrahedra" % [c.get("style"), float(c.get("length")), m.get_simplex_cell_vertex_indices().size() / 4])
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(cam)
	cam.current = true
	cam.global_position = Vector4(1.0, 9.3, 6.2, 0.0)
	cam.global_basis = Mark.basis_looking(cam.global_position, Vector4(1.0, 0.0, 3.4, 0.0))
	await _wait(0.5)
	await _shot("above")
	await _wait(0.6)
	await _shot("above_later")
	cam.global_position = Vector4(-1.0, 1.7, 8.6, 0.0)
	cam.global_basis = Mark.basis_looking(cam.global_position, Vector4(-0.5, 0.0, 2.0, 0.0))
	await _wait(0.4)
	await _shot("eye_level")
	quit(0)
