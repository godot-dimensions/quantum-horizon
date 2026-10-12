extends SceneTree

## The water scene's route, written as the carried PathCreator's graph (F4-editable later): from the
## door out along the pier to the platform (pier 2 went in round 2; the scene moves the ends to fit). Positions are in the networks' own frame (they stand at the decks' height), and
## follow seascape_4d.gd's default layout. Headless; "force" rewrites existing graphs.

const Graph := preload("res://ramon/WaterLab/carried/PathCreator/graph/path_graph.gd")
const DIR := "res://ramon/WaterLab/seascape/paths/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var force: bool = "force" in OS.get_cmdline_user_args()
	if force or not ResourceLoader.exists(DIR + "pier1.tres"):
		print("PATHS pier1: ", ResourceSaver.save(_pier1(), DIR + "pier1.tres"))
	quit()


func _p(x: float, z: float, w: float = 0.0) -> Vector4:
	return Vector4(x, 0.0, z, w)


## Door 1 at (0, 0); the run straight to x 14 and the platform centred at (20.4, 0), radius 7.
func _pier1() -> Resource:
	var g: Resource = Graph.new()
	var s: int = g.call("add_node", "start", _p(1.4, 0.0), {"band": 4.0})
	# Where you step onto the platform (its footprint starts at x 13.4): a destination outside the
	# target it is for, as the checker wants.
	var d: int = g.call("add_node", "destination", _p(12.8, 0.0), {"band": 4.0, "state": "arrival", "target": "Platform", "frame": "round", "approach": Vector2(-1, 0)})
	g.call("add_edge", s, d, "primary", "static", 4.0)
	return g
