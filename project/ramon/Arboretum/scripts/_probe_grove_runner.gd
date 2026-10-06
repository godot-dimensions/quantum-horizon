extends SceneTree

## Case study 5: the grove's baked trees side by side at one scale, from the side and turned a
## quarter through W: the voxel, smooth-voxel and lofted versions of grove skeleton 0, and the
## room's own voxel tree for comparison. Prints each mesh's bounds. Windowed; frames in
## smoke_test_output/arboretum/grove_probe/.

const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")
const Style := preload("res://ramon/Arboretum/botany/botany_style.gd")
const RoomScript := preload("res://ramon/Arboretum/carried/LabKit/lab_room_4d.gd")
const KitStyle := preload("res://ramon/Arboretum/carried/kit/kit_style.gd")
const Sun := preload("res://ramon/Arboretum/carried/kit/kit_sun_4d.gd")

const OUT := "res://smoke_test_output/arboretum/grove_probe/"

var _trees: Array = []
var _cam: Camera4D
var _f: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	(func() -> void: _build()).call_deferred()


static func _bounds(m: Resource) -> String:
	var v: PackedVector4Array = (m as ArrayTetraMesh4D).get_vertex_positions()
	var lo := Vector4(INF, INF, INF, INF)
	var hi := -lo
	for p in v:
		lo = Vector4(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z), minf(lo.w, p.w))
		hi = Vector4(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z), maxf(hi.w, p.w))
	return "min %s max %s" % [str(lo), str(hi)]


func _build() -> void:
	var scene := Node4D.new()
	root.add_child(scene)
	var room := Node4D.new()
	room.set_script(RoomScript)
	room.set("ground_size", Vector4(40, 0.5, 30, 20))
	room.set("mood_overrides", KitStyle.ROOM_LIGHT.duplicate(true))
	scene.add_child(room)
	room.call("set_mood", "bright", true, false)
	var sun := Node4D.new()
	sun.set_script(Sun)
	sun.set("target", Vector3(0, 0, 0))
	scene.add_child(sun)
	sun.position = Vector4(4.0, 16.0, 10.0, 0.0)
	var sets: Array = [["grove_vx_0", []], ["grove_dc_0", []], ["grove_lf_0", ["grove_lfc_0"]], ["voxel_tree", []]]
	var sk: Resource = Bake.load_res("grove_sk_0_skeleton")
	var sk_main: Resource = Bake.load_res("main_skeleton")
	print("PROBE grove skeleton 0: ", sk.call("summary"))
	for i in sets.size():
		var t := Node4D.new()
		scene.add_child(t)
		t.position = Vector4(-7.5 + 5.0 * float(i), 0, 0, 0)
		var use_sk: Resource = sk if i < 3 else sk_main
		var mat: TetraMaterial4D = Style.tree_material(use_sk, float((use_sk.call("summary") as Dictionary)["height"]))
		for n in [sets[i][0]] + sets[i][1]:
			var m: Resource = Bake.load_res(String(n))
			if m == null:
				print("PROBE missing ", n)
				continue
			print("PROBE %s: %s" % [n, _bounds(m)])
			var mi := MeshInstance4D.new()
			mi.mesh = m
			mi.material_override = mat
			t.add_child(mi)
		_trees.append(t)
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	scene.add_child(_cam)
	var eye := Vector4(0.0, 2.6, 15.0, 0.0)
	var at := Vector4(0.0, 2.2, 0.0, 0.0)
	var d: Vector4 = at - eye
	_cam.global_position = eye
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))
	_cam.current = true


func _process(_d: float) -> bool:
	_f += 1
	match _f:
		30:
			root.get_texture().get_image().save_png(OUT + "01_side.png")
			for t in _trees:
				(t as Node4D).position.w = 0.3
		45:
			root.get_texture().get_image().save_png(OUT + "02_w0.3.png")
			for t in _trees:
				(t as Node4D).position.w = 0.0
				(t as Node4D).basis = Basis4D.from_xw(PI * 0.5)
		60:
			root.get_texture().get_image().save_png(OUT + "03_turned.png")
			quit()
			return true
	return false
