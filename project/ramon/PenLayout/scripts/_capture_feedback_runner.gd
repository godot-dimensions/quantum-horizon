extends SceneTree

## RAMON'S 7 OCT FEEDBACK, LOOKED AT (Ramon: "yes please look at things you programmed without looking"): the pen
## loaded, and frames of each change, to res://smoke_test_output/feedback/<mode>_*.png. One mode a run:
##   ladder     the art look: the little ladder at the top of the Watchstone, from outside and from its platform
##   tower      the dev look: the Watchstone as boxes, its timber kept, the walk surfaces orange (and the art look
##              from the first view, to compare)
##   climb      the walk-up: on the first ramp, the fade, the platform at the ladder's foot, up the ladder in the
##              play view, onto the plateau (a frame every 0.4 s, the player's height printed)
##   professor  the art look: the professor close, from the front and three quarters, his marker at his feet
##   markers    the art look: the orange rings at the keeper's, the rock-pile cat's, Nike's, Mithra's and the range
##              master's feet
##   start      the first frame you see: your avatar facing the way the camera looks
##   camp       the camp's ring on the ground (dev look, at the camp's W) and the guide by its marker (art look)
##   cave       the cave road's end: the climb, then the flat stretch at the door's W, the circle, the arch (art, dev)
##   balloon    the balloon's branch off the tower road and the basket in the dev look's orange
##   lookcam    on top of the Watchstone: "Z  use the camera" at the rail, the camera up with "Scroll to zoom", T on
##              the marsh (the slice laid flat, the focus out to w +8, the heron), its photo named, the dev look's
##              orange ring and blue water (a test journal, never yours)
##
##   lab_run.sh windowed fb_<mode> res://ramon/PenLayout/scripts/_capture_feedback_runner.gd <mode>

const PEN := "res://ramon/chickenpen/playable_world.tscn"
const OUT := "res://smoke_test_output/feedback/"

var _room: Node
var _cam: Camera4D
var _mode: String = ""
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_mode = args[0] if args.size() > 0 else "tower"
	# The HUD at Ramon's size (the runner's window is 1280 x 720).
	if _mode == "panels":
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	_run.call_deferred()


func _process(_x: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 90000:
		print("FEEDBACK %s: gave up after 90 s" % _mode)
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(s: float) -> void:
	await create_timer(s).timeout


## The HUD off for a frame, and back as it was: only what was showing comes back (forcing every part on showed
## the hidden "Restart game?" prompt in the frames, 7 Oct).
var _hidden: Array = []


func _hud(on: bool) -> void:
	var ui: Node = _room.get_node_or_null("UI")
	if ui == null:
		return
	if on:
		for c in _hidden:
			if is_instance_valid(c):
				c.set("visible", true)
		_hidden.clear()
		for c in ui.get_children():
			if String(c.name) in ["GrassPanel", "PathsPanel"]:
				c.process_mode = Node.PROCESS_MODE_INHERIT
		return
	for c in ui.get_children():
		if String(c.name) in ["GrassPanel", "PathsPanel"]:
			c.process_mode = Node.PROCESS_MODE_DISABLED
		if (c is CanvasItem or c is CanvasLayer) and bool(c.get("visible")):
			c.set("visible", false)
			_hidden.append(c)


func _look(dev: bool) -> void:
	var look: Node = _room.get_node_or_null("Systems/Look")
	if look != null and look.has_method("set_dev"):
		look.call("set_dev", dev)


func _aim(eye: Vector4, at: Vector4) -> void:
	if _cam == null:
		_cam = Camera4D.new()
		_cam.name = "FeedbackCamera"
		_room.add_child(_cam)
	_cam.rendering_engine_name = "Cross-section"
	_cam.global_position = eye
	_cam.look_at(at, Vector4(0, 1, 0, 0))
	_cam.make_current()


func _shot(name: String, hud: bool = false) -> void:
	_hud(hud)
	var lookout: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout != null and lookout.has_method("set_projection"):
		lookout.call("set_projection", false)
	await _frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + _mode + "_" + name + ".png"))
	print("SHOT %s_%s" % [_mode, name])


