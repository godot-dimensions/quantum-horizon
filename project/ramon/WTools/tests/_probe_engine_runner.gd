extends SceneTree

## THE ENGINE, FOR THE W TOOLS (WTools/PLAN.md steps 7-11): what the 4D module can do for them, tried, not
## read. Prints one line per finding ("ENGINE ...") and saves frames to res://smoke_test_output/wtools/engine/.
##   7  the mesh builders on test meshes: a Godot 3D box and cylinder converted, given cells and extruded
##      through W; a half profile spun round in X and W; faces solidified (tetrahedra, time)
##   8  the 4D shapes' tetra meshes (spherinder, cubinder, duocylinder): tetrahedra by segments
##   9  a node scaled in W against a mesh built deeper: the same picture with the slice turned? lit the same?
##      and does a collider under a W-scaled body reach as far as the drawing?
##  10  the camera's W fade and projection settings, as they come
##  11  the cross-section's cost: GPU time against tetrahedra drawn (vsync off, medians)
##
##   lab_run.sh windowed wt_engine res://ramon/WTools/tests/_probe_engine_runner.gd

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const OUT := "res://smoke_test_output/wtools/engine/"

var _root4: Node4D
var _cam: Camera4D


func _initialize() -> void:
	root.unfocusable = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _say(what: String) -> void:
	print("ENGINE " + what)


