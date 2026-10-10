extends SceneTree

## BOTANY LAB, plan steps 17-24 (Ramon, 9 Oct: "Replace the current zigzag arrangement with a cleaner, more
## intentional path network. Favor straight sections and structured, grid-aligned connections. Use
## consistent angular turns, primarily 45-degree connections ... Make sure paths lead naturally to the
## specimen stations. Preserve comfortable walking space around each showcase"): the hall's route,
## written once to botany_lab/paths/hall.tres (the carried PathCreator's path_graph.gd; the F4 builder
## edits it after). Args after --: "force" to write over a graph that exists.
##
## THE LAYOUT, in the room's frame (the network stands at its origin):
##   THE SPINE      straight down the hall's middle (x 0) from the corridor to the oak's ring, with a
##                  junction 3.5 m before each pedestal.
##   THE BRANCHES   from each junction one 45-degree run to the pedestal's ring, on the side facing the
##                  spine, 1.2 m off its deck's edge (01's box: r 2.1; 02 and 03: r 2.3): you stand at
##                  the ring with the pedestal in front of you and the spine at your back.
##   THE PAD        the showcase pad (PLAY THE SHOWCASE), a short 45-degree branch just inside the door,
##                  secondary.
##   THE OAK        its ring on the spine itself, 1.2 m off its deck (r 4).
##   THE DOOR       from 03's junction a 45-degree run out to 1.4 m clear of the oak's deck, straight
##                  down past it, 45 degrees back in to the middle, and straight to the back door (the
##                  diagonal low enough to keep 0.9 m off the oak's square target: rule 10).
## Every turn is 45 degrees; every leg is longer than a mark's repeat (1.2 m).

const Graph := preload("res://ramon/Arboretum/botany_lab/carried/PathCreator/graph/path_graph.gd")

const DIR := "res://ramon/Arboretum/botany_lab/paths/"
const BAND := 8.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var force: bool = "force" in OS.get_cmdline_user_args()
	if force or not ResourceLoader.exists(DIR + "hall.tres"):
		var g: Resource = _hall()
		var notes: Array = g.call("validate") if g.has_method("validate") else []
		print("PATHS hall: saved ", ResourceSaver.save(g, DIR + "hall.tres"), ", the graph's own checks: ", notes if not notes.is_empty() else "pass")
	else:
		print("PATHS hall: kept (pass force to write over it)")
	quit()


func _p(x: float, z: float) -> Vector4:
	return Vector4(x, 0.0, z, 0.0)


## ROUND 4 (section 10, step 16; Ramon: "Reduce the steepness of the existing 45-degree branches ... approximately
## 20-25 degrees"; then, on the first try at 22.5 degrees from the spine: "i meant 25 degrees or so measured
## from the 45 degree angle. so less steep ... instead of 45 degrees, a little more angular.. but subtle"):
## every branch to a showcase leaves the spine at 67.5 degrees (45 turned 22.5 toward square), so it is a short
## slant across to its ring rather than a long diagonal. The rings stand where they stood (01 at x -4.2, 02 and
## 03 at -4.0, 1.2 m off their planters), each junction just before its ring. The tour's pad is back on the
## left, on its own short branch. The border's path and the way round the oak to the back door are kept. No
## flower room branch: that room is shelved (step 21).
const ANGLE := 67.5


## How far along the spine a branch runs to move `side` metres across at ANGLE from the spine.
func _run(side: float) -> float:
	return absf(side) / tan(deg_to_rad(ANGLE))


func _hall() -> Resource:
	var g: Resource = Graph.new()
	var b := {"band": BAND}
	var s: int = g.call("add_node", "start", _p(0.0, 19.5), b)
	var t: int = g.call("add_node", "junction", _p(0.0, 15.2), b)
	var jp: int = g.call("add_node", "junction", _p(0.0, 12.2 + _run(3.0)), b)
	var j1: int = g.call("add_node", "junction", _p(0.0, 7.0 + _run(4.2)), b)
	var j2: int = g.call("add_node", "junction", _p(0.0, 0.0 + _run(4.0)), b)
	var j3: int = g.call("add_node", "junction", _p(0.0, -7.0 + _run(4.0)), b)
	var j4: int = g.call("add_node", "junction", _p(0.0, -6.8), b)
	# Down the spine: the door's junction, the pad's, 01's, 02's, 03's, the oak's.
	g.call("add_edge", s, t, "primary", "static", BAND)
	g.call("add_edge", t, jp, "primary", "static", BAND)
	g.call("add_edge", jp, j1, "primary", "static", BAND)
	g.call("add_edge", j1, j2, "primary", "static", BAND)
	g.call("add_edge", j2, j3, "primary", "static", BAND)
	g.call("add_edge", j3, j4, "primary", "static", BAND)
	var tour: int = g.call("add_node", "destination", _p(-3.0, 12.2), {"band": BAND, "state": "available", "target": "Tour", "frame": "none", "approach": Vector2(1, 0)})
	g.call("add_edge", jp, tour, "secondary", "static", BAND)
	var d1: int = g.call("add_node", "destination", _p(-4.2, 7.0), {"band": BAND, "state": "available", "target": "P1", "frame": "rect", "approach": Vector2(1, 0)})
	g.call("add_edge", j1, d1, "primary", "static", BAND)
	# ROUND 5 (Ramon: "Add a short branch from the main exhibition path toward the flower collection. This
	# should branch near the relevant 4D showcase / V interaction area and lead naturally into the flower
	# corner"): from 01's junction, back and out to the front corner of the sixteen pots (room/bl_border_4d.gd),
	# its frame round the collection.
	var df: int = g.call("add_node", "destination", _p(-5.9, 10.6), {"band": BAND, "state": "arrival", "target": "Flowers", "frame": "rect", "approach": Vector2(1, 0)})
	g.call("add_edge", j1, df, "secondary", "static", BAND)
	var d2: int = g.call("add_node", "destination", _p(-4.0, 0.0), {"band": BAND, "state": "arrival", "target": "P2", "frame": "round", "approach": Vector2(1, 0)})
	g.call("add_edge", j2, d2, "primary", "static", BAND)
	var d3: int = g.call("add_node", "destination", _p(-4.0, -7.0), {"band": BAND, "state": "arrival", "target": "P3", "frame": "round", "approach": Vector2(1, 0)})
	g.call("add_edge", j3, d3, "primary", "static", BAND)
	# The oak, on the spine: its deck's edge at z -9.5, the ring at -8.3.
	var d4: int = g.call("add_node", "destination", _p(0.0, -8.3), {"band": BAND, "state": "arrival", "target": "P4", "frame": "round", "approach": Vector2(0, 1)})
	g.call("add_edge", j4, d4, "primary", "static", BAND)
	# (Round 5: the border's run down the right side went with the border; the way round the oak's right
	# side to the back door stays.)
	var r1: int = g.call("add_node", "bend", _p(5.4, -6.8), b)
	g.call("add_edge", j4, r1, "primary", "static", BAND)
	# The back door, round the oak's right side.
	var r2: int = g.call("add_node", "bend", _p(5.4, -17.4), b)
	var r3: int = g.call("add_node", "bend", _p(2.0, -20.8), b)
	var door: int = g.call("add_node", "destination", _p(0.0, -20.8), {"band": BAND, "state": "arrival", "target": "Door", "frame": "rect", "approach": Vector2(0, 1)})
	g.call("add_edge", r1, r2, "primary", "static", BAND)
	g.call("add_edge", r2, r3, "primary", "static", BAND)
	g.call("add_edge", r3, door, "primary", "static", BAND)
	return g
