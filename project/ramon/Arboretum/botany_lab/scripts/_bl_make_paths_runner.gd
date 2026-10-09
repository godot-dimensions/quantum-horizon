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


func _hall() -> Resource:
	var g: Resource = Graph.new()
	var b := {"band": BAND}
	var s: int = g.call("add_node", "start", _p(0.0, 19.5), b)
	var t: int = g.call("add_node", "junction", _p(0.0, 15.2), b)
	var j1: int = g.call("add_node", "junction", _p(0.0, 11.7), b)
	var j2: int = g.call("add_node", "junction", _p(0.0, 4.5), b)
	var j3: int = g.call("add_node", "junction", _p(0.0, -2.5), b)
	g.call("add_edge", s, t, "primary", "static", BAND)
	g.call("add_edge", t, j1, "primary", "static", BAND)
	g.call("add_edge", j1, j2, "primary", "static", BAND)
	g.call("add_edge", j2, j3, "primary", "static", BAND)
	# The pad, secondary: 3 m across and 3 m on.
	var tour: int = g.call("add_node", "destination", _p(3.0, 12.2), {"band": BAND, "state": "available", "target": "Tour", "frame": "none", "approach": Vector2(-1, 0)})
	g.call("add_edge", t, tour, "secondary", "static", BAND)
	# 01, left (its box, r 2.1, at x -7): the ring at x -3.7.
	var d1: int = g.call("add_node", "destination", _p(-3.7, 8.0), {"band": BAND, "state": "available", "target": "P1", "frame": "rect", "approach": Vector2(1, 0)})
	g.call("add_edge", j1, d1, "primary", "static", BAND)
	# 02, right (r 2.3 at x 7): the ring at x 3.5.
	var d2: int = g.call("add_node", "destination", _p(3.5, 1.0), {"band": BAND, "state": "arrival", "target": "P2", "frame": "round", "approach": Vector2(-1, 0)})
	g.call("add_edge", j2, d2, "primary", "static", BAND)
	# 03, left (r 2.3 at x -7): the ring at x -3.5.
	var d3: int = g.call("add_node", "destination", _p(-3.5, -6.0), {"band": BAND, "state": "arrival", "target": "P3", "frame": "round", "approach": Vector2(1, 0)})
	g.call("add_edge", j3, d3, "primary", "static", BAND)
	# The oak, on the spine: its deck's edge at z -9.5, the ring at -8.3.
	var d4: int = g.call("add_node", "destination", _p(0.0, -8.3), {"band": BAND, "state": "arrival", "target": "P4", "frame": "round", "approach": Vector2(0, 1)})
	g.call("add_edge", j3, d4, "primary", "static", BAND)
	# The back door, round the oak's right side.
	var r1: int = g.call("add_node", "bend", _p(5.4, -7.9), b)
	var r2: int = g.call("add_node", "bend", _p(5.4, -17.4), b)
	var r3: int = g.call("add_node", "bend", _p(2.0, -20.8), b)
	var door: int = g.call("add_node", "destination", _p(0.0, -20.8), {"band": BAND, "state": "arrival", "target": "Door", "frame": "rect", "approach": Vector2(0, 1)})
	g.call("add_edge", j3, r1, "primary", "static", BAND)
	g.call("add_edge", r1, r2, "primary", "static", BAND)
	g.call("add_edge", r2, r3, "primary", "static", BAND)
	g.call("add_edge", r3, door, "primary", "static", BAND)
	return g
