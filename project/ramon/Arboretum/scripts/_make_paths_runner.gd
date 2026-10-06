extends SceneTree

## Plan steps 85 and 87: the Arboretum's route graphs, written here once (the F4 builder edits them
## after): Arboretum/paths/hall.tres and grove.tres (the carried PathCreator's path_graph.gd). Every
## position is in the room's own frame (the networks stand at its origin). Args after --: "force" to
## write over graphs that exist (it would lose builder edits).
##
## THE HALL: from the corridor to a choice just inside the door; a primary route zigzags to the four
## pedestals in order (01 left, 02 right, 03 left, the oak at the end of the axis) and on round the oak
## to the grove door; a secondary route to the PLAY THE SHOWCASE pad. Each destination stands where
## you look from, its frame round the pedestal (round, or square for 01's box).
## THE GROVE: from its door down the middle aisle to the crossing where the four plot signs stand, and
## a FOLLOW route that climbs through W from the crossing to the trees that stand only ana of you
## (PathCreator's follow mode: walking through W unrolls it; the W cue says which way).

const Graph := preload("res://ramon/Arboretum/carried/PathCreator/graph/path_graph.gd")

const DIR := "res://ramon/Arboretum/paths/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var force: bool = "force" in OS.get_cmdline_user_args()
	if force or not ResourceLoader.exists(DIR + "hall.tres"):
		print("PATHS hall: ", ResourceSaver.save(_hall(), DIR + "hall.tres"))
	if force or not ResourceLoader.exists(DIR + "grove.tres"):
		print("PATHS grove: ", ResourceSaver.save(_grove(), DIR + "grove.tres"))
	quit()


func _p(x: float, z: float, w: float = 0.0) -> Vector4:
	return Vector4(x, 0.0, z, w)


func _hall() -> Resource:
	var g: Resource = Graph.new()
	var s: int = g.call("add_node", "start", _p(0, 19.5), {"band": 8.0})
	var j: int = g.call("add_node", "junction", _p(0, 13.0), {"band": 8.0})
	g.call("add_edge", s, j, "primary", "static", 8.0)
	# The showcase pad, secondary.
	var tb: int = g.call("add_node", "bend", _p(3.0, 13.0), {"band": 8.0})
	var tour: int = g.call("add_node", "destination", _p(5.2, 12.6), {"band": 8.0, "state": "available", "target": "Tour", "frame": "none", "approach": Vector2(-1, 0)})
	g.call("add_edge", j, tb, "secondary", "static", 8.0)
	g.call("add_edge", tb, tour, "secondary", "static", 8.0)
	# 01 (left): stand right of it, looking at it.
	var b1: int = g.call("add_node", "bend", _p(-1.6, 10.6), {"band": 8.0})
	var d1: int = g.call("add_node", "destination", _p(-3.6, 8.0), {"band": 8.0, "state": "available", "target": "P1", "frame": "rect", "approach": Vector2(1, 0)})
	g.call("add_edge", j, b1, "primary", "static", 8.0)
	g.call("add_edge", b1, d1, "primary", "static", 8.0)
	# 02 (right).
	var b2: int = g.call("add_node", "bend", _p(0.0, 4.4), {"band": 8.0})
	var d2: int = g.call("add_node", "destination", _p(3.6, 1.0), {"band": 8.0, "state": "arrival", "target": "P2", "frame": "round", "approach": Vector2(-1, 0)})
	g.call("add_edge", d1, b2, "primary", "static", 8.0)
	g.call("add_edge", b2, d2, "primary", "static", 8.0)
	# 03 (left).
	var b3: int = g.call("add_node", "bend", _p(0.0, -2.6), {"band": 8.0})
	var d3: int = g.call("add_node", "destination", _p(-3.6, -6.0), {"band": 8.0, "state": "arrival", "target": "P3", "frame": "round", "approach": Vector2(1, 0)})
	g.call("add_edge", d2, b3, "primary", "static", 8.0)
	g.call("add_edge", b3, d3, "primary", "static", 8.0)
	# 04, the oak, at the end of the axis.
	var b4: int = g.call("add_node", "bend", _p(0.0, -7.6), {"band": 8.0})
	var d4: int = g.call("add_node", "destination", _p(1.6, -8.6), {"band": 8.0, "state": "arrival", "target": "P4", "frame": "round", "approach": Vector2(0, 1)})
	g.call("add_edge", d3, b4, "primary", "static", 8.0)
	g.call("add_edge", b4, d4, "primary", "static", 8.0)
	# Round the oak's right side to the grove door.
	var b5: int = g.call("add_node", "bend", _p(6.2, -10.0), {"band": 8.0})
	var b6: int = g.call("add_node", "bend", _p(6.2, -16.4), {"band": 8.0})
	var b7: int = g.call("add_node", "bend", _p(2.4, -19.6), {"band": 8.0})
	var door: int = g.call("add_node", "destination", _p(0.0, -20.4), {"band": 8.0, "state": "arrival", "target": "Door", "frame": "rect", "approach": Vector2(0, 1)})
	g.call("add_edge", d4, b5, "primary", "static", 8.0)
	g.call("add_edge", b5, b6, "primary", "static", 8.0)
	g.call("add_edge", b6, b7, "primary", "static", 8.0)
	g.call("add_edge", b7, door, "primary", "static", 8.0)
	return g


func _grove() -> Resource:
	var g: Resource = Graph.new()
	# The grove room's door is at the hall's back wall (z -22); the crossing of its aisles at z -40.5.
	var s: int = g.call("add_node", "start", _p(0, -24.0), {"band": 7.0})
	var b: int = g.call("add_node", "bend", _p(0, -33.0), {"band": 7.0})
	var x: int = g.call("add_node", "junction", _p(0, -37.6), {"band": 7.0})
	g.call("add_edge", s, b, "primary", "static", 7.0)
	g.call("add_edge", b, x, "primary", "static", 7.0)
	# On down the aisle to the back wall and its painted line.
	var back: int = g.call("add_node", "destination", _p(0, -54.0), {"band": 7.0, "state": "available", "target": "GroveBack", "frame": "none", "approach": Vector2(0, 1)})
	g.call("add_edge", x, back, "secondary", "static", 7.0)
	# The follow route: from the crossing up through W to the trees ana of you, in the lofted plot.
	var f1: int = g.call("add_node", "bend", _p(-3.0, -41.0, 0.0), {"band": 1.2})
	var f2: int = g.call("add_node", "bend", _p(-6.0, -45.0, 1.2), {"band": 1.2})
	var ana: int = g.call("add_node", "destination", _p(-9.0, -47.5, 2.2), {"band": 1.4, "state": "available", "target": "AnaGrove", "frame": "round", "approach": Vector2(1, 1)})
	g.call("add_edge", x, f1, "primary", "static", 7.0)
	g.call("add_edge", f1, f2, "primary", "follow", 1.2)
	g.call("add_edge", f2, ana, "primary", "follow", 1.2)
	return g
