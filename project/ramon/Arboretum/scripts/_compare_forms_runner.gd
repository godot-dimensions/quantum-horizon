extends SceneTree

## The first pivot, decided by frames (follow_up/arboretum.md, case study 2): how should a 4D tree be
## shaped so a slice reads as a tree?
##   A  SQUASHED   grown, then flattened through W (x0.45), the wood four times deeper in W than across
##   B  ISOTROPIC  grown free in 4D, the same in X, Z and W, the wood twice as thick all round
## Each as voxels and as lofted wood with the GPU leaves, side by side, at W 0, at W 0.4, and turned a
## quarter turn through W (the right drag on a pedestal): a tree that is the same in every horizontal
## direction should still read as a tree turned; a flattened one shows its edge.
## Windowed; frames in smoke_test_output/arboretum/forms/.

const Skeleton := preload("res://ramon/Arboretum/botany/tree_skeleton_4d.gd")
const Species := preload("res://ramon/Arboretum/carried/shrubbery/shrub_species.gd")
const Voxel := preload("res://ramon/Arboretum/botany/voxel_tree_builder.gd")
const LoftTree := preload("res://ramon/Arboretum/botany/loft_tree_builder.gd")
const Leaves := preload("res://ramon/Arboretum/botany/leaf_field_4d.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const RoomScript := preload("res://ramon/Arboretum/carried/LabKit/lab_room_4d.gd")
const KitStyle := preload("res://ramon/Arboretum/carried/kit/kit_style.gd")

const OUT := "res://smoke_test_output/arboretum/forms/"

var _scene: Node4D
var _cam: Camera4D
var _wind: Node
var _trees: Array = []
var _f: int = 0
var _deadline: int = 0


func _initialize() -> void:
	root.unfocusable = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_deadline = Time.get_ticks_msec() + 120000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	(func() -> void: _build()).call_deferred()


func _build() -> void:
	_scene = Node4D.new()
	root.add_child(_scene)
	var room := Node4D.new()
	room.set_script(RoomScript)
	room.set("ground_size", Vector4(60, 0.5, 40, 30))
	room.set("mood_overrides", KitStyle.ROOM_LIGHT.duplicate(true))
	_scene.add_child(room)
	room.call("set_mood", "bright", true, false)
	_wind = Node.new()
	_wind.set_script(Wind)
	_wind.set("enabled", false)
	_scene.add_child(_wind)
	var sp: Resource = Species.new()
	var a: Resource = Skeleton.grow(sp, 2.5, 0.018, 3, 1.25, 0.45)
	var b: Resource = Skeleton.grow(sp, 2.5, 0.036, 3, 1.25, 1.0)
	var t0: int = Time.get_ticks_usec()
	var av: Dictionary = Voxel.build(a, 0.125, {"leaf_r": 0.2, "leaf_twigs": 2, "w_stretch": 4.0})
	var bv: Dictionary = Voxel.build(b, 0.125, {"leaf_r": 0.3, "leaf_twigs": 2})
	var al: Dictionary = LoftTree.build(a, {"w_stretch": 4.0, "w_floor": 0.25, "w_cap": 0.5})
	var bl: Dictionary = LoftTree.build(b, {})
	print("FORMS A voxel %d tets, A loft %d; B voxel %d tets, B loft %d; built in %.0f ms" % [av["tets"], al["tets"], bv["tets"], bl["tets"], (Time.get_ticks_usec() - t0) / 1000.0])
	_add("A_voxel", a, av["mesh"], -9.0, false, 0.0)
	_add("A_loft", a, al["mesh"], -3.0, true, 0.3)
	_add("B_voxel", b, bv["mesh"], 3.0, false, 0.0)
	_add("B_loft", b, bl["mesh"], 9.0, true, 0.3)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_scene.add_child(_cam)
	var eye := Vector4(0.0, 3.0, 17.0, 0.0)
	var at := Vector4(0.0, 2.2, 0.0, 0.0)
	var d: Vector4 = at - eye
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))
	_cam.set("field_of_view_4d", 0.95)
	_cam.current = true


func _add(nm: String, sk: Resource, mesh: ArrayTetraMesh4D, x: float, leaves: bool, leaf_w: float) -> void:
	var t := Node4D.new()
	t.name = nm
	_scene.add_child(t)
	t.position = Vector4(x, 0, 0, 0)
	var mi := MeshInstance4D.new()
	mi.mesh = mesh
	var mat: TetraMaterial4D = Style.tree_material(sk, float((sk.call("summary") as Dictionary)["height"]))
	mi.material_override = mat
	t.add_child(mi)
	_wind.call("register", Style.shader_of(mat), t)
	if leaves:
		var lf := Node4D.new()
		lf.set_script(Leaves)
		lf.set("per_node", 40)
		lf.set("leaf_w", leaf_w)
		t.add_child(lf)
		lf.call("grow_leaves", sk, 3)
	_trees.append(t)


func _place_trees(w: float, turn: float) -> void:
	for t in _trees:
		(t as Node4D).position.w = w
		(t as Node4D).basis = Basis4D.from_xw(turn)


func _process(_d: float) -> bool:
	_f += 1
	if Time.get_ticks_msec() > _deadline:
		quit(2)
		return true
	if _trees.size() < 4:
		return false
	match _f:
		20:
			_shot("01_w0")
			_place_trees(0.4, 0.0)
		35:
			_shot("02_w0.4")
			_place_trees(0.0, PI * 0.5)
		50:
			_shot("03_turned_90")
			_place_trees(0.0, PI * 0.25)
		65:
			_shot("04_turned_45")
			quit()
			return true
	return false


func _shot(n: String) -> void:
	root.get_texture().get_image().save_png(OUT + n + ".png")
	print("FORMS shot ", n)
