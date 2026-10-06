extends SceneTree

## The Lookout, played: the tower stands where it should, the HUD card lists every key, the
## ladder's F climbs to the balcony and puts the camera up, the wheel zooms, the focus ring
## finds the owl at w +1.5, the journal opens over the camera, walking the deck works with the
## camera up, a quarter turn of the slice still shows the deck, a photo lands in the journal, F
## at the gap climbs down. And on the ground Z does NOT raise it (the camera is the lookout's,
## and Wren says so); back on the deck Z raises it, E turns the ring rather than stepping you
## through W, Z lowers it and E steps you again. And the tower's cost, on and off in blocks.
##
## Windowed, small, unfocused; saves res://smoke_test_output/lookout_<n>_<what>.png. Uses
## its own journal (user://lookout_journal_test.cfg), deleted at the start and the end.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_verify_lookout_runner.gd

const SliceAngles := preload("res://ramon/chickenpen/scripts/slice_angles_4d.gd")
const TEST_BOOK := "user://lookout_journal_test.cfg"

var _room: Node
var _lookout: Node
var _station: Node
var _tower: Node4D
var _player: Node4D
var _rig: Node
var _t: float = 0.0
var _step: int = 0
var _failed: int = 0
var _n: int = 0
var _wait: float = 0.0
var _cost: Dictionary = {"on": [], "off": []}
var _block: int = 0
var _block_f: int = 0
var _did_w: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	_clean()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_room = load("res://ramon/chickenpen/playable_world.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	_lookout = _room.get_node("Systems/Lookout")
	_lookout.set("journal_path", TEST_BOOK)
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("   %s %-62s %s" % ["PASS" if ok else "FAIL", what, detail])
	if not ok:
		_failed += 1


func _save(what: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/lookout_%d_%s.png" % [_n, what])
	_n += 1


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e)


## A key held as the keyboard holds it: through Input, so its pressed state is real.
func _hold(code: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)


func _click() -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		root.push_input(e)


func _aim(p: Vector4) -> void:
	var eye: Vector4 = _station.call("home_eye")
	_station.call("look_along", p - eye)


func _slice(xw: float, zw: float) -> void:
	SliceAngles.tilt(_rig, xw, zw)


func _put(at: Vector4) -> void:
	_player.global_position = at
	_player.set("linear_velocity", Vector4.ZERO)


func _next(after: float = 0.0) -> void:
	_step += 1
	_wait = after
	_t = 0.0


func _process(d: float) -> bool:
	_t += d
	if _t < _wait:
		return false
	match _step:
		0:
			if _t < 3.0:
				return false
			_station = _lookout.get("station")
			_tower = _room.get_node("World/LookoutSite/Lookout") as Node4D
			_player = _room.get_node("Player") as Node4D
			_rig = _room.get_node("Player/CameraRig")
			var parts: Array = _tower.find_children("Parts_*", "MeshInstance4D", false, false)
			_check("the tower is built, one mesh per colour", parts.size() >= 5 and _tower.get_node_or_null("Colliders") != null, "%d meshes" % parts.size())
			_check("it is the balcony, with a walkable deck", bool(_tower.call("is_balcony")) and _tower.get_node_or_null("DeckColliders") != null)
			_check("subjects collected", (_lookout.get("subjects").call("all") as Array).size() >= 10,
				"%d" % (_lookout.get("subjects").call("all") as Array).size())
			# In the pen, at the spawn, the Lookout card is folded away (3 Oct: nothing of the
			# Lookout carries over). Where it goes when it shows is _hud_layout_runner.gd's.
			var card := _room.get_node_or_null("UI/Journal") as Control
			_check("the Lookout card folded away in the pen", card.size.y < 1.0 or not card.visible or card.modulate.a < 0.05,
				"card %s" % str(Rect2(card.position, card.size)))
			_check("Z does nothing before Wren", not bool(_station.call("can_raise")))
			_check("the owl is on its post", (_lookout.get("owl") as Node4D).global_position.w > 1.4)
			_save("spawn_view")
			_lookout.get("journal").call("set_flag", "approached", true)
			_lookout.get("journal").call("set_flag", "met_wren", true)
			_next()
		1:
			var cam := Camera4D.new()
			cam.name = "RunnerCam"
			cam.set("rendering_engine_name", "Cross-section")
			cam.set("field_of_view_4d", 1.0)
			_room.add_child(cam)
			var eye := Vector4(-4.0, 2.5, -16.0, 0.0)
			var look: Vector4 = (_tower.global_position + Vector4(0, 8, 0, 0)) - eye
			cam.global_position = eye
			cam.global_basis = Basis4D.from_zx(atan2(-look.x, -look.z)) * Basis4D.from_yz(atan2(look.y, Vector2(look.x, look.z).length()))
			cam.make_current()
			_next(0.6)
		2:
			_save("tower_from_field")
			_block = 0
			_block_f = 0
			_next()
		3:
			_block_f += 1
			var on: bool = _block % 2 == 0
			if _block_f > 5:
				(_cost["on" if on else "off"] as Array).append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			if _block_f >= 40:
				_block += 1
				_block_f = 0
				_tower.visible = _block % 2 == 0
				if _block >= 8:
					_tower.visible = true
					print("      scripts with the tower %.3f ms, without %.3f ms" % [_mean(_cost["on"]), _mean(_cost["off"])])
					_next()
		4:
			(_room.get_node("RunnerCam") as Camera4D).queue_free()
			(_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).make_current()
			_put(_tower.call("ladder_foot") + Vector4(0, 0.05, 0.3, 0))
			_next(0.8)
		5:
			_check("climbable at the ladder's foot", bool(_lookout.call("can_climb")))
			_save("ladder_prompt")
			_key(KEY_F)
			_next(0.5)
		6:
			_check("climbing", int(_station.get("mode")) == 1)
			_save("climbing")
			_next(float(_station.get("climb_seconds")) + 0.6)
		7:
			_check("on the deck, the camera up", int(_station.get("mode")) == 5 and bool(_tower.call("on_deck", _player.global_position)),
				"mode %d at %s" % [int(_station.get("mode")), str(_player.global_position)])
			_check("up the tower, as the story counts it", bool(_station.call("up_tower")))
			_check("E and Q lifted off the walk while the camera is up", InputMap.action_get_events(&"move_ana").is_empty())
			_next(0.6)
		8:
			_save("deck_north")
			for i in 6:
				for down in [true, false]:
					var e := InputEventMouseButton.new()
					e.button_index = MOUSE_BUTTON_WHEEL_UP
					e.pressed = down
					e.factor = 1.0
					root.push_input(e)
			_check("the wheel zooms", float(_station.get("zoom_goal")) > 2.5, "%.2f" % float(_station.get("zoom_goal")))
			_next(0.3)
		9:
			_save("zooming")
			_station.set("zoom_goal", 1.0)
			_aim(Vector4(0, 18, -68, 0))
			_next(0.8)
		10:
			_save("deck_flock")
			# Round to the north side of the deck, where the owl's post is.
			_put(_tower.global_position + Vector4(0.6, float(_tower.get("deck_height")) + 0.05, -2.9, 0.0))
			_aim((_lookout.get("owl") as Node4D).call("head_point"))
			_station.set("zoom_goal", 3.0)
			_next(0.8)
		11:
			_aim((_lookout.get("owl") as Node4D).call("head_point"))
			_save("owl_focus0")
			_station.set("focus_goal", 1.5)
			_next(1.0)
		12:
			_check("the focus ring got there", absf(float(_station.get("focus")) - 1.5) < 0.05, "%.3f" % float(_station.get("focus")))
			var owl_seen: bool = false
			for v in _lookout.get("subjects").call("in_view", _station.get("camera"), _station.call("home_eye"), _station.call("slice_normal"), 3.0):
				if v["subject"]["id"] == "owl":
					owl_seen = absf(float(v["w"]) - 1.5) < 0.2
			_check("the owl is in view at about w +1.5", owl_seen)
			_save("owl_focus15")
			_key(KEY_J)
			_next(0.5)
		13:
			_check("J opens the journal over the camera", bool((_lookout.get("book") as Control).call("is_open")))
			_save("book")
			_key(KEY_J)
			_station.set("focus_goal", 0.0)
			_station.set("zoom_goal", 1.0)
			_put(_tower.global_position + Vector4(2.6, float(_tower.get("deck_height")) + 0.05, 0.0, 0.0))
			_station.call("look_along", Vector4(1.0, -0.15, 0.2, 0.0))
			_next(0.8)
		14:
			_check("J closes it again", not bool((_lookout.get("book") as Control).call("is_open")))
			_check("still on the deck after a walk", bool(_tower.call("on_deck", _player.global_position)), str(_player.global_position))
			_save("deck_east")
			_slice(PI * 0.5, 0.0)
			_next(0.7)
		15:
			_save("slice_quarter_xw")
			_slice(0.0, PI * 0.5)
			_next(0.7)
		16:
			_save("slice_quarter_zw")
			_slice(0.0, 0.0)
			var nike := _room.get_node("World/Nike") as Node4D
			_put(_tower.global_position + Vector4(1.4, float(_tower.get("deck_height")) + 0.05, 2.4, 0.0))
			_aim(nike.global_position + Vector4(0, 0.5, 0, 0))
			_station.set("zoom_goal", 7.0)
			_next(1.2)
		17:
			var nike := _room.get_node("World/Nike") as Node4D
			_aim(nike.global_position + Vector4(0, 0.5, 0, 0))
			_save("nike_zoom7")
			_click()
			_next(0.8)
		18:
			var recent: Array = _lookout.get("journal").get("recent")
			_check("a photo was taken", recent.size() == 1)
			if recent.size() > 0:
				print("      photo: ", recent[-1])
			_check("the film counted down", int(_station.get("film")) == 23)
			_save("after_shot")
			_station.set("zoom_goal", 1.0)
			_put(_tower.call("ladder_top") + Vector4(0, 0.05, 0, 0))
			_next(0.5)
		19:
			_check("F at the gap would climb down", bool(_lookout.call("can_climb_down")))
			_key(KEY_F)
			_next(0.4)
		20:
			_check("climbing down", int(_station.get("mode")) == 3)
			_next(float(_station.get("down_seconds")) + 0.6)
		21:
			_check("off the tower, the pen back", int(_station.get("mode")) == 0 and _player.visible and _player.get("input_enabled") == true)
			_check("E and Q back on the walk", not InputMap.action_get_events(&"move_ana").is_empty())
			_check("the HUD back", (_room.get_node("UI/Controls") as CanvasItem).visible)
			_save("back_down")
			_put(Vector4(2.0, 0.05, -6.0, 0.0))
			_next(0.6)
		22:
			# On the ground by the tower: Z says the camera is the lookout's. (Out in the pen it
			# says nothing: 3 Oct, nothing of the Lookout carries over. Checked after.)
			_put(_tower.global_position + Vector4(4.0, 0.05, 6.0, 0.0))
			_step = 40
			_wait = 0.6
			_t = 0.0
		40:
			_key(KEY_Z)
			_step = 41
			_wait = 0.5
			_t = 0.0
		41:
			_check("on the ground, Z leaves the camera down", int(_station.get("mode")) == 0)
			_check("and Wren says it is the lookout's", int(_lookout.get("story").get("_not_here_at")) > 0)
			_lookout.get("story").set("_not_here_at", 0)
			_put(Vector4(2.0, 0.05, -6.0, 0.0))
			_step = 42
			_wait = 0.6
			_t = 0.0
		42:
			_key(KEY_Z)
			_step = 43
			_wait = 0.5
			_t = 0.0
		43:
			_check("out in the pen, Z says nothing", int(_lookout.get("story").get("_not_here_at")) == 0)
			_step = 27
		27:
			# Back up on the deck for the rest.
			_put(_tower.global_position + Vector4(0.6, float(_tower.get("deck_height")) + 0.05, -2.9, 0.0))
			_step = 28
			_wait = 0.5
			_t = 0.0
		28:
			_key(KEY_Z)
			_step = 23
			_wait = 0.5
			_t = 0.0
		23:
			_check("on the deck, Z raises the camera", int(_station.get("mode")) == 5)
			_did_w = _player.global_position.w
			_station.set("focus_goal", 0.0)
			_hold(KEY_E, true)
			_next(0.6)
		24:
			_hold(KEY_E, false)
			_check("E turns the ring with the camera up", float(_station.get("focus_goal")) > 0.3, "%.2f" % float(_station.get("focus_goal")))
			_check("and does not step you through W", absf(_player.global_position.w - _did_w) < 0.05, "w %.3f" % _player.global_position.w)
			_save("deck_camera")
			_key(KEY_Z)
			_next(0.5)
		25:
			_check("Z lowers it, and E and Q are back", int(_station.get("mode")) == 0 and not InputMap.action_get_events(&"move_ana").is_empty())
			_save("deck_after")
			_next()
		26:
			_clean()
			print("LOOKOUT RUNNER: %s (%d failed)" % ["PASS" if _failed == 0 else "FAIL", _failed])
			return true
	return false


func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sum: float = 0.0
	for v in values:
		sum += float(v)
	return sum / float(values.size())


func _clean() -> void:
	var book: String = ProjectSettings.globalize_path(TEST_BOOK)
	if FileAccess.file_exists(TEST_BOOK):
		DirAccess.remove_absolute(book)
	var photos: String = ProjectSettings.globalize_path("user://lookout_journal_test_photos")
	if DirAccess.dir_exists_absolute(photos):
		for f in DirAccess.get_files_at(photos):
			DirAccess.remove_absolute(photos + "/" + f)
		DirAccess.remove_absolute(photos)
