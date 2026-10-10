extends SceneTree
## Voxel Lab, round 6 (#60): the sign over the gallery door in two lines (round 7, #81: "WORLD / CREATION"),
## seen from the hall as you walk up to it and from right under it. Round 7 (#86): then the walk's speed, W
## alone and W with Shift held. Frames to smoke_test_output/voxel_lab/sign/.
##   VoxelLab/run.sh windowed sign res://ramon/VoxelLab/scripts/_probe_sign_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/sign/"

var _scene: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _from: Vector4
var _plain: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("SIGN saved %s" % name)


func _hold(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 90.0:
		print("SIGN FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or _scene.get("player") == null:
		return false
	if _step < 3:
		_scene.get("player").set("input_enabled", false)
	_t += delta
	match _step:
		0:
			if _t > 2.0 and not bool(_scene.get("loading")):
				var sign: Node = _scene.get_node_or_null("Hall/GallerySign")
				print("SIGN %s title %s" % ["PASS" if sign != null and String(sign.get("title")).contains("\n") else "FAIL",
					str(String(sign.get("title")).split("\n")) if sign != null else "missing"])
				_scene.call("go_to", Vector4(0.0, 0.05, -4.0, 0.0), 0.0)
				_step = 1
				_t = 0.0
		1:
			if _t > 1.5:
				_save("sign_from_hall")
				_scene.call("go_to", Vector4(0.0, 0.05, -11.0, 0.0), 0.0)
				_step = 2
				_t = 0.0
		2:
			if _t > 1.5:
				_save("sign_close")
				# The walk, down the hall: W alone, then W with Shift.
				_scene.call("go_to", Vector4(0.0, 0.05, 4.0, 0.0), PI)
				_step = 3
				_t = 0.0
		3:
			_scene.get("player").set("input_enabled", true)
			if _t > 0.5 and _t - delta <= 0.5:
				_from = (_scene.get("player") as Node4D).global_position
				_hold(KEY_W, true)
			if _t > 2.5:
				_hold(KEY_W, false)
				var p: Vector4 = (_scene.get("player") as Node4D).global_position
				_plain = Vector2(p.x - _from.x, p.z - _from.z).length() / 2.0
				_scene.call("go_to", Vector4(0.0, 0.05, 4.0, 0.0), PI)
				_step = 4
				_t = 0.0
		4:
			_scene.get("player").set("input_enabled", true)
			if _t > 0.5 and _t - delta <= 0.5:
				_from = (_scene.get("player") as Node4D).global_position
				_hold(KEY_SHIFT, true)
				_hold(KEY_W, true)
			if _t > 2.5:
				_hold(KEY_W, false)
				_hold(KEY_SHIFT, false)
				var p2: Vector4 = (_scene.get("player") as Node4D).global_position
				var fast: float = Vector2(p2.x - _from.x, p2.z - _from.z).length() / 2.0
				print("SIGN %s Shift runs: %.2f m/s with it, %.2f m/s without" % ["PASS" if fast > _plain * 1.25 else "FAIL", fast, _plain])
				print("SIGN done")
				return true
	return false