## The raised camera turned and pitched until [param id] (a photo subject) is in the middle of the frame: the
## rig's heading and pitch nudged by where it shows, a few times.
func _centre_on(lookout: Node, station: Node, rig: Node, id: String) -> void:
	var subjects: Node = lookout.get("subjects")
	var cam := station.get("camera") as Camera4D
	for i in 6:
		await _frames(3)
		var at: Variant = null
		for v in subjects.call("in_view", cam, station.call("home_eye"), station.call("slice_normal"), 12.0):
			if String(v["subject"]["id"]) == id:
				at = v["screen"]
		if at == null:
			# Not in frame yet: face it, level, and look again.
			var target: Vector4 = subjects.call("point", _subject(subjects, id))
			var eye: Vector4 = cam.global_position
			rig.call("face_toward", Vector4(target.x - eye.x, 0.0, target.z - eye.z, 0.0))
			rig.set("pitch", -atan2(eye.y - target.y, Vector2(target.x - eye.x, target.z - eye.z).length()))
			rig.call("drag_slice", Vector2.ZERO)
			continue
		var sc: Vector2 = at
		print("LOOKCAM: %s at %s on the screen" % [id, str(sc.snapped(Vector2(0.01, 0.01)))])
		if sc.length() < 0.05:
			return
		var half: float = float(cam.get("field_of_view_4d")) * 0.5
		rig.set("pitch", float(rig.get("pitch")) + sc.y * half)
		rig.set("yaw", float(rig.get("yaw")) - sc.x * half * 1.6)
		rig.call("drag_slice", Vector2.ZERO)


func _subject(subjects: Node, id: String) -> Dictionary:
	for s in subjects.call("all"):
		if String(s["id"]) == id:
			return s
	return {}


func _tower() -> Node4D:
	return _room.get_node("World/LookoutSite/Lookout") as Node4D


