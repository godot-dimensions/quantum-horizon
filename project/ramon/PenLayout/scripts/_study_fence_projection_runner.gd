extends SceneTree

## Pen layout study (6 Oct 2026): the fence seen whole in 4D. The Projected renderer draws all of a
## 4D object at once (W fades it out with distance) rather than one slice of it.
##   A. Four fences in a bare space (the pen's, one 1 m thin in W, an octagon, a diamond through W),
##      each straight on and with the camera turned 35 degrees into W (zw), in Projected.
##   B. The pen itself, read only, the grass off for this study (Ramon, 6 Oct: "toggle off the grass
##      ... we dont need to take it in consideration yet"): Cross-section, Combined and Projected
##      from the same 3/4 view, and Projected from above.
## To res://smoke_test_output/pen_layout/projection/.
##
##   CreationLab/scripts/lab_run.sh windowed pl_proj res://ramon/PenLayout/scripts/_study_fence_projection_runner.gd

const PEN_SCENE := "res://ramon/chickenpen/playable_world.tscn"
const OUT := "res://smoke_test_output/pen_layout/projection/"
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")
const Room := preload("res://ramon/CreationLab/LabKit/lab_room_4d.gd")
const Env := preload("res://ramon/CreationLab/PathCreator/path_environment.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")
const PEN := {"box_size": Vector3(8.4, 7.6, 8.0), "desired_spacing_meters": 1.5, "post_height_meters": 1.1, "post_thickness_meters": 0.15,
	"rib_height_ratio": 0.9, "rib_thickness_ratio": 0.75}
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