func _tets(m: Object) -> int:
	if m == null:
		return -1
	if m is ArrayTetraMesh4D:
		return (m as ArrayTetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	if m is TetraMesh4D:
		return (m as TetraMesh4D).get_simplex_cell_vertex_indices().size() / 4
	return -1


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_root4 = Node4D.new()
	root.add_child(_root4)
	var light := DirectionalLight4D.new() if ClassDB.class_exists("DirectionalLight4D") else null
	if light != null:
		_root4.add_child(light)
		light.basis = Basis4D.from_yz(-0.9) * Basis4D.from_zx(0.6)
	_cam = Camera4D.new()
	# The cross-section, as the game draws (a bare camera draws wireframe); set before it is current.
	_cam.rendering_engine_name = "Cross-section"
	_root4.add_child(_cam)
	_cam.position = Vector4(0, 2.0, 9.0, 0)
	_cam.make_current()
	_builders()
	_shapes()
	await _w_scale()
	_camera_settings()
	await _cost()
	print("ENGINE DONE")
	quit(0)


# --- 7 ---------------------------------------------------------------------------------------------------

func _builders() -> void:
	for spec in [["box", BoxMesh.new()], ["cylinder", CylinderMesh.new()], ["sphere", SphereMesh.new()]]:
		var t0: int = Time.get_ticks_usec()
		var faces: ArrayPolyMesh4D = PolyMeshBuilder4D.convert_mesh_3d_to_4d_faces_only(spec[1])
		var cells: int = PolyMeshBuilder4D.make_cells_from_manifold_sheets(faces)
		var deep: ArrayPolyMesh4D = PolyMeshBuilder4D.extrude_linear(faces, Vector4(0, 0, 0, 1.5))
		var tm: Object = deep.to_array_tetra_mesh() if deep != null else null
		_say("7 extrude a Godot %s: %d cells from its faces, extruded %s, %d tetrahedra, %.1f ms" % [spec[0], cells,
			"ok" if deep != null else "FAILED", _tets(tm), (Time.get_ticks_usec() - t0) / 1000.0])
	# A half profile (an L, x >= 0, the axis edge left out) spun round in X and W.
	for steps in [8, 12, 16, 24]:
		var t0: int = Time.get_ticks_usec()
		var m := ArrayPolyMesh4D.new()
		var pts := [Vector4(0, 0, 0, 0), Vector4(1, 0, 0, 0), Vector4(1, 0.3, 0, 0), Vector4(0.3, 0.3, 0, 0), Vector4(0.3, 2, 0, 0), Vector4(0, 2, 0, 0)]
		var ids: Array = []
		for p in pts:
			ids.append(m.append_vertex(p))
		var edges := PackedInt32Array()
		for i in ids.size():
			edges.append(m.append_edge_indices(ids[i], ids[(i + 1) % ids.size()]))
		m.append_poly_cell(2, edges)
		var spun: ArrayPolyMesh4D = PolyMeshBuilder4D.extrude_spin_from_faces_xw(m, steps)
		var tm: Object = spun.to_array_tetra_mesh() if spun != null else null
		_say("7 spin an L profile in X and W, %d steps: %d tetrahedra, %.1f ms" % [steps, _tets(tm), (Time.get_ticks_usec() - t0) / 1000.0])
	# Faces solidified (a fence's outline), within the ground's hyperplane (normal +Y).
	var t1: int = Time.get_ticks_usec()
	var seed := ArrayPolyMesh4D.new()
	var a: int = seed.append_vertex(Vector4(-2, 0, 0, -2))
	var b: int = seed.append_vertex(Vector4(2, 0, 0, -2))
	var c: int = seed.append_vertex(Vector4(2, 0, 0, 2))
	var d: int = seed.append_vertex(Vector4(-2, 0, 0, 2))
	seed.append_poly_cell(2, PackedInt32Array([seed.append_edge_indices(a, b), seed.append_edge_indices(b, c), seed.append_edge_indices(c, d), seed.append_edge_indices(d, a)]))
	var slab: ArrayPolyMesh4D = PolyMeshBuilder4D.solidify_faces(seed, 0.2, 0.0, 2.0, Vector4(0, 1, 0, 0))
	_say("7 solidify a face 0.2 thick: %s, %.1f ms" % ["ok" if slab != null else "FAILED", (Time.get_ticks_usec() - t1) / 1000.0])


# --- 8 ---------------------------------------------------------------------------------------------------

func _shapes() -> void:
	for cls in ["CylinderShape4D", "CubinderShape4D", "DuocylinderShape4D"]:
		if not ClassDB.class_exists(cls):
			_say("8 %s: no such class" % cls)
			continue
		var line := PackedStringArray()
		for seg in [8, 16, 32]:
			var shape: Object = ClassDB.instantiate(cls)
			var tm: Object = shape.call("to_tetra_mesh", {"segments": seg})
			line.append("%d seg %d tets" % [seg, _tets(tm)])
		_say("8 %s: %s" % [cls, ", ".join(line)])


# --- 9 ---------------------------------------------------------------------------------------------------

func _w_scale() -> void:
	# Left: a box 1 deep in W, its node scaled 3 in W. Right: a box built 3 deep. Slice turned 30 degrees.
	var scaled := _box_node(Vector4(1, 1, 1, 1), Vector4(-1.2, 0.5, 0, 0))
	scaled.basis = Basis4D.from_scale(Vector4(1, 1, 1, 3))
	var built := _box_node(Vector4(1, 1, 1, 3), Vector4(1.2, 0.5, 0, 0))
	for turn in [0.0, 30.0, 60.0]:
		_cam.basis = Basis4D.from_xw(deg_to_rad(turn))
		await _frames(6)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + "wscale_%02d.png" % int(turn)))
		var w: int = img.get_width()
		var h: int = img.get_height()
		var left: Color = _mean(img, Rect2i(int(w * 0.30), int(h * 0.45), int(w * 0.08), int(h * 0.1)))
		var right: Color = _mean(img, Rect2i(int(w * 0.62), int(h * 0.45), int(w * 0.08), int(h * 0.1)))
		_say("9 W scale against built depth, slice turned %d: left %s right %s, differ %.3f" % [int(turn), left.to_html(false), right.to_html(false),
			Vector3(left.r - right.r, left.g - right.g, left.b - right.b).length()])
	_cam.basis = Projection.IDENTITY
	scaled.queue_free()
	built.queue_free()
	# A collider under a W-scaled body: a ray straight down at W 1.2 (inside 3 deep, outside 1 deep).
	var holder := Node4D.new()
	holder.basis = Basis4D.from_scale(Vector4(1, 1, 1, 3))
	_root4.add_child(holder)
	var body := StaticBody4D.new()
	holder.add_child(body)
	var cs := CollisionShape4D.new()
	var bs := BoxShape4D.new()
	bs.size = Vector4(1, 1, 1, 1)
	cs.shape = bs
	body.add_child(cs)
	await physics_frame
	await physics_frame
	for w in [0.3, 1.2]:
		var params := RaycastParameters4D.new()
		params.global_ray_origin = Vector4(0, 5, 0, w)
		params.global_ray_direction = Vector4(0, -1, 0, 0)
		params.max_distance = 10.0
		var hit: Dictionary = PhysicsServer4D.raycast_physics_objects(params)
		_say("9 collider under a W-scaled (x3) body, ray down at W %.1f: %s" % [w, "hit" if bool(hit.get("hit", false)) else "missed"])
	holder.queue_free()


