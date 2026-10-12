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
	# Round 2 (Ramon's walkthrough, 9 Oct): the hall 30 x 18 m (its west wall at x -16, its south wall at
	# z 4), the path starting at the back of the corridor and running along the tank at z -7.7, through
	# the turning square painted on the floor in front of the tank's middle: the route ends at the
	# square's edge and starts again past it ("you could end the path, made the square, and then
	# continue"); the square's node draws no art (the paint is the destination) and keeps the route
	# clear of it. The branch south to the showcase (twice the size: radius 3.7 at (9.5, -1.8)).
	var g: Resource = Graph.new()
	var band: float = 8.0
	var s: int = g.call("add_node", "start", _p(-11.0, 13.6), {"band": band, "approach": Vector2(0, 1)})
	var turn1: int = g.call("add_node", "bend", _p(-11.0, -7.7), {"band": band})
	var square: int = g.call("add_node", "destination", _p(-5.23, -7.7), {"band": band, "state": "available", "target": "TurnSpot", "frame": "rect",
		"approach": Vector2(-1, 0), "symbol": false, "clear": 1.62})
	var turn2: int = g.call("add_node", "junction", _p(10.0, -7.7), {"band": band})
	# Round 4: the showcase 1 m off the south wall and 1 m off the east wall, (10, 0), radius 3; the
	# branch from the junction runs on to just short of it.
	var koi: int = g.call("add_node", "destination", _p(10.0, -3.7), {"band": band, "state": "available", "target": "Showcase", "frame": "round", "approach": Vector2(0, -1)})
	var door: int = g.call("add_node", "destination", _p(10.0, -12.4), {"band": band, "state": "arrival", "target": "ExitDoor", "frame": "rect", "approach": Vector2(0, 1)})
	g.call("add_edge", s, turn1, "primary", "static", band)
	g.call("add_edge", turn1, square, "primary", "static", band)
	g.call("add_edge", square, turn2, "primary", "static", band)
	g.call("add_edge", turn2, door, "primary", "static", band)
	g.call("add_edge", turn2, koi, "secondary", "static", band)
	return g
