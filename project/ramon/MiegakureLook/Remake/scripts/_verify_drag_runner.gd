extends SceneTree
## Slice Garden: the drag and the island cheat, through real input events. The right mouse button
## held and dragged 130 px turns the view about halfway and leaves it there; a click then goes to the
## nearer view; ] jumps to the next island and [ back. Frames of the halfway view to
## smoke_test_output/miegakure_remake/drag/.
##
## Run: Remake/run.sh windowed drag res://ramon/MiegakureLook/Remake/scripts/_verify_drag_runner.gd

const SCENE := "res://ramon/MiegakureLook/Remake/slice_garden.tscn"
const OUT := "res://smoke_test_output/miegakure_remake/drag/"

var _game: Node
var _cam: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _checks: int = 0
var _fails: int = 0
var _moves: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_game = (load(SCENE) as PackedScene).instantiate()
	_game.set("play_intro", false)
	root.add_child.call_deferred(_game)


func _button(pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = pressed
	e.position = Vector2(640, 360)
	Input.parse_input_event(e)


func _move(dx: float) -> void:
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(dx, 0)
	e.position = Vector2(640 + dx, 360)
	e.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(e)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 60.0:
		print("DRAG FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _game == null or not _game.is_inside_tree():
		return false
	if _cam == null:
		_cam = _game.get("camera")
		(_game.get("walker") as Node).set("input_enabled", false)
	_t += delta
	match _step:
		0:
			if _t > 1.0:
				_button(true)
				_next()
		1:
			# 13 moves of 10 px, one a frame.
			_move(10.0)
			_moves += 1
			if _moves >= 13:
				_button(false)
				_next()
		2:
			if _t > 0.5:
				var deg: float = rad_to_deg(absf(float(_cam.call("slice_angle"))))
				_check(deg > 30.0 and deg < 60.0, "a 130 px drag turns the view part way (%.1f degrees) and it stays" % deg)
				_check(not bool(_cam.call("is_turning")), "no turn running after the drag")
				_save("01_halfway_normal_side")
				_button(true)
				_button(false)
				_next()
		3:
			if _t > 1.0:
				var deg2: float = rad_to_deg(absf(float(_cam.call("slice_angle"))))
				_check(deg2 < 0.5 or absf(deg2 - 90.0) < 0.5, "a click goes to the nearer view (%.1f degrees)" % deg2)
				_key(KEY_BRACKETRIGHT)
				_next()
		4:
			if _t > 0.6:
				_check(int(_game.get("island")) == 2, "] jumps to island 2")
				_key(KEY_BRACKETRIGHT)
				_next()
		5:
			if _t > 0.6:
				_check(int(_game.get("island")) == 3, "] again: island 3")
				_key(KEY_BRACKETLEFT)
				_next()
		6:
			if _t > 0.6:
				_check(int(_game.get("island")) == 2, "[ goes back to island 2")
				# A drag on island 2, by the cage, for a frame of the diagonal slice.
				(_game.get("walker") as Node).call("place_at", Vector4(-2.4, 1.4, -13.2, -0.8), PI)
				_cam.call("snap_focus")
				_cam.call("drag_by", -0.6)
				_next()
		7:
			if _t > 0.8:
				_save("02_cage_halfway")
				print("DRAG done: %d checks, %d failed" % [_checks, _fails])
				return true
	return false


func _next() -> void:
	_step += 1
	_t = 0.0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
	print("DRAG %s %s" % ["PASS" if ok else "FAIL", what])


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
