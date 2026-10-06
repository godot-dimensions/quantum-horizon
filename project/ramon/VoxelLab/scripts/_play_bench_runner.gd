extends SceneTree
## Voxel Lab, plan step 53: the bench played with real input events (Input.parse_input_event), so the
## keys and clicks go through the same paths a player's do: E on the pad sits you down, 1 to 4 pick the
## tool, Q and E the size, a click cuts, the saw is pressed, dragged and let go, the wheel slides through
## W, R makes it whole, T switches where the draw buffers are built, C the chunk outlines, F stands you
## up. The aim is set on the bench (aim_override), never by moving the cursor: it is the user's.
## Frames to smoke_test_output/voxel_lab/play/.
##   VoxelLab/run.sh windowed play res://ramon/VoxelLab/scripts/_play_bench_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/play/"

var _scene: Node
var _bench: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fails: int = 0
var _records_before: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_bench = _scene.get_node("HeroBench")


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print("PLAY %s %s" % ["PASS" if ok else "FAIL", what])


func _key(code: Key, shift: bool = false) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		e.shift_pressed = shift
		Input.parse_input_event(e)


func _mouse(button: MouseButton, pressed: bool, at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = pressed
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)


func _aim(px: Vector2) -> void:
	_bench.call("aim_at_screen", px)


func _process(delta: float) -> bool:
	_total += delta
	if _total > 200.0:
		print("PLAY FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree() or _scene.get("player") == null:
		return false
	_scene.get("player").set("input_enabled", false)
	_t += delta
	var recs: Array = _bench.get("records")
	match _step:
		0:
			var ex: Node = _scene.get_node("Hero").get("exhibit")
			if ex != null and bool(ex.call("is_ready")) and _t > 2.0:
				_scene.call("go_to", Vector4(0, 0.05, 4.0, 0), 0.0)
				_next()
		1:
			if _t > 0.8:
				_key(KEY_E)
				_next()
		2:
			if _t > 1.0:
				_check(_scene.get("bench") == _bench, "E on the pad sits you at the bench")
				var bc: Camera4D = _bench.call("camera")
				_check(bc != null and bool(bc.get("current")), "the bench's camera is the one in use")
				_key(KEY_2)
				_aim(Vector2(700, 340))
				_next()
		3:
			if _t > 0.3:
				_check(String(_bench.get("tool")) == "block", "2 picks the block")
				_records_before = recs.size()
				_mouse(MOUSE_BUTTON_LEFT, true, Vector2(700, 340))
				_mouse(MOUSE_BUTTON_LEFT, false, Vector2(700, 340))
				_next()
		4:
			if _t > 1.2:
				_check(recs.size() == _records_before + 1, "a click cuts a notch")
				_key(KEY_1)
				_key(KEY_E)
				_aim(Vector2(560, 360))
				_next()
		5:
			if _t > 0.3:
				_check(String(_bench.get("tool")) == "ball" and int(_bench.get("size_index")) == 2, "1 and E: the ball, large")
				_mouse(MOUSE_BUTTON_LEFT, true, Vector2(560, 360))
				_mouse(MOUSE_BUTTON_LEFT, false, Vector2(560, 360))
				_next()
		6:
			if _t > 1.2:
				_save("01_ball_and_block")
				_key(KEY_3)
				_key(KEY_Q)
				_key(KEY_Q)
				_aim(Vector2(640, 410))
				_next()
		7:
			if _t > 0.3:
				_check(String(_bench.get("tool")) == "drill" and int(_bench.get("size_index")) == 0, "3 and Q Q: the drill, small")
				_mouse(MOUSE_BUTTON_LEFT, true, Vector2(640, 410))
				_mouse(MOUSE_BUTTON_LEFT, false, Vector2(640, 410))
				_next()
		8:
			if _t > 1.2:
				_key(KEY_4)
				_aim(Vector2(545, 445))
				_next()
		9:
			if _t > 0.3:
				# The saw: press here, drag, let go there.
				_mouse(MOUSE_BUTTON_LEFT, true, Vector2(545, 445))
				_next()
		10:
			if _t > 0.3:
				_aim(Vector2(745, 440))
				_save("02_saw_dragging")
				_next()
		11:
			# Let go a moment after the save: reading the screen back stalls its frame, and a cut in
			# that frame is charged for it.
			if _t > 0.2:
				_mouse(MOUSE_BUTTON_LEFT, false, Vector2(745, 440))
				_next()
		12:
			if _t > 1.4:
				_check(recs.size() >= 4, "the saw's press, drag and release cut a channel (%d cuts)" % recs.size())
				_save("03_all_four")
				_mouse(MOUSE_BUTTON_WHEEL_UP, true, Vector2(640, 360))
				_mouse(MOUSE_BUTTON_WHEEL_UP, true, Vector2(640, 360))
				_next()
		13:
			if _t > 1.2:
				_check(int(_scene.get_node("Hero").get("slice_index")) == 6, "the wheel slides the specimen through W (%d)" % int(_scene.get_node("Hero").get("slice_index")))
				_save("04_slid_through_w")
				_mouse(MOUSE_BUTTON_WHEEL_DOWN, true, Vector2(640, 360))
				_mouse(MOUSE_BUTTON_WHEEL_DOWN, true, Vector2(640, 360))
				_key(KEY_T)
				_key(KEY_C)
				_key(KEY_2)
				_aim(Vector2(600, 300))
				_next()
		14:
			if _t > 0.4:
				var sp: Node = _bench.call("specimen")
				_check(not bool(sp.get("swap")) and bool(sp.get("flash_on")), "T: built in the frame; C: chunk outlines on")
				_records_before = recs.size()
				_mouse(MOUSE_BUTTON_LEFT, true, Vector2(600, 300))
				_mouse(MOUSE_BUTTON_LEFT, false, Vector2(600, 300))
				_next()
		15:
			if _t > 1.2:
				var last: Dictionary = recs[-1] if not recs.is_empty() else {}
				_check(recs.size() == _records_before + 1 and not bool(last.get("swap", true)), "a cut the engine's way: worst frame %.1f ms" % float(last.get("worst_ms", 0)))
				_save("05_engine_way")
				_key(KEY_T)
				_key(KEY_R)
				_next()
		16:
			if _t > 1.2:
				_check(int(_scene.get_node("Hero").get("exhibit").call("cut_count")) == 0, "R: whole again")
				_save("06_whole")
				_key(KEY_F)
				_next()
		17:
			if _t > 0.8:
				_check(_scene.get("bench") == null, "F stands you up")
				for r in recs:
					print("PLAY cut %-10s voxels %4d  chunks %2d  on screen after %6.1f ms  worst frame %5.1f ms  %s" % [String(r["label"]), int(r["voxels"]),
						int(r["chunks"]), float(r["latency_ms"]), float(r["worst_ms"]), "swap" if bool(r.get("swap", true)) else "engine"])
				print("PLAY done, %d failed" % _fails)
				return true
	return false


func _next() -> void:
	_step += 1
	_t = 0.0


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("PLAY saved %s" % name)
