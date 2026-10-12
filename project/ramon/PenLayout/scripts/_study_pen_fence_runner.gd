extends SceneTree

## Pen layout study (6 Oct 2026): the pen as it is, read only (nothing is saved, nothing in
## chickenpen/ is changed). Loads playable_world.tscn and looks at:
##   1. the layout from above, with every World child's place printed (for a labelled map)
##   2. Aaron's FenceGenerator4D fence: its settings and mesh (surfaces, cells, vertices)
##   3. the fence from a 3/4 view at several W: 0, a filler-rib layer (0.8), 2, and the W faces
##      (3.95, 4.0, 4.1), plus from above at 0, 0.8 and 4
##   4. the same view with the slice tilted 20 degrees in zw and in xw, pivoting on the pen
##   5. volume view (the Combined renderer), 3/4 and from above
##   6. the frame with the fence and without it
## To res://smoke_test_output/pen_layout/fence/.
##
##   CreationLab/scripts/lab_run.sh windowed pl_fence res://ramon/PenLayout/scripts/_study_pen_fence_runner.gd

const SCENE := "res://ramon/chickenpen/playable_world.tscn"
const OUT := "res://smoke_test_output/pen_layout/fence/"
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")
const TOP := Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))

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
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


## `basis` tilted in the world's zw or xw plane, outermost, as the pen's rig tilts the slice.
func _tilted(basis: Projection, plane: String, deg: float) -> Projection:
	return (Basis4D.from_zw(deg_to_rad(deg)) if plane == "zw" else Basis4D.from_xw(deg_to_rad(deg))) * basis


## The camera W that puts the slice through `pivot`, the camera at `at` with basis `r`.
func _w_through(at: Vector4, r: Projection, pivot: Vector4) -> float:
	var n: Vector4 = r.w
	return pivot.w + (n.x * (pivot.x - at.x) + n.y * (pivot.y - at.y) + n.z * (pivot.z - at.z)) / n.w


