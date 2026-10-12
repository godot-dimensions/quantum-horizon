extends SceneTree

## PathCreator's curve tool (PLAN.md step 74, path_graph.gd round_corner): four right-angle turns
## with 16 m legs side by side (7 m needs 15.6), sharp, then rounded at each of CURVE_RADII (2, 4,
## 7 m), one tile each from above, laid out in a strip.
## The graph is made in memory and given to the W field's network for the shot, never saved. Also a
## follow route rounded at 4 m, its W read back along the curve. To
## res://smoke_test_output/pathcreator/curve/.
##
##   CreationLab/scripts/lab_run.sh windowed pc_curve res://ramon/CreationLab/PathCreator/scripts/_capture_curve_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const OUT := "res://smoke_test_output/pathcreator/curve/"
const Graph := preload("res://ramon/CreationLab/PathCreator/graph/path_graph.gd")
const Spec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const TOP := Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))

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


func _grab() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _run() -> void:
	var g: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(g)
	current_scene = g
	await _wait(3.0)
	for c in g.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	(g.get("player") as Node4D).visible = false
	var graph: Resource = Graph.new()
	var corners: Array = []
	var radii: Array = [0.0] + Spec.CURVE_RADII
	for i in radii.size():
		var x0: float = -58.0 + 18.0 * float(i)
		var s0: int = graph.call("add_node", "start", Vector4(x0, 0.0, 0.0, 0.0), {"band": 30.0})
		var b: int = graph.call("add_node", "bend", Vector4(x0, 0.0, -16.0, 0.0), {"band": 30.0})
		var d: int = graph.call("add_node", "destination", Vector4(x0 + 16.0, 0.0, -16.0, 0.0), {"band": 30.0, "state": "available", "frame": "none"})
		graph.call("add_edge", s0, b, "primary", "static", 30.0)
		graph.call("add_edge", b, d, "primary", "static", 30.0)
		corners.append(b)
	for i in radii.size():
		if float(radii[i]) > 0.0:
			var cid: int = graph.call("round_corner", int(corners[i]), float(radii[i]))
			var ids: Array = graph.call("curve_nodes", cid)
			var p0: Vector4 = graph.call("node", int(ids[0]))["pos"]
			# A right angle at radius r meets its legs r from the corner.
			_check(absf((p0.z + 16.0) - float(radii[i])) < 0.02, "%.0f m: %d chords, meeting the leg %.2f m before the corner" % [float(radii[i]), ids.size(), p0.z + 16.0])
	# A follow route climbing W 0 to 4 through the corner, rounded at 4 m: W rises along the curve.
	var fs: int = graph.call("add_node", "start", Vector4(20.0, 0.0, 0.0, 0.0), {"band": 1.4})
	var fb: int = graph.call("add_node", "bend", Vector4(20.0, 0.0, -12.0, 2.0), {"band": 1.4})
	var fd: int = graph.call("add_node", "destination", Vector4(32.0, 0.0, -12.0, 4.0), {"band": 1.4, "state": "available", "frame": "none"})
	graph.call("add_edge", fs, fb, "primary", "follow", 1.4)
	graph.call("add_edge", fb, fd, "primary", "follow", 1.4)
	var fcid: int = graph.call("round_corner", fb, 4.0)
	var ws: Array = []
	for id in graph.call("curve_nodes", fcid):
		ws.append(snappedf(float((graph.call("node", int(id))["pos"] as Vector4).w), 0.01))
	var rising: bool = true
	for i in range(1, ws.size()):
		rising = rising and float(ws[i]) > float(ws[i - 1])
	# The curve meets the legs 4 m from the corner, a third of the 12 m legs: W 2 - 2/3 to 2 + 2/3.
	_check(rising and absf(float(ws[0]) - 4.0 / 3.0) < 0.02 and absf(float(ws[-1]) - 8.0 / 3.0) < 0.02, "follow: W climbs along the curve %s" % str(ws))
	_check((graph.call("validate") as PackedStringArray).is_empty(), "the graph is sound")
	var net: Node = g.get_node("WFieldNetwork")
	net.set("graph", graph)
	await _wait(0.6)
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("projection_type", 0)
	cam.set("orthographic_size", 18.0)
	g.add_child(cam)
	cam.current = true
	cam.global_basis = TOP
	var strip: Image = null
	for i in radii.size():
		var x0: float = -58.0 + 18.0 * float(i)
		cam.global_position = Vector4(x0 + 8.0, 30.0, -8.0, 0.0)
		var img: Image = await _grab()
		var side: int = img.get_height()
		var t: Image = img.get_region(Rect2i(img.get_width() / 2 - side / 2, 0, side, side))
		t.convert(Image.FORMAT_RGB8)
		t.resize(540, 540, Image.INTERPOLATE_LANCZOS)
		if strip == null:
			strip = Image.create_empty(540 * radii.size() + 6 * (radii.size() - 1), 540, false, Image.FORMAT_RGB8)
			strip.fill(Color(0.08, 0.09, 0.12))
		strip.blit_rect(t, Rect2i(0, 0, 540, 540), Vector2i(i * 546, 0))
	strip.save_png(OUT + "curve_radii.png")
	print("saved curve_radii (sharp, 2, 4, 7 m)")
	# The follow curve at W 1.5 and W 2.5: the visible stretch moves round it.
	for w in [1.5, 2.5]:
		cam.set("orthographic_size", 10.0)
		cam.global_position = Vector4(24.0, 30.0, -10.0, w)
		var fi: Image = await _grab()
		fi.save_png(OUT + "curve_follow_w%d.png" % int(w * 10.0))
	print("CURVE %s: %d failed" % ["PASS" if _fails.is_empty() else "FAIL", _fails.size()])
	quit(0 if _fails.is_empty() else 1)
