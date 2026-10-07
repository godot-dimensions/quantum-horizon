extends SceneTree

## THE BUILDER, FILMED (Ramon, 7 Oct, for the path editor's dev log: "show in the path creator tool demo file how
## you can create paths in editor, maybe with a demo video, branch some paths and build around a shape. and again
## make the point this is also very useful in W"). The lab (pathcreator.tscn), an empty corner of its floor with
## three shapes put there for it (a rock in the way, a hut at W 0, a shrine 3 m ana), and a session in the builder
## (F4) through its own mouse and key handling, with a drawn cursor and the key on screen: a start, bends round
## the rock, the corners rounded, a junction, a branch to the hut with its frame, a branch to the shrine dragged
## 3 m ana in the W lane and set to follow; then T, and the walk: round the rock, to the junction, and up the
## branch through W into the shrine's slice; last, the volume view.
##
## Works on a graph made for it in memory (nothing saved), in a network of its own. Film to
## smoke_test_output/video/<name>.avi; scratchpad ffmpeg makes the mp4.
##
##   lab_run.sh movie_hd pc_builder_demo res://ramon/CreationLab/PathCreator/scripts/_film_builder_demo_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const Graph := preload("res://ramon/CreationLab/PathCreator/graph/path_graph.gd")
const Network := preload("res://ramon/CreationLab/PathCreator/graph/path_network_4d.gd")
const Target := preload("res://ramon/CreationLab/PathCreator/space/pc_target_4d.gd")
const LabPrint := preload("res://ramon/CreationLab/LabKit/lab_print.gd")

## Where it happens: an empty corner of the lab's floor (x, z).
const AREA := Vector2(-38.0, 14.0)

var _g: Node
var _b: Control
var _net: Node
var _graph: Resource
var _over: Control
var _cur := Vector2(-100, -100)
var _key: String = ""
var _say: String = ""
var _title: String = ""
var _t0: int = 0
var _yaw: float = 0.0


func _initialize() -> void:
	root.unfocusable = true
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - _t0 > 600000:
		print("FILM: gave up")
		return true
	return false


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await process_frame


# --- The overlay: a cursor and the key being pressed ------------------------------------------------

func _draw_over() -> void:
	var s: Vector2 = _over.size
	var bold: Font = LabPrint.font("bold")
	var body: Font = LabPrint.font("body")
	if _title != "":
		var fs: int = 34
		var tw: float = bold.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_over.draw_rect(Rect2(Vector2((s.x - tw) * 0.5 - 28.0, s.y * 0.42 - 46.0), Vector2(tw + 56.0, 70.0)), Color(0.02, 0.025, 0.03, 0.82))
		_over.draw_string(bold, Vector2((s.x - tw) * 0.5, s.y * 0.42), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
	if _say != "":
		var fs2: int = 24
		var kw: float = bold.get_string_size(_key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x if _key != "" else 0.0
		var sw: float = body.get_string_size(_say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var chip: float = kw + 28.0 if _key != "" else 0.0
		var w: float = chip + sw + (18.0 if _key != "" else 0.0) + 44.0
		var at := Vector2((s.x - w) * 0.5, 26.0)
		_over.draw_rect(Rect2(at, Vector2(w, 58.0)), Color(0.02, 0.025, 0.03, 0.82))
		var x: float = at.x + 22.0
		if _key != "":
			_over.draw_rect(Rect2(Vector2(x, at.y + 11.0), Vector2(chip, 36.0)), Color(0.24, 0.56, 1.0, 0.9))
			_over.draw_string(bold, Vector2(x + 14.0, at.y + 38.0), _key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1, 1, 1))
			x += chip + 18.0
		_over.draw_string(body, Vector2(x, at.y + 38.0), _say, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(1, 1, 1, 0.92))
	if _cur.x > -50.0:
		var p: Vector2 = _cur
		var arrow := PackedVector2Array([p, p + Vector2(0, 26), p + Vector2(7, 20), p + Vector2(12, 31), p + Vector2(17, 29), p + Vector2(12, 18), p + Vector2(20, 18)])
		_over.draw_colored_polygon(arrow, Color(1, 1, 1))
		_over.draw_polyline(arrow + PackedVector2Array([p]), Color(0, 0, 0), 1.6)


func _caption(key: String, say: String) -> void:
	_key = key
	_say = say
	_over.queue_redraw()


# --- The builder's own input ------------------------------------------------------------------------

func _screen(x: float, z: float) -> Vector2:
	return _b.call("to_screen", x, z)


## The cursor to world (x, z), eased, the builder told of every step (its hover follows).
func _move(x: float, z: float, seconds: float = 0.5) -> void:
	await _move_screen(_screen(x, z), seconds)


func _move_screen(to: Vector2, seconds: float = 0.5) -> void:
	var from: Vector2 = _cur if _cur.x > -50.0 else to + Vector2(120, 80)
	var n: int = maxi(1, int(seconds * 30.0))
	for i in n:
		var t: float = smoothstep(0.0, 1.0, float(i + 1) / float(n))
		_cur = from.lerp(to, t)
		var mm := InputEventMouseMotion.new()
		mm.position = _cur
		_b.call("_gui_input", mm)
		_over.queue_redraw()
		await process_frame


func _click() -> void:
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.position = _cur
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		_b.call("_gui_input", mb)
		await process_frame


## A frame to res://smoke_test_output/pathcreator/film/ when FILM_SNAP is set (a quick windowed run to check the
## steps, before the slow film).
func _snap(nm: String) -> void:
	if OS.get_environment("FILM_SNAP") == "":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/pathcreator/film/"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://smoke_test_output/pathcreator/film/%s.png" % nm))


