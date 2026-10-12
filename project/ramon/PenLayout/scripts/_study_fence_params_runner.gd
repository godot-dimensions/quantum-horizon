extends SceneTree

## Pen layout study (6 Oct 2026): what FenceGenerator4D's parameters do. Fresh fences in a bare,
## lit space with a white floor (nothing of the pen is loaded or changed), each one the pen's own
## settings with a few changed. For each: the time to build it, its tetrahedra, and frames from a
## 3/4 view at W 0, W 2.5 and W 3.98 (just inside the W face of an 8 m deep fence). Then volume view
## (the Combined renderer) of three of them, to see what the projection shows of a fence's W.
## To res://smoke_test_output/pen_layout/params/.
##
##   CreationLab/scripts/lab_run.sh windowed pl_params res://ramon/PenLayout/scripts/_study_fence_params_runner.gd

const OUT := "res://smoke_test_output/pen_layout/params/"
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")
const Room := preload("res://ramon/CreationLab/LabKit/lab_room_4d.gd")
const Env := preload("res://ramon/CreationLab/PathCreator/path_environment.gd")
const LabGrid := preload("res://ramon/CreationLab/LabKit/lab_grid.gd")
const Mats := preload("res://ramon/CreationLab/LabKit/lab_materials.gd")

## The pen's fence as Aaron set it (playable_world.tscn, Pen/Fence).
const PEN := {"box_size": Vector3(8.4, 7.6, 8.0), "desired_spacing_meters": 1.5, "post_height_meters": 1.1, "post_thickness_meters": 0.15,
	"rib_height_ratio": 0.9, "rib_thickness_ratio": 0.75}
const WS := [0.0, 2.5, 3.98]

var _r: Node4D


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
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img


## The variants: name, then what differs from the pen's fence (an "corners" entry switches to radial
## points with those corners).
func _variants() -> Array:
	# An octagonal prism: an octagon on the floor, 8 m deep in W.
	var octagon := PackedVector4Array()
	for wv in [-4.0, 4.0]:
		for i in 8:
			var a: float = TAU * (float(i) + 0.5) / 8.0
			octagon.append(Vector4(cos(a) * 4.6, 0.0, sin(a) * 4.2, wv))
	# A diamond through W (an octahedron in XZW): the pen you see shrinks as you leave W 0.
	var diamond := PackedVector4Array([Vector4(5.5, 0, 0, 0), Vector4(-5.5, 0, 0, 0), Vector4(0, 0, 5.0, 0), Vector4(0, 0, -5.0, 0), Vector4(0, 0, 0, 4.5),
		Vector4(0, 0, 0, -4.5)])
	# The pen's box with one corner raised 0.6 m: uneven ground.
	var raised := PackedVector4Array()
	for wv in [-4.0, 4.0]:
		for c in [Vector2(-4.2, -3.8), Vector2(4.2, -3.8), Vector2(4.2, 3.8), Vector2(-4.2, 3.8)]:
			raised.append(Vector4(c.x, 0.6 if (c.x > 0.0 and c.y > 0.0 and wv > 0.0) else 0.0, c.y, wv))
	return [
		["01 the pen's fence", {}],
		["02 engine defaults", {"box_size": Vector3(10, 10, 10), "desired_spacing_meters": 2.0, "post_height_meters": 1.25, "post_thickness_meters": 0.1,
			"rib_height_ratio": 0.8, "rib_thickness_ratio": 0.5}],
		["03 no filler (spacing 0)", {"desired_spacing_meters": 0.0}],
		["04 dense filler (0.75 m)", {"desired_spacing_meters": 0.75}],
		["05 ribs and posts only", {"beam_count": 0}],
		["06 five rails", {"beam_count": 5, "beam_coverage": 0.4}],
		["07 solid wall (coverage 1)", {"beam_coverage": 1.0}],
		["08 chunky posts", {"post_thickness_meters": 0.3, "rib_thickness_ratio": 0.9}],
		["09 thin in W (1 m)", {"box_size": Vector3(8.4, 7.6, 1.0)}],
		["10 octagon, radial points", {"corners": octagon}],
		["11 diamond through W", {"corners": diamond}],
		["12 one corner raised 0.6 m", {"corners": raised}],
	]


