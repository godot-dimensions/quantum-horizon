extends SceneTree
## Voxel Lab, round 2 (9 Oct): the hall played and photographed the way Ramon walked it. In from the
## corridor to the quiet junction (nothing plays), to the block's ring (the choice), 1 to watch its
## presentation (it cuts live), Esc, 2 to sit at the bench (its camera in use, a cut with each tool, a
## middle drag orbits), F; specimen A's pop-up; the right wall's ring turning done; the column watched
## twice (it falls both times); the lights saved and read back; the dev panel's top view; black.
## Frames to smoke_test_output/voxel_lab/room/, checks printed as PASS or FAIL.
##
## The player's input is off and the mouse is never moved or held: keys and buttons go in as events
## (Input.parse_input_event), the bench is aimed through aim_at_screen() (the cursor is the user's).
##   VoxelLab/run.sh windowed room res://ramon/VoxelLab/scripts/_capture_room_runner.gd

const OUT := "res://smoke_test_output/voxel_lab/room/"
const TEST_LIGHTS := "user://vl_lights_test.cfg"

var _scene: Node
var _room: Node
var _t: float = 0.0
var _total: float = 0.0
var _step: int = 0
var _fails: int = 0
var _hero: Node
var _bench: Node
var _column: Node
var _falls: int = 0
var _yaw0: float = 0.0
var _board_saved: bool = false


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_open.call_deferred()


