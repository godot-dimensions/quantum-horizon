extends SceneTree

## Voxel Lab, plan step 27: the room's route graphs, written once here (the F4 builder may edit them
## after): VoxelLab/paths/hall.tres and gallery.tres (the carried PathCreator's path_graph.gd), after
## the Arboretum's _make_paths_runner.gd. Every position is in the room's own frame (the networks stand
## at its origin). Args after --: "force" writes over graphs that exist (it would lose builder edits).
##
## THE HALL: from the corridor to a choice just inside the door; the route goes right to the shelf of
## pre-cut specimens, across to the block's bench, left to the column's bench, and back to the gallery
## door.
## THE GALLERY: from its door to Andrew's terrain sample (its bench), across to his caves (theirs), then
## the 24-cell and the ladder at the back, and the far door to the field.

const Graph := preload("res://ramon/VoxelLab/carried/PathCreator/graph/path_graph.gd")

const DIR := "res://ramon/VoxelLab/paths/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var force: bool = "force" in OS.get_cmdline_user_args()
	if force or not ResourceLoader.exists(DIR + "hall.tres"):
		print("PATHS hall: ", ResourceSaver.save(_hall(), DIR + "hall.tres"))
	if force or not ResourceLoader.exists(DIR + "gallery.tres"):
		print("PATHS gallery: ", ResourceSaver.save(_gallery(), DIR + "gallery.tres"))
	quit()


func _p(x: float, z: float, w: float = 0.0) -> Vector4:
	return Vector4(x, 0.0, z, w)


func _dest(g: Resource, at: Vector4, target: String, frame: String, approach: Vector2, state: String = "arrival") -> int:
	return g.call("add_node", "destination", at, {"band": 8.0, "state": state, "target": target, "frame": frame, "approach": approach})


func _hall() -> Resource:
	var g: Resource = Graph.new()
	var s: int = g.call("add_node", "start", _p(0, 21.0), {"band": 8.0})
	var j: int = g.call("add_node", "junction", _p(0, 13.5), {"band": 8.0})
	g.call("add_edge", s, j, "primary", "static", 8.0)
	# The shelf, on the right.
	var b1: int = g.call("add_node", "bend", _p(3.2, 10.4), {"band": 8.0})
	var shelf: int = _dest(g, _p(6.0, 4.4), "Shelf", "rect", Vector2(-1, 0), "available")
	g.call("add_edge", j, b1, "primary", "static", 8.0)
	g.call("add_edge", b1, shelf, "primary", "static", 8.0)
	# Across to the block's bench, in front of its pedestal.
	var b2: int = g.call("add_node", "bend", _p(3.0, 6.6), {"band": 8.0})
	var bench: int = _dest(g, _p(0.0, 6.0), "HeroBench", "rect", Vector2(0, 1))
	g.call("add_edge", shelf, b2, "primary", "static", 8.0)
	g.call("add_edge", b2, bench, "primary", "static", 8.0)
	# Left to the column's bench.
	var b3: int = g.call("add_node", "bend", _p(-3.6, 3.2), {"band": 8.0})
	var col: int = _dest(g, _p(-8.2, 0.2), "ColumnBench", "rect", Vector2(0, 1))
	g.call("add_edge", bench, b3, "primary", "static", 8.0)
	g.call("add_edge", b3, col, "primary", "static", 8.0)
	# Back to the gallery door, past the column's left.
	var b4: int = g.call("add_node", "bend", _p(-4.8, -7.4), {"band": 8.0})
	var b5: int = g.call("add_node", "bend", _p(-1.4, -11.8), {"band": 8.0})
	var door: int = _dest(g, _p(0.0, -13.4), "GalleryDoor", "rect", Vector2(0, 1))
	g.call("add_edge", col, b4, "primary", "static", 8.0)
	g.call("add_edge", b4, b5, "primary", "static", 8.0)
	g.call("add_edge", b5, door, "primary", "static", 8.0)
	return g


func _gallery() -> Resource:
	var g: Resource = Graph.new()
	var s: int = g.call("add_node", "start", _p(0, -16.2), {"band": 8.0})
	var j: int = g.call("add_node", "junction", _p(0, -17.6), {"band": 8.0})
	g.call("add_edge", s, j, "primary", "static", 8.0)
	var terrain: int = _dest(g, _p(-4.6, -17.6), "TerrainBench", "rect", Vector2(1, 0), "available")
	g.call("add_edge", j, terrain, "primary", "static", 8.0)
	var b1: int = g.call("add_node", "bend", _p(0.0, -19.6), {"band": 8.0})
	var caves: int = _dest(g, _p(4.6, -17.6), "CavesBench", "rect", Vector2(-1, 0))
	g.call("add_edge", terrain, b1, "primary", "static", 8.0)
	g.call("add_edge", b1, caves, "primary", "static", 8.0)
	var b2: int = g.call("add_node", "bend", _p(1.6, -24.4), {"band": 8.0})
	var cell: int = _dest(g, _p(-4.2, -27.4), "Cell24", "round", Vector2(1, 0))
	g.call("add_edge", caves, b2, "primary", "static", 8.0)
	g.call("add_edge", b2, cell, "primary", "static", 8.0)
	var ladder: int = _dest(g, _p(4.2, -27.4), "Ladder", "rect", Vector2(-1, 0))
	g.call("add_edge", cell, ladder, "primary", "static", 8.0)
	var door: int = _dest(g, _p(0.0, -30.4), "FieldDoorTarget", "rect", Vector2(0, 1))
	g.call("add_edge", ladder, door, "primary", "static", 8.0)
	return g
