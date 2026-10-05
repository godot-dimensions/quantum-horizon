extends SceneTree

## PathCreator: writes the starting graph files (graphs/*.tres) the dev space loads. Run once; after
## that the builder (F4) and the editor dock edit the files, and this would overwrite them, so it
## refuses to replace a file that exists unless given `force`.
##
##   yard.tres     the Figma's B1 field map, "46 x 30 m / straight-line field routing", node for node:
##                 the entry, the equal choice, the turns to the hut, the pen, the round station, the
##                 survey's curved approach of short chords, the watchtower and the store. Measured off
##                 the sheet (31.7 px a metre in its export) into the yard at x -23..23, z -50..-20.
##
##   wfield.tres   the W field (PLAN.md part F): five stations side by side, each a route from W 0 to
##                 its own blue cube at W +4, one W mode each: A static (route and bracket from any W),
##                 B here (the route at W 0, the arrival at W +4), C follow (the route climbs through W
##                 node by node), D reveal (all of it only at W +4), E ladder (one step of W a stretch).
##
##   pen.tres      the pen patch (PLAN.md step 87): in from the south over two steps and a deck (the
##                 network drapes it), through the fence's gate, then a choice: a static route to the
##                 feeder at W 0, a follow route up through W to the coop at W +3, and a follow route
##                 to the hen, anchored to her as she wanders the pen and drifts through W.
##
##   CreationLab/scripts/lab_run.sh headless pc_graphs res://ramon/CreationLab/PathCreator/scripts/_make_graphs_runner.gd [force | force=pen]
##
## `force` replaces every file, `force=<name>` only that one (the others may hold the builder's edits).

const Graph := preload("res://ramon/CreationLab/PathCreator/graph/path_graph.gd")
const Spec := preload("res://ramon/CreationLab/PathCreator/path_spec.gd")
const DIR := "res://ramon/CreationLab/PathCreator/graphs/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var force := func(name: String) -> bool:
		return "force" in args or ("force=" + name) in args
	_save("yard.tres", _yard(), force.call("yard"))
	_save("wfield.tres", _wfield(), force.call("wfield"))
	_save("pen.tres", _pen(), force.call("pen"))
	quit(0)


func _save(file: String, g: Resource, force: bool) -> void:
	var path: String = DIR + file
	if FileAccess.file_exists(path) and not force:
		print("kept ", path, " (exists; pass force, or force=", file.get_basename(), ", to replace)")
		return
	var err: int = ResourceSaver.save(g, path)
	print("wrote %s: %d nodes, %d edges, %s" % [path, g.nodes.size(), g.edges.size(), "ok" if err == OK else "error %d" % err])
	for note in g.call("validate"):
		print("  note: ", note)


## Yard coordinates (the sheet's metres, x right, z down the page) to the dev space's.
static func _at(x: float, z: float) -> Vector4:
	return Vector4(x - 23.0, 0.0, z - 50.0, 0.0)


