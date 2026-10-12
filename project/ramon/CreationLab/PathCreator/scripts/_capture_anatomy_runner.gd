extends SceneTree

## THE PARTS OF A PATH, AS THE TOOL DRAWS THEM (Ramon, 7 Oct, on the dev log's hand-drawn diagram: "this one looks a bit
## broken cant you use the graphics from the path creator"). A small graph in the lab, laid by the network itself, seen
## straight down on the dev floor: a start, the primary route's chevrons, a bend rounded into a curve of chords, a
## junction, the main branch to a destination (action available, its rectangle frame round a hut), and a secondary
## sub-branch with its small chevrons and dots to a smaller arrival circle. One frame, no HUD, at 1920 x 1080; it
## prints where each part lands on it (PARTS lines, pixels), for the labels the dev log draws over it.
##
##   lab_run.sh windowed pc_anatomy res://ramon/CreationLab/PathCreator/scripts/_capture_anatomy_runner.gd

const SCENE := "res://ramon/CreationLab/PathCreator/pathcreator.tscn"
const Graph := preload("res://ramon/CreationLab/PathCreator/graph/path_graph.gd")
const Network := preload("res://ramon/CreationLab/PathCreator/graph/path_network_4d.gd")
const Target := preload("res://ramon/CreationLab/PathCreator/space/pc_target_4d.gd")
const OUT := "res://smoke_test_output/pathcreator/anatomy.png"
## The middle of the picture (x, z) and how many metres tall it is.
const MID := Vector2(-38.6, 14.2)
const TALL := 15.0

var _g: Node


func _initialize() -> void:
	root.unfocusable = true
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_run.call_deferred()


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _px(x: float, z: float) -> Vector2:
	var size := Vector2(root.size)
	var k: float = size.y / TALL
	return size * 0.5 + (Vector2(x, z) - MID) * k


func _run() -> void:
	_g = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_g)
	current_scene = _g
	var hut := Node4D.new()
	hut.name = "AnatomyHut"
	hut.set_script(Target)
	hut.set("label", "")
	hut.set("size", Vector3(2.0, 2.0, 2.0))
	hut.set("color", Color(0.62, 0.65, 0.70))
	hut.position = Vector4(-28.3, 0.0, 13.5, 0.0)
	_g.get_node("Targets").add_child(hut)
	var g: Resource = Graph.new()
	var s: int = g.call("add_node", "start", Vector4(-50.0, 0.0, 19.5, 0.0), {"band": 1.2})
	var b: int = g.call("add_node", "bend", Vector4(-45.5, 0.0, 19.5, 0.0), {"band": 1.2})
	var c: int = g.call("add_node", "bend", Vector4(-41.5, 0.0, 13.5, 0.0), {"band": 1.2})
	var j: int = g.call("add_node", "junction", Vector4(-36.5, 0.0, 13.5, 0.0), {"band": 1.2})
	var d1: int = g.call("add_node", "destination", Vector4(-31.0, 0.0, 13.5, 0.0),
		{"band": 1.2, "state": "available", "target": "AnatomyHut", "frame": "rect", "approach": Vector2(-1, 0)})
	var d2: int = g.call("add_node", "destination", Vector4(-32.0, 0.0, 8.6, 0.0),
		{"band": 1.2, "state": "arrival", "approach": Vector2(-1, 1), "size": 0.75})
	g.call("add_edge", s, b, "primary", "static", 1.2)
	g.call("add_edge", b, c, "primary", "static", 1.2)
	g.call("add_edge", c, j, "primary", "static", 1.2)
	g.call("add_edge", j, d1, "primary", "static", 1.2)
	g.call("add_edge", j, d2, "secondary", "static", 1.2)
	# The second corner rounded (chords along a curve); the first stays a sharp bend.
	var curve: int = g.call("round_corner", c, 2.5)
	var net := Node4D.new()
	net.name = "AnatomyNetwork"
	net.set_script(Network)
	net.set("graph", g)
	net.set("targets", NodePath("../Targets"))
	_g.add_child(net)
	await _wait(2.5)
	var player: Node4D = _g.get("player")
	if player != null:
		player.global_position = Vector4(-70.0, 0.05, 50.0, 0.0)
	var hud: Node = _g.get("hud")
	if hud != null:
		(hud as CanvasItem).visible = false
	var cam := Camera4D.new()
	cam.set("rendering_engine_name", "Cross-section")
	cam.set("projection_type", 0)
	cam.set("orthographic_size", TALL)
	_g.add_child(cam)
	cam.global_position = Vector4(MID.x, 40.0, MID.y, 0.0)
	cam.global_basis = Projection(Vector4(1, 0, 0, 0), Vector4(0, 0, -1, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1))
	cam.make_current()
	await _wait(1.5)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://smoke_test_output/pathcreator/"))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("PARTS size %s" % str(root.size))
	for n in g.get("nodes"):
		var p: Vector4 = n["pos"]
		print("PARTS %s %d at %s" % [String(n["kind"]), int(n["id"]), str(_px(p.x, p.z).round())])
	print("PARTS hut at %s" % str(_px(hut.position.x, hut.position.z).round()))
	print("PARTS curve %d" % curve)
	quit(0)
