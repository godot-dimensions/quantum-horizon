extends SceneTree
## Voxel Lab (9 Oct): O in the lab goes straight to the open world (Ramon: "a shortcut o in the scene
## for going directly to the open world"). Opens the lab, waits for its board, presses O, checks the
## field opens and its board finishes. Frames to smoke_test_output/voxel_lab/shortcut_o/.
##   VoxelLab/run.sh windowed shortcut_o res://ramon/VoxelLab/scripts/_shortcut_o_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/shortcut_o/"

var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	var s: Node = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(s)
	current_scene = s


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("SHORTCUT %s %s" % ["PASS" if ok else "FAIL", what])


func _process(delta: float) -> bool:
	_total += delta
	if _total > 120.0:
		print("SHORTCUT FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cs: Node = current_scene
	if cs == null or not cs.is_inside_tree():
		return false
	_t += delta
	match _step:
		0:
			if cs.has_method("go_to") and cs.get("player") != null and not bool(cs.get("loading")) and _t > 2.0:
				var strip: Array = cs.call("_strip")
				_check(strip.any(func(kv: Array) -> bool: return String(kv[0]) == "O"), "the strip shows O")
				for pressed in [true, false]:
					var e := InputEventKey.new()
					e.keycode = KEY_O
					e.physical_keycode = KEY_O
					e.pressed = pressed
					Input.parse_input_event(e)
				_step = 1
				_t = 0.0
		1:
			if cs.has_method("fly") and cs.get("player") != null and not bool(cs.get("loading")) and _t > 1.0:
				_check(true, "O opened the open world (%.1f s)" % _t)
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "open_world.png"))
				print("SHORTCUT done, %d failed" % _fails)
				return true
			elif _t > 60.0:
				_check(false, "O never opened the open world")
				return true
	return false
