extends SceneTree
## Probe 4 (PLAN.md): Aaron's FenceGenerator4D bent into things that are not fences. Builds eight
## variants in a row on a slab, times each build (update_fence_mesh_now, TETRA output, this folder's
## surface shader on its materials), then shoots them from the islands camera in the normal view, at
## two other W, and turned into W. Frames to smoke_test_output/crosswise/probe_fence/.
##
## A seed_mesh_3d's own X, Y, Z become the fence's X, Z and W (FenceGenerator4D.xml), so:
##   a quad at constant mesh Y   is a wall across X that spans W (a sheet standing in X-W)
##   a quad at constant mesh Z   is a wall that stands ACROSS W (a sheet in X-Z: a fence in W)
##   four faces round mesh Z     is a cage closed in X and Z but open along W
##
## Run: Remake/run.sh windowed probe_fence res://ramon/MiegakureLook/Remake/probes/_probe_fence_runner.gd

const Mats := preload("res://ramon/MiegakureLook/Remake/world/mk_materials.gd")
const Env := preload("res://ramon/MiegakureLook/Remake/world/mk_env_4d.gd")
const Cam := preload("res://ramon/MiegakureLook/Remake/scripts/mk_camera_4d.gd")

const OUT := "res://smoke_test_output/crosswise/probe_fence/"
const WFACE := Color(0.36, 0.33, 0.78, 0.75)

var _stage: Node4D
var _focus: Node4D
var _cam: Camera4D
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fences: Array = []


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_stage = Node4D.new()
	var env := Node4D.new()
	env.name = "Env"
	env.set_script(Env)
	_stage.add_child(env)
	var floor_size := Vector4(40, 1, 12, 8)
	var slab := MeshInstance4D.new()
	slab.mesh = Mats.box_mesh(floor_size)
	slab.position = Vector4(0, -0.5, 0, 0)
	slab.material_override = Mats.surface("white", floor_size, 2.0, {"origin": slab.position, "side_tint": Color(0.55, 0.58, 0.66)})
	_stage.add_child(slab)
	_focus = Node4D.new()
	_focus.name = "Focus"
	_focus.position = Vector4(0, 0, 0, 0)
	_stage.add_child(_focus)
	_cam = Camera4D.new()
	_cam.name = "Camera"
	_cam.set_script(Cam)
	_cam.set("distance", 34.0)
	_cam.set("fov_degrees", 34.0)
	_cam.set("pitch_degrees", 48.0)
	_cam.set("target_path", NodePath("../Focus"))
	_cam.set("env_path", NodePath("../Env"))
	_stage.add_child(_cam)
	_build_all()
	root.add_child.call_deferred(_stage)


func _mat(tex: String) -> TetraMaterial4D:
	return Mats.surface(tex, Vector4(1, 1, 1, 1), 1.0, {"wface": WFACE})


func _fence(label: String, x: float, setup: Callable) -> void:
	var f = ClassDB.instantiate("FenceGenerator4D")
	f.name = label
	f.set("update_automatically", false)
	f.set("output_mesh_type", 2) # TETRA
	setup.call(f)
	f.position = Vector4(x, 0, 0, 0)
	_stage.add_child(f)
	_fences.append([label, f])


