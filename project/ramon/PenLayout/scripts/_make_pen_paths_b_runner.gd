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
## The camp's W (World/EggCamp in chickenpen/playable_world.tscn, 2.5 m kata). Its last stretch follows down to it
## (Ramon, 7 Oct: "why is the path to the campsite not follow? its lower no?" and "that also means placing the
## campsite at the landing spot of the path"): the route lands at the camp's sand at the camp's own W, its ring
## (CampFrame) there too. V's align to slice still comes up once the camp is half in view.
const CAMP_W := -2.5
## The W the cave road lands at: a metre kata of the arch's middle (World/Cave at w 4; the arch is round in x and W,
## terrain/pen_cave_hill_4d.gd), where the opening stands tallest against the rock round it (Ramon, 7 Oct: "if you
## can get the even version to show up at a -W ... and have the placement marker align at that point"; the
## frames: smoke_test_output/cave_w/, look/_cave_w_sweep_runner.gd). Inside the walls' gap (W 0.9 to 7.1) and the
## door tutor's reach (1.5 either side of 4).
const CAVE_DOOR_W := 3.0


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
	var cave: int = dest.call(7.4, 30.8, CAVE_DOOR_W, "CaveFrame", "round", Vector2(0, 1))
	e.call(j_trym, j_cave)
	# THE DOOR'S OWN SLICE AT THE END (Ramon, 7 Oct: "the end point of the reveal marker, does not align with the ideal
	# slice for the open cave"). The road climbed to the door's W over all of its 6.3 m and the circle showed 1.2 m
	# either side of it, so you met the circle at W 2.8, short of the door's slice, and the slanted road led your
	# eye past the arch. Now the climb ends 2.5 m short, and the last stretch lies flat at the door's best W
	# (CAVE_DOOR_W), and the circle shows only within 0.6 m of it.
	# AND A WAY IN YOU CAN SEE FROM THE ROAD (Ramon, 7 Oct: "at the cave outside, at a somewhat ideal opening, still no
	# arrow that shows up to walk to it"): the climb started at the junction, so on the farm's slice only its first
	# metre showed, inside the junction's clearance, and no arrow pointed at the cave; the flat end was shorter than
	# one chevron. Now: 2.5 m static off the junction (seen from any W, pointing at the door), a 2 m climb, and 3 m
	# flat at the door's W into a circle nearer the door.
	var cave_lead: int = n.call("chord", 7.33, 34.6, 0.0)
	var cave_flat: int = n.call("chord", 7.36, 32.6, CAVE_DOOR_W)
	e.call(j_cave, cave_lead, "static")
	e.call(cave_lead, cave_flat, "follow")
	e.call(cave_flat, cave, "here")
	g.call("node", cave)["band"] = 1.2
	g.call("node", cave)["pos"] = Vector4(7.4, 0.0, 29.6, CAVE_DOOR_W)
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
	# The camp, east, its circle at the sand's edge, the stretch following down to the camp's W; the tower
	# straight on.
	var j_camp: int = n.call("junction", -12.7, -3.9)
	e.call(j_range, j_camp)
	var camp: int = dest.call(6.4, -4.0, CAMP_W, "CampFrame", "round", Vector2(-1, 0))
	e.call(j_camp, camp, "follow")
	var tower: int = dest.call(-18.75, -27.8, 0.0, "TowerFrame", "round", Vector2(0, 1))
	# A smaller branch to Wren's balloon (Ramon, 7 Oct: "draw a smaller subpath to the balloon"): off the tower road
	# a few metres short of the tower, a secondary route (narrower, its own mark) that turns north for the last
	# 2.5 m and ends on the basket's front, its south side, the side you walk up from (Ramon: "i rather have the
	# sub-path ending on the front side of the basket, from where you're walking"). The small circle is 2 m south of
	# the basket, inside the reach where F boards it (lookout_4d.gd _near_basket), on the mooring (MooringSpot in
	# units/lookout/lookout.tscn), never the balloon itself, which flies off with its circle chasing it.
	var j_balloon: int = n.call("junction", -17.42, -22.5)
	e.call(j_camp, j_balloon)
	e.call(j_balloon, tower)
	# The turn's ball a little nearer the basket (Ramon: "move the pivot ball of the subpath slightly more toward the basket").
	var balloon_turn: int = n.call("bend", -30.0, -27.5)
	var balloon: int = dest.call(-30.0, -30.0, 0.0, "MooringSpot", "none", Vector2(0, 1), 0.75)
	g.call("add_edge", j_balloon, balloon_turn, "secondary", "here", BAND)
	g.call("add_edge", balloon_turn, balloon, "secondary", "here", BAND)
	var notes: PackedStringArray = g.call("validate")
	for line in notes:
		print("NOTE " + line)
	var err: int = ResourceSaver.save(g, OUT)
	print("PATHS B: %d nodes, %d edges -> %s (%s)" % [(g.get("nodes") as Array).size(), (g.get("edges") as Array).size(), OUT, error_string(err)])
	quit(0)