func _box_node(size: Vector4, at: Vector4) -> MeshInstance4D:
	var mi := MeshInstance4D.new()
	var box := BoxTetraMesh4D.new()
	box.size = size
	mi.mesh = box
	var m := TetraMaterial4D.new()
	m.albedo_color = Color(0.85, 0.55, 0.3)
	mi.material_override = m
	_root4.add_child(mi)
	mi.position = at
	return mi


func _mean(img: Image, r: Rect2i) -> Color:
	var s := Color(0, 0, 0, 0)
	var n: int = 0
	for y in range(r.position.y, r.end.y, 4):
		for x in range(r.position.x, r.end.x, 4):
			s += img.get_pixel(x, y)
			n += 1
	return s / maxf(float(n), 1.0)


# --- 10 --------------------------------------------------------------------------------------------------

func _camera_settings() -> void:
	var line := PackedStringArray()
	for p in ["w_fade_mode", "w_fade_distance", "w_fade_slope", "projection_opacity", "projection_opacity_base", "plane_sharpness", "edge_falloff", "depth_fade_mode"]:
		line.append("%s %s" % [p, str(_cam.get(p))])
	_say("10 camera defaults: " + ", ".join(line))
	_say("10 MeshInstance4D.allow_projection default: %s" % str(MeshInstance4D.new().get("allow_projection")))


# --- 11 --------------------------------------------------------------------------------------------------

func _cost() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	# A Godot cylinder extruded through W (3,692 tetrahedra), drawn N times in front of the camera; and the
	# same count of light pieces, to tell the cost of tetrahedra from the cost of nodes.
	var faces: ArrayPolyMesh4D = PolyMeshBuilder4D.convert_mesh_3d_to_4d_faces_only(CylinderMesh.new())
	PolyMeshBuilder4D.make_cells_from_manifold_sheets(faces)
	var piece: ArrayTetraMesh4D = PolyMeshBuilder4D.extrude_linear(faces, Vector4(0, 0, 0, 1.0)).to_array_tetra_mesh()
	var per: int = _tets(piece)
	var mat := TetraMaterial4D.new()
	mat.albedo_color = Color(0.4, 0.6, 0.9)
	var nodes: Array = []
	_cam.position = Vector4(0, 3.0, 14.0, 0)
	for count in [0, 10, 20, 40, 80, 160]:
		while nodes.size() < count:
			var k: int = nodes.size()
			var mi := MeshInstance4D.new()
			mi.mesh = piece
			mi.material_override = mat
			_root4.add_child(mi)
			mi.position = Vector4(float(k % 16) * 1.0 - 7.5, 0.0, -float(k / 16) * 1.2, 0.0)
			nodes.append(mi)
		await _frames(20)
		var gpu: Array = []
		var cpu: Array = []
		var last: int = Time.get_ticks_usec()
		for i in 90:
			await process_frame
			var now: int = Time.get_ticks_usec()
			cpu.append((now - last) / 1000.0)
			last = now
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		gpu.sort()
		cpu.sort()
		_say("11 %d pieces, %d tetrahedra drawn: GPU %.2f ms, frame %.2f ms" % [count, count * per, gpu[45], cpu[45]])
