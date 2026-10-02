extends SceneTree

## Frames of round three, for judging by eye: the owl's dead tree (from the deck, at the
## owl's w and at the farm's), the projection on and off (the farm camera, then the raised
## one), the lens primes, the round pond, the kata wood and a chipmunk going round its tree
## through W, the F4 overlay, rings on the water, the guided first photo, the judging bars
## and the roll page. Prints what it measures.
##
## Windowed, small, unfocused; saves res://smoke_test_output/round3_<n>_<view>.png.
##
##   godot... --path project --windowed --resolution 1280x720 --position 40,40
##       --script res://ramon/chickenpen/lookout/_capture_round3_runner.gd

const TEST_BOOK := "user://lookout_journal_round3_test.cfg"

var _room: Node
var _lookout: Node
var _t: float = 0.0
var _step: int = 0
var _wait: float = 0.0
var _n: int = 0
var _cam: Camera4D
var _failed: int = 0


func _initialize() -> void:
	root.unfocusable = true
	if FileAccess.file_exists(TEST_BOOK):
		DirAccess.remove_absolute(TEST_BOOK)
	_room = load("res://ramon/chickenpen/chickenpen_lookout.tscn").instantiate()
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


func _save(view: String) -> void:
	root.get_texture().get_image().save_png("res://smoke_test_output/round3_%d_%s.png" % [_n, view])
	_n += 1


func _next(after: float = 0.0) -> void:
	_step += 1
	_wait = after
	_t = 0.0


func _look(eye: Vector4, at: Vector4) -> void:
	_cam.global_position = eye
	var d: Vector4 = at - eye
	_cam.global_basis = Basis4D.from_zx(atan2(-d.x, -d.z)) * Basis4D.from_yz(atan2(d.y, Vector2(d.x, d.z).length()))


