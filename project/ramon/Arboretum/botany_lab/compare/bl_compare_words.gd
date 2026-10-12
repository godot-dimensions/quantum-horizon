extends Node

## BOTANY LAB, THE SECOND ROOM: what a side's floating panel says (plan step 74): the live numbers of its
## half (bl_compare_4d.gd stats), and on E its method and its limits.
##
## NO class_name (engine_gotchas.md).

## "blocky" or "smooth".
@export var side: String = "blocky"
## The room (bl_compare_4d.gd), from this node.
@export var room: NodePath = ^"../.."


func _stats() -> Dictionary:
	var r: Node = get_node_or_null(room)
	return (r.get("stats") as Dictionary) if r != null else {}


func face() -> Array:
	var st: Dictionary = _stats()
	var land: Dictionary = st.get(side, {})
	var trees: Dictionary = st.get("trees", {})
	if side == "blocky":
		return [["Cells of 0.5 m", Bake.thousands(int(land.get("cells", 0)))],
			["Tetrahedra", "%s land, %s trees" % [Bake.thousands(int(land.get("tets", 0))), Bake.thousands(int(trees.get("blocky_tets", 0)))]],
			["Built in", Bake.ms(float(land.get("ms", 0.0))) + " in GDScript"]]
	return [["Edits in the engine's world", Bake.thousands(int(land.get("edits", 0)))],
		["Tetrahedra", "%s land, %s trees" % [Bake.thousands(int(land.get("tets", 0))), Bake.thousands(int(trees.get("smooth_tets", 0)))]],
		["Leaves on the GPU", Bake.thousands(int(trees.get("leaves", 0)))]]


func panel_pages() -> Array:
	if side == "blocky":
		return [{"title": "Method", "kicker": "THE BLOCKY WAY  ·  HOW IT IS BUILT",
				"text": "One height for every 0.5 m of floor, read from noise over x, z and W. The column of cells under it is filled, the top cell grass. Each filled cell is a box in 4D, drawn as only the faces an empty neighbour can see, the same mesher as pedestal 01's tree."},
			{"title": "Limits", "kicker": "THE BLOCKY WAY  ·  WHAT IT CANNOT DO",
				"text": "Every slope is a staircase and every silhouette square. Finer cells cost by the cube: half the cell, about eight times the tetrahedra."}]
	return [{"title": "Method", "kicker": "THE SMOOTH WAY  ·  HOW IT IS BUILT",
			"text": "The same heights written into the engine's own voxel world: a column of soil under each, a ball of grass at its top. The engine dual-contours the whole field in C++, so the columns and balls melt into one rounded surface."},
		{"title": "Limits", "kicker": "THE SMOOTH WAY  ·  WHAT IT CANNOT DO",
			"text": "Each tetrahedron is flat-shaded, so the hills are faceted close up. A ridge thinner than a voxel is lost. The world has no collision of its own yet."}]


const Bake := preload("res://ramon/Arboretum/botany/bake_store.gd")