func _run() -> void:
	_r = Node4D.new()
	root.add_child(_r)
	var room := Node4D.new()
	room.set_script(Room)
	room.set("start_mood", "bright")
	room.set("mood_overrides", Env.mood_overrides())
	_r.add_child(room)
	LabGrid.set_swatch("pl_floor", Color(0.96, 0.965, 0.97), Color(0.86, 0.87, 0.89), Color(0.92, 0.925, 0.93), 1.0)
	var fsize := Vector4(400, 0.5, 60, 40)
	var floor := MeshInstance4D.new()
	floor.mesh = Mats.box_mesh(fsize)
	floor.material_override = LabGrid.material("pl_floor", fsize, Vector4(0, -0.25, 0, 0))
	floor.position = Vector4(0, -0.25, 0, 0)
	_r.add_child(floor)
	var wood := [TetraMaterial4D.new(), TetraMaterial4D.new(), TetraMaterial4D.new()]
	(wood[0] as TetraMaterial4D).albedo_color = Color(0.5, 0.425, 0.35)
	(wood[1] as TetraMaterial4D).albedo_color = Color(0.4, 0.34, 0.28)
	(wood[2] as TetraMaterial4D).albedo_color = Color(0.3, 0.255, 0.21)
	var variants: Array = _variants()
	var fences: Array = []
	for i in variants.size():
		var f := FenceGenerator4D.new()
		f.name = "Fence%02d" % (i + 1)
		f.update_automatically = false
		f.position = Vector4(-180.0 + 30.0 * float(i), 0.0, 0.0, 0.0)
		f.output_mesh_type = 2
		f.beam_material = wood[0]
		f.rib_material = wood[1]
		f.post_material = wood[2]
		for k in PEN:
			f.set(k, PEN[k])
		var over: Dictionary = variants[i][1]
		for k in over:
			if k == "corners":
				f.input_shape_type = 1
				f.fence_corners = over[k]
			else:
				f.set(k, over[k])
		_r.add_child(f)
		var t0: int = Time.get_ticks_usec()
		f.update_fence_mesh_now()
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		var cells: int = 0
		var mesh: Resource = f.mesh
		if mesh is MultiSurfaceMesh4D:
			for sm in (mesh as MultiSurfaceMesh4D).surface_meshes:
				cells += (sm.call("get_simplex_cell_vertex_indices") as PackedInt32Array).size() / 4
		elif mesh != null:
			cells = (mesh.call("get_simplex_cell_vertex_indices") as PackedInt32Array).size() / 4
		var inside: bool = f.is_global_point_inside(f.global_position)
		print("VARIANT %s: built in %.1f ms, %d tetrahedra, middle inside %s" % [String(variants[i][0]), ms, cells, str(inside)])
		fences.append(f)
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	_r.add_child(cam)
	cam.current = true
	await _wait(1.5)
	var tw: int = 480
	var th: int = 270
	var sheet := Image.create_empty(tw * WS.size() + 6 * (WS.size() - 1), th * fences.size() + 6 * (fences.size() - 1), false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.09, 0.12))
	for i in fences.size():
		var F: Vector4 = (fences[i] as Node4D).global_position
		for wi in WS.size():
			var w: float = WS[wi]
			cam.global_position = F + Vector4(10.0, 5.0, 9.5, w)
			cam.global_basis = Mark.basis_looking(cam.global_position, F + Vector4(0, 0.3, 0, w))
			await _wait(0.15)
			var img: Image = await _grab()
			img.save_png(OUT + "v%02d_w%03d.png" % [i + 1, int(round(w * 100.0))])
			img.resize(tw, th, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i(wi * (tw + 6), i * (th + 6)))
	sheet.save_png(OUT + "params_sheet.png")
	print("saved params_sheet (variants down; W 0, 2.5, 3.98 across)")
	# Volume view: the slice plus the projection of what lies near in W (Combined). The root needs
	# its own World3D first, or switching from Cross-section crashes (engine_gotchas.md).
	if root.world_3d == null:
		root.world_3d = World3D.new()
	cam.set("rendering_engine_name", "Combined")
	await _wait(0.8)
	for i in [0, 8, 10]:
		var F2: Vector4 = (fences[i] as Node4D).global_position
		cam.set("projection_type", 1)
		cam.global_position = F2 + Vector4(10.0, 5.0, 9.5, 0.0)
		cam.global_basis = Mark.basis_looking(cam.global_position, F2 + Vector4(0, 0.3, 0, 0))
		await _wait(0.4)
		(await _grab()).save_png(OUT + "volume_v%02d.png" % (i + 1))
	print("PARAMS done")
	quit(0)
