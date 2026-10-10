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


## ROUND 6 (section 12; Ramon: "Preserve the main route ... Reposition branches and arrival markers to match the
## updated pedestal locations. Keep the path clear of the flower collection ... Avoid introducing unnecessary path
## branches"): the hall a rectangle (its entrance 3 m before 01, its back wall flat at -22, its right wall at 5.5),
## the oak at (-2, -12.5), the door 3 m from the left wall, the flowers in two rows right of the spine (x 1.4 to 3.0,
## z 1.9 to 9.1; the spine at x 0 runs alongside them, no branch). The spine from the doorway to 03's junction; the
## tour's pad on the left between the entrance wall and 01; 01 to 03 on their 67.5-degree branches as before; the
## oak's ring on a 45-degree run from 03's junction; the way to the back door round the oak's right, behind it and
## along the back wall (between 03 and the oak there is no room for a path).
## ROUND 8 (section 13; Ramon, #57: "Move the entire Oak showcase approximately 2 meters backward ... Check that
## the adjusted position doesn't interfere with the surrounding paths"): the oak at (-2, -14.5); its branch 45
## degrees out from 03's junction to the oak's line as before, then straight on to its ring. The way to the back
## door is unchanged: 1.5 m off the oak's right, 1.6 m behind it.
func _hall() -> Resource:
	var g: Resource = Graph.new()
	var b := {"band": BAND}
	var s: int = g.call("add_node", "start", _p(0.0, 19.5), b)
	var jt: int = g.call("add_node", "junction", _p(0.0, 10.6 + _run(3.0)), b)
	var j1: int = g.call("add_node", "junction", _p(0.0, 7.0 + _run(4.2)), b)
	var j2: int = g.call("add_node", "junction", _p(0.0, 0.0 + _run(4.0)), b)
	var j3: int = g.call("add_node", "junction", _p(0.0, -7.0 + _run(4.0)), b)
	g.call("add_edge", s, jt, "primary", "static", BAND)
	g.call("add_edge", jt, j1, "primary", "static", BAND)
	g.call("add_edge", j1, j2, "primary", "static", BAND)
	g.call("add_edge", j2, j3, "primary", "static", BAND)
	var tour: int = g.call("add_node", "destination", _p(-3.0, 10.6), {"band": BAND, "state": "available", "target": "Tour", "frame": "none", "approach": Vector2(1, 0)})
	g.call("add_edge", jt, tour, "secondary", "static", BAND)
	var d1: int = g.call("add_node", "destination", _p(-4.2, 7.0), {"band": BAND, "state": "available", "target": "P1", "frame": "rect", "approach": Vector2(1, 0)})
	g.call("add_edge", j1, d1, "primary", "static", BAND)
	var d2: int = g.call("add_node", "destination", _p(-4.0, 0.0), {"band": BAND, "state": "arrival", "target": "P2", "frame": "round", "approach": Vector2(1, 0)})
	g.call("add_edge", j2, d2, "primary", "static", BAND)
	var d3: int = g.call("add_node", "destination", _p(-4.0, -7.0), {"band": BAND, "state": "arrival", "target": "P3", "frame": "round", "approach": Vector2(1, 0)})
	g.call("add_edge", j3, d3, "primary", "static", BAND)
	# The oak: its deck's edge at z -10.5 (round 8), its ring 1.2 m off it; 45 degrees from 03's junction to x -2,
	# then straight down to it.
	var b4: int = g.call("add_node", "bend", _p(-2.0, -7.0 + _run(4.0) - 2.0), b)
	var d4: int = g.call("add_node", "destination", _p(-2.0, -9.3), {"band": BAND, "state": "arrival", "target": "P4", "frame": "round", "approach": Vector2(0, 1)})
	g.call("add_edge", j3, b4, "primary", "static", BAND)
	g.call("add_edge", b4, d4, "primary", "static", BAND)
	# The back door: 45 degrees out to the right of the oak, straight down past it, 45 degrees back in behind it, and
	# along the back wall to the door.
	var b1: int = g.call("add_node", "bend", _p(3.5, -7.0 + _run(4.0) - 3.5), b)
	var b2: int = g.call("add_node", "bend", _p(3.5, -18.0), b)
	var b3: int = g.call("add_node", "bend", _p(1.4, -20.1), b)
	var door: int = g.call("add_node", "destination", _p(-7.3, -20.1), {"band": BAND, "state": "arrival", "target": "Door", "frame": "rect", "approach": Vector2(1, 0)})
	g.call("add_edge", j3, b1, "primary", "static", BAND)
	g.call("add_edge", b1, b2, "primary", "static", BAND)
	g.call("add_edge", b2, b3, "primary", "static", BAND)
	g.call("add_edge", b3, door, "primary", "static", BAND)
	return g