func _yard() -> Resource:
	var g: Resource = Graph.new()
	# The yard lies at W 0 and reads from any W, its nodes as deep in W as its routes.
	var deep: float = Spec.W_REACH * 2.0
	var n := func(kind: String, x: float, z: float, extra: Dictionary = {}) -> int:
		var ex: Dictionary = {"band": deep}
		ex.merge(extra, true)
		return g.call("add_node", kind, _at(x, z), ex)
	var entry: int = n.call("start", 1.3, 16.0)
	var choice: int = n.call("junction", 6.0, 16.0)
	var up: int = n.call("bend", 6.0, 10.6)
	var hut: int = n.call("destination", 11.0, 10.6, {"state": "focused", "target": "Hut", "frame": "rect", "approach": Vector2(0, 1)})
	var down: int = n.call("bend", 6.0, 20.0)
	var pen_fork: int = n.call("junction", 11.0, 20.0)
	var pen: int = n.call("destination", 11.0, 22.6, {"state": "arrival", "target": "Pen", "frame": "rect", "approach": Vector2(0, -1)})
	var mid_fork: int = n.call("junction", 17.0, 20.0)
	var station_fork: int = n.call("junction", 17.0, 15.0)
	var station: int = n.call("destination", 18.6, 15.0, {"state": "available", "target": "RoundStation", "frame": "round", "approach": Vector2(-1, 0)})
	var c1: int = n.call("chord", 16.3, 12.3)
	var c2: int = n.call("chord", 16.5, 9.7)
	var c3: int = n.call("chord", 17.7, 7.3)
	var c4: int = n.call("chord", 19.7, 5.7)
	var survey: int = n.call("destination", 23.0, 5.0, {"state": "available", "target": "Survey", "frame": "rect", "approach": Vector2(-1, 0)})
	var tower_fork: int = n.call("junction", 29.0, 20.0)
	var tower_turn: int = n.call("bend", 29.0, 13.6)
	var tower: int = n.call("destination", 36.0, 13.6, {"state": "available", "target": "Watchtower", "frame": "rect", "approach": Vector2(0, 1)})
	var store_turn: int = n.call("bend", 36.0, 20.0)
	var store: int = n.call("destination", 36.0, 22.6, {"state": "arrival", "target": "Store", "frame": "rect", "approach": Vector2(0, -1)})
	var e := func(a: int, b: int, pri: String = "primary") -> void:
		g.call("add_edge", a, b, pri, "static")
	e.call(entry, choice)
	e.call(choice, up)
	e.call(up, hut)
	e.call(choice, down)
	e.call(down, pen_fork)
	e.call(pen_fork, pen, "secondary")
	e.call(pen_fork, mid_fork)
	e.call(mid_fork, station_fork, "secondary")
	e.call(station_fork, station, "secondary")
	e.call(station_fork, c1, "secondary")
	e.call(c1, c2, "secondary")
	e.call(c2, c3, "secondary")
	e.call(c3, c4, "secondary")
	e.call(c4, survey, "secondary")
	e.call(mid_fork, tower_fork)
	e.call(tower_fork, tower_turn)
	e.call(tower_turn, tower)
	e.call(tower_fork, store_turn, "secondary")
	e.call(store_turn, store, "secondary")
	return g


## The pen patch, in the dev space's metres (PenPatch stands at x 42, z -5; its fence is the pen's,
## 8.4 x 7.6 m and W -4 to +4, with a gate in the south side).
func _pen() -> Resource:
	var g: Resource = Graph.new()
	var deep: float = 8.0
	var n := func(kind: String, x: float, z: float, w: float, band: float, extra: Dictionary = {}) -> int:
		var ex: Dictionary = {"band": band}
		ex.merge(extra, true)
		return g.call("add_node", kind, Vector4(x, 0.0, z, w), ex)
	var start: int = n.call("start", 42.0, -17.0, 0.0, deep)
	var gate: int = n.call("chord", 42.0, -4.2, 0.0, deep)
	var choice: int = n.call("junction", 42.0, -2.6, 0.0, deep)
	var feeder: int = n.call("destination", 39.5, -0.4, 0.0, deep, {"state": "available", "target": "Feeder", "frame": "rect", "approach": Vector2(0, -1)})
	var turn: int = n.call("bend", 44.5, -2.6, 1.0, 1.4)
	var coop: int = n.call("destination", 44.5, 0.0, 3.0, 1.4, {"state": "available", "target": "Coop", "frame": "rect", "approach": Vector2(0, -1)})
	# The hen starts at (43.6, -0.5, W 0); her destination stands 0.8 m in front of her and goes where she goes.
	var hen: int = n.call("destination", 43.6, -1.3, 0.0, 1.4, {"state": "available", "target": "Hen", "frame": "round", "approach": Vector2(0, -1), "anchor": true})
	g.call("add_edge", start, gate, "primary", "static", deep)
	g.call("add_edge", gate, choice, "primary", "static", deep)
	g.call("add_edge", choice, feeder, "secondary", "static", deep)
	g.call("add_edge", choice, turn, "primary", "follow", 1.4)
	g.call("add_edge", turn, coop, "primary", "follow", 1.4)
	g.call("add_edge", choice, hen, "secondary", "follow", 1.4)
	return g


