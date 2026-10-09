extends SceneTree

## The tank room's route, written as the carried PathCreator's graph (F4 edits it later). Straight runs
## and square turns only (Ramon, 9 Oct: "strict, like boxy paths"; "make sure the main path stays
## straight. at most a little subpath branch"): from the corridor north up the left of the hall, at
## the first turn right along the tank's glass, at the second north up the gap by the tank's end to
## the sci-fi door. The row runs a metre from the tank's stand, and half way along it the route passes
## through the turning circle, a destination node with a big round frame. One branch: from the
## second turn the other way, straight south along the research wall, to the koi showcase in the
## south-east corner (Ramon: "put the koi presenter pedestal in this empty corner instead"). Positions follow water_lab.tscn (the hall 24 x 24 m,
## centred: since 9 Oct, 28 x 28 m, Ramon: "a little bit more space to breathe around"). Headless;
## "force" rewrites the graph.

const Graph := preload("res://ramon/WaterLab/carried/PathCreator/graph/path_graph.gd")
const DIR := "res://ramon/WaterLab/paths/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var force: bool = "force" in OS.get_cmdline_user_args()
	if force or not ResourceLoader.exists(DIR + "hall.tres"):
		var g: Resource = _hall()
		print("PATHS hall: ", ResourceSaver.save(g, DIR + "hall.tres"), " ", g.call("validate"))
	quit()


func _p(x: float, z: float) -> Vector4:
	return Vector4(x, 0.0, z, 0.0)


func _hall() -> Resource:
	var g: Resource = Graph.new()
	var band: float = 8.0
	var s: int = g.call("add_node", "start", _p(-11.0, 16.6), {"band": band, "approach": Vector2(0, 1)})
	# Close along the glass (Ramon: "make the path move closely along the fishtank, and in the mid of
	# the fishtank add a node for a bigger circle"): the row a metre from the tank's stand, and half way
	# along it, on the route, the turning circle's node, its big round frame round it.
	var turn1: int = g.call("add_node", "bend", _p(-11.0, -8.2), {"band": band})
	var spin: int = g.call("add_node", "destination", _p(-4.23, -8.2), {"band": band, "state": "available", "target": "TurnSpot", "frame": "round", "approach": Vector2(-1, 0)})
	var turn2: int = g.call("add_node", "junction", _p(10.0, -8.2), {"band": band})
	# The showcase: its pedestal (radius 1.85) at (10, 10.4); the destination just outside it.
	var koi: int = g.call("add_node", "destination", _p(10.0, 7.9), {"band": band, "state": "available", "target": "Showcase", "frame": "round", "approach": Vector2(0, -1)})
	var door: int = g.call("add_node", "destination", _p(10.0, -12.4), {"band": band, "state": "arrival", "target": "ExitDoor", "frame": "rect", "approach": Vector2(0, 1)})
	g.call("add_edge", s, turn1, "primary", "static", band)
	g.call("add_edge", turn1, spin, "primary", "static", band)
	g.call("add_edge", spin, turn2, "primary", "static", band)
	g.call("add_edge", turn2, door, "primary", "static", band)
	g.call("add_edge", turn2, koi, "secondary", "static", band)
	return g
