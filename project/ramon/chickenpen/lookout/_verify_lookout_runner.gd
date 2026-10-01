extends SceneTree

## The Lookout, played: the tower stands where it should, the ladder's F climbs it, the cab
## looks out north, the lens zooms, the focus ring finds the ana post at w +1.5, a quarter
## turn of the slice still shows walls, a photo of Nike lands in the journal, Escape climbs
## down and gives the pen back as it was. And the tower's frame cost, on and off in blocks.
##
## Windowed, small, unfocused; saves res://smoke_test_output/lookout_<n>_<what>.png. Uses
## its own journal (user://lookout_journal_test.cfg), deleted at the end.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_verify_lookout_runner.gd

const TEST_BOOK := "user://lookout_journal_test.cfg"

var _room: Node
var _lookout: Node
var _station: Node
var _tower: Node4D
var _player: Node4D
var _t: float = 0.0
var _step: int = 0
var _failed: int = 0
var _n: int = 0
var _wait: float = 0.0
var _cost: Dictionary = {"on": [], "off": []}
var _block: int = 0
var _block_f: int = 0


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
	for node in _room.find_children("*", "", true, false):
		if "debug_key_enabled" in node:
			node.set("debug_key_enabled", false)
	_lookout = _room.get_node("Systems/Lookout")
	_lookout.set("journal_path", TEST_BOOK)
	root.add_child(_room)
	current_scene = _room


func _check(what: String, ok: bool, detail: String = "") -> void:
	print("   %s %-60s %s" % ["PASS" if ok else "FAIL", what, detail])
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


func _click() -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		root.push_input(e)


