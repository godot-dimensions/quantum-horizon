extends SceneTree

## Pen layout B (6 Oct 2026, PenLayout/PLAN_B.md steps 25-30): the pen's routes as Ramon drew them over
## the top view (measured from the sketch to the centimetre's tenth: the plan's table), into
## res://ramon/PenLayout/paths/pen_b.tres. The network stands at the field's origin: field coordinates,
## x east, z south, and W.
##
## Ramon: "the last time you created the paths i found them lacking in logic and contain errors. make
## them more like this, logical paths, pivots where they matter. and with a unique medium sized action
## circle in front of the landmarks."
##
## THE ROUTE, in the order he numbered it: 1 the start, south to the main line; 2 Trym's house, its
## circle larger; 3 the cave, its last stretch slanting from the farm's W to the door's, four metres
## ana; 4 the pen. From the pen's corner the way north through the gate in the town wall: the range,
## the camp (ending at its sand, not round it) and the tower straight on. Junctions where routes meet,
## one bend where the gate road turns, and no other pivots (his strokes' few-degree kinks are the
## pen's, not the road's).
##
## Every destination is an action circle (the sheet's "available": its arc turns), anchored to its
## landmark's frame marker (scripts/pen_frame_marker_4d.gd), which in the dev look gets a rectangle or
## circle round it.
##
##   CreationLab/scripts/lab_run.sh headless pl_paths_b res://ramon/PenLayout/scripts/_make_pen_paths_b_runner.gd

const Graph := preload("res://ramon/CreationLab/PathCreator/graph/path_graph.gd")
const OUT := "res://ramon/PenLayout/paths/pen_b.tres"
const BAND := 2.4
## The main line's z, and the start's line's x (his strokes were ruled).
const MAIN_Z := 37.1
const START_X := 24.9


func _initialize() -> void:
	var g: Resource = Graph.new()
	var n := func(kind: String, x: float, z: float, w: float = 0.0) -> int:
		return g.call("add_node", kind, Vector4(x, 0.0, z, w), {"band": BAND})
	var dest := func(x: float, z: float, w: float, target: String, frame: String, approach: Vector2, size: float = 1.0) -> int:
		return g.call("add_node", "destination", Vector4(x, 0.0, z, w), {"band": BAND, "state": "available",
			"target": target, "frame": frame, "approach": approach, "anchor": true, "size": size})
	var e := func(a: int, b: int, mode: String = "here") -> void:
		g.call("add_edge", a, b, "primary", mode, BAND)
	# 1 and 2: the start, south to the main line, and Trym's house beyond it (his circle larger).
	var start: int = n.call("start", START_X, 19.1)
	var j_trym: int = n.call("junction", START_X, MAIN_Z)
	var trym: int = dest.call(START_X, 40.9, 0.0, "TrymFrame", "rect", Vector2(0, -1), 1.35)
	e.call(start, j_trym)
	e.call(j_trym, trym)
	# 3: west along the main line to the cave's road; its last stretch slants to the door, 4 m ana.
	var j_cave: int = n.call("junction", 7.3, MAIN_Z)
	var cave: int = dest.call(7.4, 30.8, 4.0, "CaveFrame", "round", Vector2(0, 1))
	e.call(j_trym, j_cave)
	e.call(j_cave, cave, "follow")
	# 4: on west to the pen's corner, and the pen's gate at the line's end.
	var j_pen: int = n.call("junction", -4.0, MAIN_Z)
	# The dev look draws its own frame round the pen (pen_look_4d.gd _frame_pen): none here.
	var pen: int = dest.call(-14.2, MAIN_Z, 0.0, "PenFrame", "none", Vector2(1, 0))
	e.call(j_cave, j_pen)
	e.call(j_pen, pen)
	# North: one bend where the road turns for the gate, straight through the gate to the range's turn.
	var bend: int = n.call("bend", -11.1, 23.1)
	var j_range: int = n.call("junction", -12.3, 2.1)
	e.call(j_pen, bend)
	e.call(bend, j_range)
	var range_d: int = dest.call(-19.3, 2.1, 0.0, "RangeFrame", "rect", Vector2(1, 0))
	e.call(j_range, range_d)
	# The camp, east, its circle at the sand's edge; the tower straight on.
	var j_camp: int = n.call("junction", -12.7, -3.9)
	e.call(j_range, j_camp)
	var camp: int = dest.call(6.4, -4.0, 0.0, "CampFrame", "round", Vector2(-1, 0))
	e.call(j_camp, camp)
	var tower: int = dest.call(-18.75, -27.8, 0.0, "TowerFrame", "round", Vector2(0, 1))
	e.call(j_camp, tower)
	var notes: PackedStringArray = g.call("validate")
	for line in notes:
		print("NOTE " + line)
	var err: int = ResourceSaver.save(g, OUT)
	print("PATHS B: %d nodes, %d edges -> %s (%s)" % [(g.get("nodes") as Array).size(), (g.get("edges") as Array).size(), OUT, error_string(err)])
	quit(0)
