extends SceneTree
## Slice Garden: the tools, as frames. The artist dev panel (F1, pressed as a real key), a slider
## moved through it (the spot's strength: the pool must change), then 4D sight (V) on island 2 in the
## normal view and turned (the crate and cage should show faintly from the next lane), and the
## carried crate's ghost outline. Frames to smoke_test_output/miegakure_remake/tools/.
##
## Run: Remake/run.sh windowed tools res://ramon/MiegakureLook/Remake/scripts/_capture_tools_runner.gd

const SCENE := "res://ramon/MiegakureLook/Remake/slice_garden.tscn"
const OUT := "res://smoke_test_output/miegakure_remake/tools/"

var _game: Node
var _walker: CharacterBody4D
var _cam: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _checks: int = 0
var _fails: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_game = (load(SCENE) as PackedScene).instantiate()
	_game.set("play_intro", false)
	root.add_child.call_deferred(_game)


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new()
	r.keycode = code
	r.physical_keycode = code
	r.pressed = false
	Input.parse_input_event(r)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 90.0:
		print("TOOLS FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _game == null or not _game.is_inside_tree():
		return false
	if _walker == null:
		_walker = _game.get("walker")
		_cam = _game.get("camera")
		_walker.set("input_enabled", false)
		_t = 0.0
	_t += delta
	match _step:
		0:
			if _t > 1.2:
				_key(KEY_F1)
				_next()
		1:
			if _t > 0.6:
				var tuner: Control = _game.get("tuner")
				_check(tuner.visible, "F1 opens the dev panel")
				_save("01_dev_panel")
				var env: Node = _game.get("env")
				env.call("set_value", "spot_strength", 20.0)
				_next()
		2:
			if _t > 0.5:
				_save("02_spot_turned_up")
				var env2: Node = _game.get("env")
				env2.call("set_value", "spot_strength", 8.77)
				_key(KEY_F1)
				# Island 2, lane -1, by the cage's footprint.
				_walker.call("place_at", Vector4(-2.4, 1.4, -12.4, -1.6), PI)
				_cam.call("snap_focus")
				_next()
		3:
			if _t > 1.2:
				_check(not (_game.get("tuner") as Control).visible, "F1 closes it")
				_save("03_lane_m1_no_sight")
				_key(KEY_V)
				_next()
		4:
			if _t > 0.8:
				_check(bool(_game.get("sight")), "V turns 4D sight on")
				_save("04_lane_m1_sight")
				_walker.call("place_at", Vector4(-2.4, 1.4, -14.6, -1.6), PI)
				_cam.call("request_turn")
				_next()
		5:
			if _t > 1.3:
				_save("05_turned_sight")
				_key(KEY_V)
				_next()
		6:
			if _t > 0.6:
				_check(not bool(_game.get("sight")), "V turns it off")
				_save("06_turned_no_sight")
				print("TOOLS done: %d checks, %d failed" % [_checks, _fails])
				return true
	return false


func _next() -> void:
	_step += 1
	_t = 0.0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("TOOLS %s %s" % ["PASS" if ok else "FAIL", what])


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