func _shot(what: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


func _hide_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		elif c is CanvasItem:
			(c as CanvasItem).visible = false
		_hide_ui(c)


func _run() -> void:
	# A World3D of the root's own from the start: Combined and Projected need it (engine_gotchas.md).
	root.world_3d = World3D.new()
	# A. Four fences in a bare space.
	var space := Node4D.new()
	root.add_child(space)
	var room := Node4D.new()
	room.set_script(Room)
	room.set("start_mood", "bright")
	room.set("mood_overrides", Env.mood_overrides())
	space.add_child(room)
	LabGrid.set_swatch("pl_floor", Color(0.96, 0.965, 0.97), Color(0.86, 0.87, 0.89), Color(0.92, 0.925, 0.93), 1.0)
	# No floor here: projected, a floor deep in W covers everything with its own haze.
	var octagon := PackedVector4Array()
	for wv in [-4.0, 4.0]:
		for i in 8:
			var a: float = TAU * (float(i) + 0.5) / 8.0
			octagon.append(Vector4(cos(a) * 4.6, 0.0, sin(a) * 4.2, wv))
	var diamond := PackedVector4Array([Vector4(5.5, 0, 0, 0), Vector4(-5.5, 0, 0, 0), Vector4(0, 0, 5.0, 0), Vector4(0, 0, -5.0, 0), Vector4(0, 0, 0, 4.5),
		Vector4(0, 0, 0, -4.5)])
	var variants: Array = [["pen", {}], ["thin_w", {"box_size": Vector3(8.4, 7.6, 1.0)}], ["octagon", {"corners": octagon}], ["diamond", {"corners": diamond}]]
	var wood := TetraMaterial4D.new()
	wood.albedo_color = Color(0.5, 0.425, 0.35)
	var fences: Array = []
	for i in variants.size():
		var f := FenceGenerator4D.new()
		f.update_automatically = false
		f.position = Vector4(-45.0 + 30.0 * float(i), 0.0, 0.0, 0.0)
		f.output_mesh_type = 2
		f.beam_material = wood
		f.rib_material = wood
		f.post_material = wood
		for k in PEN:
			f.set(k, PEN[k])
		var over: Dictionary = variants[i][1]
		for k in over:
			if k == "corners":
				f.input_shape_type = 1
				f.fence_corners = over[k]
			else:
				f.set(k, over[k])
		space.add_child(f)
		f.update_fence_mesh_now()
		fences.append(f)
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Projected")
	space.add_child(cam)
	cam.current = true
	await _wait(1.5)
	for i in fences.size():
		var F: Vector4 = (fences[i] as Node4D).global_position
		var eye: Vector4 = F + Vector4(8.0, 6.0, 9.0, 0.0)
		cam.global_position = eye
		cam.global_basis = Mark.basis_looking(eye, F + Vector4(0, 0.3, 0, 0))
		await _wait(0.3)
		await _shot("clean_%s_projected" % String(variants[i][0]))
		# Turned 35 degrees into W: the fence's W depth becomes depth on screen.
		cam.global_basis = Basis4D.from_zw(deg_to_rad(35.0)) * Mark.basis_looking(eye, F + Vector4(0, 0.3, 0, 0))
		await _wait(0.3)
		await _shot("clean_%s_projected_zw35" % String(variants[i][0]))
	space.queue_free()
	await _wait(0.5)
	# B. The pen, grass off.
	var g: Node = (load(PEN_SCENE) as PackedScene).instantiate()
	root.add_child(g)
	current_scene = g
	await _wait(4.0)
	_hide_ui(g)
	var grass: Node = g.get_node_or_null("World/Grass")
	if grass != null:
		(grass as Node4D).visible = false
		grass.process_mode = Node.PROCESS_MODE_DISABLED
	var p: Node4D = g.get_node_or_null("Player") as Node4D
	if p != null:
		p.visible = false
	var F2: Vector4 = (g.get_node("Pen/Fence") as Node4D).global_position
	# The pen's Lookout puts the current camera back on its own renderer every frame: Cross-section,
	# or Combined while its P toggle is on (lookout_4d.gd _apply_projection). So Combined comes from
	# its own toggle, and for Projected it is paused (this run only; nothing is saved).
	var lookout: Node = g.get_node_or_null("Systems/Lookout")
	var eye2: Vector4 = F2 + Vector4(9.5, 4.0, 8.5, 0.0)
	var pcam := Camera4D.new()
	pcam.set("rendering_engine_name", "Cross-section")
	g.add_child(pcam)
	pcam.current = true
	pcam.set("projection_type", 1)
	pcam.global_position = eye2
	pcam.global_basis = Mark.basis_looking(eye2, F2 + Vector4(0, 0.4, 0, 0))
	await _wait(0.8)
	await _shot("pen_cross_section")
	if lookout != null:
		lookout.call("set_projection", true)
	await _wait(1.0)
	print("renderer now: ", pcam.get("rendering_engine_name"))
	await _shot("pen_combined")
	pcam.global_basis = Basis4D.from_zw(deg_to_rad(35.0)) * Mark.basis_looking(eye2, F2 + Vector4(0, 0.4, 0, 0))
	await _wait(0.5)
	await _shot("pen_combined_zw35")
	if lookout != null:
		lookout.call("set_projection", false)
		lookout.process_mode = Node.PROCESS_MODE_DISABLED
	# The ground and the hills are slabs hundreds of metres deep in W: projected, they fog it all.
	for path in ["World/Ground/GroundMesh", "World/Hills", "World/CaveHill"]:
		var n: Node = g.get_node_or_null(path)
		if n is Node4D:
			(n as Node4D).visible = false
	pcam.queue_free()
	pcam = Camera4D.new()
	pcam.set("rendering_engine_name", "Projected")
	g.add_child(pcam)
	pcam.current = true
	pcam.set("projection_type", 1)
	pcam.global_position = eye2
	pcam.global_basis = Mark.basis_looking(eye2, F2 + Vector4(0, 0.4, 0, 0))
	await _wait(0.8)
	print("renderer now: ", pcam.get("rendering_engine_name"))
	await _shot("pen_projected")
	pcam.global_basis = Basis4D.from_zw(deg_to_rad(35.0)) * Mark.basis_looking(eye2, F2 + Vector4(0, 0.4, 0, 0))
	await _wait(0.4)
	await _shot("pen_projected_zw35")
	pcam.set("projection_type", 0)
	pcam.set("orthographic_size", 14.0)
	pcam.global_basis = TOP
	pcam.global_position = F2 + Vector4(0, 30.0, 0, 0)
	await _wait(0.4)
	await _shot("pen_projected_top")
	print("PROJECTION done")
	quit(0)
