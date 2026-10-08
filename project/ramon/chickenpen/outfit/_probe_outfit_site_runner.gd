extends SceneTree

## WHERE THE FITTING CIRCLE CAN GO (outfit/PLAN_OUTFIT.md step 7): everything round Trym's house that
## a circle must keep clear of, printed from the running pen, with top views of the place, and, given
## candidates, the circle stood at each and checked against every F reach there.
##
##   lab_run.sh windowed outfit_site res://ramon/chickenpen/outfit/_probe_outfit_site_runner.gd [x,z ...]

const OUT := "res://smoke_test_output/outfit/site/"
const CIRCLE := "res://ramon/chickenpen/units/outfit/outfit_circle.tscn"
const HOUSE := Vector4(25.0, 0.0, 44.9, 0.0)

var _room: Node
var _t0: int = 0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 120000:
		print("SITE FAIL: gave up after 120 s")
		return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	root.add_child(_room)
	current_scene = _room
	var guard := Node.new()
	guard.set_script(load("res://ramon/PenLayout/scripts/input_guard.gd"))
	root.add_child(guard)
	await _frames(60)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var player := _room.get_node("Player") as Node4D
	player.set("input_enabled", false)
	print("PLAYER start %s" % str(player.global_position))

	var cabin := _room.get_node("World/TrymCabin") as Node4D
	print("CABIN %s basis x %s z %s" % [str(cabin.global_position), str(cabin.global_basis.x), str(cabin.global_basis.z)])
	for child in cabin.get_children():
		if child is Node4D:
			print("  cabin/%s at %s" % [child.name, _v(child.global_position)])
	# Everything under World within 14 m of the house, one level down.
	for child in _room.get_node("World").get_children():
		if child is Node4D and child != cabin:
			var gap: Vector4 = (child as Node4D).global_position - HOUSE
			if Vector2(gap.x, gap.z).length() < 14.0:
				print("NEAR World/%s at %s (%.1f m)" % [child.name, _v(child.global_position), Vector2(gap.x, gap.z).length()])
	var trees: Node = _room.get_node_or_null("World/Trees")
	if trees != null:
		for tree in trees.get_children():
			if tree is Node4D:
				var gap: Vector4 = (tree as Node4D).global_position - HOUSE
				if Vector2(gap.x, gap.z).length() < 12.0 and absf(gap.w) < 2.0:
					print("TREE %s at %s" % [tree.name, _v(tree.global_position)])
	# Who takes F, and how far.
	for talker in get_nodes_in_group(&"npc_talk"):
		var where: Vector4 = Vector4.ZERO
		var at: Node = talker.get("_character") if talker.get("_character") != null else talker
		if at is Node4D:
			where = (at as Node4D).global_position
		var gap: Vector4 = where - HOUSE
		if Vector2(gap.x, gap.z).length() < 20.0:
			print("TALK %s at %s reach %s" % [_room.get_path_to(talker), _v(where), str(talker.get("reach"))])
	for node in _room.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path.ends_with("pen_laptop_4d.gd") and node is Node4D:
			print("LAPTOP %s at %s reach %s" % [_room.get_path_to(node), _v((node as Node4D).global_position), str(node.get("reach"))])
	var invite: Node = _room.get_node_or_null("Invitation")
	if invite != null:
		for p in invite.get("route"):
			print("ROUTE %s" % _v(invite.call("_in_world", p)))
		print("DOOR %s" % _v(invite.call("_door_spot")))

	# Candidates, from the command line as x,z.
	var candidates: Array[Vector4] = []
	for a in OS.get_cmdline_user_args():
		if a.contains(","):
			candidates.append(Vector4(float(a.get_slice(",", 0)), 0.0, float(a.get_slice(",", 1)), 0.0))
	for c in candidates:
		_check_candidate(player, c)

	_hud_off()
	var top_cam := Camera4D.new()
	top_cam.projection_type = Camera4D.PROJECTION4D_ORTHOGRAPHIC
	top_cam.clip_far = 400.0
	top_cam.rendering_engine_name = "Cross-section"
	_room.add_child(top_cam)
	for c in candidates:
		var piece: Node4D = (load(CIRCLE) as PackedScene).instantiate() as Node4D
		_room.get_node("World").add_child(piece)
		piece.global_position = c
	for shot in [["site_20", Vector4(24.0, 0.0, 41.0, 0.0), 22.0], ["site_12", Vector4(22.0, 0.0, 42.0, 0.0), 12.0]]:
		top_cam.orthographic_size = shot[2]
		var c: Vector4 = shot[1]
		top_cam.position = Vector4(c.x, 40.0, c.z, 0.0)
		top_cam.look_at(Vector4(c.x, 0.0, c.z, 0.0), Vector4(0, 0, -1, 0))
		top_cam.make_current()
		await _frames(30)
		var path: String = OUT + shot[0] + _look_tag() + ".png"
		root.get_texture().get_image().save_png(path)
		print("FRAME %s" % path)
	# And from where you come up the path, through the player's own camera.
	(player.get_node("CameraRig/Pitch/Camera4D") as Camera4D).make_current()
	for c in candidates:
		var from: Vector4 = c + Vector4(0.0, 0.0, -7.0, 0.0)
		player.global_position = Vector4(from.x, 1.2, from.z, 0.0)
		var rig := player.get_node("CameraRig") as Node4D
		rig.call("face_toward", Vector4(0.0, 0.0, 1.0, 0.0))
		await _frames(45)
		var path: String = OUT + "eye_%d_%d%s.png" % [int(c.x * 10), int(c.z * 10), _look_tag()]
		root.get_texture().get_image().save_png(path)
		print("FRAME %s" % path)
	print("SITE DONE")
	quit(0)


func _check_candidate(player: Node4D, at: Vector4) -> void:
	player.global_position = Vector4(at.x, 1.2, at.z, 0.0)
	var takers: Array[String] = []
	for talker in get_nodes_in_group(&"npc_talk"):
		if talker.has_method("_can_talk") and bool(talker.call("_can_talk")):
			takers.append(String(_room.get_path_to(talker)))
	for node in _room.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		if script != null and script.resource_path.ends_with("pen_laptop_4d.gd") and node.has_method("usable"):
			player.set("input_enabled", true)
			if bool(node.call("usable")):
				takers.append(String(_room.get_path_to(node)))
			player.set("input_enabled", false)
	print("CANDIDATE %s: F taken by %s" % [_v(at), "nobody" if takers.is_empty() else ", ".join(takers)])


## The pen's HUD off for clean frames: everything on its UI layer but the circle's own words.
func _hud_off() -> void:
	var ui: Node = _room.get_node_or_null("UI")
	if ui == null:
		return
	for c in ui.get_children():
		if String(c.name) in ["GrassPanel", "PathsPanel"]:
			c.process_mode = Node.PROCESS_MODE_DISABLED
		if c.name == &"OutfitCircleUI":
			continue
		if c is CanvasItem:
			(c as CanvasItem).visible = false
		elif c is CanvasLayer:
			(c as CanvasLayer).visible = false


func _look_tag() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("look="):
			return "_" + a.substr(5)
	return ""


func _v(p: Vector4) -> String:
	return "(%.1f, %.1f, %.1f, w %.1f)" % [p.x, p.y, p.z, p.w]
