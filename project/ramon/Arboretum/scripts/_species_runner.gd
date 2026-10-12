extends SceneTree

## Case study 3: which skeleton makes a tree. Candidates side by side, lofted with the room's form and
## the GPU leaves: the Shrubbery Lab's own tree (its box) for reference, three crown envelopes for
## the specimen, and the oak. Shot with leaves, without (the wood alone shows the structure), and
## turned an eighth through W. Prints each skeleton's numbers. Windowed; frames in
## smoke_test_output/arboretum/species/.

const Species := preload("res://ramon/Arboretum/botany/tree_species.gd")
const LoftTree := preload("res://ramon/Arboretum/botany/loft_tree_builder.gd")
const Leaves := preload("res://ramon/Arboretum/botany/leaf_field_4d.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const Wind := preload("res://ramon/Arboretum/botany/wind_4d.gd")
const RoomScript := preload("res://ramon/Arboretum/carried/LabKit/lab_room_4d.gd")
const KitStyle := preload("res://ramon/Arboretum/carried/kit/kit_style.gd")

const OUT := "res://smoke_test_output/arboretum/species/"

var _scene: Node4D
var _cam: Camera4D
var _wind: Node
var _trees: Array = []
var _leaves: Array = []
var _f: int = 0
var _deadline: int = 0


func _initialize() -> void:
	root.unfocusable = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_deadline = Time.get_ticks_msec() + 150000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	(func() -> void: _build()).call_deferred()


func _build() -> void:
	_scene = Node4D.new()
	root.add_child(_scene)
	var room := Node4D.new()
	room.set_script(RoomScript)
	room.set("ground_size", Vector4(80, 0.5, 40, 30))
	room.set("mood_overrides", KitStyle.ROOM_LIGHT.duplicate(true))
	_scene.add_child(room)
	room.call("set_mood", "bright", true, false)
	_wind = Node.new()
	_wind.set_script(Wind)
	_wind.set("enabled", false)
	_scene.add_child(_wind)
	var cands: Array = [
		["shrubbery", "shrubbery", {}],
		["crown_a", "specimen", {}],
		["crown_b", "specimen", {"gen": {"attract_distance": 1.8}}],
		["crown_c", "specimen", {"gen": {"attractor_count": 1100, "max_branches": 700}, "crown": [Vector4(0.0, 3.2, 0.0, 0.0), Vector4(1.9, 1.55, 1.9, 1.9), 1.55, 0.7]}],
		["oak", "oak", {}],
	]
	var xs := [-15.0, -8.0, -1.0, 6.0, 15.0]
	for i in cands.size():
		var c: Array = cands[i]
		var sk: Resource = Species.grow(String(c[1]), -1, c[2])
		var summ: Dictionary = sk.call("summary")
		var w: Dictionary = LoftTree.build(sk, Species.loft_opts())
		print("SPECIES %s: %s  grow %s ms  loft %d tets in %.0f ms" % [c[0], str(summ), str((sk.get("stats") as Dictionary).get("grow_ms")), w["tets"], w["ms"]])
		var t := Node4D.new()
		t.name = String(c[0])
		_scene.add_child(t)
		t.position = Vector4(xs[i], 0, 0, 0)
		var mi := MeshInstance4D.new()
		mi.mesh = w["mesh"]
		var mat: TetraMaterial4D = Style.tree_material(sk, float(summ["height"]), String(c[1]) == "oak")
		mi.material_override = mat
		t.add_child(mi)
		_wind.call("register", Style.shader_of(mat), t)
		var lf := Node4D.new()
		lf.set_script(Leaves)
		lf.set("per_node", int(Species.form()["per_node"]))
		lf.set("leaf_w", float(Species.form()["leaf_w"]))
		t.add_child(lf)
		lf.call("grow_leaves", sk, 3)
		print("SPECIES %s leaves %d" % [c[0], int(lf.get("count"))])
		_trees.append(t)
		_leaves.append(lf)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_scene.add_child(_cam)
	var eye := Vector4(0.0, 4.0, 24.0, 0.0)
	var at := Vector4(0.0, 3.2, 0.0, 0.0)
	var d: Vector4 = at - eye
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))
	_cam.set("field_of_view_4d", 1.0)
	_cam.current = true


func _process(_d: float) -> bool:
	_f += 1
	if Time.get_ticks_msec() > _deadline:
		quit(2)
		return true
	if _trees.size() < 5:
		return false
	match _f:
		30:
			_shot("01_leaves")
			for l in _leaves:
				l.set("enabled", false)
		45:
			_shot("02_wood")
			for t in _trees:
				(t as Node4D).basis = Basis4D.from_xw(PI * 0.25)
			for l in _leaves:
				l.set("enabled", true)
		60:
			_shot("03_turned_45")
			for t in _trees:
				(t as Node4D).basis = Projection.IDENTITY
				(t as Node4D).position.w = 0.35
		75:
			_shot("04_w0.35")
			quit()
			return true
	return false


func _shot(n: String) -> void:
	root.get_texture().get_image().save_png(OUT + n + ".png")
	print("SPECIES shot ", n)
