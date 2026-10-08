extends SceneTree
## Voxel Lab, round 2 (9 Oct): the column, watched. From its ring, 1 ("Watch it fall") plays its
## presentation: cut through your slice (it stands, some of its base left ana and kata), cut kata as
## well (it falls, kata, the way it lost its support), where it lies; then it is whole and standing
## again. Every part photographed through the story camera. Frames to smoke_test_output/voxel_lab/column/.
##   VoxelLab/run.sh windowed column res://ramon/VoxelLab/scripts/_capture_column_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/column/"

var _scene: Node
var _st: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fails: int = 0
var _seen: Dictionary = {}
var _fell_kata: bool = false


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_st = _scene.get_node("Column")


func _ex() -> Node:
	return _st.get("exhibit")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("COLUMN %s %s" % ["PASS" if ok else "FAIL", what])


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 160.0:
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
			if ex != null and bool(ex.call("is_ready")) and _t > 2.0 and not bool(current_scene.get("loading")):
				_scene.call("go_to", Vector4(-5.1, 0.05, -5.0, 0.0), deg_to_rad(90.0))
				_next()
		1:
			if _t > 1.2:
				_check(String(ex.get("state")) == "standing" and int(_st.get("seq_index")) < 0, "it stands, and nothing plays by itself")
				_save("01_column_ring")
				_key(KEY_1)
				_next()
		2:
			# Each part photographed once, a little way in; the fall's direction read as it falls.
			var part: int = int(_st.get("seq_index"))
			var seqs: Array = _st.call("sequences")
			if part >= 0 and not _seen.has(part) and float(_st.get("seq_t")) > float(seqs[part]["length"]) * 0.6:
				_seen[part] = true
				_save("%02d_part_%s" % [part + 2, String(seqs[part]["key"])])
				if String(seqs[part]["key"]) == "slice":
					var s: Dictionary = ex.get("support")
					_check(String(ex.get("state")) == "standing", "cut through your slice, it stands (%d%% of its base left)" % int(float(s.get("fraction", 1.0)) * 100.0))
			var f: Dictionary = ex.get("_fall")
			if not f.is_empty() and (f["d"] as Vector4).w < -0.5:
				_fell_kata = true
			if _scene.get("watching") == null and _t > 4.0:
				_check(_seen.size() == seqs.size(), "every part played (%d of %d)" % [_seen.size(), seqs.size()])
				_check(_fell_kata, "it fell kata, the way it lost its support")
				_next()
			elif _t > 80.0:
				_check(false, "the presentation never ended")
				_next()
		3:
			if _t > 3.0:
				_check(String(ex.get("state")) == "standing" and (ex.get("specimen").get("cuts") as Array).is_empty(), "whole and standing again after")
				_save("07_whole_again")
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
