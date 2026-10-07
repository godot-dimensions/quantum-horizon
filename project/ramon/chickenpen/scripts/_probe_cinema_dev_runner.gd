extends SceneTree

## THE CINEMA FROM THE DEV LOOK (Ramon, 7 Oct: "the cinema is super broken. can't walk, stuck in the air. orange pads
## anywhere, cant sit in the chair. presentation starts without me. sky looks dark but different"). The theatre and
## crossing tests pass; they go in from the art look. This goes in as he did: the pen in the look it opens in (dev, or
## look=art to compare), C (the crossing's own key, go_for_testing), and then what the theatre's player does: frames,
## where it stands and whether it falls, a walk forward, what is orange, which environment is current.
##
##   lab_run.sh windowed probe_cinema res://ramon/chickenpen/scripts/_probe_cinema_dev_runner.gd [look=art]

const OUT := "res://smoke_test_output/cinema_probe/"

var _room: Node
var _tag: String = "dev"


func _initialize() -> void:
	root.unfocusable = true
	for a in OS.get_cmdline_user_args():
		if a == "look=art":
			_tag = "art"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_room = (load("res://ramon/chickenpen/playable_world.tscn") as PackedScene).instantiate()
	_room.get_node("Systems/Lookout").set("journal_path", "user://probe_cinema_journal.cfg")
	root.add_child(_room)
	current_scene = _room
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "%s_%s.png" % [_tag, nm]))


func _theatre_player(th: Node) -> CharacterBody4D:
	for n in th.find_children("*", "CharacterBody4D", true, false):
		return n as CharacterBody4D
	return null


func _run() -> void:
	await _wait(6.0)
	var crossing: Node = _room.get_node("Crossing")
	print("CINEMA %s: look applied %s" % [_tag, str(_room.get_node("Systems/Look").get("_applied"))])
	crossing.call("go_for_testing")
	await _wait(0.5)
	var th: Node = crossing.get("_theatre")
	if th == null:
		print("CINEMA %s: no theatre" % _tag)
		quit(1)
		return
	var p := _theatre_player(th)
	print("CINEMA %s: theatre %s, its player %s" % [_tag, th.name, str(p.get_path()) if p != null else "none"])
	for i in 6:
		await _wait(0.5)
		if p != null:
			print("CINEMA %s t=%.1f: player at %s, velocity %s, on floor %s, input %s, process %s" % [_tag, 0.5 * (i + 2),
				str(p.global_position.snapped(Vector4.ONE * 0.01)), str((p.get("linear_velocity") as Vector4).snapped(Vector4.ONE * 0.01)), str(p.is_on_floor()),
				str(p.get("input_enabled")), str(p.can_process())])
	await _shot("1_arrived")
	# Orange in view: what is laid in the look's landmark colour, and the NPC markers' rings.
	var look: Node = _room.get_node("Systems/Look")
	var orange: Color = look.get("landmark_colour")
	var lit: Array = []
	for mi in _room.find_children("*", "MeshInstance4D", true, false):
		var m := (mi as MeshInstance4D).material_override as TetraMaterial4D
		if m != null and m.albedo_color.is_equal_approx(orange) and (mi as MeshInstance4D).is_visible_in_tree():
			lit.append(str(_room.get_path_to(mi)))
	print("CINEMA %s: %d visible meshes in the landmark orange: %s" % [_tag, lit.size(), str(lit.slice(0, 12))])
	var rings: Node = _room.get_node_or_null("Systems/NpcMarkers")
	if rings != null:
		var shown: int = 0
		for r in rings.get_children():
			if r is Node4D and (r as Node4D).is_visible_in_tree():
				shown += 1
		print("CINEMA %s: NPC rings showing %d" % [_tag, shown])
	for env in _room.find_children("*", "WorldEnvironment4D", true, false):
		print("CINEMA %s: environment %s current %s in tree %s" % [_tag, str(_room.get_path_to(env)), str(env.get("current")), str(env.is_inside_tree())])
	# Walk forward two seconds.
	if p != null:
		var from: Vector4 = p.global_position
		Input.action_press(&"move_forward")
		await _wait(2.0)
		Input.action_release(&"move_forward")
		print("CINEMA %s: walked %.2f m (from %s to %s)" % [_tag, (p.global_position - from).length(), str(from.snapped(Vector4.ONE * 0.01)),
			str(p.global_position.snapped(Vector4.ONE * 0.01))])
	await _shot("2_walked")
	# The chair: walked to (put beside it), offered, sat in.
	var seat: Node = null
	for n in th.find_children("*", "", true, false):
		if n.has_method("is_seated") and n.has_method("sit"):
			seat = n
	if seat != null and p != null:
		var sp: Vector4 = (seat as Node4D).global_position if seat is Node4D else p.global_position
		p.global_position = sp + Vector4(0.6, 0.3, 0.6, 0.0)
		await _wait(1.0)
		print("CINEMA %s: by the chair at %s, offering %s" % [_tag, str(p.global_position.snapped(Vector4.ONE * 0.01)), str(seat.call("is_offering"))])
		seat.call("sit")
		await _wait(3.0)
		print("CINEMA %s: seated %s" % [_tag, str(seat.call("is_seated"))])
		await _shot("2b_seated")
	else:
		print("CINEMA %s: no seat found" % _tag)
	var show: Node = null
	for n in th.find_children("*", "", true, false):
		if n.has_method("current_act"):
			show = n
	if show != null:
		print("CINEMA %s: the show's act %s, phase %s" % [_tag, str(show.call("current_act")), str(show.get("_phase"))])
	# The show's state, if it says.
	for n in th.find_children("*", "", true, false):
		if n.has_method("is_running") or "running" in n or "_slide" in n:
			print("CINEMA %s: %s running %s slide %s" % [_tag, n.name, str(n.get("running")), str(n.get("_slide"))])
	await _wait(1.0)
	await _shot("3_later")
	print("CINEMA %s: done" % _tag)
	quit(0)
