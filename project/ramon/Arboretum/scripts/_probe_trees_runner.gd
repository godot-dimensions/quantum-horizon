extends SceneTree

## Plan steps 5 to 8: the three construction methods from ONE skeleton, side by side under the lab's
## light, wearing the bark shader with the room's wind, and the GPU leaves on the lofted one. Windowed
## (frames are what this proves): smoke_test_output/arboretum/probe/.
##
## Checks: every builder makes a mesh; the dual-contoured tree arrives from the engine and is read
## back; the wind moves the corners (frames a second apart differ) without cracks; the leaves draw in
## the cross-section world and are cut by the slice (the trees moved through W). Prints the cost.

const Skeleton := preload("res://ramon/Arboretum/botany/tree_skeleton_4d.gd")
const Species := preload("res://ramon/Arboretum/carried/shrubbery/shrub_species.gd")
const Voxel := preload("res://ramon/Arboretum/botany/voxel_tree_builder.gd")
const LoftTree := preload("res://ramon/Arboretum/botany/loft_tree_builder.gd")
const DC := preload("res://ramon/Arboretum/botany/dc_tree_builder_4d.gd")
const Leaves := preload("res://ramon/Arboretum/botany/leaf_field_4d.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const RoomScript := preload("res://ramon/Arboretum/carried/LabKit/lab_room_4d.gd")
const KitStyle := preload("res://ramon/Arboretum/carried/kit/kit_style.gd")

const OUT := "res://smoke_test_output/arboretum/probe/"
const CELL := 0.125

var _scene: Node4D
var _cam: Camera4D
var _wind: Node
var _sk: Resource
var _trees: Array = []
var _dc: Node4D
var _leaves: Node4D
var _f: int = 0
var _step: int = 0
var _deadline: int = 0
var _times: Array = []
var _last: int = 0


func _initialize() -> void:
	root.unfocusable = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_deadline = Time.get_ticks_msec() + 120000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	(func() -> void: _build()).call_deferred()


func _build() -> void:
	_scene = Node4D.new()
	_scene.name = "Probe"
	root.add_child(_scene)
	var room := Node4D.new()
	room.name = "Room"
	room.set_script(RoomScript)
	room.set("ground_size", Vector4(60, 0.5, 40, 30))
	room.set("mood_overrides", KitStyle.ROOM_LIGHT.duplicate(true))
	_scene.add_child(room)
	room.call("set_mood", "bright", true, false)
	_wind = Node.new()
	_wind.name = "Wind"
	_wind.set_script(Wind)
	_wind.set("gust_every", 0.0)
	_scene.add_child(_wind)

	var sp: Resource = Species.new()
	_sk = Skeleton.grow(sp)
	var summ: Dictionary = _sk.call("summary")
	print("PROBE skeleton: ", summ, " stats ", _sk.get("stats"))
	var h: float = float(summ["height"])

	# 01 voxels
	var vx: Dictionary = Voxel.build(_sk, CELL, {})
	print("PROBE voxel: cells %d (wood %d), tets %d, voxelize %.0f ms, mesh %.0f ms" % [vx["cells"], vx["wood_cells"], vx["tets"], vx["voxelize_ms"], vx["mesh_ms"]])
	_add_tree("Voxel", vx["mesh"], Vector4(-6.0, 0, 0, 0), h)
	# 03 lofted, with lofted clumps
	var lf: Dictionary = LoftTree.build(_sk, {})
	var cl: Dictionary = LoftTree.clumps(_sk, {})
	print("PROBE loft: tets %d (sections %d) in %.0f ms; clumps %d tets in %.0f ms" % [lf["tets"], lf["sections"], lf["ms"], cl["tets"], cl["ms"]])
	var t: Node4D = _add_tree("Loft", lf["mesh"], Vector4(6.0, 0, 0, 0), h)
	var cm := MeshInstance4D.new()
	cm.mesh = cl["mesh"]
	cm.material_override = (t.get_child(0) as MeshInstance4D).material_override
	t.add_child(cm)
	# 04: lofted wood with the GPU leaves
	var oak: Node4D = _add_tree("Leafy", lf["mesh"], Vector4(12.0, 0, 0, 0), h)
	_leaves = Node4D.new()
	_leaves.name = "Leaves"
	_leaves.set_script(Leaves)
	oak.add_child(_leaves)
	_leaves.call("grow_leaves", _sk, 3)
	print("PROBE leaves: %d in %.0f ms" % [int(_leaves.get("count")), float(_leaves.get("build_ms"))])
	# 02: the engine's dual contouring, live
	_dc = Node4D.new()
	_dc.name = "DCBuilder"
	_dc.set_script(DC)
	_dc.set("cell", CELL)
	_scene.add_child(_dc)
	_dc.position = Vector4(0, 0, 0, 0)
	_dc.connect("built", _on_dc)
	_dc.call("start", _sk, {})

	_cam = Camera4D.new()
	_cam.name = "Cam"
	_cam.set("rendering_engine_name", "Cross-section")
	_scene.add_child(_cam)
	_look(Vector4(3.0, 3.2, 17.0, 0.0), Vector4(3.0, 2.2, 0.0, 0.0), 0.9)
	_cam.current = true
	_step = 1
	_last = Time.get_ticks_usec()


func _add_tree(nm: String, mesh: ArrayTetraMesh4D, at: Vector4, h: float) -> Node4D:
	var t := Node4D.new()
	t.name = nm
	_scene.add_child(t)
	t.position = at
	var mi := MeshInstance4D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	var mat: TetraMaterial4D = Style.tree_material(_sk, h)
	mi.material_override = mat
	t.add_child(mi)
	_wind.call("register", Style.shader_of(mat), t)
	_trees.append(t)
	return t


func _on_dc(r: Dictionary) -> void:
	print("PROBE dc: edits %d, load %.0f ms, edits %.0f ms, mesh %.0f ms, chunks %d, read %.0f ms, label %.0f ms, tets %d, vertices %d" % [
		int(r["edits"]), float(r.get("load_ms", 0)), float(r.get("edit_ms", 0)), float(r.get("mesh_ms", 0)), int(r.get("chunks", 0)),
		float(r.get("read_ms", 0)), float(r.get("label_ms", 0)), int(r["tets"]), int(r.get("vertices", 0))])
	var t: Node4D = _add_tree("DC", r["mesh"], Vector4(0, 0, 0, 0), float((_sk.call("summary") as Dictionary)["height"]))
	ResourceSaver.save(r["mesh"], OUT + "dc_tree.res")


func _look(eye: Vector4, at: Vector4, fov: float) -> void:
	var d: Vector4 = at - eye
	var yaw: float = atan2(-d.x, -d.z)
	var pitch: float = atan2(d.y, Vector2(d.x, d.z).length())
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(yaw) * Basis4D.from_yz(pitch)
	_cam.set("field_of_view_4d", fov)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("PROBE shot ", name)


func _set_w(w: float) -> void:
	for t in _trees:
		(t as Node4D).position.w = w


func _process(_d: float) -> bool:
	_f += 1
	var now: int = Time.get_ticks_usec()
	if _step >= 2:
		_times.append((now - _last) / 1000.0)
	_last = now
	if Time.get_ticks_msec() > _deadline:
		print("PROBE TIMEOUT at step ", _step)
		quit(2)
		return true
	match _step:
		1:
			if _dc != null and String(_dc.get("phase")) == "done" and _trees.size() >= 4:
				_wind.set("enabled", false)
				_step = 2
				_f = 0
		2:
			if _f == 20:
				_shot("01_still_front")
				_wind.set("enabled", true)
				_wind.set("speed", 9.0)
			if _f == 80:
				_shot("02_wind_a")
			if _f == 110:
				_shot("03_wind_b")
				_wind.call("gust")
			if _f == 150:
				_shot("04_gust")
			if _f == 160:
				_set_w(0.5)
			if _f == 175:
				_shot("05_slice_w_0.5")
				_set_w(1.0)
			if _f == 190:
				_shot("06_slice_w_1.0")
				_set_w(0.0)
				_look(Vector4(13.5, 3.0, 6.5, 0.0), Vector4(12.0, 3.2, 0.0, 0.0), 0.9)
			if _f == 210:
				_shot("07_leafy_close")
				_look(Vector4(0.8, 3.0, 5.5, 0.0), Vector4(0.0, 2.4, 0.0, 0.0), 0.9)
			if _f == 225:
				_shot("08_dc_close")
				_look(Vector4(-5.2, 3.0, 5.5, 0.0), Vector4(-6.0, 2.4, 0.0, 0.0), 0.9)
			if _f == 240:
				_shot("09_voxel_close")
				_times.sort()
				var med: float = _times[_times.size() / 2]
				var worst: float = _times[int(_times.size() * 0.95)]
				print("PROBE frame time over %d frames: median %.2f ms, 95%% %.2f ms" % [_times.size(), med, worst])
				quit()
				return true
	return false