func _quad_mesh(quads: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		var a: Vector3 = q[0]
		var b: Vector3 = q[1]
		var c: Vector3 = q[2]
		var d: Vector3 = q[3]
		for v in [a, b, c, a, c, d]:
			st.add_vertex(v)
	return st.commit()


func _build_all() -> void:
	# 1. A wall across X that spans W (mesh quad at constant mesh Y = fence Z).
	_fence("Wall", -16.0, func(f) -> void:
		f.set("input_shape_type", 3)
		f.set("seed_mesh_3d", _quad_mesh([[Vector3(-2.5, 0, -2), Vector3(2.5, 0, -2), Vector3(2.5, 0, 2), Vector3(-2.5, 0, 2)]]))
		f.set("post_height_meters", 1.8)
		f.set("post_thickness_meters", 0.3)
		f.set("beam_count", 1)
		f.set("beam_coverage", 1.0)
		f.set("desired_spacing_meters", 1.6)
		f.set("beam_material", _mat("grey"))
		f.set("rib_material", _mat("grey"))
		f.set("post_material", _mat("dark_grey")))
	# 2. A fence that stands ACROSS W (mesh quad at constant mesh Z = fence W).
	_fence("WWall", -10.5, func(f) -> void:
		f.set("input_shape_type", 3)
		f.set("seed_mesh_3d", _quad_mesh([[Vector3(-2, -2, 1), Vector3(2, -2, 1), Vector3(2, 2, 1), Vector3(-2, 2, 1)]]))
		f.set("post_height_meters", 1.6)
		f.set("post_thickness_meters", 0.25)
		f.set("beam_count", 2)
		f.set("beam_coverage", 0.6)
		f.set("desired_spacing_meters", 1.4)
		f.set("beam_material", _mat("violet"))
		f.set("rib_material", _mat("grey"))
		f.set("post_material", _mat("grey")))
	# 3. A cage closed in X and Z, open along W.
	_fence("Cage", -5.0, func(f) -> void:
		var a := 1.0
		var b := 0.8
		f.set("input_shape_type", 3)
		f.set("seed_mesh_3d", _quad_mesh([
			[Vector3(-a, -a, -b), Vector3(-a, a, -b), Vector3(-a, a, b), Vector3(-a, -a, b)],
			[Vector3(a, -a, -b), Vector3(a, -a, b), Vector3(a, a, b), Vector3(a, a, -b)],
			[Vector3(-a, -a, -b), Vector3(-a, -a, b), Vector3(a, -a, b), Vector3(a, -a, -b)],
			[Vector3(-a, a, -b), Vector3(a, a, -b), Vector3(a, a, b), Vector3(-a, a, b)]]))
		f.set("post_height_meters", 1.6)
		f.set("post_thickness_meters", 0.16)
		f.set("beam_count", 3)
		f.set("beam_coverage", 0.18)
		f.set("desired_spacing_meters", 0.4)
		f.set("beam_material", _mat("black_metal"))
		f.set("rib_material", _mat("black_metal"))
		f.set("post_material", _mat("black_metal")))
	# 4. A crate: a box footprint 0.7 in X, Z and W, slatted.
	_fence("Crate", -1.0, func(f) -> void:
		f.set("input_shape_type", 0)
		f.set("box_size", Vector3(0.7, 0.7, 0.7))
		f.set("post_height_meters", 0.7)
		f.set("post_thickness_meters", 0.1)
		f.set("rib_height_ratio", 0.999)
		f.set("beam_max_height_ratio", 0.999)
		f.set("beam_count", 3)
		f.set("beam_coverage", 0.65)
		f.set("desired_spacing_meters", 0.0)
		f.set("beam_material", _mat("yellow"))
		f.set("rib_material", _mat("yellow"))
		f.set("post_material", _mat("grey")))
	# 5. A gate frame: a narrow sheet in X-W with one beam at the top.
	_fence("Gate", 2.5, func(f) -> void:
		f.set("input_shape_type", 3)
		f.set("seed_mesh_3d", _quad_mesh([[Vector3(-1.1, 0, -0.8), Vector3(1.1, 0, -0.8), Vector3(1.1, 0, 0.8), Vector3(-1.1, 0, 0.8)]]))
		f.set("post_height_meters", 2.6)
		f.set("post_thickness_meters", 0.26)
		f.set("rib_height_ratio", 0.999)
		f.set("beam_max_height_ratio", 0.999)
		f.set("beam_count", 1)
		f.set("beam_coverage", 0.12)
		f.set("desired_spacing_meters", 0.0)
		f.set("beam_material", _mat("red"))
		f.set("rib_material", _mat("red"))
		f.set("post_material", _mat("red")))
	# 6. A tower: a box footprint leaning in, rings of rails.
	_fence("Tower", 7.0, func(f) -> void:
		f.set("input_shape_type", 0)
		f.set("box_size", Vector3(2.4, 2.4, 2.4))
		f.set("post_height_meters", 6.0)
		f.set("post_thickness_meters", 0.22)
		f.set("top_footprint_ratio", 0.55)
		f.set("beam_count", 5)
		f.set("beam_coverage", 0.22)
		f.set("desired_spacing_meters", 0.0)
		f.set("beam_material", _mat("white"))
		f.set("rib_material", _mat("white"))
		f.set("post_material", _mat("dark_grey")))
	# 7. A pyramid roof: a box footprint leaning almost to a point, solid.
	_fence("Roof", 11.5, func(f) -> void:
		f.set("input_shape_type", 0)
		f.set("box_size", Vector3(2.6, 2.6, 2.6))
		f.set("post_height_meters", 1.5)
		f.set("post_thickness_meters", 0.12)
		f.set("top_footprint_ratio", 0.05)
		f.set("rib_height_ratio", 0.999)
		f.set("beam_max_height_ratio", 0.999)
		f.set("beam_count", 1)
		f.set("beam_coverage", 1.0)
		f.set("desired_spacing_meters", 0.0)
		f.set("beam_material", _mat("red"))
		f.set("rib_material", _mat("red"))
		f.set("post_material", _mat("dark_grey")))
	# 8. Shrine walls: a box footprint, solid walls with posts.
	_fence("Shrine", 15.5, func(f) -> void:
		f.set("input_shape_type", 0)
		f.set("box_size", Vector3(2.4, 2.4, 2.4))
		f.set("post_height_meters", 1.9)
		f.set("post_thickness_meters", 0.22)
		f.set("beam_count", 1)
		f.set("beam_coverage", 1.0)
		f.set("desired_spacing_meters", 1.2)
		f.set("beam_material", _mat("white"))
		f.set("rib_material", _mat("white"))
		f.set("post_material", _mat("dark_grey")))


func _process(delta: float) -> bool:
	_total += delta
	if _total > 80.0:
		print("PROBE_FENCE FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not _stage.is_inside_tree():
		return false
	_t += delta
	match _step:
		0:
			for pair in _fences:
				var f = pair[1]
				var start: int = Time.get_ticks_usec()
				f.call("update_fence_mesh_now")
				var ms: float = float(Time.get_ticks_usec() - start) / 1000.0
				var mesh = f.get("mesh")
				var cells: int = 0
				if mesh != null and mesh.has_method("get_cell_indices"):
					cells = (mesh.call("get_cell_indices") as PackedInt32Array).size() / 4
				var ok: bool = mesh != null
				print("PROBE_FENCE %s %s built in %.1f ms, mesh %s, %d tetrahedra" % ["PASS" if ok else "FAIL", pair[0], ms, mesh.get_class() if mesh != null else "none", cells])
			_step = 1
			_t = 0.0
		1:
			if _t > 1.2:
				_save("01_normal_w0")
				_focus.position.w = 0.75
				_step = 2
				_t = 0.0
		2:
			if _t > 0.8:
				_save("02_normal_w075")
				_focus.position.w = 1.2
				_step = 3
				_t = 0.0
		3:
			if _t > 0.8:
				_save("03_normal_w120")
				_focus.position.w = 0.0
				_focus.position.z = 0.0
				_cam.call("request_turn")
				_step = 4
				_t = 0.0
		4:
			if _t > 1.4:
				_save("04_turned_z0")
				_focus.position.z = 0.3
				_step = 5
				_t = 0.0
		5:
			if _t > 0.8:
				_save("05_turned_z03")
				print("PROBE_FENCE done")
				return true
	return false


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("PROBE_FENCE saved %s" % name)