func _key_press(code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	_b.call("_unhandled_key_input", k)
	await process_frame


func _node_id_at(x: float, z: float) -> int:
	var best: int = -1
	var best_d: float = INF
	for n in _graph.get("nodes"):
		var p: Vector4 = n["pos"]
		var d: float = Vector2(p.x - x, p.z - z).length()
		if d < best_d:
			best_d = d
			best = int(n["id"])
	return best


# --- The film --------------------------------------------------------------------------------------

func _shape(nm: String, label: String, at: Vector4, size: Vector3, colour: Color, round_: bool = false, w_depth: float = 1.2) -> void:
	var t := Node4D.new()
	t.name = nm
	t.set_script(Target)
	t.set("label", label)
	t.set("size", size)
	t.set("color", colour)
	t.set("w_depth", w_depth)
	if round_:
		t.set("shape", "cubinder")
	t.position = at
	_g.get_node("Targets").add_child(t)


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	_shape("DemoRock", "Rock", Vector4(AREA.x, 0.0, AREA.y - 2.0, 0.0), Vector3(6.0, 3.0, 6.0), Color(0.6, 0.62, 0.66), true, 6.0)
	_shape("DemoHut", "Hut / W 0", Vector4(AREA.x + 11.0, 0.0, AREA.y - 11.0, 0.0), Vector3(4.0, 3.0, 4.0), Color(0.14, 0.34, 0.86))
	_shape("DemoShrine", "Shrine / W +3", Vector4(AREA.x - 11.5, 0.0, AREA.y - 11.0, 3.0), Vector3(3.0, 2.0, 3.0), Color(0.95, 0.78, 0.15), true)
	_graph = Graph.new()
	_net = Node4D.new()
	_net.name = "DemoNetwork"
	_net.set_script(Network)
	_net.set("graph", _graph)
	_net.set("targets", NodePath("../Targets"))
	_g.add_child(_net)
	_b = _g.get("builder")
	var layer := CanvasLayer.new()
	layer.layer = 20
	_g.add_child(layer)
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.draw.connect(_draw_over)
	layer.add_child(_over)
	await _wait(2.0)
	_g.call("go_to", Vector4(AREA.x, 0.05, AREA.y + 18.0, 0.0), 0.0)
	await _wait(0.8)
	_title = "PathCreator: building paths"
	_over.queue_redraw()
	await _wait(2.2)
	_title = ""
	# Into the builder, the view over the corner.
	_g.call("set_build", true)
	var cam: Camera4D = _b.get("cam")
	# Framed so the build sits clear of the builder's panel (right) and its W lane (bottom).
	cam.global_position = Vector4(AREA.x + 5.0, 40.0, AREA.y + 3.0, 0.0)
	cam.set("orthographic_size", 42.0)
	_b.queue_redraw()
	_caption("F4", "build mode: the floor from above, in the live slice")
	await _wait(2.4)
	# A start, by hand: N with nothing picked would join the lab's own graphs, so the first node is laid here and
	# picked, as a click would.
	_caption("1  N", "a start")
	await _move(AREA.x, AREA.y + 15.0)
	var s: int = _graph.call("add_node", "start", Vector4(AREA.x, 0.0, AREA.y + 15.0, 0.0), {"band": 1.2})
	_b.set("_pick", [_net, s])
	_graph.emit_changed()
	_b.queue_redraw()
	await _wait(1.0)
	# Bends round the rock.
	await _key_press(KEY_3)
	_caption("3  N", "bends, each joined from the last: round the rock")
	for p in [Vector2(AREA.x, AREA.y + 6.5), Vector2(AREA.x + 6.0, AREA.y + 3.0), Vector2(AREA.x + 6.0, AREA.y - 6.0)]:
		await _move(p.x, p.y, 0.55)
		await _key_press(KEY_N)
		await _wait(0.45)
	await _snap("1_bends")
	_print_graph("after the bends")
	await _key_press(KEY_4)
	_caption("4  N", "a junction: where the way splits")
	await _move(AREA.x, AREA.y - 11.0, 0.6)
	await _key_press(KEY_N)
	await _wait(1.0)
	# The corners rounded.
	_caption("R", "round a corner: the sheet's curve, wider each press")
	for p in [Vector2(AREA.x + 6.0, AREA.y + 3.0), Vector2(AREA.x + 6.0, AREA.y - 6.0)]:
		await _move(p.x, p.y, 0.55)
		await _key_press(KEY_R)
		await _wait(0.7)
	await _snap("2_rounded")
	_print_graph("after rounding")
	# Branch one: the hut, at W 0, with its frame.
	_caption("click", "pick the junction")
	await _move(AREA.x, AREA.y - 11.0, 0.6)
	await _click()
	await _wait(0.5)
	await _key_press(KEY_5)
	_caption("5  N", "a destination: the hut")
	await _move(AREA.x + 6.5, AREA.y - 11.0, 0.6)
	await _key_press(KEY_N)
	var hut: int = _node_id_at(AREA.x + 6.5, AREA.y - 11.0)
	var hut_n: Dictionary = _graph.call("node", hut)
	hut_n["target"] = "DemoHut"
	hut_n["approach"] = Vector2(-1, 0)
	hut_n["state"] = "available"
	await _wait(0.6)
	_caption("F", "its frame round the hut")
	await _key_press(KEY_F)
	await _wait(1.2)
	# Branch two: the shrine, 3 m ana.
	_caption("click", "the junction again: a second branch")
	await _move(AREA.x, AREA.y - 11.0, 0.6)
	await _click()
	await _wait(0.4)
	_caption("5  N", "a destination: the shrine")
	await _move(AREA.x - 7.0, AREA.y - 11.0, 0.6)
	await _key_press(KEY_N)
	var shrine: int = _node_id_at(AREA.x - 7.0, AREA.y - 11.0)
	var shrine_n: Dictionary = _graph.call("node", shrine)
	shrine_n["target"] = "DemoShrine"
	shrine_n["approach"] = Vector2(1, 0)
	shrine_n["state"] = "available"
	await _wait(0.6)
	# Through W in the lane at the bottom.
	_caption("W lane", "drag it through W: the shrine stands 3 m ana")
	var lane_x: float = 220.0
	await _move_screen(Vector2(lane_x, float(_b.call("_lane_y", 0.0))), 0.6)
	var press := InputEventMouseButton.new()
	press.position = _cur
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	_b.call("_gui_input", press)
	await process_frame
	await _move_screen(Vector2(lane_x, float(_b.call("_lane_y", 3.0))), 1.2)
	var release := InputEventMouseButton.new()
	release.position = _cur
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	_b.call("_gui_input", release)
	await process_frame
	await _wait(0.8)
	# The branch's W mode: static, here, follow.
	var mid := Vector2(AREA.x - 3.5, AREA.y - 11.0)
	await _move(mid.x, mid.y, 0.6)
	_caption("M", "the stretch's W mode: here (at its start's W)")
	await _key_press(KEY_M)
	await _wait(1.3)
	_caption("M", "follow: it slants from W 0 to the shrine's W +3")
	await _key_press(KEY_M)
	await _wait(1.8)
	await _snap("3_built")
	_print_graph("built")
	# Walk it.
	_caption("T", "walk from here")
	await _move(AREA.x, AREA.y + 15.0, 0.6)
	await _key_press(KEY_T)
	_cur = Vector2(-100, -100)
	_over.queue_redraw()
	await _wait(0.6)
	var player: CharacterBody4D = _g.get("player")
	var rig: Node = player.get_node("CameraRig")
	_yaw = 0.0
	_turn(rig)
	_caption("", "round the rock on the arrows")
	var route: Array = [Vector2(AREA.x, AREA.y + 6.5), Vector2(AREA.x + 5.4, AREA.y + 2.0), Vector2(AREA.x + 5.4, AREA.y - 5.0), Vector2(AREA.x + 0.6, AREA.y - 10.6)]
	await _walk(player, rig, route, 0.0)
	_caption("", "the shrine's branch: walk it, stepping ana (E) as you go")
	await _walk(player, rig, [Vector2(AREA.x - 7.0, AREA.y - 11.0)], 3.0)
	Input.action_release(&"move_forward")
	# The walk is faster than the step through W: the last of it standing on the circle.
	var guard: int = 0
	while player.global_position.w < 2.97 and guard < 150:
		guard += 1
		Input.action_press(&"move_ana")
		await process_frame
	Input.action_release(&"move_ana")
	await _snap("4_walked")
	print("FILM: walked to %s" % str(player.global_position))
	_caption("", "at W +3: the shrine is in your slice")
	await _wait(2.4)
	_caption("F7", "volume view: what is ana and kata of you, faintly")
	_g.call("set_volume_view", true)
	for i in 96:
		_yaw += 0.012
		_turn(rig)
		await process_frame
	_caption("", "")
	await _wait(0.4)
	print("FILM: done, %d nodes, %d edges" % [(_graph.get("nodes") as Array).size(), (_graph.get("edges") as Array).size()])
	quit(0)


## The lab's walker goes where its camera rig faces. The lab carries an older rig (LabKit/carried/...) that keeps
## its heading in yaw and builds its frame from it in _apply, so the heading is set there.
func _turn(rig: Node) -> void:
	rig.set("yaw", _yaw)
	rig.call("_apply")


func _print_graph(when: String) -> void:
	var parts: PackedStringArray = []
	for n in _graph.get("nodes"):
		var p: Vector4 = n["pos"]
		parts.append("%d %s (%.1f, %.1f, w %.1f)" % [int(n["id"]), String(n["kind"]), p.x, p.z, p.w])
	print("FILM GRAPH %s: %s" % [when, ", ".join(parts)])


## Walks [param player] through [param points] (x, z) on the arrows, turning the camera to each, and through W
## toward [param to_w] on the way (E held while short of it).
func _walk(player: CharacterBody4D, rig: Node, points: Array, to_w: float) -> void:
	for p in points:
		var guard: int = 0
		while guard < 30 * 12:
			guard += 1
			var at: Vector4 = player.global_position
			var d := Vector2(p.x - at.x, p.y - at.z)
			if d.length() < 0.6:
				break
			# The heading: 0 faces -z, PI faces +z, -PI/2 faces +x (pathcreator_4d.gd PLACES), eased.
			_yaw = lerp_angle(_yaw, atan2(-d.x, -d.y), 0.12)
			_turn(rig)
			Input.action_press(&"move_forward")
			if to_w > 0.0 and at.w < to_w - 0.05:
				Input.action_press(&"move_ana")
			else:
				Input.action_release(&"move_ana")
			await process_frame
	Input.action_release(&"move_forward")
