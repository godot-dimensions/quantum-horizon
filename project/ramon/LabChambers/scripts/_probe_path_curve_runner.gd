extends SceneTree

## Does a path's curve reach the shader? One straight path on the goat room's floor, photographed with
## the curve handed over three ways: as colours, as flat floats, as Vector4s.
##
##   LabChambers/scripts/lab_run.sh windowed curve res://ramon/LabChambers/scripts/_probe_path_curve_runner.gd

const SCENE := "res://ramon/LabChambers/goat_room.tscn"
const Path := preload("res://ramon/LabChambers/kit/kit_path_4d.gd")
const Mark := preload("res://ramon/LabKit/lab_mark_4d.gd")
const OUT := "res://smoke_test_output/goat_room/"


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw


func _run() -> void:
	var g: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(g)
	current_scene = g
	await _frames(200)
	for c in g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	var p := Node4D.new()
	p.set_script(Path)
	p.set("points", PackedVector4Array([Vector4(0, 0, 0, 0), Vector4(0, 0, 4, 0)]))
	p.position = Vector4(-6.0, 0.0, -1.0, 0.0)
	g.add_child(p)
	await _frames(5)
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	g.add_child(cam)
	cam.current = true
	cam.global_position = Vector4(-6.0, 3.0, 4.5, 0.0)
	cam.global_basis = Mark.basis_looking(cam.global_position, Vector4(-6.0, 0.0, 1.0, 0.0))
	var strip: MeshInstance4D = p.get("_strip")
	var cs: ShaderMaterial = (strip.material_override as TetraMaterial4D).get_cross_section_material_3d()
	var curve: PackedColorArray = cs.get_shader_parameter("path_curve")
	await _frames(10)
	root.get_texture().get_image().save_png(OUT + "curve_color.png")
	var flat := PackedFloat32Array()
	for c in curve:
		flat.append_array([c.r, c.g, c.b, c.a])
	cs.set_shader_parameter("path_curve", flat)
	await _frames(10)
	root.get_texture().get_image().save_png(OUT + "curve_flat.png")
	var v4 := PackedVector4Array()
	for c in curve:
		v4.append(Vector4(c.r, c.g, c.b, c.a))
	cs.set_shader_parameter("path_curve", v4)
	await _frames(10)
	root.get_texture().get_image().save_png(OUT + "curve_v4.png")
	print("done")
	quit(0)