## Points the station's camera at [param p].
func _aim(p: Vector4) -> void:
	var eye: Vector4 = _station.call("home_eye")
	_station.call("look_along", p - eye)


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
			_tower = _room.get_node("World/Lookout") as Node4D
			_player = _room.get_node("Player") as Node4D
			var parts: Array = _tower.find_children("Parts_*", "MeshInstance4D", false, false)
			_check("the tower is built, one mesh per colour", _tower != null and parts.size() >= 5 and _tower.get_node_or_null("Colliders") != null,
				"%d meshes" % parts.size())
			var ground: RefCounted = _lookout.get("ground")
			_check("the ground is mapped", ground != null)
			if ground != null:
				var g: Array = []
				for at in [Vector2(-16, -36), Vector2(-30, -30), Vector2(-24, -30), Vector2(0, -50), Vector2(20, -40), Vector2(-40, -10)]:
					g.append("%s:%.2f" % [str(at), float(ground.call("height", at.x, at.y))])
				print("      ground heights ", ", ".join(g))
			_check("subjects collected", (_lookout.get("subjects").call("all") as Array).size() >= 10,
				"%d" % (_lookout.get("subjects").call("all") as Array).size())
			_check("not climbable from the spawn point", not bool(_lookout.call("can_climb")))
			var card := _room.get_node_or_null("UI/Journal") as Control
			var cine := _room.get_node("UI/Cinematics") as Control
			var picker := _room.get_node("UI/CameraPicker") as Control
			# Under the Cinematics card when there is room; beside it, tops level, when a small
			# window at a big UI size leaves none.
			var under: bool = card != null and absf(card.position.y - (cine.position.y + cine.size.y + 10.0)) < 1.5
			var beside: bool = card != null and absf(card.position.y - cine.position.y) < 1.5 and absf(card.position.x + card.size.x + 10.0 - cine.position.x) < 1.5
			var screen: Vector2 = card.get_viewport_rect().size if card else Vector2.ZERO
			_check("the Journal card under the Cinematics card, or beside it when short of room",
				under or (beside and cine.position.y + cine.size.y + 10.0 + card.size.y > screen.y - 6.0),
				"card %s cine %s screen %s" % [str(Rect2(card.position, card.size)) if card else "-", str(Rect2(cine.position, cine.size)), str(screen)])
			_check("the card on screen", card != null and card.position.y + card.size.y <= screen.y and card.position.x >= 0.0)
			_check("the camera picker clear of the Journal card", card != null and not Rect2(card.position, card.size).intersects(Rect2(picker.position, picker.size)),
				"picker %s" % str(Rect2(picker.position, picker.size)))
			_check("Wren is there", _room.get_node_or_null("World/Wren") != null)
			_check("the owl is on its post", _lookout.get("owl") != null and (_lookout.get("owl") as Node4D).global_position.w > 1.4)
			_save("spawn_view")
			# This runner tests the camera: the story is skipped (its own runner walks it).
			_lookout.get("journal").call("set_flag", "approached", true)
			_lookout.get("journal").call("set_flag", "met_wren", true)
			_next()
		1:
			# Look at the tower from the field, with a camera of our own.
			var cam := Camera4D.new()
			cam.name = "RunnerCam"
			cam.set("rendering_engine_name", "Cross-section")
			cam.set("field_of_view_3d", 0.96)
			_room.add_child(cam)
			var eye := Vector4(-6.0, 1.7, -14.0, 0.0)
			var look: Vector4 = (_tower.global_position + Vector4(0, 7, 0, 0)) - eye
			cam.global_position = eye
			cam.global_basis = Basis4D.from_zx(atan2(-look.x, -look.z)) * Basis4D.from_yz(atan2(look.y, Vector2(look.x, look.z).length()))
			cam.make_current()
			_next(0.6)
		2:
			_save("tower_from_field")
			# The tower's cost: on and off in blocks of 40 frames.
			_block = 0
			_block_f = 0
			_next()
		3:
			_block_f += 1
			var on: bool = _block % 2 == 0
			if _block_f > 5:
				(_cost["on" if on else "off"] as Array).append(d * 1000.0)
			if _block_f >= 40:
				_block += 1
				_block_f = 0
				_tower.visible = _block % 2 == 0
				if _block >= 8:
					_tower.visible = true
					var on_ms: float = _mean(_cost["on"])
					var off_ms: float = _mean(_cost["off"])
					print("      frame time with the tower %.3f ms, without %.3f ms" % [on_ms, off_ms])
					_next()
		4:
			# Walk up to the ladder.
			(_room.get_node("RunnerCam") as Camera4D).queue_free()
			(_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).make_current()
			_player.global_position = _tower.call("ladder_foot") + Vector4(0, 0.05, 0.3, 0)
			_next(0.8)
		5:
			_check("climbable at the ladder's foot", bool(_lookout.call("can_climb")))
			_save("ladder_prompt")
			_key(KEY_F)
			_next(0.5)
		6:
			_check("climbing", int(_station.get("mode")) == 1)
			_check("the player hidden and frozen", not _player.visible and _player.get("input_enabled") == false)
			_save("climbing")
			_next(float(_station.get("climb_seconds")))
		7:
			_check("in the cab", int(_station.get("mode")) == 2)
			_next(0.5)
		8:
			_save("cab_north")
			_station.set("yaw", PI)
			_next(0.6)
		9:
			_save("cab_south")
			# The roost, and the flock over it.
			_aim(Vector4(0, 18, -68, 0))
			_station.set("zoom_goal", 3.0)
			_next(1.0)
		10:
			_save("flock_zoom3")
			# North window, the ana post: nothing there at focus 0.
			_station.set("zoom_goal", 1.6)
			_aim(_tower.call("ana_perch"))
			_next(0.8)
		11:
			_save("ana_post_focus0")
			_station.set("focus_goal", 1.5)
			_station.set("zoom_goal", 3.5)
			_aim((_lookout.get("owl") as Node4D).call("head_point"))
			_next(1.0)
		12:
			_check("the focus ring got there", absf(float(_station.get("focus")) - 1.5) < 0.05, "%.3f" % float(_station.get("focus")))
			_save("owl_focus15")
			var owl_seen: bool = false
			for v in _lookout.get("subjects").call("in_view", _station.get("camera"), _station.call("home_eye"), _station.call("slice_normal"), 3.0):
				if v["subject"]["id"] == "owl":
					owl_seen = absf(float(v["w"]) - 1.5) < 0.2
			_check("the owl is in view at about w +1.5", owl_seen)
			_key(KEY_J)
			_next(0.5)
		13:
			var book: Control = _lookout.get("book")
			_check("J opens the journal in the cab", bool(book.call("is_open")))
			_save("book_in_cab")
			_key(KEY_DOWN)
			_next(0.3)
		14:
			_save("book_page2")
			_key(KEY_J)
			_station.set("focus_goal", 0.0)
			_station.set("slice_xw", PI * 0.5)
			_station.set("zoom_goal", 1.0)
			_station.set("yaw", 0.0)
			_station.set("pitch", 0.0)
			_next(0.8)
		15:
			_check("J closes it again", not bool((_lookout.get("book") as Control).call("is_open")))
			_save("slice_quarter_xw")
			_station.set("slice_xw", 0.0)
			_station.set("slice_zw", PI * 0.5)
			_next(0.6)
		16:
			_save("slice_quarter_zw")
			_station.set("yaw", PI * 0.5)
			_next(0.5)
		17:
			_save("slice_quarter_zw_west")
			_station.set("slice_zw", 0.0)
			_station.set("slice_xw", PI * 0.5)
			_station.set("yaw", -PI * 0.5)
			_next(0.5)
		18:
			_save("slice_quarter_xw_east")
			_station.set("slice_xw", 0.0)
			_station.set("yaw", 0.0)
			_next(0.2)
		19:
			_station.set("slice_zw", 0.0)
			var nike := _room.get_node("World/Nike") as Node4D
			_aim(nike.global_position + Vector4(0, 0.5, 0, 0))
			_station.set("zoom_goal", 8.0)
			_next(1.2)
		20:
			_save("nike_zoom8")
			var seen: Array = []
			for v in _lookout.get("subjects").call("in_view", _station.get("camera"), _station.call("home_eye"), _station.call("slice_normal"), 3.0):
				seen.append("%s w%+.2f at %s" % [v["subject"]["id"], float(v["w"]), str((v["screen"] as Vector2).snapped(Vector2(0.01, 0.01)))])
			print("      in view: ", ", ".join(seen))
			_click()
			_next(0.8)
		21:
			var journal: Node = _lookout.get("journal")
			var recent: Array = journal.get("recent")
			_check("a photo was taken", recent.size() == 1)
			if recent.size() > 0:
				print("      photo: ", recent[-1])
			_check("the film counted down", int(_station.get("film")) == 23)
			_save("after_shot")
			_key(KEY_ESCAPE)
			_next(0.4)
		22:
			_check("climbing down", int(_station.get("mode")) == 3)
			_next(float(_station.get("down_seconds")) + 0.6)
		23:
			_check("off the tower", int(_station.get("mode")) == 0)
			_check("the player back, shown, in control", _player.visible and _player.get("input_enabled") == true \
				and _player.process_mode != Node.PROCESS_MODE_DISABLED)
			var hud_back: bool = (_room.get_node("UI/Controls") as CanvasItem).visible
			_check("the HUD back", hud_back)
			_save("back_down")
			_next()
		24:
			var book: String = ProjectSettings.globalize_path(TEST_BOOK)
			if FileAccess.file_exists(TEST_BOOK):
				DirAccess.remove_absolute(book)
			var photos: String = ProjectSettings.globalize_path("user://lookout_journal_test_photos")
			if DirAccess.dir_exists_absolute(photos):
				for f in DirAccess.get_files_at(photos):
					DirAccess.remove_absolute(photos + "/" + f)
				DirAccess.remove_absolute(photos)
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