func _tg(local: Vector4) -> Vector4:
	var t: Node4D = _tower()
	return t.global_position + t.global_basis * local


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_room = (load(PEN) as PackedScene).instantiate()
	# A journal of the run's own: never Ramon's book (lookout_4d.gd journal_path).
	var book: String = "user://feedback_test_journal.cfg"
	if FileAccess.file_exists(book):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(book))
	var lookout_node: Node = _room.get_node_or_null("Systems/Lookout")
	if lookout_node != null:
		lookout_node.set("journal_path", book)
	root.add_child(_room)
	current_scene = _room
	# Keys and the mouse kept out of the window (follow_up: test windows steal focus; a stray key opened the
	# restart prompt over the first frame).
	var guard := Node.new()
	guard.set_script(load("res://ramon/PenLayout/scripts/input_guard.gd"))
	root.add_child(guard)
	await _wait(3.0)
	var player := _room.get_node("Player") as CharacterBody4D
	if _mode != "climb" and _mode != "start":
		player.set("input_enabled", false)
	match _mode:
		"ladder":
			_look(false)
			await _wait(0.5)
			_aim(_tg(Vector4(10.0, 13.6, 8.5, 0)), _tg(Vector4(2.7, 12.7, 2.8, 0)))
			await _shot("1_outside")
			_aim(_tg(Vector4(6.2, 12.9, 4.2, 0)), _tg(Vector4(2.6, 12.9, 2.7, 0)))
			await _shot("2_platform")
		"tower":
			_look(true)
			await _wait(0.8)
			var views := [[Vector4(20, 9, 20, 0), Vector4(0, 7, 0, 0)], [Vector4(-18, 8, 16, 0), Vector4(0, 7, 0, 0)],
				[Vector4(16, 15, -14, 0), Vector4(0, 8, 0, 0)], [Vector4(9, 4, 15, 0), Vector4(2, 3, 6, 0)],
				[Vector4(13, 12, 15, 0), Vector4(2, 5, 4, 0)]]
			for i in views.size():
				_aim(_tg(views[i][0]), _tg(views[i][1]))
				await _shot("dev_%d" % (i + 1))
			_look(false)
			await _wait(0.8)
			_aim(_tg(views[0][0]), _tg(views[0][1]))
			await _shot("art_1")
		"climb":
			_look(false)
			var t: Node4D = _tower()
			player.set("input_enabled", true)
			player.global_position = t.call("walk_up_point")
			player.set("linear_velocity", Vector4.ZERO)
			var rig: Node = player.get_node("CameraRig")
			rig.call("face_toward", t.call("walk_up_direction"))
			_hud(false)
			var k: int = 0
			var started: int = Time.get_ticks_msec()
			while Time.get_ticks_msec() - started < 4400:
				await _wait(0.4)
				k += 1
				print("CLIMB %.1f s: phase %d, player at y %.2f (x %.2f z %.2f), input %s" % [(Time.get_ticks_msec() - started) / 1000.0,
					int(t.get("_phase")), player.global_position.y, player.global_position.x, player.global_position.z,
					str(player.get("input_enabled"))])
				await _shot("%02d" % k)
			print("CLIMB: on the plateau %s, walking again %s" % [str(bool(t.call("on_deck", player.global_position))), str(player.get("input_enabled"))])
		"professor":
			_look(false)
			var prof := _room.get_node("World/ProfessorPost/Professor") as Node4D
			var p: Vector4 = prof.global_position
			var front: Vector4 = (prof.global_basis * Vector4(0, 0, 1, 0)).normalized()
			player.global_position = p + front * 3.0 + Vector4(0, 1.0, 0, 0)
			await _wait(1.0)
			front = (prof.global_basis * Vector4(0, 0, 1, 0)).normalized()
			var side: Vector4 = (prof.global_basis * Vector4(1, 0, 0, 0)).normalized()
			_aim(p + front * 2.3 + Vector4(0, 1.25, 0, 0), p + Vector4(0, 0.9, 0, 0))
			await _shot("1_front")
			_aim(p + front * 1.8 + side * 1.4 + Vector4(0, 1.4, 0, 0), p + Vector4(0, 0.8, 0, 0))
			await _shot("2_three_quarters")
			_aim(p + front * 1.2 + Vector4(0, 1.45, 0, 0), p + Vector4(0, 1.25, 0, 0))
			await _shot("3_face")
		"markers":
			# The rings are the dev look's only (7 Oct).
			_look(true)
			await _wait(0.8)
			for path in ["World/KeeperPost/Keeper", "World/RockPileSpot/Cat", "World/Nike", "Mithra", "World/Range/RangeMaster"]:
				var who := _room.get_node_or_null(path) as Node4D
				if who == null:
					print("MARKERS: %s not found" % path)
					continue
				var w: Vector4 = who.global_position
				var eye: Vector4 = w + Vector4(2.6, 2.2, 2.6, 0)
				eye.w = w.w
				_aim(eye, w + Vector4(0, 0.2, 0, 0))
				_cam.global_position.w = w.w
				await _shot(String(path).get_file())
				var ring := _room.get_node_or_null("Systems/NpcMarkers/Marker_" + String(path).get_file()) as Node4D
				print("MARKERS %s: at (%.2f, %.2f, %.2f, w %.2f), its ring %s at y %.2f w %.2f" % [path, w.x, w.y, w.z, w.w,
					"shown" if ring != null and ring.visible else "HIDDEN", ring.global_position.y if ring != null else NAN,
					ring.global_position.w if ring != null else NAN])
		"start":
			_hud(true)
			await _wait(0.5)
			var avatar := player.get_node("Avatar") as Node4D
			var face: Vector4 = avatar.global_basis * Vector4(0, 0, 1, 0)
			var view: Vector4 = -(player.get_node("CameraRig/Pitch/Camera4D") as Node4D).global_basis.z
			print("START: the avatar faces (%.2f, %.2f), the camera looks (%.2f, %.2f): %s" % [face.x, face.z, view.x, view.z,
				"the same way" if Vector2(face.x, face.z).normalized().dot(Vector2(view.x, view.z).normalized()) > 0.9 else "NOT the same way"])
			await _shot("1_first_frame", false)
		"camp":
			var camp := _room.get_node("World/EggCamp") as Node4D
			var c: Vector4 = camp.global_position
			_look(true)
			await _wait(0.8)
			_aim(Vector4(c.x - 16.0, 7.0, c.z + 9.0, c.w), Vector4(c.x - 5.0, 0.0, c.z, c.w))
			await _shot("1_ring_dev")
			_look(false)
			await _wait(0.8)
			_aim(Vector4(c.x - 16.0, 7.0, c.z + 9.0, c.w), Vector4(c.x - 5.0, 0.0, c.z, c.w))
			await _shot("2_art_at_its_w")
			var guide := _room.get_node_or_null("World/CampGuide/Guide") as Node4D
			if guide != null:
				var g: Vector4 = guide.global_position
				_aim(Vector4(g.x - 6.0, 2.4, g.z + 2.0, g.w), g + Vector4(0, 0.9, 0, 0))
				await _shot("3_guide")
			else:
				print("CAMP: no guide yet")
		"talk":
			# The camp's guide, talked to: you beside him, F, his first line on screen.
			_look(false)
			var guide := _room.get_node("World/CampGuide/Guide") as Node4D
			var g: Vector4 = guide.global_position
			player.set("input_enabled", true)
			player.global_position = g + Vector4(-1.4, 0.3, 0.2, 0)
			player.set("linear_velocity", Vector4.ZERO)
			player.get_node("CameraRig").call("face_toward", g - player.global_position)
			await _wait(1.0)
			var ev := InputEventAction.new()
			ev.action = &"catch_target"
			ev.pressed = true
			Input.parse_input_event(ev)
			await _wait(2.2)
			var talk: Node = _room.get_node("Systems/CampGuideTalk")
			print("TALK: open %s" % str(talk.call("is_open") if talk.has_method("is_open") else talk.get("_open")))
			await _shot("1_line", true)
		"devorange":
			# The dev look's test oranges (7 Oct): the range, the chicken pen and its coop, the camp, Trym's house.
			_look(true)
			await _wait(0.8)
			for path in ["World/Range", "Pen", "World/EggCamp", "World/TrymCabin"]:
				var unit := _room.get_node_or_null(path) as Node4D
				if unit == null:
					print("DEVORANGE: %s not found" % path)
					continue
				var u: Vector4 = unit.global_position
				var eye: Vector4 = u + Vector4(11.0, 7.0, 11.0, 0)
				eye.w = u.w
				_aim(eye, u + Vector4(0, 1.0, 0, 0))
				_cam.global_position.w = u.w
				await _shot(String(path).get_file())
		"kata":
			# The kata wood's trees, their leaf balls off (7 Oct: "dont change the trees. just remove the leave balls").
			_look(false)
			await _wait(1.0)
			var wood := _room.get_node_or_null("World/KataWood") as Node4D
			if wood != null:
				var k: Vector4 = wood.global_position
				_aim(Vector4(k.x + 13.0, 5.0, k.z + 9.0, k.w), Vector4(k.x, 3.5, k.z, k.w))
				_cam.global_position.w = k.w
				await _shot("1_wood")
			else:
				print("KATA: no wood")
		"down":
			# At the ladder's head on the Watchstone: "Go down?  Y / N".
			_look(false)
			var t: Node4D = _tower()
			player.set("input_enabled", true)
			var head: Vector4 = t.call("_ladder_head")
			player.global_position = t.global_position + t.global_basis * head + Vector4(0, 0.05, 0, 0)
			player.set("linear_velocity", Vector4.ZERO)
			player.get_node("CameraRig").call("face_toward", t.global_basis * Vector4(0.4, 0, 0.6, 0))
			await _wait(1.5)
			print("DOWN: asking %s, it says \"%s\"" % [str(t.get("_asking")), String(t.get("_way_shown"))])
			await _shot("1_asks", true)
		"lookcam":
			_look(false)
			var t: Node4D = _tower()
			var lookout: Node = _room.get_node("Systems/Lookout")
			var station: Node = lookout.get("station")
			var journal: Node = lookout.get("journal")
			for f in ["approached", "met_wren", "first_raise", "first_photo"]:
				journal.call("set_flag", f, true)
			var wren: Node = lookout.get("wren")
			if wren != null:
				wren.set("has_camera", false)
			var marsh := lookout.get("marsh") as Node4D
			var heron := lookout.get("heron") as Node4D
			var to_marsh: Vector4 = marsh.global_position - t.global_position
			var local: Vector4 = t.global_basis.inverse() * to_marsh
			# By the rail, a quarter turn round from the ladder's head (which is on the marsh's side).
			var head: Vector4 = t.call("_ladder_head")
			var dir := Vector2(head.x, head.z).normalized().rotated(1.1)
			player.set("input_enabled", true)
			player.global_position = t.global_position + t.global_basis * Vector4(dir.x * 3.0, 13.70, dir.y * 3.0, 0.0)
			player.set("linear_velocity", Vector4.ZERO)
			var rig: Node = player.get_node("CameraRig")
			rig.call("face_toward", Vector4(to_marsh.x, 0.0, to_marsh.z, 0.0))
			await _wait(1.5)
			print("LOOKCAM: on deck %s, can raise %s, rail prompt \"%s\"" % [str(t.call("on_deck", player.global_position)),
				str(station.call("can_raise")), String(lookout.get("_rail_shown"))])
			await _shot("1_rail", true)
			station.call("raise")
			await _wait(1.0)
			await _centre_on(lookout, station, rig, "marsh")
			print("LOOKCAM: mode %d, zoomed flag %s" % [int(station.get("mode")), str(journal.call("flag", "zoomed"))])
			await _shot("2_raised", true)
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			for i in 4:
				station.call("_input", wheel)
			await _wait(0.8)
			print("LOOKCAM: after 4 wheel notches zoom %.2f, zoomed flag %s" % [float(station.get("zoom")), str(journal.call("flag", "zoomed"))])
			station.call("autofocus")
			await _wait(1.2)
			var cam := station.get("camera") as Camera4D
			print("LOOKCAM: T: focus %.2f, ring reach %.1f, slice tilt %.3f, camera w %.2f, marsh w %.2f, heron w %.2f shown %s" % [
				float(station.get("focus")), float(station.call("ring_reach")), float(station.call("slice_tilt")), cam.global_position.w,
				marsh.global_position.w, heron.global_position.w, str(heron.is_visible_in_tree())])
			await _shot("3_aligned", true)
			station.call("take_photo")
			await _wait(0.7)
			var recent: Array = journal.get("recent")
			var last: Dictionary = recent[-1] if recent.size() > 0 else {}
			print("LOOKCAM: photo of \"%s\" (%s), page %s" % [String(last.get("name", "")), String(last.get("verdict", "")), String(last.get("page", ""))])
			await _shot("4_photo", true)
			# The marsh on its own (the heron away): its photo is named for it.
			heron.visible = false
			await _wait(1.2)
			station.call("take_photo")
			await _wait(0.7)
			recent = journal.get("recent")
			last = recent[-1] if recent.size() > 0 else {}
			print("LOOKCAM: without the heron, a photo of \"%s\" (%s)" % [String(last.get("name", "")), String(last.get("verdict", ""))])
			await _shot("4b_marsh_photo", true)
			heron.visible = true
			_look(true)
			await _wait(1.2)
			await _shot("5_dev_aligned", true)
			# The turned slice: back flat at home, then turned by a drag till the marsh is half in, and T from there.
			rig.call("align_to", 0.0)
			station.set("focus_goal", 0.0)
			await _wait(1.0)
			# Tipped forward through W, 15 degrees, as a drag with the right button would: the marsh ahead comes partly in.
			rig.call("drag_slice", Vector2(0.0, float(OS.get_environment("FB_DRAG")) if OS.get_environment("FB_DRAG") != "" else -0.26))
			await _wait(0.6)
			print("LOOKCAM: turned %.3f, focus %.2f" % [float(station.call("slice_tilt")), float(station.get("focus"))])
			await _shot("6_turned", true)
			station.call("autofocus")
			await _wait(1.2)
			print("LOOKCAM: T from turned: focus %.2f, tilt %.3f, camera w %.2f" % [float(station.get("focus")), float(station.call("slice_tilt")),
				cam.global_position.w])
			await _shot("7_turned_aligned", true)
			station.call("lower")
			await _wait(0.5)
		"panels":
			# The left panels in the dev look: the paths window stacked on top of the grass panel, the blue and orange
			# swatches under Dev / Art.
			_look(true)
			await _wait(1.5)
			var gp := _room.get_node_or_null("UI/GrassPanel") as Control
			var pp := _room.get_node_or_null("UI/PathsPanel") as Control
			if gp != null and pp != null:
				print("PANELS: paths at %s size %s, grass at %s size %s: %s" % [str(pp.position), str(pp.size), str(gp.position), str(gp.size),
					"stacked" if absf(pp.position.x - gp.position.x) < 1.0 and pp.position.y + pp.size.y * pp.scale.y <= gp.position.y + 0.5 else "NOT stacked"])
			await _shot("1_hud", true)
			var ui: Node = _room.get_node("UI")
			for c in ui.get_children():
				var cc := c as Control
				if cc == null or not cc.is_visible_in_tree():
					continue
				var r: Rect2 = cc.get_global_transform() * Rect2(Vector2.ZERO, cc.size)
				if r.size.x >= 2.0 and r.size.y >= 2.0:
					print("PANELS HUD: %-16s at %s size %s" % [cc.name, str(r.position.round()), str(r.size.round())])
			# The two colours: the swatches only in the dev look, and a colour set reaching what it should.
			var box := gp.get("_colours_box") as Control if gp != null else null
			print("PANELS: swatches in the dev look %s" % str(box != null and box.is_visible_in_tree()))
			var look: Node = _room.get_node("Systems/Look")
			var fc := Color(0.2, 0.7, 0.3)
			var lc := Color(0.9, 0.1, 0.6)
			look.call("set_colours", fc, lc)
			await _wait(0.3)
			var range_mesh: MeshInstance4D = null
			for m in _room.get_node("World/Range").find_children("*", "MeshInstance4D", true, false):
				if (m as MeshInstance4D).material_override is TetraMaterial4D and (m as MeshInstance4D).mesh != null:
					range_mesh = m
					break
			var block := _tower().get_node_or_null("DevBlockout_blue") as MeshInstance4D
			var ring := _room.get_node_or_null("Systems/NpcMarkers/Marker_Keeper") as MeshInstance4D
			print("PANELS: the range takes the landmark colour %s, the tower's boxes the foundation colour %s, a ring changed %s" % [
				str(range_mesh != null and (range_mesh.material_override as TetraMaterial4D).albedo_color.is_equal_approx(lc)),
				str(block != null and (block.material_override as TetraMaterial4D).albedo_color.is_equal_approx(fc)),
				str(ring != null and ring.material_override != null)])
			await _shot("2_recoloured", true)
			_look(false)
			await _wait(0.8)
			print("PANELS: swatches in the art look %s" % str(box != null and box.is_visible_in_tree()))
			await _shot("3_art", true)
		"cave":
			# Every path shown, without touching the saved settings (pen_paths_4d.gd set_found saves).
			var net: Variant = _room.get_node("Systems/Paths").get("_network")
			if net != null:
				(net as Node).set("reveal", false)
			var rig: Node = player.get_node("CameraRig")
			player.set("input_enabled", true)
			for dev in [false, true]:
				_look(dev)
				for spot in [[Vector4(7.3, 0.2, 38.5, 0.0), "1_junction"], [Vector4(7.38, 0.2, 34.6, 3.0), "2_flat"], [Vector4(7.4, 0.2, 32.4, 3.0), "3_circle"]]:
					player.global_position = spot[0]
					player.set("linear_velocity", Vector4.ZERO)
					rig.call("face_toward", Vector4(0.0, 0.0, -1.0, 0.0))
					await _wait(1.2)
					print("CAVE: %s at w %.2f" % [spot[1], player.global_position.w])
					await _shot(String(spot[1]) + ("_dev" if dev else "_art"))
		"balloon":
			var lookout: Node = _room.get_node("Systems/Lookout")
			var balloon: Node = lookout.get("balloon")
			if balloon != null:
				balloon.call("set_ready", true, true)
			var net: Variant = _room.get_node("Systems/Paths").get("_network")
			if net != null:
				(net as Node).set("reveal", false)
			for dev in [true, false]:
				_look(dev)
				await _wait(1.2)
				_aim(Vector4(-12.0, 16.0, -14.0, 0.0), Vector4(-24.0, 0.0, -29.0, 0.0))
				await _shot("1_branch" + ("_dev" if dev else "_art"))
				_aim(Vector4(-24.5, 3.2, -28.5, 0.0), Vector4(-30.0, 1.0, -32.0, 0.0))
				await _shot("2_basket" + ("_dev" if dev else "_art"))
		"road":
			# Down the camp's road from its junction, on the farm's slice: how far it shows, and the scout on it.
			for dev in [false, true]:
				_look(dev)
				await _wait(1.0)
				_aim(Vector4(-17.0, 3.0, -3.9, 0.0), Vector4(4.0, 0.0, -4.0, 0.0))
				await _shot("1_dev" if dev else "1_art")
	print("FEEDBACK %s: done" % _mode)
	quit(0)