func _process(d: float) -> bool:
	_t += d
	if _t < _wait:
		return false
	var tower: Node4D = _lookout.get("tower")
	var owl: Node4D = _lookout.get("owl")
	var tree: Node4D = _lookout.get("owl_tree")
	var station: Node = _lookout.get("station")
	match _step:
		0:
			if _t < 4.0:
				return false
			for f in ["approached", "met_wren"]:
				_lookout.get("journal").call("set_flag", f, true)
			_check("the owl's tree is built", tree != null and tree.get_child_count() > 0, "%d tetrahedra" % int(tree.get("cells")) if tree else "")
			var gap: Vector4 = owl.global_position - (tree.call("perch_point") as Vector4)
			_check("the owl sits on its twig", gap.length() < 0.06, str(gap))
			_cam = Camera4D.new()
			_cam.set("rendering_engine_name", "Cross-section")
			_cam.set("field_of_view_4d", 1.0)
			_room.add_child(_cam)
			_cam.make_current()
			# From the deck's north rail, at the owl's own w.
			var eye: Vector4 = tower.global_position + Vector4(0.6, float(tower.get("deck_height")) + 1.5, -2.9, owl.global_position.w)
			_look(eye, owl.global_position + Vector4(0, 0.3, 0, 0))
			_next(0.4)
		1:
			_save("tree_deck_owl_w")
			var o: Vector4 = owl.global_position
			_look(Vector4(o.x + 9.0, 4.0, o.z - 14.0, o.w), Vector4(o.x - 1.0, 6.5, o.z - 1.0, o.w))
			_next(0.4)
		2:
			_save("tree_far_owl_w")
			var o: Vector4 = owl.global_position
			_look(Vector4(o.x + 9.0, 4.0, o.z - 14.0, 0.0), Vector4(o.x - 1.0, 6.5, o.z - 1.0, 0.0))
			_next(0.4)
		3:
			_save("tree_far_w0")
			# The farm camera, the player by the tower looking at it.
			(_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).make_current()
			_cam.queue_free()
			var player := _room.get_node("Player") as Node4D
			player.global_position = tower.global_position + Vector4(6.0, 0.05, 12.0, 0.0)
			_next(1.0)
		4:
			_save("proj_off_farm")
			_lookout.call("set_projection", true)
			_next(1.5)
		5:
			var cam: Camera4D = _lookout.call("current_camera")
			_check("the projection is on: the camera is on the Combined renderer", String(cam.get("rendering_engine_name")) == "Combined", String(cam.get("rendering_engine_name")))
			_save("proj_on_farm")
			_lookout.call("set_projection", false)
			_next(1.0)
		6:
			var cam: Camera4D = _lookout.call("current_camera")
			_check("and off again: back on Cross-section, still running", String(cam.get("rendering_engine_name")) == "Cross-section")
			_save("proj_off_again")
			station.call("raise")
			_next(1.2)
		7:
			_lookout.call("set_projection", true)
			_next(1.5)
		8:
			_save("proj_on_held")
			_lookout.call("set_projection", false)
			for k in 3:
				station.call("next_lens", 1)
			_next(1.0)
		9:
			_check("three presses of L: the 50 mm", absf(float(station.call("lens_mm")) - 50.0) < 1.0, "%.1f mm, %.1f deg" % [float(station.call("lens_mm")), float(station.call("lens_degrees", float(station.call("lens_mm"))))])
			_save("lens_50")
			station.call("next_lens", -1)
			_next(0.25)
		10:
			_save("lens_back_to_35_zooming")
			station.call("lower")
			_next(0.6)
		11:
			_cam = Camera4D.new()
			_cam.set("rendering_engine_name", "Cross-section")
			_cam.set("field_of_view_4d", 1.0)
			_room.add_child(_cam)
			_cam.make_current()
			var m: Node4D = _lookout.get("marsh")
			var c: Vector4 = m.global_position
			_look(c + Vector4(0.0, 16.0, 9.0, 0.0), c)
			_next(0.5)
		12:
			_save("pond_above")
			var c: Vector4 = (_lookout.get("marsh") as Node4D).global_position
			_look(c + Vector4(9.0, 2.2, 7.0, 0.0), c + Vector4(0, 0.3, 0, 0))
			_next(0.5)
		13:
			_save("pond_low")
			var wood: Node4D = _lookout.get("wood")
			_check("the kata wood is built, with its chipmunks", wood != null and wood.get("tree") != null and (_lookout.get("chipmunks") as Array).size() == 3)
			_look(wood.global_position + Vector4(5.0, 2.2, 6.5, 0.0), wood.global_position + Vector4(0, 1.3, 0, 0))
			_next(0.5)
		14:
			_save("kata_wood")
			var chip: Node4D = (_lookout.get("chipmunks") as Array)[0]
			chip.call("perform", "round_w")
			var trunk: Node4D = (_lookout.get("wood") as Node4D).get("tree")
			_look(trunk.global_position + Vector4(0.0, 1.4, 2.6, 0.0), trunk.global_position + Vector4(0, 1.0, 0, 0))
			_next(0.9)
		15, 16, 17:
			var chip: Node4D = (_lookout.get("chipmunks") as Array)[0]
			var trunk: Node4D = (_lookout.get("wood") as Node4D).get("tree")
			print("      chipmunk on the trunk: state %d, w from the tree %+.2f, %s" % [int(chip.get("state")), chip.global_position.w - trunk.global_position.w, str(chip.call("behaviour"))])
			_save("chip_round_w_%d" % (_step - 14))
			if _step == 17:
				_lookout.get("dev_overlay").set("on", true)
				_lookout.get("dev_overlay").set("visible", true)
			_next(0.9)
		18:
			_save("dev_overlay")
			_lookout.get("dev_overlay").set("on", false)
			_lookout.get("dev_overlay").set("visible", false)
			var m: Node4D = _lookout.get("marsh")
			_look(m.global_position + Vector4(3.5, 1.6, 4.0, 0.0), m.global_position + Vector4(0, 0.1, 0, 0))
			m.call("ripple", Vector4(0.5, 0, 0.5, 0), 1.2)
			_next(0.9)
		19:
			_save("ripples")
			(_room.get_node("Player/CameraRig/Pitch/Camera4D") as Camera4D).make_current()
			_cam.queue_free()
			var wren: Node4D = _lookout.get("wren")
			(_room.get_node("Player") as Node4D).global_position = wren.global_position + Vector4(3.0, 0.05, 3.0, 0.0)
			_next(0.6)
		20:
			station.call("raise")
			_next(1.2)
		21:
			var wren: Node4D = _lookout.get("wren")
			station.call("look_along", wren.global_position + Vector4(0, 0.9, 0, 0) - (station.call("home_eye") as Vector4))
			_next(0.8)
		22:
			_save("guide_wren")
			station.call("take_photo")
			_next(0.9)
		23:
			_save("toast_bars")
			var recent: Array = _lookout.get("journal").get("recent")
			_check("the photo is on the roll, with how it was judged", not recent.is_empty() and (recent.back() as Dictionary).has("sharp"), str(recent.back() if not recent.is_empty() else ""))
			station.call("lower")
			_next(0.5)
		24:
			var book: Node = _lookout.get("book")
			book.call("open_book")
			book.set("_page", (_lookout.get("journal").get("PAGES") as Array).size() if _lookout.get("journal").get("PAGES") != null else 11)
			book.call("queue_redraw")
			_next(0.4)
		25:
			_save("journal_roll")
			_lookout.get("book").call("close_book")
			print("ROUND3 CAPTURE: %s (%d failed)" % ["PASS" if _failed == 0 else "FAIL", _failed])
			if FileAccess.file_exists(TEST_BOOK):
				DirAccess.remove_absolute(TEST_BOOK)
			return true
	return false
