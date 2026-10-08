extends SceneTree

## The water scene's two routes, written as the carried PathCreator's graphs (F4-editable later):
## pier 1 from door 1 out along the run, round the left turn, to the platform; pier 2 from door 2
## to its circle. Positions are in the networks' own frame (they stand at the decks' height), and
## follow water4d_test_ramon_4d.gd's default layout. Headless; "force" rewrites existing graphs.

const Graph := preload("res://ramon/Water/carried/PathCreator/graph/path_graph.gd")
const DIR := "res://ramon/Water/paths/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var force: bool = "force" in OS.get_cmdline_user_args()
	if force or not ResourceLoader.exists(DIR + "pier1.tres"):
		print("PATHS pier1: ", ResourceSaver.save(_pier1(), DIR + "pier1.tres"))
	if force or not ResourceLoader.exists(DIR + "pier2.tres"):
		print("PATHS pier2: ", ResourceSaver.save(_pier2(), DIR + "pier2.tres"))
	quit()


func _p(x: float, z: float, w: float = 0.0) -> Vector4:
	return Vector4(x, 0.0, z, w)


## Door 1 at (0, 0); the run to x 26, its corner centred at x 24.3; the turn down to the platform
## centred at (24.3, -16.1), radius 7.
func _pier1() -> Resource:
	var g: Resource = Graph.new()
	var s: int = g.call("add_node", "start", _p(1.4, 0.0), {"band": 4.0})
	var b1: int = g.call("add_node", "bend", _p(24.3, 0.0), {"band": 4.0})
	# Where you step onto the platform (its footprint runs to z -9.1): a destination outside the
	# target it is for, as the checker wants.
	var d: int = g.call("add_node", "destination", _p(24.3, -8.4), {"band": 4.0, "state": "arrival", "target": "Platform", "frame": "round", "approach": Vector2(0, 1)})
	g.call("add_edge", s, b1, "primary", "static", 4.0)
	g.call("add_edge", b1, d, "primary", "static", 4.0)
	g.call("round_corner", b1, 1.2)
	return g


## Door 2 at (0, 24); the circle at (25.5, 24), radius 2.2 (its target's footprint 4.4 m).
func _pier2() -> Resource:
	var g: Resource = Graph.new()
	var s: int = g.call("add_node", "start", _p(1.4, 24.0), {"band": 4.0})
	var d: int = g.call("add_node", "destination", _p(22.6, 24.0), {"band": 4.0, "state": "arrival", "target": "Circle", "frame": "round", "approach": Vector2(-1, 0)})
	g.call("add_edge", s, d, "primary", "static", 4.0)
	return g
