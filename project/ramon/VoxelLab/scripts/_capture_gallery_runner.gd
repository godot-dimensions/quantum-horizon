extends SceneTree
## Voxel Lab, plan steps 62 to 66: the gallery of the engine's test cases. Each pedestal photographed
## (normal and slid through W), the terrain sample and the caves cut at their benches (aimed through
## the engine's own meshes: their noise is beyond our copy), the 24-cell pair close up, and the ladder's
## timed cuts at 20, 10 and 5 cm. Frames to smoke_test_output/voxel_lab/gallery/.
##   VoxelLab/run.sh windowed gallery res://ramon/VoxelLab/scripts/_capture_gallery_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/gallery/"

var _scene: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _st(nm: String) -> Node:
	return _scene.get_node(nm)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("GALLERY %s %s" % ["PASS" if ok else "FAIL", what])


func _ready_all() -> bool:
	for nm in ["Terrain", "Caves", "Cell24", "Ladder"]:
		var ex: Node = _st(nm).get("exhibit")
		if ex == null or not bool(ex.call("is_ready")):
			return false
	return true


func _process(delta: float) -> bool:
	_total += delta
	if _total > 240.0:
		print("GALLERY FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree() or _scene.get("player") == null:
		return false
	_scene.get("player").set("input_enabled", false)
	_t += delta
	match _step:
		0:
			if _ready_all() and _t > 2.0:
				for nm in ["Terrain", "Caves", "Cell24", "Ladder"]:
					var ex: Node = _st(nm).get("exhibit")
					print("GALLERY %s: %s" % [nm, str(ex.call("numbers"))])
				_scene.call("go_to", Vector4(0.0, 0.05, -14.0, 0.0), 0.0)
				_next()
			elif _t > 90.0:
				_check(false, "the gallery's specimens never all got ready")
				return true
		1:
			if _t > 1.6:
				_save("01_gallery_from_door")
				_scene.call("go_to", Vector4(-4.8, 0.05, -16.4, 0.0), deg_to_rad(35.0))
				_next()
		2:
			if _t > 1.6:
				_save("02_terrain")
				_st("Terrain").call("step_slice", 3)
				_next()
		3:
			if _t > 1.4:
				_save("03_terrain_slid_w")
				_st("Terrain").call("step_slice", -3)
				_scene.call("go_to", Vector4(-7.5, 0.05, -18.8, 0.0), 0.0)
				_next()
		4:
			if _t > 0.6:
				_scene.call("sit", _scene.get_node("TerrainBench"))
				_next()
		5:
			if _t > 1.2:
				var b: Node = _scene.get_node("TerrainBench")
				b.set("tool", "ball")
				b.set("size_index", 2)
				var h: Dictionary = b.call("aim_at_screen", Vector2(640, 330))
				_check(not h.is_empty(), "the terrain sample is aimed at through its meshes (material %s)" % str(h.get("material", -1)))
				if not h.is_empty():
					b.call("cut_here")
				_next()
		6:
			if _t > 1.4:
				_save("04_terrain_cut")
				var b: Node = _scene.get_node("TerrainBench")
				var recs: Array = b.get("records")
				_check(not recs.is_empty(), "a crater in the terrain sample (%s)" % (str(recs[-1].get("latency_ms", 0)) + " ms to show" if not recs.is_empty() else "none"))
				b.call("undock")
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
				_scene.call("go_to", Vector4(4.8, 0.05, -16.4, 0.0), deg_to_rad(-35.0))
				_next()
		7:
			if _t > 1.6:
				_save("05_caves")
				_st("Caves").call("step_slice", 2)
				_next()
		8:
			if _t > 1.4:
				_save("06_caves_slid_w")
				_st("Caves").call("step_slice", -2)
				_scene.call("go_to", Vector4(-4.6, 0.05, -24.6, 0.0), deg_to_rad(40.0))
				_next()
		9:
			if _t > 1.6:
				_save("07_cell24")
				_scene.call("go_to", Vector4(5.0, 0.05, -24.8, 0.0), deg_to_rad(-40.0))
				_next()
		10:
			if _t > 1.2:
				var said: String = String(_st("Ladder").call("action"))
				_check(not said.is_empty(), "the ladder times a cut in each: %s" % said)
				_next()
		11:
			var res: Array = _st("Ladder").get("exhibit").get("ladder_results")
			if res.size() >= 3 or _t > 20.0:
				_check(res.size() >= 3, "all three rungs timed")
				for r in res:
					print("GALLERY ladder %.0f cm: %s solid voxels, shown after %.0f ms, worst frame %.1f ms, %d chunks, %s voxels cut, %d tetrahedra" % [
						float(r["voxel"]) * 100.0, str(r["solid"]), float(r["latency_ms"]), float(r["worst_ms"]), int(r["chunks"]), str(r["voxels"]), int(r["tets"])])
				_save("08_ladder_timed")
				_scene.call("go_to", Vector4(0.0, 0.05, -29.4, 0.0), 0.0)
				_next()
		12:
			if _t > 1.2:
				_save("09_far_door")
				print("GALLERY done, %d failed" % _fails)
				return true
	return false


func _next() -> void:
	_step += 1
	_t = 0.0


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("GALLERY saved %s" % name)