func _open() -> void:
	_scene = (load("res://ramon/VoxelLab/voxel_lab.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	current_scene = _scene
	_room = _scene
	_hero = _scene.get_node("Hero")
	_bench = _scene.get_node("HeroBench")
	_column = _scene.get_node("Column")


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ROOM PASS %s" % what)
	else:
		_fails += 1
		print("ROOM FAIL %s" % what)


func _player() -> Node:
	return _room.get("player")


func _place(x: float, z: float, yaw: float) -> void:
	_room.call("go_to", Vector4(x, 0.05, z, 0.0), yaw)


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)


func _ex(st: Node) -> Node:
	return st.get("exhibit")


func _spot_name() -> String:
	var sp: Dictionary = _room.get("spot")
	return String((sp["node"] as Node).name) if not sp.is_empty() else ""


func _process(delta: float) -> bool:
	_total += delta
	if _total > 300.0:
		print("ROOM FAIL: timed out at step %d" % _step)
		return true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _scene == null or not _scene.is_inside_tree() or _player() == null:
		return false
	if _room.get("bench") == null:
		_player().set("input_enabled", false)
	_t += delta
	if _step == 0 and bool(_room.get("loading")) and not _board_saved and _t > 1.5:
		_board_saved = true
		_save("00_loading_board")
	match _step:
		0:
			if bool(_ex(_hero).call("is_ready")) and bool(_ex(_column).call("is_ready")) and _t > 2.0 and not bool(current_scene.get("loading")):
				_save("01_entrance")
				_place(0.0, 9.0, 0.0)
				_next()
		1:
			if _t > 1.6:
				_check(int(_hero.get("seq_index")) < 0 and not bool(_hero.get("armed")), "nothing plays at the junction")
				_save("02_junction")
				_place(0.0, 3.0, 0.0)
				_next()
		2:
			if _t > 1.2:
				var ch: Control = _room.get("choice")
				var opts: Array = ch.get("options")
				_check(_spot_name() == "Block" and bool(ch.get("shown")) and opts.size() == 2, "the block's ring offers a choice (%s)" % str(opts.map(func(o): return o["label"])))
				_check(int(_hero.get("seq_index")) < 0, "and its presentation has not started by itself")
				_save("03_block_choice")
				_key(KEY_1)
				_next()
		3:
			if _t > 1.5:
				_check(_room.get("watching") == _hero and int(_hero.get("seq_index")) >= 0, "1 plays the presentation (part %d)" % int(_hero.get("seq_index")))
				_check(not bool(_room.get("choice").get("shown")), "and the choice steps aside while it plays")
				_save("04_watch_specimen")
				_key(KEY_RIGHT)
				_next()
		4:
			# One part at a time: two presses in one frame both skip from the same part.
			if _t > 0.4 and _t - delta <= 0.4:
				_key(KEY_RIGHT)
			if _t > 4.4:
				_save("05_watch_two_cuts")
				_check(int(_ex(_hero).call("cut_count")) >= 2, "the presentation cut the ball and the box (%d cuts)" % int(_ex(_hero).call("cut_count")))
				_key(KEY_ESCAPE)
				_next()
		5:
			if _t > 2.0:
				_check(_room.get("watching") == null, "Esc stops it")
				_check(int(_ex(_hero).call("cut_count")) == 0, "and the block is whole again (%d cuts)" % int(_ex(_hero).call("cut_count")))
				_key(KEY_2)
				_next()
		6:
			if _t > 1.2:
				_check(_room.get("bench") == _bench, "2 sits you at the bench")
				var bc: Camera4D = _bench.call("camera")
				_check(bc != null and bool(bc.get("current")), "the bench's camera is the one in use")
				_save("06_bench")
				_next()
		7:
			if _t > 0.4:
				_bench.set("tool", "ball")
				_bench.set("size_index", 1)
				_cut_at(Vector2(560, 330))
				_next()
		8:
			if _t > 0.5:
				_bench.set("tool", "block")
				_cut_at(Vector2(730, 320))
				_next()
		9:
			if _t > 0.5:
				_bench.set("tool", "drill")
				_cut_at(Vector2(640, 400))
				_next()
		10:
			if _t > 1.2:
				_yaw0 = float(_bench.get("_yaw"))
				_mouse_button(MOUSE_BUTTON_MIDDLE, true)
				# Motion is handed over at the end of the frame, so the button is let go in the next step.
				var mm := InputEventMouseMotion.new()
				mm.relative = Vector2(120, 0)
				mm.button_mask = MOUSE_BUTTON_MASK_MIDDLE
				Input.parse_input_event(mm)
				_next()
		11:
			if _t > 0.3:
				_mouse_button(MOUSE_BUTTON_MIDDLE, false)
				_check(absf(float(_bench.get("_yaw")) - _yaw0) > 0.3, "a middle drag orbits the bench camera")
				_save("07_bench_cuts")
				var recs: Array = _bench.get("records")
				for r in recs:
					print("ROOM cut %-10s voxels %4d  chunks %2d  on screen after %6.1f ms  worst frame %5.1f ms" % [String(r["label"]), int(r["voxels"]),
						int(r["chunks"]), float(r["latency_ms"]), float(r["worst_ms"])])
				_check(recs.size() >= 3, "%d cuts recorded" % recs.size())
				_key(KEY_F)
				_next()
		12:
			if _t > 0.8:
				_check(_room.get("bench") == null, "F stands you up")
				_place(6.2, 9.0, deg_to_rad(-90.0))
				_next()
		13:
			if _t > 1.0:
				_check(_spot_name() == "ShelfA", "specimen A's marker is a spot")
				_room.set("_popup_open", true)
				_next()
		14:
			if _t > 0.6:
				var pd: Dictionary = _room.get("popup").get("data")
				_check(bool(_room.get("popup").get("shown")) and not String(pd.get("title", "")).is_empty(), "a click opens its pop-up (%s)" % String(pd.get("title", "")))
				_save("08_shelf_popup")
				_place(5.1, -8.0, deg_to_rad(-48.0))
				_next()
		15:
			if _t > 2.0:
				var done: Dictionary = _room.get("_done")
				_check(done.has("RightWallTarget"), "standing at the right wall's ring marks it done")
				_save("09_right_wall")
				_place(-5.1, -8.0, deg_to_rad(48.0))
				_next()
		16:
			if _t > 2.0:
				_save("10_left_wall")
				_place(-5.1, -5.0, deg_to_rad(90.0))
				_next()
		17:
			if _t > 1.2:
				var ch: Control = _room.get("choice")
				_check(_spot_name() == "Column" and (ch.get("options") as Array).size() == 1, "the column's ring offers to watch it fall")
				_save("11_column_choice")
				_key(KEY_1)
				_next()
		18:
			# Watched through: it must fall (state "lying"), then the story ends and it is whole again.
			if String(_ex(_column).get("state")) == "lying" and _falls == 0:
				_falls = 1
				_save("12_column_fallen")
			if _room.get("watching") == null and _t > 3.0:
				_check(_falls == 1, "the column falls the first time")
				_next()
			elif _t > 60.0:
				_check(false, "the column's presentation never ended")
				_next()
		19:
			if _t > 1.0:
				_key(KEY_1)
				_next()
		20:
			if String(_ex(_column).get("state")) == "lying" and _falls == 1:
				_falls = 2
				_save("13_column_fallen_again")
			if _room.get("watching") == null and _t > 3.0:
				_check(_falls == 2, "and it falls the second time")
				_next()
			elif _t > 70.0:
				_check(false, "the second presentation never ended")
				_next()
		21:
			if _t > 3.0:
				_check(String(_ex(_column).get("state")) == "standing", "and stands again after")
				_lights_test()
				_place(0.0, 7.0, 0.0)
				var dp: Control = _room.get("dev_panel")
				dp.visible = true
				dp.get("_settings_box").visible = false
				dp.get("_lights_box").visible = true
				_next()
		22:
			if _t > 1.0:
				_save("14_dev_lights")
				var dp: Control = _room.get("dev_panel")
				dp.visible = false
				_room.call("toggle_palette")
				_place(0.0, 9.0, 0.0)
				_next()
		23:
			if _t > 1.6:
				_save("15_black")
				print("ROOM done, %d failed" % _fails)
				return true
	return false


## The light rig: a room slider moves its lights, a light's own value moves only it, and what is saved
## reads back.
func _lights_test() -> void:
	var rig: Node = _room.get("lights")
	var lights: Array = rig.get("lights")
	_check(lights.size() >= 6, "%d lights in the rig" % lights.size())
	var block: Node = rig.call("light", "Block")
	var shelf_a: Node = rig.call("light", "ShelfA")
	rig.call("set_room", "hall", "strength", 3.3)
	_check(is_equal_approx(float((block.get("energy") as Dictionary)["bright"]), 3.3), "the hall's strength moves the block's light")
	_check(not is_equal_approx(float((shelf_a.get("energy") as Dictionary)["bright"]), 3.3), "but not specimen A's, which has its own")
	rig.call("move_to", "Block", 0.6, -1.0)
	rig.call("set_own", "Block", "cone", 22.0)
	rig.call("save", TEST_LIGHTS)
	rig.call("reset_own", "Block")
	rig.call("load_saved", TEST_LIGHTS)
	rig.call("apply_all")
	var e: Dictionary = rig.call("effective", block)
	_check(is_equal_approx(float(e["cone"]), 22.0) and is_equal_approx(float(e["x"]), 0.6), "a light's own cone and place save and read back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_LIGHTS))
	# Back to the plan's values, so the frames after this one show the room as it starts.
	rig.call("reset_own", "Block")
	rig.call("set_room", "hall", "strength", 2.4)


func _mouse_button(b: MouseButton, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = b
	e.pressed = pressed
	Input.parse_input_event(e)


func _cut_at(px: Vector2) -> void:
	var h: Dictionary = _bench.call("aim_at_screen", px)
	if h.is_empty():
		_check(false, "%s: the aim at %s found the block" % [String(_bench.get("tool")), str(px)])
		return
	var rec: Dictionary = _bench.call("cut_here")
	_check(not rec.is_empty(), "%s cut at %s" % [String(_bench.get("tool")), str(px)])


func _next() -> void:
	_step += 1
	_t = 0.0


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("ROOM saved %s" % name)
