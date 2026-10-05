extends SceneTree

## The wall panels in the Creation Lab (follow_up/wall_panels_plan.md): each panel straight on and
## from where you stand, the research panel through the story's parts, the review gallery as the
## Figma's frame 01, the walls switch both ways, and the legibility check (rule 5 of the handoff):
## each type role's height on screen from the approach, the reading spot and close up. To
## res://smoke_test_output/wall_panels/room/.
##
##   CreationLab/scripts/lab_run.sh windowed panels_room res://ramon/CreationLab/scripts/_capture_panels_runner.gd

const SCENE := "res://ramon/CreationLab/creation_lab.tscn"
const OUT := "res://smoke_test_output/wall_panels/room/"
const Spec := preload("res://ramon/CreationLab/kit/panels/kit_panel_spec.gd")
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")

var _g: Node
var _cam: Camera4D
var _fails: Array = []


func _initialize() -> void:
	root.unfocusable = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _process(_dt: float) -> bool:
	return false


func _wait(s: float) -> void:
	var until: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(what: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


## The camera `dist` metres in front of `panel`'s middle (eye 1.7 m high unless `eye_y`), looking at it.
func _look(panel: Node, dist: float, eye_y: float = 1.7, side: float = 0.0) -> Vector4:
	var fr: Array = panel.call("panel_frame")
	var c: Vector4 = fr[0]
	var n: Vector4 = fr[1]
	var across := Vector4(n.z, 0.0, -n.x, 0.0)
	var eye: Vector4 = c + n * dist + across * side
	eye.y = eye_y
	_cam.global_position = eye
	_cam.global_basis = Mark.basis_looking(eye, Vector4(c.x, c.y if eye_y > 3.0 else lerpf(eye_y, c.y, 0.7), c.z, 0.0))
	return c


## Stands the player `dist` m in front of `panel`'s middle, facing it, and waits for the camera.
func _stand(panel: Node, dist: float) -> void:
	var fr: Array = panel.call("panel_frame")
	var c: Vector4 = fr[0]
	var n: Vector4 = fr[1]
	var p: CharacterBody4D = _g.get("player")
	var at: Vector4 = c + n * dist
	p.global_position = Vector4(at.x, 0.05, at.z, 0.0)
	p.set("linear_velocity", Vector4.ZERO)
	var inward := Vector2(n.x, n.z)
	var yaw: float = atan2(inward.x, inward.y)
	p.set("_facing", yaw + PI)
	var rig: Node = p.get_node_or_null("CameraRig")
	if rig != null:
		rig.set("yaw", yaw)
		rig.call("_apply")
	await _wait(0.8)


## A role's cap height on screen in pixels (Montserrat's caps are 0.70 of its size), at the middle
## of `panel`, through the camera `cam`'s own projection; scaled to a 1080-pixel-tall screen.
func _cap_px(cam: Camera4D, panel: Node, role: String) -> float:
	var c: Vector4 = (panel.call("panel_frame") as Array)[0]
	var half: float = Spec.em_m(role) * 0.70 * 0.5
	var a: Vector2 = cam.call("world_to_viewport", c + Vector4(0, half, 0, 0))
	var b: Vector2 = cam.call("world_to_viewport", c - Vector4(0, half, 0, 0))
	return absf(a.y - b.y) * 1080.0 / float(root.get_texture().get_height())


## From where the player stands `dist` m from `panel`, through the player's camera where its rig rests
## (`camera_distance` behind them, up at `camera_height` and pitched down `camera_pitch_degrees`, as
## creation_lab_4d.gd sets it; the live rig pulls in when something stands behind you, which would
## make the check depend on the goat): each role's cap height at 1080p. Essential roles must clear
## `floor_px` from the reading spot.
func _legibility(panel: Node, where: String, dist: float, floor_px: float = 10.0) -> void:
	await _stand(panel, dist)
	var fr: Array = panel.call("panel_frame")
	var c: Vector4 = fr[0]
	var n: Vector4 = fr[1]
	var back: float = float(_g.get("camera_distance"))
	var pitch: float = deg_to_rad(float(_g.get("camera_pitch_degrees")))
	var at: Vector4 = c + n * (dist + back * cos(pitch))
	at.y = float(_g.get("camera_height")) - back * sin(pitch)
	_cam.global_position = at
	_cam.global_basis = Mark.basis_looking(at, Vector4(c.x, at.y + (c.y - at.y) * 0.5, c.z, 0.0))
	_cam.current = true
	await _wait(0.3)
	var line: String = "  %-8s %-13s player %4.1f m, camera %4.1f m:" % [where, panel.name, dist, dist + back * cos(pitch)]
	for role in ["hero", "lead", "body", "specimen", "section", "value", "control", "small", "label", "micro", "fine", "tiny"]:
		line += " %s %.0f" % [role, _cap_px(_cam, panel, role)]
	print(line)
	await _shot("legibility_%s_%s" % [String(panel.name).to_lower(), where])
	if where == "reading":
		for role in Spec.ESSENTIAL:
			var px: float = _cap_px(_cam, panel, role)
			if panel.get("kind") == "intro" and role in ["specimen", "value", "section"]:
				continue
			if panel.get("kind") == "research" and role in ["hero", "lead", "body", "control"]:
				continue
			_check(px >= floor_px, "%s on %s reads from the reading spot (%.1f px caps at 1080p, %.0f wanted)" % [role, panel.name, px, floor_px])


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(5.0)
	var intro: Node = _g.get_node("IntroPanel")
	var board: Node = _g.get_node("ResearchBoard")
	_check(intro.get("page") != null and board.get("page") != null, "both panels built")
	_check(_g.get_node("GoatRoom/Lesson").get("enabled") == false and _g.get_node("ResearchWall").get("enabled") == false, "the first walls are off")
	for p in [intro, board]:
		var w: PackedStringArray = p.call("_get_configuration_warnings")
		_check(w.is_empty(), "%s has no warnings %s" % [p.name, str(w)])
	await _shot("player_view")
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	# The player's own lens, so the check sees what the player sees.
	var pc: Node = (_g.get("player") as Node).get_node_or_null("CameraRig/Pitch/Camera4D")
	if pc != null:
		for prop in ["keep_aspect", "projection_type", "view_angle_type", "focal_length_4d", "focal_length_3d", "field_of_view_4d", "field_of_view_3d"]:
			_cam.set(prop, pc.get(prop))
	_g.add_child(_cam)
	print("legibility (cap height in px at 1080p, through the player's camera at rest):")
	for panel in [intro, board]:
		await _legibility(panel, "approach", 12.0)
		await _legibility(panel, "reading", 4.0)
		await _legibility(panel, "close", 1.5)
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	(_g.get("player") as Node4D).visible = false
	_cam.current = true
	await _wait(0.3)
	# Straight on, whole panel in frame.
	_look(intro, 10.5, 4.25)
	await _wait(0.8)
	await _shot("intro_straight")
	_look(board, 10.5, 4.25)
	await _wait(0.8)
	await _shot("research_straight")
	# From the reading spot and close up.
	_look(intro, 6.0)
	await _wait(0.5)
	await _shot("intro_reading")
	_look(board, 6.0)
	await _wait(0.5)
	await _shot("research_reading")
	_look(board, 2.0, 1.7, -2.6)
	await _wait(0.5)
	await _shot("research_close_benchmark")
	# The research panel through the story.
	var sc: Node = _g.get_node("Showcase")
	sc.call("replay")
	_look(board, 10.5, 4.25)
	for part in 5:
		var until: int = Time.get_ticks_msec() + 20000
		while int(sc.get("seq_index")) < part and Time.get_ticks_msec() < until:
			await process_frame
		await _wait(2.4)
		await _shot("research_part%d" % (part + 1))
		if part < 4:
			sc.call("skip")
	var page: Node = board.get("page")
	_check(page.get_node_or_null("Research/Page/Chart surface") != null, "the page has its chart surface")
	# The review gallery, Figma's frame 01.
	var gal: Node4D = _g.get_node("PanelGallery")
	var mid := Vector4(gal.global_position.x, 4.392, gal.global_position.z - 7.0, 0.0)
	_cam.global_position = mid + Vector4(0, 0, 13.4, 0)
	_cam.global_basis = Mark.basis_looking(_cam.global_position, mid)
	await _wait(1.0)
	await _shot("gallery_frame01")
	# The walls switch, and back.
	_g.set("walls", "first")
	await _wait(2.0)
	_check(_g.get_node("GoatRoom/Lesson").get("enabled") == true and intro.get("page") == null, "the first walls come back")
	_look(board, 10.5, 4.25)
	await _wait(0.8)
	await _shot("first_walls_research")
	_g.set("walls", "panels")
	await _wait(2.0)
	_check(intro.get("page") != null, "the panels come back")
	_look(board, 10.5, 4.25)
	await _wait(0.8)
	await _shot("panels_again_research")
	print("PANELS %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