## The station x positions and their modes.
const STATIONS := [[-16.0, "A"], [-8.0, "B"], [0.0, "C"], [8.0, "D"], [16.0, "E"]]


func _wfield() -> Resource:
	var g: Resource = Graph.new()
	var deep: float = Spec.W_REACH * 2.0
	for st in STATIONS:
		var x: float = st[0]
		var mode: String = st[1]
		var n := func(kind: String, px: float, pz: float, w: float, band: float, extra: Dictionary = {}) -> int:
			var ex: Dictionary = {"band": band}
			ex.merge(extra, true)
			return g.call("add_node", kind, Vector4(px, 0.0, pz, w), ex)
		var dest_extra := {"state": "available", "target": "Pad" + mode, "frame": "rect", "approach": Vector2(0, -1)}
		match mode:
			"A":
				var s0: int = n.call("start", x, 12.0, 0.0, deep)
				var b1: int = n.call("bend", x, 22.0, 0.0, deep)
				var b2: int = n.call("bend", x + 3.0, 25.0, 0.0, deep)
				var d: int = n.call("destination", x + 3.0, 34.0, 4.0, deep, dest_extra)
				for pair in [[s0, b1], [b1, b2], [b2, d]]:
					g.call("add_edge", pair[0], pair[1], "primary", "static")
			"B":
				var s0: int = n.call("start", x, 12.0, 0.0, 1.2)
				var b1: int = n.call("bend", x, 22.0, 0.0, 1.2)
				var b2: int = n.call("bend", x + 3.0, 25.0, 0.0, 1.2)
				var d: int = n.call("destination", x + 3.0, 34.0, 4.0, 1.2, dest_extra)
				for pair in [[s0, b1], [b1, b2], [b2, d]]:
					g.call("add_edge", pair[0], pair[1], "primary", "here", 1.2)
			"C":
				var s0: int = n.call("start", x, 12.0, 0.0, 1.4)
				var b1: int = n.call("bend", x, 22.0, 1.6, 1.4)
				var b2: int = n.call("bend", x + 3.0, 25.0, 2.2, 1.4)
				var d: int = n.call("destination", x + 3.0, 34.0, 4.0, 1.4, dest_extra)
				for pair in [[s0, b1], [b1, b2], [b2, d]]:
					g.call("add_edge", pair[0], pair[1], "primary", "follow", 1.4)
			"D":
				var s0: int = n.call("start", x, 12.0, 0.0, 1.2)
				var b1: int = n.call("bend", x, 22.0, 4.0, 1.2)
				var b2: int = n.call("bend", x + 3.0, 25.0, 4.0, 1.2)
				var d: int = n.call("destination", x + 3.0, 34.0, 4.0, 1.2, dest_extra)
				for pair in [[s0, b1], [b1, b2], [b2, d]]:
					g.call("add_edge", pair[0], pair[1], "primary", "reveal", 1.2)
			"E":
				var s0: int = n.call("start", x, 12.0, 0.0, 1.0)
				var c1: int = n.call("chord", x, 17.0, 1.0, 1.0)
				var c2: int = n.call("chord", x, 22.0, 2.0, 1.0)
				var c3: int = n.call("chord", x + 3.0, 25.0, 3.0, 1.0)
				var d: int = n.call("destination", x + 3.0, 34.0, 4.0, 1.0, dest_extra)
				for pair in [[s0, c1], [c1, c2], [c2, c3], [c3, d]]:
					g.call("add_edge", pair[0], pair[1], "primary", "here", 1.0)
	return g
