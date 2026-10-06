extends SceneTree
## Voxel Lab, plan steps 55 to 61: the column. Its story (cut through the slice: it stands; cut kata
## too: it falls, out of your slice), then at its bench: a cut through the slice only (it must stand),
## a cut through W as well (it must fall), and the tree. Frames to
## smoke_test_output/voxel_lab/column/, checks as PASS or FAIL.
##   VoxelLab/run.sh windowed column res://ramon/VoxelLab/scripts/_capture_column_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/column/"
const Cut := preload("res://ramon/VoxelLab/specimen/vl_cut.gd")

var _scene: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fails: int = 0
var _st: Node
var _bench: Node


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_st = _scene.get_node("Column")
	_bench = _scene.get_node("ColumnBench")


func _ex() -> Node:
	return _st.get("exhibit")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("COLUMN %s %s" % ["PASS" if ok else "FAIL", what])


func _process(delta: float) -> bool:
	_total += delta
	if _total > 220.0:
		print("COLUMN FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree() or _scene.get("player") == null:
		return false
	_scene.get("player").set("input_enabled", false)
	_t += delta
	var ex: Node = _ex()
	match _step:
		0:
			if ex != null and bool(ex.call("is_ready")) and _t > 2.0:
				_scene.call("go_to", Vector4(-7.0, 0.05, -0.2, 0.0), deg_to_rad(12.0))
				_next()
			elif _t > 60.0:
				_check(false, "the column never got ready")
				return true
		1:
			if _t > 3.0:
				_check(int(_st.get("seq_index")) >= 0, "its story starts as you come near")
				_save("01_story_column")
				_st.call("skip")
				_next()
		2:
			if _t > 3.4:
				_save("02_story_cut_slice")
				var s: Dictionary = ex.get("support")
				_check(String(ex.get("state")) == "standing", "cut through the slice it stands (%d%% of its base left)" % int(float(s.get("fraction", 1.0)) * 100.0))
				_next()
		3:
			if _t > 4.0:
				_save("03_story_slid_through_w")
				_st.call("skip")
				_next()
		4:
			if _t > 2.4:
				_save("04_story_kata_cut")
			if _t > 3.6:
				_save("05_story_falling")
				_check(String(ex.get("state")) != "standing", "cut kata as well, it falls (%s)" % String(ex.get("state")))
				_next()
		5:
			if _t > 2.4:
				_save("06_story_lying")
				_st.call("skip")
				_next()
		6:
			if _t > 3.6:
				_save("07_story_where_kata")
				_next()
		7:
			if _t > 6.0:
				_check(String(ex.get("state")) == "standing", "after the story: standing again")
				# The bench.
				_scene.call("go_to", Vector4(-8.2, 0.05, -1.2, 0.0), 0.0)
				_next()
		8:
			if _t > 0.6:
				_scene.call("sit", _bench)
				_next()
		9:
			if _t > 1.2:
				_save("08_bench")
				# Through the slice only: a slab across X and Z, 0.24 m deep in W.
				var sp: Node = ex.get("specimen")
				var r: Dictionary = sp.get("recipe")
				var col: Dictionary = r["column"]
				var c: Vector4 = col["center"]
				var rad: float = float(col["radius"])
				var y: float = lerpf(float(col["y0"]), float(col["y1"]), 0.5)
				sp.call("apply_cut", Cut.block(Vector4(c.x, y, c.z, c.w), Vector4(rad + 2.0, 1.5, rad + 2.0, 0.12 / 0.07)))
				_next()
		10:
			if _t > 1.2:
				_save("09_bench_slice_cut")
				_check(String(ex.get("state")) == "standing", "bench: through the slice only, it stands (%d%% left)" % int(float((ex.get("support") as Dictionary).get("fraction", 1.0)) * 100.0))
				# Now the ana side away too (leaving kata): it should tip ana.
				var sp: Node = ex.get("specimen")
				var r: Dictionary = sp.get("recipe")
				var col: Dictionary = r["column"]
				var c: Vector4 = col["center"]
				var rad: float = float(col["radius"])
				var y: float = lerpf(float(col["y0"]), float(col["y1"]), 0.5)
				sp.call("apply_cut", Cut.block(Vector4(c.x, y, c.z, c.w + rad), Vector4(rad + 2.0, 1.5, rad + 2.0, rad)))
				_next()
		11:
			if _t > 0.9:
				_save("10_bench_falling")
			if _t > 3.2:
				_save("11_bench_fallen")
				var f: Dictionary = ex.get("_fall")
				var d: Vector4 = f.get("d", Vector4.ZERO)
				_check(String(ex.get("state")) == "lying", "bench: cut ana as well, it fell and lies (direction %s)" % str(d))
				_check(d.w > 0.5, "it fell ana, the way it lost its support")
				_scene.call("toggle_volume_view")
				_next()
		12:
			if _t > 1.2:
				_save("12_bench_fallen_volume")
				_scene.call("toggle_volume_view")
				ex.call("reset")
				_next()
		13:
			if _t > 1.2:
				_check(String(ex.get("state")) == "standing" and int(ex.call("cut_count")) == 0, "R: whole and standing again")
				_bench.call("undock")
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_scene.call("go_to", Vector4(-6.6, 0.05, -1.4, 0.0), deg_to_rad(18.0))
				_next()
		14:
			if _t > 0.8:
				var said: String = String(ex.call("action"))
				_check(said.contains("tree"), "E: a tree instead (%s)" % said)
				_next()
		15:
			if ex.call("is_ready") and _t > 3.0:
				_save("13_tree")
				var sp: Node = ex.get("specimen")
				var r: Dictionary = sp.get("recipe")
				var col: Dictionary = r["column"]
				var c: Vector4 = col["center"]
				var rad: float = float(col["radius"])
				var y: float = lerpf(float(col["y0"]), float(col["y1"]), 0.5)
				# A notch from the front, most of the way through, through all of W: it falls forward.
				sp.call("apply_cut", Cut.block(Vector4(c.x, y, c.z + rad * 0.75, c.w), Vector4(rad + 2.0, 1.6, rad * 0.95, rad + 2.0)))
				_next()
			elif _t > 40.0:
				_check(false, "the tree never got ready")
				_next()
		16:
			if _t > 1.0:
				_save("14_tree_falling")
			if _t > 3.4:
				_save("15_tree_fallen")
				_check(String(ex.get("state")) == "lying", "the tree, notched, fell (%s)" % String(ex.get("state")))
				print("COLUMN done, %d failed" % _fails)
				return true
	return false


func _next() -> void:
	_step += 1
	_t = 0.0


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("COLUMN saved %s" % name)
