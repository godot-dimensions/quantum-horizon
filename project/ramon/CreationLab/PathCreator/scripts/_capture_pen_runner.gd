extends SceneTree

## PathCreator's pen patch (PLAN.md steps 85-87): the pen's fence (8.4 x 7.6 m, W -4 to +4) with a
## gate, two steps and a deck before it, a feeder at W 0, a coop at W +3 and a hen that wanders
## (pathcreator.tscn's PenPatch, graphs/pen.tres). Checks the draping (the ground the rays find, the
## route laid as one run per step), walks the player in along the route with the game's own input,
## checks the hen's anchored destination keeps up with her, and shuts the gate with a door to see
## the way in hide and come back (rule 09). Frames from above at W 0, 1.5 and 3, from beside the
## steps, from the player's camera, of the hen, and of the shut gate. To
## res://smoke_test_output/pathcreator/pen/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_pen res://ramon/CreationLab/PathCreator/scripts/_capture_pen_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/pen/"
const Mark := preload("res://ramon/CreationLab/LabKit/lab_mark_4d.gd")
const Spec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const TOP := Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))

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


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_fails.append(what)


func _shot(what: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + what + ".png")
	print("shot ", what)


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	await _wait(3.0)
	var net: Node = _g.get_node("PenNetwork")
	var notes: PackedStringArray = net.call("notes")
	_check(notes.is_empty(), "the pen graph is sound %s" % str(notes))
	# The ground the rays find along the way in: floor, step, deck, step, floor.
	var hs: Array = []
	for z in [-16.0, -13.5, -11.0, -8.5, -6.0]:
		hs.append(snappedf(float(net.call("ground_at", 42.0, z, 0.0)), 0.01))
	_check(hs == [0.0, 0.25, 0.5, 0.25, 0.0], "the rays find floor, step, deck, step, floor %s" % str(hs))
	_check(absf(float(net.call("ground_at", 42.0, -11.0, 6.0))) < 0.01, "past the steps' W depth (W +6) there is only floor")
	# The way in laid as one run per height, its risers where the boxes' edges are.
	var g: Resource = net.get("graph")
	var e0: Dictionary = g.edges[0]
	var a: Vector4 = g.call("node", int(e0["from"]))["pos"]
	var b: Vector4 = g.call("node", int(e0["to"]))["pos"]
	var d := Vector2(b.x - a.x, b.z - a.z)
	var runs: Array = net.call("_runs", a, d.normalized(), d.length(), func(_t: float) -> float: return 0.0)
	var cuts: Array = []
	var heights: Array = []
	for r in runs:
		heights.append(snappedf(float(r[2]), 0.01))
		cuts.append(snappedf(float(r[1]), 0.05))
	print("runs on the way in: ", runs)
	_check(heights == [0.0, 0.25, 0.5, 0.25, 0.0], "the way in is laid in five runs %s" % str(heights))
	_check(cuts.slice(0, 4) == [3.0, 4.0, 8.0, 9.0], "its risers at 3, 4, 8 and 9 m from the start %s" % str(cuts))
	var boxes: Array = []
	for c in net.get_children():
		if c is MeshInstance4D and String(c.name).begins_with("Edge0"):
			boxes.append(snappedf((c as Node4D).position.y - Spec.PROUD_M, 0.01))
	boxes.sort()
	_check(boxes == [0.0, 0.0, 0.25, 0.25, 0.5], "and a box for each, at its own height %s" % str(boxes))
	# Walk in with the game's own input: forward from the start, over the steps, through the gate.
	var p: CharacterBody4D = _g.get("player")
	p.global_position = Vector4(42.0, 0.05, -17.5, 0.0)
	p.set("_facing", PI)
	var rig: Node = p.get_node_or_null("CameraRig")
	if rig != null:
		rig.set("yaw", PI)
		rig.call("_apply")
	await _wait(0.8)
	await _shot("player_start")
	Input.action_press(&"move_forward")
	var top_y: float = 0.0
	var on_deck_shot: bool = false
	var until: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < until and p.global_position.z < -1.5:
		await process_frame
		top_y = maxf(top_y, p.global_position.y)
		if not on_deck_shot and p.global_position.z > -11.5 and p.global_position.y > 0.4:
			on_deck_shot = true
			Input.action_release(&"move_forward")
			await _wait(0.4)
			await _shot("player_on_deck")
			Input.action_press(&"move_forward")
	Input.action_release(&"move_forward")
	print("walked to %s, highest %.2f" % [str(p.global_position), top_y])
	_check(top_y > 0.45 and top_y < 0.65, "the player climbs onto the deck (highest %.2f m)" % top_y)
	_check(p.global_position.z > -1.6, "and walks on through the gate into the pen (z %.1f)" % p.global_position.z)
	await _wait(0.6)
	await _shot("player_in_pen")
	# The hen's destination keeps its place beside her as she wanders and drifts through W.
	var hen: Node4D = _g.get_node("PenPatch/Hen")
	var hen_id: int = -1
	for n in g.nodes:
		if String(n.get("target", "")) == "Hen":
			hen_id = int(n["id"])
	var off0: Vector4 = (net.call("_pos", g.call("node", hen_id)) as Vector4) - (hen.global_position - net.global_position)
	var hen0: Vector4 = hen.global_position
	await _wait(2.0)
	var off1: Vector4 = (net.call("_pos", g.call("node", hen_id)) as Vector4) - (hen.global_position - net.global_position)
	var went: float = (hen.global_position - hen0).length()
	_check(went > 0.5 and Vector2(off1.x - off0.x, off1.z - off0.z).length() < 0.08 and absf(off1.w - off0.w) < 0.08,
		"the hen's destination keeps up with her (she went %.2f m; offset %s then %s)" % [went, str(off0), str(off1)])
	# Shut the gate with a door: the way in hides; open it: it is back.
	var door := Node4D.new()
	door.set_script(load("res://ramon/CreationLab/PathCreator/space/pc_target_4d.gd"))
	door.name = "GateDoor"
	door.set("label", "Gate door")
	door.set("size", Vector3(1.7, 0.95, 0.15))
	door.set("w_depth", 8.0)
	door.set("color", Color(0.4, 0.3, 0.22))
	door.position = Vector4(0.0, 0.0, 0.2, 0.0)
	_g.get_node("PenPatch").add_child(door)
	await _wait(1.2)
	var shut: Dictionary = net.call("shut_routes")
	var shut_edges: Array = []
	for ri in shut:
		shut_edges.append_array(shut[ri])
	var hidden_ok: bool = true
	for c in net.get_children():
		if c is MeshInstance4D and int(c.get_meta("edge", -1)) == 0:
			hidden_ok = hidden_ok and not (c as MeshInstance4D).visible
	_check(0 in shut_edges and 1 in shut_edges and hidden_ok, "a door across the gate shuts the way in (edges %s hidden)" % str(shut_edges))
	_check(not (2 in shut_edges) and not (3 in shut_edges), "the routes on from the choice stay")
	# Seen from the approach, a little above, where the whole way in shows.
	var look := Camera4D.new()
	look.set("rendering_engine_name", "Cross-section")
	_g.add_child(look)
	look.global_position = Vector4(42.0, 2.6, -21.0, 0.0)
	look.global_basis = Mark.basis_looking(look.global_position, Vector4(42.0, 0.0, -6.0, 0.0))
	look.current = true
	await _wait(0.3)
	await _shot("door_shut")
	door.queue_free()
	await _wait(1.2)
	_check((net.call("shut_routes") as Dictionary).is_empty(), "the door gone, the way in is back")
	await _shot("door_open")
	look.queue_free()
	(_g.call("camera") as Camera4D).current = true
	# Frames from outside the player.
	for c in _g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	p.visible = false
	_cam = Camera4D.new()
	_cam.set("rendering_engine_name", "Cross-section")
	_g.add_child(_cam)
	_cam.current = true
	# The hen and her route from above, three moments apart.
	for k in 3:
		_cam.set("projection_type", 0)
		_cam.set("orthographic_size", 7.0)
		var hp: Vector4 = hen.global_position
		_cam.global_position = Vector4(42.5, 30.0, -1.5, hp.w)
		_cam.global_basis = TOP
		await _wait(0.1)
		await _shot("hen_%d" % k)
		await _wait(1.6)
	for w in [0.0, 1.5, 3.0]:
		_cam.set("projection_type", 0)
		_cam.set("orthographic_size", 23.0)
		_cam.global_position = Vector4(42.0, 30.0, -6.0, w)
		_cam.global_basis = TOP
		await _wait(0.2)
		await _shot("top_w%d" % int(w * 10.0))
	_cam.set("projection_type", 1)
	_cam.global_position = Vector4(36.5, 1.3, -14.5, 0.0)
	_cam.global_basis = Mark.basis_looking(_cam.global_position, Vector4(42.0, 0.25, -10.0, 0.0))
	await _wait(0.2)
	await _shot("side_steps")
	_cam.global_position = Vector4(42.0, 2.6, -21.0, 0.0)
	_cam.global_basis = Mark.basis_looking(_cam.global_position, Vector4(42.0, 0.0, -6.0, 0.0))
	await _wait(0.2)
	await _shot("approach")
	_g.call("set_look", "walk")
	await _wait(0.3)
	await _shot("approach_walk")
	_g.call("set_look", "dev")
	print("PEN %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
