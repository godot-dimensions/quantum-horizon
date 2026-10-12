extends SceneTree

## Probe: the pen patch's draped way in, from straight above over the steps, at several W with the
## marks held still, plus each run box's slice extents. To res://smoke_test_output/pathcreator/pen/probe/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_drape_w res://ramon/CreationLab/PathCreator/scripts/_probe_drape_w_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/pen/probe/"
const TOP := Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))


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


func _run() -> void:
	var g: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(g)
	current_scene = g
	await _wait(3.0)
	for c in g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	(g.get("player") as Node4D).visible = false
	var net: Node = g.get_node("PenNetwork")
	net.set("motion", false)
	for c in net.get_children():
		if c is MeshInstance4D and String(c.name).begins_with("Edge0"):
			var mi := c as MeshInstance4D
			print("%s at %s size %s" % [mi.name, str(mi.position), str((mi.mesh as BoxTetraMesh4D).size)])
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("projection_type", 0)
	cam.set("orthographic_size", 9.0)
	g.add_child(cam)
	cam.current = true
	cam.global_basis = TOP
	for w in [0.0, 0.5, 1.0, 1.5, 2.0, 3.0]:
		cam.global_position = Vector4(42.0, 30.0, -12.0, w)
		await _wait(0.3)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "steps_w%02d.png" % int(w * 10.0))
	# Moving: six frames 0.33 s apart at W 0 (a mark moves 0.18 m between them), each riser crossed.
	net.set("motion", true)
	cam.global_position = Vector4(42.0, 30.0, -12.0, 0.0)
	for i in 6:
		await _wait(0.33)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "moving_%d.png" % i)
	net.set("motion", false)
	# The same with the steps hidden: is it the steps or the route?
	g.get_node("PenPatch/StepLow").visible = false
	g.get_node("PenPatch/Deck").visible = false
	for w in [0.0, 1.5]:
		cam.global_position = Vector4(42.0, 30.0, -12.0, w)
		await _wait(0.3)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "nosteps_w%02d.png" % int(w * 10.0))
	print("PROBE done")
	quit(0)