func _hide_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
		elif c is CanvasItem:
			(c as CanvasItem).visible = false
		_hide_ui(c)


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(4.0)
	_hide_ui(_g)
	var p: Node4D = _g.get_node_or_null("Player") as Node4D
	if p != null:
		p.visible = false
	# 1. The layout: every World child's place, for the map.
	var places: Dictionary = {}
	for c in _g.get_node("World").get_children():
		if c is Node4D:
			places[String(c.name)] = (c as Node4D).global_position
	var pen: Node4D = _g.get_node("Pen")
	places["Pen"] = pen.global_position
	places["Coop"] = (_g.get_node("Pen/Coop") as Node4D).global_position
	places["Player start"] = p.global_position if p != null else Vector4.ZERO
	places["Mithra"] = (_g.get_node("Mithra") as Node4D).global_position
	var chickens: Array = []
	for c in _g.get_node("Chickens").get_children():
		if c is Node4D:
			chickens.append((c as Node4D).global_position)
	print("PLACES ", JSON.stringify(places.keys().map(func(k): return [k, [places[k].x, places[k].y, places[k].z, places[k].w]])))
	print("CHICKENS ", JSON.stringify(chickens.map(func(v): return [v.x, v.z, v.w])))
	var ground: Node = _g.get_node("World/Ground")
	for c in ground.get_children():
		if c is CollisionShape4D and (c as CollisionShape4D).shape != null:
			print("GROUND shape ", (c as CollisionShape4D).shape.get("size"), " at ", (ground as Node4D).global_position)
	# 2. The fence.
	var fence: Node4D = _g.get_node("Pen/Fence")
	var F: Vector4 = fence.global_position
	print("FENCE class %s at %s" % [fence.get_class(), str(F)])
	for prop in ["input_shape_type", "output_mesh_type", "update_automatically", "box_size", "beam_count", "beam_coverage", "beam_max_height_ratio",
			"beam_thickness_ratio", "desired_spacing_meters", "post_height_meters", "post_thickness_meters", "rib_height_ratio", "rib_thickness_ratio"]:
		print("  %s = %s" % [prop, str(fence.get(prop))])
	var mesh: Resource = fence.get("mesh")
	var total_cells: int = 0
	if mesh is MultiSurfaceMesh4D:
		var names: Array = ["posts", "ribs", "beams"]
		var surfaces: Array = (mesh as MultiSurfaceMesh4D).surface_meshes
		for i in surfaces.size():
			var sm: Resource = surfaces[i]
			var cells: int = (sm.call("get_simplex_cell_vertex_indices") as PackedInt32Array).size() / 4
			var verts: int = (sm.get("vertex_positions") as PackedVector4Array).size() if sm.get("vertex_positions") != null else -1
			total_cells += cells
			print("  surface %d (%s): %d tetrahedra, %d vertices" % [i, names[i] if i < names.size() else "?", cells, verts])
	print("  in all %d tetrahedra" % total_cells)
	print("  is_global_point_inside(middle) = %s, (middle + 5 x) = %s, (middle + 4.5 w) = %s" % [str(fence.call("is_global_point_inside", F)),
		str(fence.call("is_global_point_inside", F + Vector4(5, 0, 0, 0))), str(fence.call("is_global_point_inside", F + Vector4(0, 0, 0, 4.5)))])
	var return_node: Node = _g.get_node_or_null("Pen/Return")
	print("RETURN fence_path = '%s', resolves: %s" % [str(return_node.get("fence_path")), str(return_node.get("_fence") != null)])
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(cam)
	cam.current = true
	# The whole layout from above (image up is world -z).
	cam.set("projection_type", 0)
	cam.set("orthographic_size", 80.0)
	cam.global_basis = TOP
	cam.global_position = Vector4(-2.0, 60.0, -12.0, 0.0)
	await _wait(0.4)
	await _shot("layout_top")
	print("LAYOUT_CAM centre (-2, -12), ortho 80 m tall")
	# 3. The fence from a 3/4 view at several W, and from above.
	var eye := Vector4(9.5, 4.0, 8.5, 0.0)
	var look_at := Vector4(0.0, 0.4, 0.0, 0.0)
	for w in [0.0, 0.8, 2.0, 3.95, 4.0, 4.1]:
		cam.set("projection_type", 1)
		cam.global_position = F + eye + Vector4(0, 0, 0, w)
		cam.global_basis = Mark.basis_looking(cam.global_position, F + look_at + Vector4(0, 0, 0, w))
		await _wait(0.2)
		await _shot("fence_w%03d" % int(round(w * 100.0)))
	for w in [0.0, 0.8, 4.0]:
		cam.set("projection_type", 0)
		cam.set("orthographic_size", 11.0)
		cam.global_basis = TOP
		cam.global_position = F + Vector4(0, 30.0, 0, w)
		await _wait(0.2)
		await _shot("fence_top_w%03d" % int(round(w * 100.0)))
	# 4. Tilted slices, pivoting on the pen's middle.
	for t in [["zw", 20.0], ["xw", 20.0], ["zw", 45.0]]:
		cam.set("projection_type", 1)
		var at: Vector4 = F + eye
		var r: Projection = _tilted(Mark.basis_looking(at, F + look_at), String(t[0]), float(t[1]))
		at.w = _w_through(at, r, F + Vector4(0, 0.4, 0, 0))
		cam.global_position = at
		cam.global_basis = r
		await _wait(0.2)
		await _shot("fence_tilt_%s%d" % [String(t[0]), int(t[1])])
	# 6. Cost: the fence on and off, from the 3/4 view at W 0, vsync off.
	cam.global_position = F + eye
	cam.global_basis = Mark.basis_looking(cam.global_position, F + look_at)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var on_ms: float = await _frame_ms()
	fence.visible = false
	var off_ms: float = await _frame_ms()
	fence.visible = true
	print("COST frame with the fence %.3f ms, without %.3f ms (%+.3f)" % [on_ms, off_ms, on_ms - off_ms])
	# 5. Volume view (Combined). The root needs its own World3D before a Combined camera, or the
	# switch from Cross-section crashes (engine_gotchas.md).
	if root.world_3d == null:
		root.world_3d = World3D.new()
	var vol := Camera4D.new()
	vol.set("rendering_engine_name", "Combined")
	_g.add_child(vol)
	vol.current = true
	vol.set("projection_type", 1)
	vol.global_position = F + eye
	vol.global_basis = Mark.basis_looking(vol.global_position, F + look_at)
	await _wait(0.6)
	await _shot("volume_34")
	vol.global_position = F + Vector4(0.0, 6.0, 13.0, 0.0)
	vol.global_basis = Mark.basis_looking(vol.global_position, F + look_at)
	await _wait(0.3)
	await _shot("volume_front")
	vol.set("projection_type", 0)
	vol.set("orthographic_size", 11.0)
	vol.global_basis = TOP
	vol.global_position = F + Vector4(0, 30.0, 0, 0)
	await _wait(0.3)
	await _shot("volume_top")
	print("STUDY done")
	quit(0)


func _frame_ms() -> float:
	await _wait(0.5)
	var n: int = 0
	var t0: int = Time.get_ticks_usec()
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		n += 1
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(maxi(n, 1))
